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

    describe("the list view", function()
        it("shows the name in the difficulty color, with how many can be made, and for the unknown ones skill and source", function()
            ns.RecipeList_Set(rows(), "list", nil, 60)
            local shown = rowsShown()
            assert.are.equal(4, #shown)
            assert.are.equal("Elixir of Wisdom (2)", shown[2].text._text)
            assert.are.same({ 1, 1, 0 }, shown[2].text._set.SetTextColor)
            assert.are.equal("Skill 250  Vendor", shown[4].info._text)
            assert.are.equal(24, shown[2]:GetHeight())
        end)
    end)

    describe("the table view", function()
        it("has a column for components, cost, auction value and level", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local row = rowsShown()[2]
            assert.are.equal("2x Peacebloom, 1x item 11", row.comp._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
            assert.matches("1|cffffd100g|r 20|cffc7c7cfs|r%+", row.cost._text) -- incomplete: a floor
            assert.matches("5|cffffd100g|r", row.value._text)
            assert.matches("55", row.level._text)
            local other = rowsShown()[4]
            assert.are.equal("-", other.value._text) -- no auction price
            assert.matches("|cffff4c4c250|r", other.level._text) -- skill 60 isn't enough for 250: red
        end)

        it("colors the components of a known recipe by whether the bags have them", function()
            ns.RecipeList_Set(rows(), "table", nil, 60)
            local text = rowsShown()[2].comp._text
            assert.matches("|cff40bf402x Peacebloom|r", text) -- has 5
            assert.matches("|cffff60601x item 11|r", text) -- has none
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
            ns.RecipeList_Set(rows(), "list", nil, 60)
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
            assert.matches("Peacebloom", row.line3._text)
            assert.matches("Cost", row.info._text)
            assert.matches("AH", row.info._text)
            assert.matches("Skill 250", rowsShown()[4].line2._text)
            assert.matches("Vendor", rowsShown()[4].line2._text)
        end)
    end)

    describe("the group titles", function()
        it("show a minus when open and a plus when folded, and fold or unfold on a click", function()
            ns.RecipeList_Set(rows(), "list", nil, 60)
            local shown = rowsShown()
            assert.matches("MinusButton", shown[1].icon._set.SetTexture[1])
            assert.matches("PlusButton", shown[3].icon._set.SetTexture[1])
            assert.are.equal("Known recipes (1)", shown[1].text._text)
            shown[3]._scripts.OnClick(shown[3])
            assert.are.equal("unknown", toggled)
        end)
    end)

    it("the scroll's content is as tall as the rows of the view", function()
        local content = WowMock.Find(function(f) return f._kind == "Frame" and f._parent and f._parent._kind == "ScrollFrame" end)
        ns.RecipeList_Set(rows(), "list", nil, 60)
        assert.are.equal(24 * 4, content._h)
        ns.RecipeList_Set(rows(), "detailed", nil, 60)
        assert.are.equal(24 + 58 + 24 + 58, content._h)
    end)
end)
