dofile("setupTests.lua")

-- "You can craft now": what the bags allow to make with the recipes the character knows, under the professions of the main screen.
describe("You can craft now", function()
    local ns, bag, known, opened

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 140, 160, 180, 200 }, m = { { 10, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Mana Potion", c = { 140, 160, 180, 200 }, m = { { 11, 1 } }, k = { 6 } },
            [4] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, m = { { 10, 1 } }, k = { 6 } },
            [5] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, m = { { 10, 1 } }, k = { 6 } },
        },
        items = {}, trainers = {},
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function rows()
        local out = {}
        for _, f in ipairs(framesWith("craft")) do out[#out + 1] = f end
        return out
    end

    local function names()
        local out = {}
        for _, f in ipairs(rows()) do out[#out + 1] = f.name._text end
        return out
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function fireBags()
        for _, f in ipairs(WowMock.FindAll(function(f) return f._events and f._events.BAG_UPDATE_DELAYED and f._scripts.OnEvent end)) do
            f._scripts.OnEvent(f, "BAG_UPDATE_DELAYED")
        end
    end

    before_each(function()
        WowMock.Reset()
        WowMock.menuDropdowns = true
        bag = { [10] = 5 }
        known = { [1] = true, [2] = true, [3] = true, [5] = true } -- 4 is not known; 5 is blacksmithing, which the character lacks
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = {
            GetSpellBookItemInfo = function(slot) return { spellID = slot } end,
            IsSpellKnown = function(id) return known[id] == true end,
        }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function(id) return bag[id] or 0 end }
        _G.RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB = nil, nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        opened = {}
        ns.Craft_Open = function(recipeID, skillLine) opened[#opened + 1] = { recipeID, skillLine } return true end
        StartAddon(ns)
    end)

    it("lists the known recipes of the character's professions that its bags allow, orange first, with how many", function()
        ns.UI_Show()
        -- Healing Potion is orange (5 times), Elixir grey (2 times); Mana Potion lacks its ingredient, the Flask is not known and
        -- the sword is another profession's
        assert.are.same({ "Healing Potion (5)", "Elixir of Wisdom (2)" }, names())
        assert.are.equal("Alchemy", rows()[1].skillText._text)
        assert.are.same({ 1, 0.5, 0.25 }, rows()[1].name._set.SetTextColor)
    end)

    -- the title of the quadrant, with the count
    local function title()
        return WowMock.FindAll(function(f)
            return f._text and f._text:match("^You can craft now") and f:IsVisible()
        end)[1]
    end

    it("is a quadrant of its own with the count in its title, under the professions' quadrant", function()
        ns.UI_Show()
        assert.are.equal("You can craft now (2)", title()._text)
        -- the bottom left: its rows are lower on the screen than the professions' (not in the same scroll)
        assert.are_not.equal(rows()[1]._parent, framesWith("profession")[1]._parent)
    end)

    it("a click opens the game's profession window on the recipe, as the Craft button does", function()
        ns.UI_Show()
        click(rows()[2])
        assert.are.same({ { 1, 171 } }, opened)
    end)

    it("says so when the bags allow nothing", function()
        bag = {}
        ns.UI_Show()
        assert.are.same({}, names())
        local none = WowMock.FindAll(function(f) return f._text and f._text:match("^Nothing to craft") and f:IsVisible() end)
        assert.are.equal(1, #none)
    end)

    it("follows the bags", function()
        ns.UI_Show()
        assert.are.equal(2, #rows())
        bag = { [10] = 5, [11] = 4 }
        fireBags()
        assert.are.same({ "Healing Potion (5)", "Mana Potion (4)", "Elixir of Wisdom (2)" }, names())
    end)

    describe("with Consolidate alts on", function()
        local function saveElsa()
            FabrikaoDB.characters = { ["Elsa-Realm"] = { name = "Elsa", realm = "Realm", class = "MAGE", time = 1, professions = {
                { skillLine = 164, name = "Blacksmithing", icon = 333, rank = 120, maxRank = 150, primary = true, hasRecipes = true, known = { 5 } },
            } } }
        end

        local function withEmbolsao(holders)
            _G.EmbolsaoAPI = { version = 1, GetCharacters = function() return {} end, GetOthersItemCount = function() return 0, 0 end,
                GetItemHolders = function(itemID) return holders[itemID] or {} end }
        end

        after_each(function() _G.EmbolsaoAPI = nil end)

        -- the group of a profession of an alt, folded until it is opened
        local function openGroup(text)
            local header = WowMock.Find(function(f) return f.kind == "craft" and f.text and f.text._text == text and f:IsVisible() end)
            header._scripts.OnClick(header, "LeftButton")
        end

        it("lists what each alt can craft with its own bags, under its name and by profession, after the playing character", function()
            saveElsa()
            withEmbolsao({ [10] = { { name = "Elsa", class = "MAGE", bags = 3, bank = 7 } } })
            ns.UI_Show()
            ns.SetConsolidated(true)
            assert.are.same({ "Healing Potion (5)", "Elixir of Wisdom (2)" }, names()) -- the playing character's, with no title
            local headings = WowMock.FindAll(function(f) return f._text and f._text:match("Elsa|r %(1%)") and f:IsVisible() end)
            assert.are.equal(1, #headings)
            openGroup("Blacksmithing (1)")
            assert.are.same({ "Healing Potion (5)", "Elixir of Wisdom (2)", "Iron Sword (3)" }, names()) -- her bags, not her bank
            assert.are.equal("You can craft now (3)", title()._text)
        end)

        it("an alt's row only tells: a click crafts nothing", function()
            saveElsa()
            withEmbolsao({ [10] = { { name = "Elsa", class = "MAGE", bags = 3, bank = 0 } } })
            ns.UI_Show()
            ns.SetConsolidated(true)
            openGroup("Blacksmithing (1)")
            local sword = rows()[3]
            assert.are.equal("Elsa-Realm", sword.craft.owner)
            click(sword)
            assert.are.same({}, opened)
            click(rows()[1])
            assert.are.equal(1, #opened) -- the playing character's still do
        end)

        it("says Embolsao!! is needed to know what the alts carry", function()
            saveElsa()
            ns.UI_Show()
            ns.SetConsolidated(true)
            assert.are.equal(2, #rows())
            local note = WowMock.FindAll(function(f) return f._text and f._text:match("Install Embolsao") and f:IsVisible() end)
            assert.are.equal(1, #note)
        end)
    end)

    it("cuts the list to the limit and says how many there were", function()
        local found, total = ns.Recipes_CraftableNow(ns.Professions_Mine(), 1)
        assert.are.equal(1, #found)
        assert.are.equal(2, total)
        assert.are.equal("Healing Potion", found[1].recipe.name)
    end)
end)
