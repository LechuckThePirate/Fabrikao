dofile("setupTests.lua")

-- "Can train: Journeyman": a profession whose skill is within 25 of the cap of its rank (a trainer asks for 50 of 75, 125 of 150...), when
-- the character's level lets a trainer teach the next one, and this game has a higher rank (the data has recipes that ask for more skill).
describe("The next rank of a profession", function()
    local ns, skill

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Artisan Elixir", c = { 300, 310, 320, 330 }, m = { { 10, 2 } }, k = { 6 } }, -- the game goes up to 300
            [5] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, k = { 6 } },
        },
        items = {},
        trainers = { [171] = { { id = 9, n = "Near Anna", z = { 1519 } } } },
        npcs = { [9] = { 1453, 40, 60 } },
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function badge()
        local b = framesWith("profession")[1]
        return b.train:IsShown() and b.train._text or nil
    end

    local function givenSkill(rank, maxRank, level)
        skill = { rank, maxRank }
        WowMock.level = level
    end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        givenSkill(75, 75, 10)
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 111, skill[1], skill[2], 1, 10, 171, 0 end
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

    local function nextRank(rank, maxRank, level)
        return (ns.Professions_NextRank({ rank = rank, maxRank = maxRank, charLevel = level }))
    end

    describe("when it is", function()
        it("the skill is at the cap of its rank and the level is the one the next rank asks for", function()
            assert.are.equal("Journeyman", nextRank(75, 75, 10))
            assert.are.equal("Expert", nextRank(150, 150, 20))
            assert.are.equal("Artisan", nextRank(225, 225, 35))
        end)

        it("also gives the skill the rank goes up to", function()
            local _, cap = ns.Professions_NextRank({ rank = 150, maxRank = 150, charLevel = 20 })
            assert.are.equal(225, cap)
        end)

        it("is there before the cap, once the skill is the one the trainer asks for (50 of 75, 125 of 150, 200 of 225)", function()
            assert.are.equal("Journeyman", nextRank(50, 75, 10))
            assert.are.equal("Journeyman", nextRank(60, 75, 40))
            assert.are.equal("Expert", nextRank(125, 150, 20))
            assert.are.equal("Artisan", nextRank(200, 225, 35))
        end)

        it("is not there while the skill is under what the trainer asks for", function()
            assert.is_nil(nextRank(49, 75, 40))
            assert.is_nil(nextRank(0, 75, 40))
            assert.is_nil(nextRank(124, 150, 40))
            assert.is_nil(nextRank(199, 225, 40))
        end)

        it("is not there when the level is lower than the rank asks for", function()
            assert.is_nil(nextRank(75, 75, 9))
            assert.is_nil(nextRank(150, 150, 19))
            assert.is_nil(nextRank(225, 225, 34))
            assert.is_nil(nextRank(75, 75, false)) -- unknown level (a copy saved by an older version)
        end)

        it("is not there when this game has no higher rank: nothing in the data asks for more skill", function()
            assert.is_nil(nextRank(300, 300, 60))
        end)

        it("is not there for a profession that is not learned", function()
            assert.is_nil(ns.Professions_NextRank({ learned = false }))
            assert.is_nil(ns.Professions_NextRank(nil))
        end)
    end)

    describe("the windows say it", function()
        it("the profession of the overview carries it", function()
            ns.UI_Show()
            assert.are.equal("Can train: Journeyman", badge())
        end)

        it("is on a profession that has not reached its cap, once the trainer's skill is there", function()
            givenSkill(60, 75, 40)
            ns.UI_Show()
            assert.are.equal("Can train: Journeyman", badge())
        end)

        it("is not on a profession with too little skill, or when the level is too low", function()
            givenSkill(49, 75, 40)
            ns.UI_Show()
            assert.is_nil(badge())
            givenSkill(75, 75, 5)
            ns.UI_Hide()
            ns.UI_Show()
            assert.is_nil(badge())
        end)

        it("the recipes page says it next to the skill", function()
            ns.UI_Show()
            click(framesWith("profession")[1])
            local texts = WowMock.FindAll(function(f) return f._text and f._text:match("^Skill: 75 / 75") and f:IsVisible() end)
            assert.are.equal(1, #texts)
            assert.matches("Can train: Journeyman", texts[1]._text)
        end)

        it("the trainers' panel says it too", function()
            ns.UI_Show()
            click(framesWith("profession")[1])
            local button = WowMock.FindAll(function(f) return f._text == "Trainers" and f._scripts.OnClick and f:IsVisible() end)[1]
            click(button)
            assert.matches("You can train Journeyman here", _G.FabrikaoTrainersFrame.subtitle._text)
        end)

        it("an alt's profession says it by the alt's level, not the playing character's", function()
            WowMock.level = 60 -- the one playing could, her alt is level 5
            FabrikaoDB.characters = { ["Elsa-Realm"] = { name = "Elsa", realm = "Realm", class = "MAGE", time = 1, level = 5, professions = {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 75, maxRank = 75, primary = true, hasRecipes = true, known = {} },
            } } }
            ns.UI_Show()
            ns.UI_ViewCharacter("Elsa-Realm")
            assert.is_nil(badge())
            FabrikaoDB.characters["Elsa-Realm"].level = nil -- a copy of an older version: unknown, not the playing character's
            ns.UI_ViewCharacter(nil)
            ns.UI_ViewCharacter("Elsa-Realm")
            assert.is_nil(badge())
            FabrikaoDB.characters["Elsa-Realm"].level = 12
            ns.UI_ViewCharacter(nil)
            ns.UI_ViewCharacter("Elsa-Realm")
            assert.are.equal("Can train: Journeyman", badge())
        end)
    end)

    it("an alt's copy keeps its level", function()
        ns.Roster_Snapshot()
        assert.are.equal(10, FabrikaoDB.characters["Tester-Realm"].level)
    end)
end)
