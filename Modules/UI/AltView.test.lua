dofile("setupTests.lua")

-- Another character's professions in the window: the picker, the professions that are not learned, the blue tint and the
-- line that say whose they are, and no crafting.
describe("Another character's professions", function()
    local ns

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [5] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, m = { { 20, 1 } }, k = { 6 } },
            [6] = { s = 164, n = "Steel Axe", c = { 150, 170, 190, 210 }, m = { { 20, 2 } }, k = { 6 } },
            [7] = { s = 185, n = "Spiced Wolf Meat", c = { 1, 20, 40, 60 }, k = { 6 } },
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

    local function professionNames()
        local names = {}
        for _, b in ipairs(framesWith("profession")) do names[#names + 1] = b.profession.name end
        return names
    end

    local function recipeNames()
        local out = {}
        for _, row in ipairs(framesWith("data")) do
            if row.data.kind == "recipe" then out[#out + 1] = row.data.recipe.name end
        end
        return out
    end

    local function picker()
        return WowMock.FindAll(function(f) return f._template == "WowStyle1DropdownTemplate" and f:IsVisible() end)[1]
    end

    local function pick(text)
        for _, e in ipairs(picker().menu) do
            if e.text == text then e.choose() return end
        end
        error("no entry " .. text)
    end

    local function toggleButton()
        return WowMock.FindAll(function(f)
            return f._scripts.OnClick and f._text and f._text:match("professions not learned") and f:IsVisible()
        end)[1]
    end

    -- the copy another character saved of itself
    local function saveElsa()
        FabrikaoDB.characters = FabrikaoDB.characters or {}
        FabrikaoDB.characters["Elsa-Realm"] = {
            name = "Elsa", realm = "Realm", class = "MAGE", time = 1, professions = {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 120, maxRank = 150, primary = true, hasRecipes = true, known = { 5 } },
                { skillLine = 185, name = "Cooking", icon = 444, rank = 10, maxRank = 75, primary = false, hasRecipes = true, known = { 7 } },
            },
        }
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
        saveElsa()
    end)

    describe("the picker", function()
        it("offers the playing character's professions, then each alt that has saved its own", function()
            ns.UI_Show()
            local options = {}
            for _, e in ipairs(picker().menu) do options[#options + 1] = e.text end
            assert.are.same({ "My professions", "Elsa" }, options)
            assert.are.equal("My professions", picker().shownText)
        end)

        it("says how an alt gets here when there is none yet", function()
            FabrikaoDB.characters["Elsa-Realm"] = nil
            ns.UI_Show()
            picker():GenerateMenu()
            local hint
            for _, e in ipairs(picker().menu) do if e.kind == "title" then hint = e.text end end
            assert.matches("Log in with your other characters", hint)
        end)
    end)

    describe("the professions that are not learned", function()
        it("are hidden by default and a button lists them under their own title", function()
            ns.UI_Show()
            assert.are.same({ "Alchemy" }, professionNames())
            assert.are.equal("Show professions not learned", toggleButton()._text)
            click(toggleButton())
            assert.are.same({ "Alchemy", "Blacksmithing", "Cooking" }, professionNames())
            assert.are.equal("Hide professions not learned", toggleButton()._text)
            click(toggleButton())
            assert.are.same({ "Alchemy" }, professionNames())
        end)

        it("open a page with every recipe of the profession, none of them known", function()
            ns.UI_Show()
            click(toggleButton())
            for _, b in ipairs(framesWith("profession")) do
                if b.profession.name == "Blacksmithing" then click(b) end
            end
            assert.are.same({ "Iron Sword", "Steel Axe" }, recipeNames())
            for _, row in ipairs(framesWith("data")) do
                if row.data.kind == "recipe" then assert.is_false(row.data.recipe.learned) end
            end
        end)

        it("are remembered for the character, and a reset of the settings forgets it", function()
            ns.UI_Show()
            click(toggleButton())
            assert.is_true(FabrikaoCharDB.showMissing)
            ns.ResetSettings()
            assert.is_nil(FabrikaoCharDB.showMissing)
        end)
    end)

    describe("looking at an alt", function()
        local function lookAtElsa()
            ns.UI_Show()
            pick("Elsa")
        end

        it("lists her professions, as the playing character would see its own", function()
            lookAtElsa()
            assert.are.same({ "Blacksmithing", "Cooking" }, professionNames())
            assert.are.equal("120 / 150", framesWith("profession")[1].barText._text)
        end)

        it("names her in the picker, tints the window blue and puts her name in the title", function()
            lookAtElsa()
            assert.are.equal("Elsa", picker().shownText)
            assert.is_true(_G.FabrikaoFrame.viewTint:IsShown())
            local titles = WowMock.FindAll(function(f) return f._text and f._text:match("^Fabrikao!! v") end)
            assert.is_true(#titles > 0)
            assert.matches("|cff3fc7ebElsa|r", titles[#titles]._text)
        end)

        it("shows the recipes she knows as known, with a line on the page saying whose they are", function()
            lookAtElsa()
            click(framesWith("profession")[1]) -- blacksmithing
            local known = {}
            for _, row in ipairs(framesWith("data")) do
                if row.data.kind == "recipe" and row.data.recipe.learned then known[#known + 1] = row.data.recipe.name end
            end
            assert.are.same({ "Iron Sword" }, known) -- Steel Axe is not hers
            local banner = WowMock.FindAll(function(f) return f._text and f._text:match("read only") and f:IsVisible() end)[1]
            assert.is_not_nil(banner)
            assert.matches("Elsa", banner._text)
        end)

        it("has no Craft button in the panel of a recipe, and names her", function()
            lookAtElsa()
            click(framesWith("profession")[1])
            for _, row in ipairs(framesWith("data")) do
                if row.data.kind == "recipe" and row.data.recipe.name == "Iron Sword" then
                    row._scripts.OnClick(row, "LeftButton")
                    break
                end
            end
            assert.is_true(_G.FabrikaoDetailFrame:IsShown())
            assert.is_false(_G.FabrikaoDetailFrame.craftBar:IsShown())
            assert.matches("Elsa", ns.RecipeDetail_Build(ns.RecipeDetail_Current(), {}).status)
        end)

        it("counts what she carries for 'can make', not what the playing character does", function()
            _G.EmbolsaoAPI = { version = 1, GetCharacters = function() return {} end, GetOthersItemCount = function() return 0, 0 end,
                GetItemHolders = function(itemID)
                    if itemID == 20 then return { { name = "Elsa", class = "MAGE", bags = 3, bank = 0 } } end
                    return {}
                end }
            lookAtElsa()
            assert.are.equal(3, ns.Inventory_Count(20, false)) -- the playing character has 10 of everything
            assert.are.equal(0, ns.Inventory_Count(10, false))
        end)

        it("goes back to the playing character's professions with the first entry", function()
            lookAtElsa()
            pick("My professions")
            assert.are.same({ "Alchemy" }, professionNames())
            assert.is_false(_G.FabrikaoFrame.viewTint:IsShown())
        end)

        it("is the playing character's again when the window is closed and opened", function()
            lookAtElsa()
            ns.UI_Hide()
            assert.is_nil(ns.Roster_ViewKey())
            assert.is_false(_G.FabrikaoFrame.viewTint:IsShown())
            ns.UI_Show()
            assert.are.same({ "Alchemy" }, professionNames())
        end)
    end)
end)
