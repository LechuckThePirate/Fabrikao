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

    describe("an empty answer of the game", function()
        local timers

        before_each(function()
            timers = {}
            WowMock.Reset()
            _G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
            ns = LoadAddon({ files = { "Modules/Professions/Professions.lua", "Modules/Professions/Roster.lua", "Modules/Data/RecipeDB.lua" } })
            ns.RECIPE_DATA = DATA
            ns.db = FabrikaoDB
            ns.Roster_Snapshot() -- the copy of an earlier session
        end)

        local function runTimers()
            local now = timers
            timers = {}
            for _, f in ipairs(now) do f() end
        end

        it("never wipes the copy while the game loads or logs out (it answers no professions then)", function()
            givenProfessions({})
            FireEvent("PLAYER_ENTERING_WORLD")
            FireEvent("SKILL_LINES_CHANGED")
            runTimers()
            FireEvent("PLAYER_LOGOUT")
            assert.are.equal(2, #FabrikaoDB.characters["Therzok-Realm"].professions)
        end)

        it("still saves a character that dropped its last profession while playing", function()
            FireEvent("SKILL_LINES_CHANGED")
            runTimers() -- the game answered its professions this session
            givenProfessions({})
            FireEvent("SKILL_LINES_CHANGED")
            runTimers()
            assert.are.equal(0, #FabrikaoDB.characters["Therzok-Realm"].professions)
        end)

        it("saves an alt whose earlier copy came out empty once the game answers", function()
            FabrikaoDB.characters["Therzok-Realm"].professions = {}
            FireEvent("PLAYER_ENTERING_WORLD")
            runTimers()
            assert.are.equal(2, #FabrikaoDB.characters["Therzok-Realm"].professions)
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

        it("without Consolidate alts, the professions and recipes are the playing character's own", function()
            assert.is_false(ns.Consolidated())
            local list = ns.Professions_List()
            assert.are.equal(2, #list)
            assert.are.equal("Alchemy", list[1].name)
            assert.is_true(ns.Roster_Knows(1)) -- the spell book
            assert.is_false(ns.Roster_Knows(5)) -- Elsa's only
        end)

        it("knows what each character knows, from its saved copy", function()
            assert.is_true(ns.Roster_KnowsFor("Elsa-Realm", 5))
            assert.is_false(ns.Roster_KnowsFor("Elsa-Realm", 1))
            assert.is_true(ns.Roster_KnowsFor(nil, 1)) -- the playing character: its spell book
            assert.is_false(ns.Roster_KnowsFor("Nobody-Realm", 5))
            local list = ns.Roster_ProfessionsOf("Elsa-Realm")
            assert.are.equal("Blacksmithing", list[1].name)
            assert.are.equal(80, list[1].rank)
            assert.are.equal("Elsa-Realm", list[1].owner)
        end)

        it("colors the name by class", function()
            assert.are.equal("|cff3fc7ebElsa|r", ns.Roster_NameOf("Elsa-Realm"))
            assert.are.equal("|cff3fc7ebElsa|r", ns.Roster_ColoredName(ns.Roster_Others()[2]))
        end)
    end)

    describe("Consolidate alts", function()
        before_each(function()
            ns.char = { consolidateAlts = true }
            saveAlt("Elsa-Realm", "Elsa", "MAGE", {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 80, maxRank = 150, primary = true, hasRecipes = true, known = { 5 } },
                { skillLine = 171, name = "Alchemy", icon = 111, rank = 40, maxRank = 75, primary = true, hasRecipes = true, known = { 3 } },
            })
            saveAlt("Bob-Realm", "Bob", "MAGE", {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 120, maxRank = 150, primary = true, hasRecipes = true, known = {} },
            })
        end)

        it("counts as known a recipe any character knows", function()
            assert.is_true(ns.Roster_Knows(1)) -- the playing character's
            assert.is_true(ns.Roster_Knows(5)) -- Elsa's
            assert.is_true(ns.Roster_Knows(3)) -- Elsa's, in a profession the playing character has too
            assert.is_false(ns.Roster_Knows(6 + 100))
        end)

        it("says who knows a recipe: the playing character first, then the alts by name", function()
            known[5] = true
            local names = {}
            for _, info in ipairs(ns.Roster_KnownBy(5)) do names[#names + 1] = info.name end
            assert.are.same({ "Therzok", "Elsa" }, names)
            assert.are.same({}, ns.Roster_KnownBy(6 + 100))
        end)

        it("lists every profession of the account once, with the alts that have it", function()
            local list = ns.Professions_List()
            local names = {}
            for _, p in ipairs(list) do names[#names + 1] = p.name end
            assert.are.same({ "Alchemy", "Blacksmithing", "Cooking" }, names) -- the primary ones first
            local alchemy, smithing = list[1], list[2]
            assert.are.equal(150, alchemy.rank) -- the playing character's own skill
            assert.is_nil(alchemy.owner)
            assert.are.equal("Elsa", alchemy.holders[1].name)
            -- one only alts have: the best skill among them, and both of them
            assert.are.equal(120, smithing.rank)
            assert.are.equal("Bob-Realm", smithing.owner)
            assert.are.equal(2, #smithing.holders)
            assert.are.equal(0, #list[3].holders) -- Cooking: only the playing character
        end)

        it("only puts together the characters of the same realm", function()
            saveAlt("Ann-Other", "Ann", "MAGE", {
                { skillLine = 197, name = "Tailoring", icon = 1, rank = 10, maxRank = 75, primary = true, hasRecipes = true, known = { 9 } },
            })
            FabrikaoDB.characters["Ann-Other"].realm = "Other"
            local names = {}
            for _, info in ipairs(ns.Roster_Alts()) do names[#names + 1] = info.name end
            assert.are.same({ "Bob", "Elsa" }, names)
            assert.is_false(ns.Roster_Knows(9))
        end)

        it("leaves a Hardcore character out of the normal ones of its realm", function()
            FabrikaoDB.characters["Bob-Realm"].ruleset = "Realm+HC"
            assert.are.equal(1, #ns.Roster_Alts())
            _G.C_GameRules = { IsHardcoreActive = function() return true end }
            local alts = ns.Roster_Alts()
            _G.C_GameRules = nil
            assert.are.equal(1, #alts)
            assert.are.equal("Bob", alts[1].name)
        end)

        it("saves the ruleset of the playing character", function()
            ns.Roster_Snapshot()
            assert.are.equal("Realm", FabrikaoDB.characters["Therzok-Realm"].ruleset)
        end)

        it("saves the whole name too, when the game cuts a two-word one (Embolsao!! saves the bags under it)", function()
            _G.GetUnitName = function() return "Therzok Bonecrusher" end
            ns.Roster_Snapshot()
            _G.GetUnitName = nil
            local saved = FabrikaoDB.characters["Therzok-Realm"]
            assert.are.equal("Therzok", saved.name)
            assert.are.equal("Therzok Bonecrusher", saved.fullName)
            assert.are.equal("Elsa", ns.Roster_BagsName("Elsa-Realm")) -- a copy without it: the short name
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

        it("with Consolidate alts on, are the ones no character of the account has", function()
            saveAlt("Elsa-Realm", "Elsa", "MAGE", {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 1, maxRank = 75, primary = true, hasRecipes = true, known = {} },
            })
            ns.char = { consolidateAlts = true }
            assert.are.same({}, ns.Professions_Missing(ns.Professions_List()))
        end)
    end)
end)
