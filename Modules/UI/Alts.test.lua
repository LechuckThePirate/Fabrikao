dofile("setupTests.lua")

-- The items of the other characters (Embolsao's copies) in the recipe pages: counts, filter, tooltips, details, preference.
describe("Other characters' items", function()
    local ns, bag, tooltipLines

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 } }, k = { 6 } },
            [3] = { s = 171, n = "Elixir of Giants", c = { 200, 220, 240, 260 }, m = { { 10, 1 } }, k = { 4 } },
        },
        items = {}, trainers = {},
    }

    local function visible(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f, button) f._scripts.OnClick(f, button or "LeftButton") end

    local function recipeRows()
        local out = {}
        for _, row in ipairs(visible("data")) do
            if row.data.kind == "recipe" then out[#out + 1] = row end
        end
        return out
    end

    local function checks()
        return WowMock.FindAll(function(f) return f._template == "UICheckButtonTemplate" and f:IsVisible() end)
    end

    local function openAlchemy()
        ns.UI_Toggle()
        click(visible("profession")[1])
    end

    before_each(function()
        WowMock.Reset()
        bag = { [10] = 1 } -- the character has one: not enough for the elixir (two)
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 60, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return id == 1 end }
        _G.C_Item = {
            GetItemCount = function(id, includeBank) return (bag[id] or 0) + (includeBank and 0 or 0) end,
            GetItemNameByID = function(id) return "Item" .. id end,
        }
        _G.UnitName = function() return "Therzok" end
        _G.UnitClass = function() return "Warrior", "WARRIOR" end
        _G.EmbolsaoDB = { characterItems = {
            ["Elsa-Realm"] = { name = "Elsa", class = "MAGE", time = 1, bags = { [10] = 4 }, bank = {} },
        } }
        tooltipLines = {}
        GameTooltip.AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
    end)

    it("counts the other characters' items when asked: 1 + 4 = 5 of the ingredient, two elixirs", function()
        openAlchemy()
        assert.are.equal(0, recipeRows()[1].data.craftable)
        local alts = checks()[3]
        alts:SetChecked(true)
        click(alts)
        assert.are.equal(2, recipeRows()[1].data.craftable)
        assert.matches("Elixir of Wisdom %(2%)", recipeRows()[1].text._text)
        assert.is_true(ns.char.filters.alts)
    end)

    it("can make now with the other characters' items", function()
        openAlchemy()
        local canMake, alts = checks()[1], checks()[3]
        canMake:SetChecked(true)
        click(canMake)
        assert.are.equal(1, #recipeRows()) -- only the giants' elixir (needs one)
        alts:SetChecked(true)
        click(alts)
        assert.are.equal(2, #recipeRows())
    end)

    it("offers the checkbox only when there are other characters", function()
        _G.EmbolsaoDB = nil
        ns.char.filters = { alts = true } -- remembered from before Embolsao went away: it doesn't count
        openAlchemy()
        assert.are.equal(2, #checks()) -- can make now, hide grey
        assert.are.equal(0, recipeRows()[1].data.craftable)
    end)

    it("an ingredient's icon says who has the item", function()
        ns.char.view = "table"
        openAlchemy()
        local icon = recipeRows()[1].compIcons[1]
        icon._scripts.OnEnter(icon)
        local text = table.concat(tooltipLines, "\n")
        assert.matches("Needs 2, you have 1", text)
        assert.matches("Therzok: 1 in bags", text)
        assert.matches("Elsa|r: 4 in bags", text)
    end)

    it("the ingredient icon is tinted by what the counts allow", function()
        ns.char.view = "table"
        openAlchemy()
        local icon = recipeRows()[1].compIcons[1]
        assert.are.same({ 1, 0.35, 0.35 }, icon.texture._set.SetVertexColor) -- one of two
        local alts = checks()[3]
        alts:SetChecked(true)
        click(alts)
        assert.are.same({ 1, 1, 1 }, recipeRows()[1].compIcons[1].texture._set.SetVertexColor) -- five
    end)

    it("the recipe's detail in the search says how many the other characters have", function()
        local _, body = ns.SearchPage_DetailText(1)
        assert.matches("you have 1, %+4 on other characters", body)
    end)

    describe("the preference", function()
        it("turns all of it off", function()
            ns.char.useAlts = false
            openAlchemy()
            assert.are.equal(2, #checks())
            local _, body = ns.SearchPage_DetailText(1)
            assert.is_nil(body:find("other characters", 1, true))
        end)

        it("is a checkbox, with a line saying how many characters Embolsao saved", function()
            ns.Prefs_Toggle()
            local frame = _G.FabrikaoPreferencesFrame
            frame._scripts.OnShow(frame)
            assert.matches("1 with items saved by Embolsao", frame.prices._text)
            frame.altsCheck:SetChecked(false)
            click(frame.altsCheck)
            assert.is_false(ns.char.useAlts)
            frame._scripts.OnShow(frame)
            assert.matches("not used", frame.prices._text)
        end)
    end)
end)
