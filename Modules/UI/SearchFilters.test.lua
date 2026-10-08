dofile("setupTests.lua")

-- The filters and sorting of the search of every recipe: the same as a profession's page.
describe("Search page filters", function()
    local ns, bag

    local DATA = {
        recipes = {
            [100] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 } },
            [101] = { s = 171, n = "Mighty Flask", c = { 250, 270, 290, 310 }, m = { { 12, 3 } }, k = { 2 }, i = 900 },
            [102] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, k = { 5 }, i = 901 },
        },
        items = {
            [900] = { n = "Recipe: Mighty Flask", lv = 50, k = { 2 } },
            [901] = { n = "Plans: Iron Sword", lv = 20, k = { 5 } },
        },
        trainers = {},
    }

    local function click(f, button) f._scripts.OnClick(f, button or "LeftButton") end

    local function button(prefix)
        return WowMock.Find(function(f)
            -- (the skill's button drops its "Skill:" when it filters: it says what it filters)
            local text = f._text
            local named = type(text) == "string" and (text:sub(1, #prefix) == prefix
                or (prefix == "Skill:" and (text == "Learnable now" or text == "Needs more skill")))
            return named and f._scripts.OnClick and f:IsVisible()
        end)
    end

    local function check(index)
        local list = WowMock.FindAll(function(f) return f._template == "UICheckButtonTemplate" and f:IsVisible() end)
        return list[index]
    end

    local function names()
        local out = {}
        for _, row in ipairs(ns.SearchPage_Results()) do out[#out + 1] = row.recipe.name end
        return out
    end

    before_each(function()
        WowMock.Reset()
        bag = { [10] = 5, [11] = 1, [12] = 0 }
        _G.UnitFactionGroup = function() return "Alliance" end
        _G.C_Map = { GetAreaInfo = function() return nil end }
        _G.C_Item = {
            GetItemNameByID = function(id) return "Item" .. id end,
            GetItemIconByID = function(id) return 9000 + id end,
            GetItemCount = function(id) return bag[id] or 0 end,
        }
        _G.C_SpellBook = { IsSpellKnown = function(id) return id == 100 end }
        _G.Enum = { SpellBookSpellBank = { Player = 0 } }
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 80, 300, 1, 10, 171, 0 end
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        ns.UI_ShowSearch("i") -- all three
    end)

    it("starts with all of them", function()
        assert.are.same({ "Elixir of Wisdom", "Iron Sword", "Mighty Flask" }, names())
    end)

    it("source: the sources of what was found, one after the other", function()
        click(button("Source:")) -- 2: drop
        assert.are.same({ "Mighty Flask" }, names())
        click(button("Source:")) -- 5: vendor
        assert.are.same({ "Iron Sword" }, names())
        click(button("Source:")) -- 6: trainer
        assert.are.same({ "Elixir of Wisdom" }, names())
        click(button("Source:")) -- all
        assert.are.equal(3, #names())
    end)

    it("color: for the skill of the character in each profession; what it can't use yet is not any color", function()
        click(button("Color:")) -- orange
        assert.are.same({}, names())
        click(button("Color:")) -- yellow
        assert.are.same({}, names())
        click(button("Color:")) -- green: the elixir, at skill 80
        assert.are.same({ "Elixir of Wisdom" }, names())
        click(button("Color:")) -- grey
        assert.are.same({}, names())
    end)

    it("skill: learnable now needs the profession and the skill; the rest need more", function()
        click(button("Skill:"))
        assert.matches("Learnable now", button("Skill:")._text)
        assert.are.same({}, names()) -- the flask needs 250, and the sword needs blacksmithing
        click(button("Skill:"))
        assert.matches("Needs more skill", button("Skill:")._text)
        assert.are.same({ "Iron Sword", "Mighty Flask" }, names())
    end)

    it("can make now: what the bags allow", function()
        bag[12] = 3
        check(1):SetChecked(true)
        click(check(1))
        assert.are.same({ "Elixir of Wisdom", "Mighty Flask" }, names()) -- the sword has no ingredients
    end)

    it("hide grey: what gives no skill points", function()
        _G.GetProfessionInfo = function() return "Alchemy", 5, 100, 300, 1, 10, 171, 0 end
        ns.UI_ShowSearch("elixir")
        check(2):SetChecked(true)
        click(check(2))
        assert.are.same({}, names())
    end)

    it("lists everything that passes the filters when there is no text", function()
        ns.UI_ShowSearch("")
        assert.are.same({}, names())
        click(button("Source:")) -- drop
        assert.are.same({ "Mighty Flask" }, names())
    end)

    it("sorts, and keeps the filters for next time", function()
        click(button("Sort:")) -- name
        click(button("Sort:"), "RightButton") -- turned around
        assert.are.same({ "Mighty Flask", "Iron Sword", "Elixir of Wisdom" }, names())
        check(1):SetChecked(true)
        click(check(1))
        assert.is_true(ns.char.searchFilters.canMake)
        assert.are.equal("name", ns.char.searchFilters.sort.key)
        assert.is_true(ns.char.searchFilters.sort.desc)
    end)

    it("clear brings everything back", function()
        click(button("Source:"))
        click(button("Skill:"))
        click(button("Clear"))
        assert.are.equal(3, #names())
        assert.matches("All", button("Source:")._text)
    end)

    it("the preferences' reset of the filters clears these too", function()
        click(button("Source:"))
        ns.UI_ResetFilters()
        assert.is_nil(ns.char.searchFilters)
        assert.are.equal(3, #names())
    end)
end)
