dofile("setupTests.lua")

describe("RecipeList", function()
    local ns, sorted, toggled, parent

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local known = {
        id = 1, name = "Elixir of Wisdom", icon = 5, learned = true, difficulty = 1, required = 55,
        colors = { 55, 75, 95, 115 },
        reagents = { { items = { 10 }, quantity = 2 }, { items = { 11 }, quantity = 1 } },
        db = { s = 171, n = "Elixir", k = { 6 } },
    }
    local unknown = {
        id = 2, name = "Mighty Flask", icon = 6, learned = false, required = 250, colors = { 250, 270, 290, 310 },
        reagents = { { items = { 12 }, quantity = 3 } }, db = { s = 171, n = "Flask", k = { 5 } },
    }

    local function rows()
        return {
            { kind = "header", text = "Known recipes", count = 1, group = "known", collapsed = false },
            { kind = "recipe", recipe = known, craftable = 2, cost = 12034, incomplete = true, value = 50003 },
            { kind = "header", text = "Not known", count = 1, group = "unknown", collapsed = true },
            { kind = "recipe", recipe = unknown, craftable = 0, cost = 500 },
        }
    end

    before_each(function()
        WowMock.Reset()
        local names = { [10] = "Peacebloom", [12] = "Dreamfoil" }
        _G.C_Item = { GetItemNameByID = function(id) return names[id] end, GetItemCount = function(id) return ({ [10] = 5, [12] = 0 })[id] or 0 end }
        ns = LoadAddon()
        sorted, toggled = nil, nil
        parent = WowMock.NewFrame("Frame", nil, UIParent)
        ns.RecipeList_Create(parent, function(key) sorted = key end, function(group) toggled = group end)
    end)

    local function rowsShown() return framesWith("data") end


    describe("the table view", function()
        it("shows the name in the difficulty color, with how many can be made", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local shown = rowsShown()
            assert.are.equal(4, #shown)
            assert.are.equal("Elixir of Wisdom (2)", shown[2].text._text)
            assert.are.same({ 1, 1, 0 }, shown[2].text._set.SetTextColor)
            assert.are.equal(24, shown[2]:GetHeight())
        end)

        it("has a column for cost, auction value and level", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local row = rowsShown()[2]
            assert.matches("1|cffffd100g|r 20|cffc7c7cfs|r%+", row.cost._text) -- incomplete: a floor
            assert.matches("5|cffffd100g|r", row.value._text)
            assert.matches("55", row.level._text)
            local other = rowsShown()[4]
            assert.are.equal("-", other.value._text) -- no auction price
            assert.matches("|cffff4c4c250|r", other.level._text) -- skill 60 isn't enough for 250: red
        end)

        it("shows the ingredients as icons with their count, the missing ones of a known recipe tinted red", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local icons = rowsShown()[2].compIcons
            assert.are.equal(10, icons[1].itemID)
            assert.are.equal("2", icons[1].count._text)
            assert.are.same({ 1, 1, 1 }, icons[1].texture._set.SetVertexColor) -- the bags have 5
            assert.are.equal(11, icons[2].itemID)
            assert.are.equal("", icons[2].count._text) -- one of them: no number
            assert.are.same({ 1, 0.35, 0.35 }, icons[2].texture._set.SetVertexColor) -- the bags have none
            assert.is_true(icons[1]:IsShown())
            assert.is_false(rowsShown()[2].comp:IsShown())
            -- a recipe the character doesn't know isn't tinted
            local unknownIcon = rowsShown()[4].compIcons[1]
            assert.are.same({ 1, 1, 1 }, unknownIcon.texture._set.SetVertexColor)
        end)

        it("an ingredient's icon shows the item's tooltip and how many are needed and owned", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local icon = rowsShown()[2].compIcons[1]
            icon._scripts.OnEnter(icon)
            assert.are.same({ 10 }, GameTooltip._set.SetItemByID)
        end)

        it("shows a dash for a recipe without known ingredients, and a +n when the icons don't fit", function()
            local plain = { id = 3, name = "Plain", icon = 7, learned = false, reagents = {}, db = { s = 171, n = "Plain" } }
            local many = { id = 4, name = "Many", icon = 7, learned = false, db = { s = 171, n = "Many" }, reagents = {} }
            for i = 1, 14 do many.reagents[i] = { items = { 100 + i }, quantity = 1 } end
            ns.RecipeList_Set({ { kind = "recipe", recipe = plain, craftable = 0 }, { kind = "recipe", recipe = many, craftable = 0 } }, "table", nil, 60)
            local shown = rowsShown()
            assert.are.equal("-", shown[1].comp._text)
            assert.is_true(shown[1].comp:IsShown())
            assert.matches("^%+%d+$", shown[2].compMore._text)
            local visibleIcons = 0
            for _, icon in ipairs(shown[2].compIcons) do if icon:IsShown() then visibleIcons = visibleIcons + 1 end end
            assert.is_true(visibleIcons >= 1 and visibleIcons < 14)
            assert.are.equal(14, visibleIcons + tonumber(shown[2].compMore._text:sub(2)))
        end)

        it("shows the column titles, which sort", function()
            ns.RecipeList_Set(rows(), "table", { key = "cost", desc = true }, 60)
            local cost = WowMock.Find(function(f) return f.sortKey == "cost" and f.text and f.text._text end)
            assert.is_not_nil(cost)
            assert.matches("Cost v", cost.text._text) -- descending
            cost._scripts.OnClick(cost)
            assert.are.equal("cost", sorted)
            local components = WowMock.Find(function(f) return f.text and f.text._text == "Components" end)
            components._scripts.OnClick(components)
            assert.are.equal("cost", sorted) -- not a sortable column
        end)

        it("only the table has column titles", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local header = ns.RecipeList_HeaderFrame()
            assert.is_true(header:IsShown())
            ns.RecipeList_Set(rows(), "detailed", nil, 60)
            assert.is_false(header:IsShown())
        end)
    end)

    describe("the detailed view", function()
        it("has a big icon and three lines", function()
            ns.RecipeList_Set(rows(), "detailed", nil, 60)
            local row = rowsShown()[2]
            assert.are.equal(58, row:GetHeight())
            assert.are.same({ 44, 44 }, { row.icon._w, row.icon._h })
            assert.are.equal("Elixir of Wisdom (2)", row.text._text)
            assert.matches("Skill 55", row.line2._text)
            assert.matches("|cffffff00", row.line2._text) -- the colors of the recipe
            assert.matches("Known", row.line2._text)
            assert.matches("Cost", row.info._text)
            assert.matches("AH", row.info._text)
            assert.matches("Skill 250", rowsShown()[4].line2._text)
            assert.matches("Vendor", rowsShown()[4].line2._text)
        end)
    end)

    describe("the detailed view's ingredients", function()
        it("are icons with the item's tooltip, on the third line", function()
            ns.RecipeList_Set(rows(), "detailed", nil, 60)
            local row = rowsShown()[2]
            local icon = row.compIcons[1]
            assert.is_true(icon:IsShown())
            assert.are.same({ 16, 16 }, { icon._w, icon._h })
            assert.is_false(row.line3:IsShown())
            icon._scripts.OnEnter(icon)
            assert.are.same({ 10 }, GameTooltip._set.SetItemByID)
        end)

        it("give way to the table's when the view changes back", function()
            ns.RecipeList_Set(rows(), "detailed", nil, 60)
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local icon = rowsShown()[2].compIcons[1]
            assert.is_true(icon:IsShown())
            assert.are.same({ 20, 20 }, { icon._w, icon._h })
        end)

        it("show a dash for a recipe without known ingredients", function()
            local plain = { id = 3, name = "Plain", icon = 7, learned = false, reagents = {}, db = { s = 171, n = "Plain" } }
            ns.RecipeList_Set({ { kind = "recipe", recipe = plain, craftable = 0 } }, "detailed", nil, 60)
            local row = rowsShown()[1]
            assert.are.equal("-", row.line3._text)
            assert.is_true(row.line3:IsShown())
        end)
    end)

    describe("the group titles", function()
        it("show a minus when open and a plus when folded, and fold or unfold on a click", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local shown = rowsShown()
            assert.matches("MinusButton", shown[1].icon._set.SetTexture[1])
            assert.matches("PlusButton", shown[3].icon._set.SetTexture[1])
            assert.are.equal("Known recipes (1)", shown[1].text._text)
            shown[3]._scripts.OnClick(shown[3])
            assert.are.equal("unknown", toggled)
        end)
    end)

    describe("many recipes", function()
        local function manyRows(count)
            local out = {}
            for i = 1, count do
                local recipe = { id = i, name = "R" .. i, icon = 5, learned = false, required = i, reagents = {},
                    db = { s = 171, n = "R" .. i, k = { 5 } } }
                out[i] = { kind = "recipe", recipe = recipe, craftable = 0 }
            end
            return out
        end
        local function scroll() return WowMock.Find(function(f) return f._kind == "ScrollFrame" end) end
        local function content() return WowMock.Find(function(f) return f._kind == "Frame" and f._parent and f._parent._kind == "ScrollFrame" end) end
        local function made()
            return #WowMock.FindAll(function(f) return f._parent == content() and f.compIcons ~= nil end)
        end
        local function names()
            local out = {}
            for _, f in ipairs(WowMock.FindAll(function(f) return f._parent == content() and f.compIcons ~= nil and f:IsShown() end)) do
                out[#out + 1] = f.data.recipe.name
            end
            table.sort(out)
            return out
        end

        it("only makes frames for the rows in view, however many recipes there are", function()
            ns.RecipeList_Set(manyRows(600), "table", nil, 60)
            assert.is_true(made() < 60)
            assert.are.equal(24 * 600, content()._h) -- the scroll is as tall as all of them
        end)

        it("the same few frames show other rows as the list scrolls", function()
            ns.RecipeList_Set(manyRows(600), "table", nil, 60)
            local before = made()
            scroll():SetVerticalScroll(24 * 300)
            WowMock.Fire(scroll(), "OnVerticalScroll", 24 * 300)
            assert.are.equal(before, made()) -- reused, none new
            local shown = names()
            local found301 = false
            for _, name in ipairs(shown) do if name == "R301" then found301 = true end end
            assert.is_true(found301)
            for _, name in ipairs(shown) do assert.is_not.equal("R1", name) end
        end)

        it("the detailed view makes fewer frames still (the rows are taller)", function()
            ns.RecipeList_Set(manyRows(600), "detailed", nil, 60)
            assert.is_true(made() <= 20)
        end)

        it("with fewer rows after a filter, the list is not left scrolled past the end", function()
            ns.RecipeList_Set(manyRows(600), "table", nil, 60)
            scroll():SetVerticalScroll(24 * 500)
            ns.RecipeList_Set(manyRows(10), "table", nil, 60)
            assert.is_true(scroll():GetVerticalScroll() <= 24 * 10)
        end)
    end)

    describe("resizing the window", function()
        local timers, draws

        before_each(function()
            timers, draws = {}, 0
            _G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
            local original = ns.RecipeDB_ShortSource
            -- the detailed view asks it once for every unknown recipe it draws: a count of the redraws
            ns.RecipeDB_ShortSource = function(...) draws = draws + 1; return original(...) end
            ns.RecipeList_Set(rows(), "detailed", nil, 60)
            draws, timers = 0, {}
        end)

        local function scroll() return WowMock.Find(function(f) return f._kind == "ScrollFrame" end) end
        local function runTimers()
            local pending = timers
            timers = {}
            for _, f in ipairs(pending) do f() end
        end

        it("does not redraw the rows at every step of the drag, only the content's width follows", function()
            for width = 700, 720, 5 do
                scroll():SetWidth(width)
                scroll()._scripts.OnSizeChanged(scroll(), width)
                ns.RecipeList_Relayout()
            end
            assert.are.equal(0, draws)
            assert.are.equal(1, #timers) -- one wait, however many steps
            local content = WowMock.Find(function(f) return f._kind == "Frame" and f._parent and f._parent._kind == "ScrollFrame" end)
            assert.are.equal(720, content._w) -- the rows stretch with it
        end)

        it("redraws once when the size has stopped changing", function()
            scroll():SetWidth(700)
            ns.RecipeList_Relayout()
            runTimers()
            assert.are.equal(1, draws)
            assert.are.equal(0, #timers)
        end)

        it("keeps waiting while the size still changes", function()
            scroll():SetWidth(700)
            ns.RecipeList_Relayout()
            scroll():SetWidth(710)
            ns.RecipeList_Relayout() -- another step of the drag, before the wait ended
            runTimers()
            assert.are.equal(0, draws)
            assert.are.equal(1, #timers) -- waiting again
            runTimers()
            assert.are.equal(1, draws)
        end)

        it("a later resize waits and redraws again", function()
            ns.RecipeList_Relayout()
            runTimers()
            ns.RecipeList_Relayout()
            runTimers()
            assert.are.equal(2, draws)
        end)
    end)

    it("the scroll's content is as tall as the rows of the view", function()
        local content = WowMock.Find(function(f) return f._kind == "Frame" and f._parent and f._parent._kind == "ScrollFrame" end)
        ns.RecipeList_Set(rows(), "table", nil, 60)
        assert.are.equal(24 * 4, content._h)
        ns.RecipeList_Set(rows(), "detailed", nil, 60)
        assert.are.equal(24 + 58 + 24 + 58, content._h)
    end)
end)
