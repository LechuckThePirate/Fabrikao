dofile("setupTests.lua")

describe("Recipes", function()
    local ns, game, known

    -- The addon's own data for the recipes of the tests: [spell id] = record
    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Elixir of Giants", c = { 200, 220, 240, 260 }, k = { 4 }, i = 900 },
            [4] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, k = { 2 }, i = 901 },
            [5] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, k = { 5 } },
        },
        items = {
            [900] = { n = "Recipe: Elixir of Giants", k = { 4 }, qs = { { id = 1, n = "A Hard Day" } } },
            [901] = { n = "Recipe: Flask of the Titans", k = { 2 }, d = { { id = 2, n = "Dragon Whelp", z = { 46 } } } },
        },
        trainers = {},
    }

    -- A fake trade skill API: `game.open` is the profession whose window is open (nil for none), `game.recipes` the
    -- recipes it answers with, in the game's recipe info shape.
    local function installGame()
        game = { open = nil, ready = false, learned = true, unlearned = true, bag = {}, recipes = {}, sourceTexts = {} }
        known = {}
        _G.Enum = { CraftingReagentType = { Basic = 1 }, SpellBookSpellBank = { Player = 0 } }
        _G.C_Item = { GetItemCount = function(itemID) return game.bag[itemID] or 0 end }
        _G.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
        _G.C_TradeSkillUI = {
            GetBaseProfessionInfo = function() return { professionID = game.open or 0 } end,
            IsTradeSkillReady = function() return game.ready end,
            GetShowLearned = function() return game.learned end,
            GetShowUnlearned = function() return game.unlearned end,
            SetShowLearned = function(v) game.learned = v end,
            SetShowUnlearned = function(v) game.unlearned = v end,
            GetFilteredRecipeIDs = function()
                local ids = {}
                for id, r in pairs(game.recipes) do
                    if (r.learned and game.learned) or (not r.learned and game.unlearned) then ids[#ids + 1] = id end
                end
                table.sort(ids)
                return ids
            end,
            GetRecipeInfo = function(id) local r = game.recipes[id]; return r and { recipeID = id, name = r.name, icon = r.icon or 1,
                learned = r.learned, relativeDifficulty = r.difficulty, maxTrivialLevel = r.trivial, previousRecipeID = r.previous,
                hyperlink = "|Hlink:" .. id .. "|h[" .. r.name .. "]|h" } end,
            IsRecipeInSkillLine = function(id, skillLine) return game.recipes[id].skillLine == nil or game.recipes[id].skillLine == skillLine end,
            GetRecipeSourceText = function(id) return game.sourceTexts[id] end,
            GetRecipeSchematic = function(id)
                local slots = {}
                for _, reagent in ipairs(game.recipes[id].reagents or {}) do
                    local choices = {}
                    for _, itemID in ipairs(reagent.items) do choices[#choices + 1] = { itemID = itemID } end
                    slots[#slots + 1] = { reagentType = reagent.type or 1, quantityRequired = reagent.quantity, reagents = choices }
                end
                return { reagentSlotSchematics = slots }
            end,
        }
    end

    local function recipe(name, fields)
        fields = fields or {}
        fields.name = name
        return fields
    end

    local function openAndReady(skillLine)
        game.open, game.ready = skillLine, true
    end

    local function names(list)
        local out = {}
        for _, r in ipairs(list) do out[#out + 1] = r.name end
        return out
    end

    before_each(function()
        WowMock.Reset()
        installGame()
        ns = LoadAddon({ files = { "Modules/Data/RecipeDB.lua", "Modules/Professions/Recipes.lua" } })
        ns.RECIPE_DATA = DATA
    end)

    describe("the live answer of the game's window", function()
        it("gives nothing while that profession isn't the one open", function()
            assert.is_nil(ns.Recipes_Read(171))
            openAndReady(164)
            assert.is_nil(ns.Recipes_Read(171))
        end)

        it("splits known from not known recipes and sorts them", function()
            game.recipes = {
                [11] = recipe("Yellow one", { learned = true, difficulty = 1 }),
                [12] = recipe("Orange one", { learned = true, difficulty = 0 }),
                [13] = recipe("Another orange", { learned = true, difficulty = 0 }),
                [14] = recipe("Grey one", { learned = true, difficulty = 3 }),
                [15] = recipe("Late", { learned = false, trivial = 250 }),
                [16] = recipe("Early", { learned = false, trivial = 80 }),
            }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            assert.are.same({ "Another orange", "Orange one", "Yellow one", "Grey one" }, names(copy.known))
            assert.are.same({ "Early", "Late" }, names(copy.unknown))
        end)

        it("keeps the source text of the ones not known", function()
            game.recipes = { [15] = recipe("Pattern", { learned = false }) }
            game.sourceTexts[15] = "Vendor: Somebody"
            openAndReady(171)
            assert.are.equal("Vendor: Somebody", ns.Recipes_Read(171).unknown[1].sourceText)
        end)

        it("asks the game for everything and gives its filters back", function()
            game.learned, game.unlearned = true, false
            game.recipes = { [11] = recipe("Known", { learned = true }), [12] = recipe("Unknown", { learned = false }) }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            assert.are.equal(1, #copy.known)
            assert.are.equal(1, #copy.unknown)
            assert.is_true(game.learned)
            assert.is_false(game.unlearned)
        end)

        it("a recipe with several ranks is one entry, the first", function()
            game.recipes = {
                [11] = recipe("Rank 1", { learned = true, difficulty = 1 }),
                [12] = recipe("Rank 2", { learned = true, difficulty = 1, previous = 11 }),
            }
            openAndReady(171)
            assert.are.same({ "Rank 1" }, names(ns.Recipes_Read(171).known))
        end)

        it("only takes the recipes of that skill line, or of that profession name when the numbers differ", function()
            game.recipes = {
                [11] = recipe("Mine", { learned = true, skillLine = 171 }),
                [12] = recipe("Another profession's", { learned = true, skillLine = 164 }),
            }
            openAndReady(171)
            assert.are.equal(1, #ns.Recipes_Read(171).known)
            _G.C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 4242, professionName = "Alchemy" } end
            game.open = 4242
            assert.are.equal(2, #ns.Recipes_Read(171, "Alchemy").known)
        end)

        it("takes the data's skill levels, where it is learned, and searches in the data's NPCs and zones", function()
            game.recipes = { [3] = recipe("Elixir of Giants", { learned = false }), [4] = recipe("Flask of the Titans", { learned = false }) }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            assert.are.equal(200, copy.unknown[1].required)
            assert.are.same({ 200, 220, 240, 260 }, copy.unknown[1].colors)
            assert.are.equal(4, copy.unknown[1].sourceType)
            assert.are.same({ [4] = true, [2] = true }, copy.sources)
            local rows = ns.Recipes_Rows(copy, { text = "dragon whelp", unknown = true })
            assert.are.equal("Flask of the Titans", rows[2].recipe.name)
        end)
    end)

    describe("from the addon's data", function()
        it("splits a profession's recipes by what the spell book knows, and colors the known ones for the skill", function()
            known[1], known[2] = true, true
            local copy = ns.Recipes_FromData(171, 50)
            assert.are.same({ "Elixir of Wisdom", "Healing Potion" }, names(copy.known)) -- orange, then yellow... by difficulty and name
            assert.are.equal(0, copy.known[1].difficulty) -- skill 50 < 55
            assert.are.equal(2, copy.known[2].difficulty) -- skill 50 >= 40, < 60
            assert.are.same({ "Elixir of Giants", "Flask of the Titans" }, names(copy.unknown))
        end)

        it("doesn't mix professions", function()
            local copy = ns.Recipes_FromData(164, 0)
            assert.are.equal(0, #copy.known)
            assert.are.same({ "Iron Sword" }, names(copy.unknown))
        end)

        it("gives the unknown ones their skill, sources and search text", function()
            known[1], known[2] = true, true
            local copy = ns.Recipes_FromData(171, 0)
            local giants = copy.unknown[1]
            assert.are.equal(200, giants.required)
            assert.are.equal(4, giants.sourceType)
            assert.is_not_nil(giants.db)
            assert.matches("a hard day", giants.search)
            assert.are.same({ [4] = true, [2] = true }, copy.sources)
        end)

        it("counts how many of the known ones can be made from the bags", function()
            known[1] = true
            game.bag = { [10] = 7, [11] = 9 }
            local copy = ns.Recipes_FromData(171, 0)
            assert.are.equal(3, ns.Recipes_Craftable(copy.known[1])) -- 7 // 2
            game.bag[10] = 1
            assert.are.equal(0, ns.Recipes_Craftable(copy.known[1]))
        end)

        it("an empty profession gives empty lists", function()
            local copy = ns.Recipes_FromData(999, 0)
            assert.are.same({}, copy.known)
            assert.are.same({}, copy.unknown)
        end)
    end)

    describe("how many can be made", function()
        local function copyOf(reagents)
            game.recipes = { [11] = recipe("Thing", { learned = true, reagents = reagents }) }
            openAndReady(171)
            return ns.Recipes_Read(171).known[1]
        end

        it("takes the ingredient that runs out first", function()
            local r = copyOf({ { quantity = 2, items = { 10 } }, { quantity = 1, items = { 11 } } })
            game.bag = { [10] = 7, [11] = 9 }
            assert.are.equal(3, ns.Recipes_Craftable(r))
            game.bag[11] = 0
            assert.are.equal(0, ns.Recipes_Craftable(r))
        end)

        it("adds up the alternatives of one ingredient", function()
            local r = copyOf({ { quantity = 2, items = { 10, 12 } } })
            game.bag = { [10] = 3, [12] = 3 }
            assert.are.equal(3, ns.Recipes_Craftable(r))
        end)

        it("ignores what isn't a basic ingredient", function()
            local r = copyOf({ { quantity = 1, items = { 10 } }, { quantity = 1, items = { 99 }, type = 2 } })
            game.bag = { [10] = 5 }
            assert.are.equal(5, ns.Recipes_Craftable(r))
        end)

        it("is zero for a recipe with no ingredients known", function()
            assert.are.equal(0, ns.Recipes_Craftable(copyOf(nil)))
        end)
    end)

    describe("the list rows", function()
        local copy
        before_each(function()
            known[1], known[2] = true, true
            game.bag = { [10] = 4, [11] = 4 }
            copy = ns.Recipes_FromData(171, 0)
        end)

        local function kinds(rows)
            local out = {}
            for _, row in ipairs(rows) do out[#out + 1] = row.kind == "header" and ("# " .. row.text .. " " .. row.count) or row.recipe.name end
            return out
        end

        it("shows the known recipes first, then the unknown ones, each under a header", function()
            local rows = ns.Recipes_Rows(copy, { known = true, unknown = true })
            assert.are.same({ "# Known recipes 2", "Elixir of Wisdom", "Healing Potion",
                "# Not known 2", "Elixir of Giants", "Flask of the Titans" }, kinds(rows))
            assert.are.equal(2, rows[2].craftable) -- 4 // 2, 4 // 1, 4
        end)

        it("can hide either group", function()
            assert.are.same({ "# Known recipes 2", "Elixir of Wisdom", "Healing Potion" }, kinds(ns.Recipes_Rows(copy, { known = true })))
            assert.are.same({ "# Not known 2", "Elixir of Giants", "Flask of the Titans" }, kinds(ns.Recipes_Rows(copy, { unknown = true })))
            assert.are.same({}, ns.Recipes_Rows(copy, {}))
        end)

        it("searches in names, ignoring case", function()
            assert.are.same({ "# Known recipes 1", "Elixir of Wisdom", "# Not known 1", "Elixir of Giants" },
                kinds(ns.Recipes_Rows(copy, { text = "ELIXIR", known = true, unknown = true })))
        end)

        it("searches in where the unknown ones are learned", function()
            assert.are.same({ "# Not known 1", "Flask of the Titans" }, kinds(ns.Recipes_Rows(copy, { text = "dragon", known = true, unknown = true })))
            assert.are.same({ "# Not known 1", "Elixir of Giants" }, kinds(ns.Recipes_Rows(copy, { text = "hard day", known = true, unknown = true })))
        end)

        it("filters the unknown ones by source", function()
            assert.are.same({ "# Not known 1", "Flask of the Titans" }, kinds(ns.Recipes_Rows(copy, { unknown = true, source = 2 })))
        end)

        it("names the sources", function()
            assert.are.equal("Drop", ns.Recipes_SourceLabel(2))
            assert.are.equal("Quest", ns.Recipes_SourceLabel(4))
            assert.are.equal("Other", ns.Recipes_SourceLabel(nil))
        end)
    end)

    describe("asking for a profession", function()
        it("answers at once from the data when that profession's window isn't open", function()
            known[1] = true
            local got
            ns.Recipes_Request(171, function(copy) got = copy end, { name = "Alchemy", rank = 10 })
            assert.are.equal(1, #got.known)
            assert.are.equal(171, got.skillLine)
        end)

        it("prefers the live answer when the window of that profession is open", function()
            game.recipes = { [11] = recipe("Live recipe", { learned = true, difficulty = 1 }) }
            openAndReady(171)
            local got
            ns.Recipes_Request(171, function(copy) got = copy end)
            assert.are.same({ "Live recipe" }, names(got.known))
        end)

        it("remembers the last copy", function()
            local got
            ns.Recipes_Request(171, function(copy) got = copy end)
            assert.are.equal(got, ns.Recipes_Cached(171))
            assert.is_nil(ns.Recipes_Cached(164))
        end)
    end)
end)
