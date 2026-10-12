dofile("setupTests.lua")

-- The saved copy of every character's professions and known recipes, and the view of another character's.
describe("Roster", function()
    local ns, known, playing
    local realTimer = C_Timer

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Elixir of Giants", c = { 200, 220, 240, 260 }, k = { 6 } },
            [5] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, k = { 6 } },
            [6] = { s = 185, n = "Spiced Wolf Meat", c = { 1, 20, 40, 60 }, k = { 6 } },
        },
        items = {}, trainers = {},
    }

    -- what the playing character has: slot -> { name, icon, rank, maxRank, skillLine }
    local function givenProfessions(info)
        local order = {}
        for index in pairs(info) do order[#order + 1] = index end
        table.sort(order)
        _G.GetProfessions = function() return unpack(order, 1, 6) end
        _G.GetProfessionInfo = function(index)
            local p = info[index]
            if not p then return nil end
            return p[1], p[2], p[3], p[4], 1, index * 10, p[5], 0
        end
    end

    local function alchemistAndCook()
        givenProfessions({
            [1] = { "Alchemy", 111, 150, 300, 171 },
            [2] = { "Cooking", 222, 20, 75, 185 },
        })
    end

    -- another character's saved copy, as the addon writes it
    local function saveAlt(key, name, class, professions)
        FabrikaoDB.characters = FabrikaoDB.characters or {}
        FabrikaoDB.characters[key] = { name = name, realm = "Realm", class = class, time = 1, professions = professions }
    end

    before_each(function()
        WowMock.Reset()
        known, playing = { [1] = true, [2] = true, [6] = true }, "Therzok"
        alchemistAndCook()
        _G.Enum = { SpellBookSpellBank = { Player = 0 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
        _G.C_TradeSkillUI = nil
        _G.UnitName = function() return playing end
        _G.UnitClass = function() return "Warrior", "WARRIOR" end
        _G.GetRealmName = function() return "Realm" end
        _G.RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
        _G.time = function() return 1000 end
        ns = LoadAddon({ files = { "Modules/Professions/Professions.lua", "Modules/Professions/Roster.lua", "Modules/Data/RecipeDB.lua" } })
        ns.RECIPE_DATA = DATA
        FabrikaoDB, FabrikaoCharDB = {}, {}
        ns.db = FabrikaoDB
    end)

    after_each(function()
        _G.C_Timer = realTimer -- a test may replace it (its callbacks wait to be called)
    end)

    describe("saving the playing character", function()
        it("saves its professions in the window's order, with the recipes of the data it knows", function()
            assert.is_true(ns.Roster_Snapshot())
            local saved = FabrikaoDB.characters["Therzok-Realm"]
            assert.are.equal("Therzok", saved.name)
            assert.are.equal("WARRIOR", saved.class)
            assert.are.equal(2, #saved.professions)
            local alchemy, cooking = saved.professions[1], saved.professions[2]
            assert.are.equal("Alchemy", alchemy.name)
            assert.are.equal(150, alchemy.rank)
            assert.are.equal(300, alchemy.maxRank)
            assert.is_true(alchemy.primary)
            assert.are.same({ 1, 2 }, alchemy.known) -- 3 is not known, 5 is another profession's
            assert.is_false(cooking.primary)
            assert.are.same({ 6 }, cooking.known)
        end)

        it("does not list the playing character among the others", function()
            ns.Roster_Snapshot()
            assert.are.same({}, ns.Roster_Others())
        end)

        it("keeps the old copy when the game answers with no professions at all (not ready yet)", function()
            ns.Roster_Snapshot()
            givenProfessions({})
            assert.is_false(ns.Roster_Snapshot())
            assert.are.equal(2, #FabrikaoDB.characters["Therzok-Realm"].professions)
            -- but a character that really dropped them all is saved as that
            assert.is_true(ns.Roster_Snapshot(true))
            assert.are.equal(0, #FabrikaoDB.characters["Therzok-Realm"].professions)
        end)

        it("keeps the recipes a profession had when the spell book answers none (not loaded yet)", function()
            ns.Roster_Snapshot()
            known = {}
            ns.Roster_Snapshot()
            assert.are.same({ 1, 2 }, FabrikaoDB.characters["Therzok-Realm"].professions[1].known)
        end)

        it("saves when the game says the skills changed, once for a burst of events, and at logout", function()
            local timers = {}
            WowMock.Reset() -- (the frames of the addon loaded before each test would answer the events too)
            _G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
            ns = LoadAddon({ files = { "Modules/Professions/Professions.lua", "Modules/Professions/Roster.lua", "Modules/Data/RecipeDB.lua" } })
            ns.RECIPE_DATA = DATA
            ns.db = FabrikaoDB
            FireEvent("SKILL_LINES_CHANGED")
            FireEvent("SKILL_LINES_CHANGED")
            assert.are.equal(1, #timers)
            timers[1]()
            assert.is_not_nil(FabrikaoDB.characters["Therzok-Realm"])
            FabrikaoDB.characters = nil
            FireEvent("PLAYER_LOGOUT")
            assert.is_not_nil(FabrikaoDB.characters["Therzok-Realm"])
        end)
    end)

    describe("another character", function()
        before_each(function()
            saveAlt("Elsa-Realm", "Elsa", "MAGE", {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 80, maxRank = 150, primary = true, hasRecipes = true, known = { 5 } },
                { skillLine = 185, name = "Cooking", icon = 222, rank = 5, maxRank = 75, primary = false, hasRecipes = true, known = {} },
            })
            saveAlt("Bad Yuyu-Realm", "Bad Yuyu", "WARLOCK", {})
        end)

        it("lists the other characters by name", function()
            local others = ns.Roster_Others()
            assert.are.equal(2, #others)
            assert.are.equal("Bad Yuyu", others[1].name)
            assert.are.equal("Elsa-Realm", others[2].key)
            assert.are.equal("MAGE", others[2].class)
        end)

        it("names two characters of the same name by realm", function()
            saveAlt("Elsa-Other", "Elsa", "MAGE", {})
            FabrikaoDB.characters["Elsa-Other"].realm = "Other"
            local labels = {}
            for _, info in ipairs(ns.Roster_Others()) do labels[#labels + 1] = info.label end
            assert.are.same({ "Bad Yuyu", "Elsa-Other", "Elsa-Realm" }, labels)
        end)

        it("shows the playing character's own professions and recipes until another one is picked", function()
            assert.is_nil(ns.Roster_ViewKey())
            assert.is_nil(ns.Roster_Viewed())
            assert.are.equal("Alchemy", ns.Professions_List()[1].name)
            assert.is_true(ns.Roster_Knows(1)) -- the spell book
            assert.is_false(ns.Roster_Knows(5))
        end)

        it("shows that character's professions and recipes when picked, as the saved copy has them", function()
            assert.are.equal("Elsa-Realm", ns.Roster_SetView("Elsa-Realm"))
            assert.are.equal("Elsa", ns.Roster_Viewed().name)
            local list = ns.Professions_List()
            assert.are.equal(2, #list)
            assert.are.equal("Blacksmithing", list[1].name)
            assert.are.equal(80, list[1].rank)
            assert.are.equal(150, list[1].maxRank)
            assert.is_true(list[1].primary)
            assert.is_true(ns.Roster_Knows(5)) -- Elsa's
            assert.is_false(ns.Roster_Knows(1)) -- the playing character knows it, she doesn't
        end)

        it("goes back to the playing character with nil, or with a key that isn't there", function()
            ns.Roster_SetView("Elsa-Realm")
            assert.is_nil(ns.Roster_SetView("Nobody-Realm"))
            assert.is_nil(ns.Roster_ViewKey())
            ns.Roster_SetView("Elsa-Realm")
            ns.Roster_SetView(nil)
            assert.are.equal("Alchemy", ns.Professions_List()[1].name)
            -- and the playing character is not "another" one
            assert.is_nil(ns.Roster_SetView("Therzok-Realm"))
        end)

        it("colors the name by class", function()
            ns.Roster_SetView("Elsa-Realm")
            assert.are.equal("|cff3fc7ebElsa|r", ns.Roster_ColoredName(ns.Roster_Viewed()))
        end)
    end)

    describe("the professions that are not learned", function()
        it("lists the ones with recipes in the data that the character lacks, with an icon", function()
            local missing = ns.Professions_Missing(ns.Professions_List())
            assert.are.equal(1, #missing)
            assert.are.equal(164, missing[1].skillLine)
            assert.is_false(missing[1].learned)
            assert.is_nil(missing[1].rank)
            assert.is_not_nil(missing[1].icon)
            assert.is_true(missing[1].primary)
        end)

        it("takes an icon some character saved when there is one", function()
            saveAlt("Elsa-Realm", "Elsa", "MAGE", {
                { skillLine = 164, name = "Blacksmithing", icon = 4242, rank = 1, maxRank = 75, primary = true, hasRecipes = true, known = {} },
            })
            assert.are.equal(4242, ns.Professions_Missing(ns.Professions_List())[1].icon)
        end)

        it("is relative to the character shown", function()
            saveAlt("Elsa-Realm", "Elsa", "MAGE", {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 1, maxRank = 75, primary = true, hasRecipes = true, known = {} },
            })
            ns.Roster_SetView("Elsa-Realm")
            local skills = {}
            for _, p in ipairs(ns.Professions_Missing(ns.Professions_List())) do skills[#skills + 1] = p.skillLine end
            assert.are.same({ 171, 185 }, skills)
        end)
    end)
end)
