dofile("setupTests.lua")

describe("Recipes", function()
    local ns, game

    -- A fake trade skill API: `game.open` is the profession whose window is open (nil for none), `game.recipes` the
    -- recipes it answers with, in the game's recipe info shape.
    local function installGame()
        game = {
            open = nil, ready = false, learned = true, unlearned = true, closed = 0, opened = {}, bag = {},
            recipes = {}, sourceTexts = {}, opens = true,
        }
        _G.Enum = { CraftingReagentType = { Basic = 1 } }
        _G.C_Item = { GetItemCount = function(itemID) return game.bag[itemID] or 0 end }
        _G.C_TradeSkillUI = {
            GetBaseProfessionInfo = function() return { professionID = game.open or 0 } end,
            IsTradeSkillReady = function() return game.ready end,
            OpenTradeSkill = function(skillLine)
                game.opened[#game.opened + 1] = skillLine
                if not game.opens then return false end
                game.open = skillLine
                return true
            end,
            CloseTradeSkill = function() game.open, game.ready = nil, false; game.closed = game.closed + 1 end,
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
                learned = r.learned, relativeDifficulty = r.difficulty, maxTrivialLevel = r.trivial, sourceType = r.sourceType,
                previousRecipeID = r.previous, hyperlink = "|Hlink:" .. id .. "|h[" .. r.name .. "]|h" } end,
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

    before_each(function()
        WowMock.Reset()
        installGame()
        ns = LoadAddon()
    end)

    describe("reading", function()
        it("gives nothing while that profession isn't the one open", function()
            assert.is_nil(ns.Recipes_Read(171))
            openAndReady(164)
            assert.is_nil(ns.Recipes_Read(171))
        end)

        it("splits known from not known recipes and sorts them", function()
            game.recipes = {
                [1] = recipe("Yellow one", { learned = true, difficulty = 1 }),
                [2] = recipe("Orange one", { learned = true, difficulty = 0 }),
                [3] = recipe("Another orange", { learned = true, difficulty = 0 }),
                [4] = recipe("Grey one", { learned = true, difficulty = 3 }),
                [5] = recipe("Late", { learned = false, trivial = 250, sourceType = 1 }),
                [6] = recipe("Early", { learned = false, trivial = 80, sourceType = 2 }),
            }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            local known, unknown = {}, {}
            for _, r in ipairs(copy.known) do known[#known + 1] = r.name end
            for _, r in ipairs(copy.unknown) do unknown[#unknown + 1] = r.name end
            assert.are.same({ "Another orange", "Orange one", "Yellow one", "Grey one" }, known)
            assert.are.same({ "Early", "Late" }, unknown)
            assert.are.same({ [1] = true, [2] = true }, copy.sources)
        end)

        it("keeps the source text of the ones not known", function()
            game.recipes = { [5] = recipe("Pattern", { learned = false, sourceType = 2 }) }
            game.sourceTexts[5] = "Vendor: Somebody"
            openAndReady(171)
            assert.are.equal("Vendor: Somebody", ns.Recipes_Read(171).unknown[1].sourceText)
        end)

        it("asks the game for everything and gives its filters back", function()
            game.learned, game.unlearned = true, false
            game.recipes = { [1] = recipe("Known", { learned = true }), [2] = recipe("Unknown", { learned = false }) }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            assert.are.equal(1, #copy.known)
            assert.are.equal(1, #copy.unknown)
            assert.is_true(game.learned)
            assert.is_false(game.unlearned)
        end)

        it("a recipe with several ranks is one entry, the first", function()
            game.recipes = {
                [1] = recipe("Rank 1", { learned = true, difficulty = 1 }),
                [2] = recipe("Rank 2", { learned = true, difficulty = 1, previous = 1 }),
            }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            assert.are.equal(1, #copy.known)
            assert.are.equal("Rank 1", copy.known[1].name)
        end)

        it("only takes the recipes of that skill line", function()
            game.recipes = {
                [1] = recipe("Mine", { learned = true, skillLine = 171 }),
                [2] = recipe("Another profession's", { learned = true, skillLine = 164 }),
            }
            openAndReady(171)
            assert.are.equal(1, #ns.Recipes_Read(171).known)
        end)

        it("remembers the last copy", function()
            game.recipes = { [1] = recipe("Known", { learned = true }) }
            openAndReady(171)
            local copy = ns.Recipes_Read(171)
            assert.are.equal(copy, ns.Recipes_Cached(171))
            assert.is_nil(ns.Recipes_Cached(164))
        end)
    end)

    describe("how many can be made", function()
        local function copyOf(reagents)
            game.recipes = { [1] = recipe("Thing", { learned = true, reagents = reagents }) }
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
            game.recipes = {
                [1] = recipe("Elixir of Wisdom", { learned = true, difficulty = 0, reagents = { { quantity = 1, items = { 10 } } } }),
                [2] = recipe("Healing Potion", { learned = true, difficulty = 2 }),
                [3] = recipe("Elixir of Giants", { learned = false, trivial = 200, sourceType = 1 }),
                [4] = recipe("Flask of the Titans", { learned = false, trivial = 300, sourceType = 3 }),
            }
            game.sourceTexts[3] = "Quest: A Hard Day"
            game.sourceTexts[4] = "Drop: Some dragon"
            game.bag = { [10] = 4 }
            openAndReady(171)
            copy = ns.Recipes_Read(171)
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
            assert.are.equal(4, rows[2].craftable)
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
            assert.are.same({ "# Not known 1", "Flask of the Titans" },
                kinds(ns.Recipes_Rows(copy, { text = "dragon", known = true, unknown = true })))
        end)

        it("filters the unknown ones by source", function()
            assert.are.same({ "# Not known 1", "Flask of the Titans" },
                kinds(ns.Recipes_Rows(copy, { unknown = true, source = 3 })))
        end)

        it("names the sources like the game does", function()
            _G.BATTLE_PET_SOURCE_1 = "Drop"
            _G.BATTLE_PET_SOURCE_2 = "Quest"
            assert.are.equal("Drop", ns.Recipes_SourceLabel(0))
            assert.are.equal("Quest", ns.Recipes_SourceLabel(1))
            assert.are.equal("Other", ns.Recipes_SourceLabel(nil))
        end)
    end)

    describe("with the addon's own recipe data", function()
        before_each(function()
            local db = {
                [5] = { s = 171, n = "Late", c = { 200, 220, 240, 260 } },
                [6] = { s = 171, n = "Early", c = { 1, 20, 40, 60 }, l = 1 },
            }
            ns.RecipeDB_Get = function(id) return db[id] end
            ns.RecipeDB_Required = function(r) return r.l or r.c[1] end
            ns.RecipeDB_Colors = function(r) return r.c end
            ns.RecipeDB_SearchText = function(id) return id == 6 and "early alchemist anna stormwind" or "" end
            game.recipes = {
                [5] = recipe("Late", { learned = false, trivial = 1 }),
                [6] = recipe("Early", { learned = false, trivial = 999 }),
            }
            openAndReady(171)
        end)

        it("gives the unknown recipes their skill levels and sorts them by the skill they need", function()
            local copy = ns.Recipes_Read(171)
            assert.are.equal("Early", copy.unknown[1].name)
            assert.are.equal(1, copy.unknown[1].required)
            assert.are.same({ 200, 220, 240, 260 }, copy.unknown[2].colors)
            assert.is_not_nil(copy.unknown[2].db)
        end)

        it("searches in the data's NPCs and zones too", function()
            local copy = ns.Recipes_Read(171)
            local rows = ns.Recipes_Rows(copy, { text = "stormwind", unknown = true })
            assert.are.equal("Early", rows[2].recipe.name)
            assert.are.equal(2, #rows)
        end)
    end)

    describe("asking for a profession", function()
        local timers

        before_each(function()
            timers = {}
            _G.C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
            _G.ProfessionsFrame = nil
            game.recipes = { [1] = recipe("Known", { learned = true }) }
        end)

        local function fire(event) FireEvent(event) end

        it("answers at once when the profession is already open", function()
            openAndReady(171)
            local got
            ns.Recipes_Request(171, function(copy) got = copy end)
            assert.is_not_nil(got)
            assert.are.equal(0, #game.opened)
            assert.are.equal(0, game.closed)
        end)

        it("opens the profession, reads it when the game says it is ready, and closes it again", function()
            local got
            ns.Recipes_Request(171, function(copy, reason) got = { copy = copy, reason = reason } end)
            assert.are.same({ 171 }, game.opened)
            assert.is_nil(got)
            game.ready = true
            fire("TRADE_SKILL_LIST_UPDATE")
            assert.is_not_nil(got.copy)
            assert.are.equal(1, #got.copy.known)
            assert.are.equal(1, game.closed)
        end)

        it("hides the game's window while it is open for us, and shows it again", function()
            local frame = WowMock.NewFrame("ProfessionsFrame")
            _G.ProfessionsFrame = frame
            ns.Recipes_Request(171, function() end)
            game.ready = true
            fire("TRADE_SKILL_SHOW")
            assert.are.equal(1, frame:GetAlpha())
        end)

        it("leaves a window the player had open alone", function()
            openAndReady(164) -- another profession is open
            local got
            ns.Recipes_Request(171, function(copy) got = copy end)
            game.ready = true
            game.open = 171
            fire("TRADE_SKILL_LIST_UPDATE")
            assert.is_not_nil(got)
            assert.are.equal(0, game.closed)
        end)

        it("waits when the list arrives empty and fills in later", function()
            local saved = game.recipes
            game.recipes = {}
            local got
            ns.Recipes_Request(171, function(copy) got = copy end)
            game.ready = true
            fire("TRADE_SKILL_LIST_UPDATE")
            assert.is_nil(got)
            game.recipes = saved
            fire("TRADE_SKILL_LIST_UPDATE")
            assert.are.equal(1, #got.known)
        end)

        it("gives up when the game never answers", function()
            local got, why
            ns.Recipes_Request(171, function(copy, reason) got, why = copy, reason end)
            for _, f in ipairs(timers) do f() end
            assert.is_nil(got)
            assert.are.equal("timeout", why)
            assert.are.equal(1, game.closed)
        end)

        it("reports when the game refuses to open it", function()
            game.opens = false
            local got, why = "unset", nil
            ns.Recipes_Request(171, function(copy, reason) got, why = copy, reason end)
            assert.is_nil(got)
            assert.are.equal("not-opened", why)
        end)

        it("reports a client without the API", function()
            _G.C_TradeSkillUI = nil
            local why
            ns.Recipes_Request(171, function(_, reason) why = reason end)
            assert.are.equal("no-api", why)
        end)

        it("a new request supersedes the one waiting", function()
            local first, second
            ns.Recipes_Request(171, function(_, reason) first = reason end)
            ns.Recipes_Request(164, function(copy) second = copy end)
            assert.are.equal("superseded", first)
            game.ready = true
            fire("TRADE_SKILL_LIST_UPDATE")
            assert.is_not_nil(second)
            assert.are.equal(164, second.skillLine)
        end)
    end)
end)
