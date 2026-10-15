dofile("setupTests.lua")

-- Recipes tied to a world event (Gingerbread Cookie and Egg Nog, sold only by the Winter Veil vendors...): "You can learn" leaves them
-- out, since nobody can teach them out of season.
describe("Seasonal recipes", function()
    local ns

    local DATA = {
        recipes = {
            [2538] = { s = 185, n = "Charred Wolf Meat", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            -- sold by the Smokywood Pastures vendors of Winter Veil only
            [21143] = { s = 185, n = "Gingerbread Cookie", c = { 1, 45, 65, 85 }, m = { { 6889, 1 } }, k = { 5 }, i = 17200 },
            [21144] = { s = 185, n = "Egg Nog", c = { 35, 75, 95, 115 }, m = { { 6889, 1 } }, k = { 5 }, i = 17201 },
            -- an ordinary vendor recipe, to show the list is not just empty
            [2549] = { s = 185, n = "Spider Sausage", c = { 40, 60, 80, 100 }, m = { { 10, 1 } }, k = { 5 }, i = 900 },
        },
        items = {
            [900] = { n = "Recipe: Spider Sausage", k = { 5 }, v = { { id = 3, n = "Vendor Vic", z = { 1519 } } } },
            [17200] = { n = "Recipe: Gingerbread Cookie", k = { 5 }, v = { { id = 4, n = "Penney Copperpinch", z = { 1637 }, t = "Smokywood Pastures" } } },
            [17201] = { n = "Recipe: Egg Nog", k = { 5 }, v = { { id = 4, n = "Penney Copperpinch", z = { 1637 }, t = "Smokywood Pastures" } } },
        },
        trainers = { [185] = { { id = 2, n = "Cook Cora", z = { 1519 } } } },
        npcs = { [2] = { 1453, 30, 30 }, [3] = { 1453, 60, 60 } },
    }

    local function names(groups)
        local out = {}
        for _, group in ipairs(groups) do
            for _, recipe in ipairs(group.recipes) do out[#out + 1] = recipe.name end
        end
        table.sort(out)
        return out
    end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        WowMock.level = 20
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Cooking", 333, 100, 150, 1, 20, 185, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end, IsSpellKnown = function() return false end }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function() return 0 end }
        _G.C_Map = { GetAreaInfo = function() return "Stormwind City" end, GetBestMapForUnit = function() return 1453 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB = nil, nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
    end)

    it("names the event of a seasonal recipe, and nothing for the others", function()
        assert.are.equal("Feast of Winter Veil", ns.Seasonal_Event(21143))
        assert.are.equal("Feast of Winter Veil", ns.Seasonal_Event(21144))
        assert.are.equal("Lunar Festival", ns.Seasonal_Event(26442))
        assert.is_nil(ns.Seasonal_Event(2538))
        assert.is_nil(ns.Seasonal_Event(nil))
    end)

    it("are not offered as something to learn", function()
        local groups = ns.Recipes_LearnableNow(ns.Professions_List())
        assert.are.same({ "Charred Wolf Meat", "Spider Sausage" }, names(groups))
    end)

    it("stay in the profession's own page: only the \"You can learn\" list drops them", function()
        local copy = ns.Recipes_FromData(185, 100)
        local found = {}
        for _, recipe in ipairs(copy.unknown) do found[recipe.name] = true end
        assert.is_true(found["Gingerbread Cookie"])
        assert.is_true(found["Egg Nog"])
    end)
end)
