dofile("setupTests.lua")

-- Poisons, the rogue's class skill: a profession of the list for a rogue that has learned the spell, its poisons learnable by level, with
-- a notice when new ones can be learned.
describe("Poisons", function()
    local ns, known

    local DATA = {
        recipes = {
            [8681] = { s = 40, n = "Instant Poison", c = { 100, 0, 0, 0 }, p = { 6947, 1, 1 }, m = { { 2928, 1 }, { 3371, 1 } }, k = { 6 } },
            [8687] = { s = 40, n = "Instant Poison II", c = { 140, 0, 0, 0 }, p = { 6949, 1, 1 }, m = { { 2928, 3 }, { 3372, 1 } }, k = { 6 } },
            [2835] = { s = 40, n = "Deadly Poison", c = { 150, 0, 0, 0 }, p = { 2892, 1, 1 }, m = { { 5173, 1 }, { 3372, 1 } }, k = { 6 } },
            [11343] = { s = 40, n = "Instant Poison VI", c = { 300, 0, 0, 0 }, p = { 8928, 1, 1 }, m = { { 8924, 4 }, { 8925, 1 } }, k = { 6 } },
            [100] = { s = 185, n = "Spiced Wolf Meat", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
        },
        items = {},
        trainers = {
            [40] = { { id = 1, n = "Keryn Sylvius", t = "Rogue Trainer", z = { 1519 } } },
            [185] = { { id = 2, n = "Cook Cora", z = { 1519 } } },
        },
        npcs = { [1] = { 1453, 40, 60 } },
    }

    local function names(list)
        local out = {}
        for _, p in ipairs(list) do out[#out + 1] = p.name end
        return out
    end

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    -- the character: a rogue of that level with the spell of Poisons (or without it), with Alchemy and Cooking
    local function setup(class, level, hasSpell)
        WowMock.Reset()
        WowMock.faction = "Alliance"
        WowMock.level = level
        WowMock.class = class == "ROGUE" and { "Rogue", "ROGUE", 4 } or { "Mage", "MAGE", 8 }
        known = {}
        if hasSpell then known[2842] = true end
        _G.GetProfessions = function() return 1, 2 end
        _G.GetProfessionInfo = function(index)
            if index == 1 then return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
            return "Cooking", 333, 90, 150, 1, 20, 185, 0
        end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = {
            GetSpellBookItemInfo = function(slot) return { spellID = slot } end,
            IsSpellKnown = function(id) return known[id] == true end,
        }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = {
            GetItemCount = function() return 0 end, GetItemNameByID = function(id) return "Item" .. id end, GetItemIconByID = function() return 1 end,
        }
        _G.C_Map = { GetAreaInfo = function() return "Stormwind City" end, GetBestMapForUnit = function() return 1453 end }
        _G.C_Spell, _G.GetSpellInfo, _G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil, nil, nil
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB, _G.TomTom, _G.CompletaoAPI = nil, nil, nil, nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        ns.Map_Distance = function() return 400 end
        StartAddon(ns)
    end

    describe("the profession", function()
        it("is there for a rogue that knows the spell, after the primary professions and before the secondary ones", function()
            setup("ROGUE", 40, true)
            assert.are.same({ "Alchemy", "Poisons", "Cooking" }, names(ns.Professions_List()))
            assert.is_true(ns.Professions_List()[2].primary)
        end)

        it("has its skill: five a level, up to 300", function()
            setup("ROGUE", 40, true)
            local poisons = ns.Professions_List()[2]
            assert.are.equal(200, poisons.rank)
            assert.are.equal(300, poisons.maxRank)
            assert.are.equal(40, poisons.skillLine)
            assert.is_true(poisons.hasRecipes)
            setup("ROGUE", 60, true)
            assert.are.equal(300, ns.Professions_List()[2].rank)
            setup("ROGUE", 70, true)
            assert.are.equal(300, ns.Professions_List()[2].rank) -- (no more than that)
        end)

        it("takes the game's own numbers when it has them", function()
            setup("ROGUE", 40, true)
            _G.C_TradeSkillUI.GetProfessionInfoBySkillLineID = function() return { skillLevel = 137, maxSkillLevel = 300 } end
            assert.are.equal(137, ns.Professions_List()[2].rank)
        end)

        it("is the game's own entry when the game lists Poisons with the professions: not twice", function()
            setup("ROGUE", 40, true)
            _G.GetProfessions = function() return 1, 2, 3 end
            _G.GetProfessionInfo = function(index)
                if index == 1 then return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
                if index == 2 then return "Cooking", 333, 90, 150, 1, 20, 185, 0 end
                return "Poisons", 444, 116, 110, 1, 30, 40, 0 -- (its numbers are the game's)
            end
            local list = ns.Professions_List()
            assert.are.same({ "Alchemy", "Poisons", "Cooking" }, names(list))
            assert.are.equal(116, list[2].rank)
            assert.are.equal(110, list[2].maxRank)
            assert.are.equal(444, list[2].icon)
        end)

        it("the game's entry is the profession of the data's skill even when the game numbers it differently", function()
            setup("ROGUE", 40, true)
            _G.GetProfessions = function() return 1, 2 end
            _G.GetProfessionInfo = function(index)
                if index == 1 then return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
                return "Poisons", 444, 116, 300, 1, 30, 999, 0
            end
            local list = ns.Professions_List()
            assert.are.same({ "Alchemy", "Poisons" }, names(list))
            assert.are.equal(40, list[2].skillLine)
        end)

        it("is not there for another class, or for a rogue that has not learned it yet", function()
            setup("MAGE", 40, true)
            assert.are.same({ "Alchemy", "Cooking" }, names(ns.Professions_List()))
            setup("ROGUE", 12, false)
            assert.are.same({ "Alchemy", "Cooking" }, names(ns.Professions_List()))
        end)

        it("is among the professions not learned for a rogue that has not learned it, and not for another class", function()
            setup("ROGUE", 12, false)
            local missing = {}
            for _, p in ipairs(ns.Professions_Missing(ns.Professions_List())) do missing[#missing + 1] = p.skillLine end
            assert.are.same({ 40 }, missing)
            setup("MAGE", 12, false)
            assert.are.same({}, ns.Professions_Missing(ns.Professions_List()))
        end)

        it("an alt's class decides it when looking at an alt", function()
            setup("MAGE", 40, false)
            FabrikaoDB.characters = { ["Rex-Realm"] = { name = "Rex", realm = "Realm", class = "ROGUE", level = 30, time = 1, professions = {
                { skillLine = 185, name = "Cooking", icon = 333, rank = 20, maxRank = 75, primary = false, hasRecipes = true, known = {} },
            } } }
            ns.Roster_SetView("Rex-Realm")
            local missing = {}
            for _, p in ipairs(ns.Professions_Missing(ns.Professions_List())) do missing[#missing + 1] = p.skillLine end
            assert.are.same({ 40 }, missing)
        end)
    end)

    describe("what can be learned", function()
        it("tells when new poisons can be learned, as it does for a rank", function()
            setup("ROGUE", 30, true) -- skill 150: Instant Poison (100), Instant Poison II (140) and Deadly Poison (150)
            local poisons = ns.Professions_List()[2]
            assert.are.equal("Can learn: 3", ns.Professions_Notice(poisons))
            known[8681] = true
            assert.are.equal("Can learn: 2", ns.Professions_Notice(poisons))
            known[8687], known[2835] = true, true
            assert.is_nil(ns.Professions_Notice(poisons))
        end)

        it("lists the poisons that the level reaches among the recipes to learn, by level, with the rogue trainers", function()
            setup("ROGUE", 30, true)
            ns.UI_Show()
            -- the badge of the profession
            local badge
            for _, f in ipairs(framesWith("profession")) do
                if f.profession.name == "Poisons" and f.train:IsShown() then badge = f.train._text end
            end
            assert.are.equal("Can learn: 3", badge)
            -- the group of the list of what can be learned, and who teaches
            local header
            for _, f in ipairs(framesWith("kind")) do
                if f.key == 40 then header = f end
            end
            assert.matches("^Poisons %(3%)", header.text._text)
            header._scripts.OnClick(header, "LeftButton")
            local rows = {}
            for _, f in ipairs(framesWith("learn")) do rows[#rows + 1] = f.name._text end
            assert.are.same({ "Instant Poison", "Instant Poison II", "Deadly Poison" }, rows)
            local first = framesWith("learn")[1]
            first._scripts.OnClick(first, "LeftButton")
            local teacher = framesWith("teacher")[1]
            assert.are.equal("Keryn Sylvius", teacher.teacher.name)
            assert.is_true(teacher.mapButton:IsShown())
        end)
    end)
end)
