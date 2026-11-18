dofile("setupTests.lua")

-- "Consolidate alts" in the window: the switch in the title bar, the professions of every character, the recipes any of them knows
-- counted as known (with who knows them), and the Craft button only for what the playing character knows.
describe("Consolidate alts", function()
    local ns

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Mana Potion", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [5] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, m = { { 20, 1 } }, k = { 6 } },
            [6] = { s = 164, n = "Steel Axe", c = { 150, 170, 190, 210 }, m = { { 20, 2 } }, k = { 6 } },
        },
        items = {}, trainers = {},
    }

    local mine -- the spells the playing character knows

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function switch() return _G.FabrikaoFrame.consolidateSwitch end

    local function professionRow(skillLine)
        for _, b in ipairs(framesWith("profession")) do
            if b.profession.skillLine == skillLine then return b end
        end
    end

    local function recipeRows()
        local out = {}
        for _, row in ipairs(framesWith("data")) do
            if row.data.kind == "recipe" then out[row.data.recipe.name] = row end
        end
        return out
    end

    local function knownNames()
        local out = {}
        for _, row in ipairs(framesWith("data")) do
            if row.data.kind == "recipe" and row.data.recipe.learned then out[#out + 1] = row.data.recipe.name end
        end
        table.sort(out)
        return out
    end

    before_each(function()
        WowMock.Reset()
        WowMock.menuDropdowns = true
        mine = { [1] = true, [2] = true }
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = {
            GetSpellBookItemInfo = function(slot) return { spellID = slot } end,
            IsSpellKnown = function(id) return mine[id] == true end,
        }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function() return 10 end }
        _G.RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB = nil, nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        FabrikaoDB.characters = {
            ["Elsa-Realm"] = { name = "Elsa", realm = "Realm", class = "MAGE", time = 1, professions = {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 120, maxRank = 150, primary = true, hasRecipes = true, known = { 5 } },
                { skillLine = 171, name = "Alchemy", icon = 111, rank = 40, maxRank = 75, primary = true, hasRecipes = true, known = { 3 } },
            } },
        }
        ns.UI_Show()
    end)

    describe("the switch", function()
        it("sits in the title bar, off at first, and is kept", function()
            assert.is_not_nil(switch())
            assert.is_false(switch().on)
            click(switch())
            assert.is_true(switch().on)
            assert.is_true(ns.Consolidated())
            assert.is_true(FabrikaoCharDB.consolidateAlts)
            click(switch())
            assert.is_false(ns.Consolidated())
        end)

        it("says what it does in its tooltip", function()
            local lines = {}
            GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
            switch()._scripts.OnEnter(switch())
            assert.matches("all your characters as one", table.concat(lines, "\n"))
        end)

        it("there is no picker of a character any more", function()
            assert.is_nil(WowMock.Find(function(f) return f._template == "WowStyle1DropdownTemplate" and f:IsVisible()
                and f.shownText == "My professions" end))
        end)
    end)

    describe("the professions", function()
        it("off, are the playing character's", function()
            assert.is_not_nil(professionRow(171))
            assert.is_nil(professionRow(164))
            assert.are.equal("Alchemy", professionRow(171).name._text)
        end)

        it("on, are every character's, each once, with the alts that have it after the name in their class color", function()
            click(switch())
            assert.are.equal("Alchemy |cffffffff(|r|cff3fc7ebElsa|r|cffffffff)|r", professionRow(171).name._text)
            local smithing = professionRow(164)
            assert.matches("|cff3fc7ebElsa|r", smithing.name._text)
            assert.are.equal("120 / 150", smithing.barText._text) -- her skill: nobody else has it
        end)

        it("the tooltip gives each character's skill", function()
            click(switch())
            local lines = {}
            GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
            professionRow(171)._scripts.OnEnter(professionRow(171))
            local all = table.concat(lines, "\n")
            assert.matches("Tester|r: 150 / 300", all, 1, true) -- (in the playing character's class color too)
            assert.matches("|cff3fc7ebElsa|r: 40 / 75", all)
        end)
    end)

    describe("a profession's recipes", function()
        it("count as known what any character knows, and say it is the whole account's", function()
            click(professionRow(171))
            assert.are.same({ "Elixir of Wisdom", "Healing Potion" }, knownNames())
            ns.UI_ShowOverview()
            click(switch())
            click(professionRow(171))
            assert.are.same({ "Elixir of Wisdom", "Healing Potion", "Mana Potion" }, knownNames())
            local banner = WowMock.Find(function(f) return f._text == "All your characters" and f:IsVisible() end)
            assert.is_not_nil(banner)
        end)

        it("are drawn again when switched on the page", function()
            click(professionRow(171))
            click(switch())
            assert.are.same({ "Elixir of Wisdom", "Healing Potion", "Mana Potion" }, knownNames())
        end)

        it("of a profession only an alt has go by its skill, and the page names it", function()
            click(switch())
            click(professionRow(164))
            assert.are.same({ "Iron Sword" }, knownNames())
            local banner = WowMock.Find(function(f) return f._text and f._text:match("skill of |cff3fc7ebElsa|r") and f:IsVisible() end)
            assert.is_not_nil(banner)
            -- switched off, the playing character has no Blacksmithing: back to the start screen
            click(switch())
            assert.is_nil(professionRow(164))
        end)

        it("the tooltip of a recipe says who knows it", function()
            click(switch())
            click(professionRow(171))
            local lines = {}
            GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
            local potion = recipeRows()["Mana Potion"]
            potion._scripts.OnEnter(potion)
            assert.matches("Known by: |cff3fc7ebElsa|r", table.concat(lines, "\n"))
        end)
    end)

    describe("the panel of a recipe", function()
        local function open(name)
            click(professionRow(171))
            local row = recipeRows()[name]
            row._scripts.OnClick(row, "LeftButton")
            return ns.RecipeDetail_Build(ns.RecipeDetail_Current(), {})
        end

        it("says who knows it, and has no Craft button when only an alt does", function()
            click(switch())
            local data = open("Mana Potion")
            assert.matches("Elsa", data.status)
            local fact
            for _, f in ipairs(data.facts) do if f.label == "Known by:" then fact = f.value end end
            assert.are.equal("|cff3fc7ebElsa|r", fact)
            assert.is_false(_G.FabrikaoDetailFrame.craftBar:IsShown())
        end)

        it("has the Craft button for what the playing character knows", function()
            click(switch())
            local data = open("Healing Potion")
            assert.matches("You know this recipe", data.status)
            assert.is_true(_G.FabrikaoDetailFrame.craftBar:IsShown())
        end)
    end)

    describe("the search of every recipe", function()
        it("counts as known what any character knows", function()
            click(switch())
            ns.UI_ShowSearch("Sword")
            local results = ns.SearchPage_Results()
            assert.are.equal(1, #results)
            assert.is_true(results[1].recipe.learned)
            click(switch())
            assert.is_false(ns.SearchPage_Results()[1].recipe.learned)
        end)
    end)
end)
