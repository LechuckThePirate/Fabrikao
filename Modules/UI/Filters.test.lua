dofile("setupTests.lua")

-- The recipes page with its filters, sorting, views and folding groups, with the real data path (recipes from
-- the data, "known" from the spell book).
describe("Recipes page", function()
    local ns, known

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 1, 20, 40, 60 }, m = { { 11, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Elixir of Giants", c = { 200, 220, 240, 260 }, m = { { 10, 1 } }, k = { 4 } },
            [4] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, m = { { 12, 1 } }, k = { 2 } },
        },
        items = {}, trainers = {},
    }

    local function visible(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f, button) f._scripts.OnClick(f, button or "LeftButton") end

    local function recipeNames()
        local out = {}
        for _, row in ipairs(visible("data")) do
            if row.data.kind == "recipe" then out[#out + 1] = row.data.recipe.name end
        end
        return out
    end

    local function button(prefix)
        -- (the skill's button drops its "Skill:" when it filters: it says what it filters)
        local function named(text)
            return text:sub(1, #prefix) == prefix or (prefix == "Skill:" and (text == "Learnable now" or text == "Needs more skill"))
        end
        return WowMock.Find(function(f) return type(f._text) == "string" and named(f._text) and f._scripts.OnClick and f:IsVisible() end)
    end

    local function checks()
        return WowMock.FindAll(function(f) return f._template == "UICheckButtonTemplate" and f:IsVisible() end)
    end

    local function openAlchemy()
        ns.UI_Toggle()
        click(visible("profession")[1])
    end

    before_each(function()
        WowMock.Reset()
        known = { [1] = true, [2] = true }
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 60, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
        local bag = { [10] = 4, [11] = 0, [12] = 0 }
        _G.C_Item = { GetItemCount = function(id) return bag[id] or 0 end, GetItemNameByID = function(id) return "Item" .. id end }
        _G.C_TradeSkillUI = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
    end)

    it("lists the known recipes first, then the unknown ones", function()
        openAlchemy()
        assert.are.same({ "Elixir of Wisdom", "Healing Potion", "Elixir of Giants", "Flask of the Titans" }, recipeNames())
    end)

    describe("folding the groups", function()
        it("a click on the title of a group folds it, and the state is kept", function()
            openAlchemy()
            click(visible("data")[1]) -- the title of the known ones
            assert.are.same({ "Elixir of Giants", "Flask of the Titans" }, recipeNames())
            assert.is_true(ns.char.collapsed.known)
            assert.matches("PlusButton", visible("data")[1].icon._set.SetTexture[1])
            click(visible("data")[1])
            assert.are.same({ "Elixir of Wisdom", "Healing Potion", "Elixir of Giants", "Flask of the Titans" }, recipeNames())
            assert.is_false(ns.char.collapsed.known)
        end)

        it("a folded group stays folded the next time", function()
            ns.char.collapsed = { unknown = true }
            openAlchemy()
            assert.are.same({ "Elixir of Wisdom", "Healing Potion" }, recipeNames())
        end)

        it("there are no checkboxes for known and not known any more", function()
            openAlchemy()
            assert.are.equal(2, #checks()) -- can make now, hide grey
        end)
    end)

    describe("the filters", function()
        it("can make now: what the bags allow, unknown recipes too", function()
            openAlchemy()
            local canMake = checks()[1]
            canMake:SetChecked(true)
            click(canMake)
            -- the bags have 4 of item 10 only: Elixir of Wisdom (2 each) and Elixir of Giants
            assert.are.same({ "Elixir of Wisdom", "Elixir of Giants" }, recipeNames())
            assert.is_true(ns.char.filters.canMake)
        end)

        it("hide grey: what gives no skill points at the character's skill", function()
            openAlchemy()
            local hideGrey = checks()[2]
            hideGrey:SetChecked(true)
            click(hideGrey)
            assert.are.same({ "Elixir of Wisdom", "Elixir of Giants", "Flask of the Titans" }, recipeNames())
        end)

        it("color: cycles all, orange, yellow, green, grey", function()
            openAlchemy()
            click(button("Color:")) -- orange: nothing at skill 60
            assert.matches("orange", button("Color:")._text)
            assert.are.same({}, recipeNames())
            click(button("Color:")) -- yellow
            assert.are.same({ "Elixir of Wisdom" }, recipeNames())
            click(button("Color:")) -- green
            click(button("Color:")) -- grey
            assert.are.same({ "Healing Potion" }, recipeNames())
            click(button("Color:")) -- all again
            assert.matches("All", button("Color:")._text)
            assert.are.equal(4, #recipeNames())
        end)

        it("skill: the unknown recipes the skill is enough to learn now, or not yet", function()
            _G.GetProfessionInfo = function() return "Alchemy", 5, 210, 300, 1, 10, 171, 0 end
            openAlchemy()
            click(button("Skill:"))
            assert.matches("Learnable now", button("Skill:")._text)
            assert.are.same({ "Elixir of Giants" }, recipeNames()) -- needs 200; the flask needs 250
            click(button("Skill:"))
            assert.matches("Needs more skill", button("Skill:")._text)
            assert.are.same({ "Flask of the Titans" }, recipeNames())
        end)

        it("source: the sources of the profession's recipes, one after the other", function()
            openAlchemy()
            click(button("Source:")) -- 2: drop
            assert.are.same({ "Flask of the Titans" }, recipeNames())
            click(button("Source:")) -- 4: quest
            assert.are.same({ "Elixir of Giants" }, recipeNames())
            click(button("Source:")) -- 6: trainer
            assert.are.same({ "Elixir of Wisdom", "Healing Potion" }, recipeNames())
            click(button("Source:")) -- all
            assert.are.equal(4, #recipeNames())
        end)

        it("clear brings everything back", function()
            openAlchemy()
            click(button("Source:"))
            click(button("Skill:"))
            click(button("Clear"))
            assert.are.equal(4, #recipeNames())
            assert.matches("All", button("Source:")._text)
            assert.matches("All", button("Skill:")._text)
        end)
    end)

    describe("sorting", function()
        it("the sort button goes through name, level, cost, value and can make; a right click turns it around", function()
            openAlchemy()
            click(button("Sort:"))
            assert.matches("Name %^", button("Sort:")._text)
            assert.are.same({ "Elixir of Wisdom", "Healing Potion", "Elixir of Giants", "Flask of the Titans" }, recipeNames())
            click(button("Sort:"), "RightButton")
            assert.matches("Name v", button("Sort:")._text)
            assert.are.same({ "Healing Potion", "Elixir of Wisdom", "Flask of the Titans", "Elixir of Giants" }, recipeNames())
            assert.are.equal("name", ns.char.filters.sort.key)
            assert.is_true(ns.char.filters.sort.desc)
            click(button("Sort:")) -- level
            assert.matches("Level", button("Sort:")._text)
        end)

        it("a click on a column title of the table sorts by it, a second one turns it around", function()
            ns.char.view = "table"
            openAlchemy()
            local level = WowMock.Find(function(f) return f.sortKey == "level" and f:IsVisible() end)
            click(level)
            assert.are.equal("level", ns.char.filters.sort.key)
            assert.is_false(ns.char.filters.sort.desc)
            click(level)
            assert.is_true(ns.char.filters.sort.desc)
        end)
    end)

    describe("the views", function()
        it("the page opens as a table; the view button goes to detailed and back, and the choice is kept", function()
            openAlchemy()
            assert.matches("Table", button("View:")._text)
            assert.is_not_nil(visible("data")[2].compIcons[1])
            click(button("View:"))
            assert.are.equal("detailed", ns.char.view)
            assert.matches("Detailed", button("View:")._text)
            assert.are.equal(58, visible("data")[2]:GetHeight())
            click(button("View:"))
            assert.are.equal("table", ns.char.view)
        end)

        it("a \"list\" saved by an older version opens as the table", function()
            ns.char.view = "list"
            openAlchemy()
            assert.matches("Table", button("View:")._text)
            assert.is_not_nil(visible("data")[2].compIcons[1])
        end)

        it("the view chosen in the preferences is the one the page opens with", function()
            ns.char.view = "detailed"
            openAlchemy()
            assert.are.equal(58, visible("data")[2]:GetHeight())
        end)
    end)

    describe("the window", function()
        it("has a gear that opens the preferences", function()
            ns.UI_Toggle()
            click(_G.FabrikaoFrame.gear)
            assert.is_true(_G.FabrikaoPreferencesFrame:IsShown())
        end)

        it("is resizable and keeps its size and place; the reset puts it back", function()
            ns.UI_Toggle()
            local grip = _G.FabrikaoFrame.grip
            _G.FabrikaoFrame:SetSize(900, 700)
            grip._scripts.OnMouseUp(grip)
            assert.are.equal(900, ns.char.window.w)
            assert.are.equal(700, ns.char.window.h)
            ns.UI_ResetWindow()
            assert.is_nil(ns.char.window)
            assert.are.equal(760, _G.FabrikaoFrame:GetWidth())
            assert.are.equal(620, _G.FabrikaoFrame:GetHeight())
        end)

        it("applies the scale", function()
            ns.UI_Toggle()
            ns.char.scale = 1.2
            ns.UI_ApplySettings()
            assert.are.equal(1.2, _G.FabrikaoFrame:GetScale())
        end)
    end)
end)
