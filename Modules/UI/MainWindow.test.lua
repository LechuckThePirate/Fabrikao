dofile("setupTests.lua")

describe("MainWindow", function()
    local ns, requested

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f) end

    before_each(function()
        WowMock.Reset()
        _G.GetProfessions = function() return 1, 2, nil, 3 end
        local info = {
            [1] = { "Alchemy", 111, 150, 300, 171 },
            [2] = { "Herbalism", 222, 20, 300, 182 },
            [3] = { "Cooking", 333, 75, 300, 185 },
        }
        _G.GetProfessionInfo = function(index)
            local p = info[index]
            return p[1], p[2], p[3], p[4], 1, index * 10, p[5], 0
        end
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end }
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_Item = { GetItemCount = function() return 10 end }
        requested = nil
        _G.C_TradeSkillUI = {
            CanTradeSkillShowCraftingUI = function(spellID) return spellID ~= 21 end, -- herbalism has none
        }
        ns = LoadAddon()
        -- the recipes arrive through the request: replaced by a fake that answers at once
        ns.Recipes_Request = function(skillLine, callback)
            requested = skillLine
            callback({
                skillLine = skillLine, sources = { [1] = true, [3] = true },
                known = { { id = 1, name = "Elixir", icon = 5, learned = true, difficulty = 0, reagents = { { items = { 7 }, quantity = 2 } } } },
                unknown = {
                    { id = 3, name = "Potion", icon = 7, learned = false, trivial = 100, sourceType = 3 },
                    { id = 2, name = "Flask", icon = 6, learned = false, trivial = 250, sourceType = 1, sourceText = "Quest: x" },
                },
            })
        end
        StartAddon(ns)
    end)

    it("is a top-level window, so it comes above the other addons' windows when shown or clicked", function()
        ns.UI_Toggle()
        assert.is_true(_G.FabrikaoFrame._set.SetToplevel[1])
    end)

    it("opens and closes", function()
        ns.UI_Toggle()
        assert.is_true(_G.FabrikaoFrame:IsShown())
        ns.UI_Toggle()
        assert.is_false(_G.FabrikaoFrame:IsShown())
        ns.UI_Show()
        assert.is_true(_G.FabrikaoFrame:IsShown())
        ns.UI_Hide()
        assert.is_false(_G.FabrikaoFrame:IsShown())
    end)

    it("closes with Escape", function()
        ns.UI_Toggle()
        local found = false
        for _, name in ipairs(UISpecialFrames) do if name == "FabrikaoFrame" then found = true end end
        assert.is_true(found)
    end)

    it("lists the character's professions with their icons", function()
        ns.UI_Toggle()
        local buttons = framesWith("profession")
        assert.are.equal(3, #buttons)
        assert.are.equal("Alchemy", buttons[1].profession.name)
        assert.are.equal("Herbalism", buttons[2].profession.name)
        assert.are.equal("Cooking", buttons[3].profession.name)
        assert.are.equal(111, buttons[1].icon._set.SetTexture[1])
    end)

    it("a profession with recipes opens its page; one without doesn't", function()
        ns.UI_Toggle()
        local buttons = framesWith("profession")
        click(buttons[2]) -- herbalism
        assert.is_nil(requested)
        click(buttons[1])
        assert.are.equal(171, requested)
    end)

    it("the recipe page shows the known ones in difficulty color, with how many can be made, then the unknown ones (already sorted)", function()
        ns.UI_Toggle()
        click(framesWith("profession")[1])
        local rows = framesWith("data")
        assert.are.equal(5, #rows) -- two headers, one known, two unknown
        assert.matches("Known recipes %(1%)", rows[1].text._text)
        assert.are.equal("Elixir (5)", rows[2].text._text)
        assert.are.same({ 1, 0.5, 0.25 }, rows[2].text._set.SetTextColor)
        assert.matches("Not known %(2%)", rows[3].text._text)
        assert.are.equal("Potion", rows[4].text._text) -- turns grey sooner
        assert.are.equal("Flask", rows[5].text._text)
    end)

    it("an unknown recipe the data knows shows the skill it needs", function()
        ns.Recipes_Request = function(skillLine, callback)
            callback({
                skillLine = skillLine, sources = {}, known = {},
                unknown = { { id = 3, name = "Potion", icon = 7, learned = false, required = 250, colors = { 250, 270, 290, 310 },
                    db = { s = 171, n = "Potion", c = { 250, 270, 290, 310 }, k = { 6 } } } },
            })
        end
        ns.UI_Toggle()
        click(framesWith("profession")[1])
        local rows = framesWith("data")
        assert.matches("250", rows[2].level._text)
    end)

    it("over the icon of a recipe, the tooltip of what it makes (the spell's, when it makes no item)", function()
        ns.Recipes_Request = function(skillLine, callback)
            callback({
                skillLine = skillLine, sources = {},
                known = { { id = 1, name = "Elixir", icon = 5, learned = true, difficulty = 0, db = { s = 171, n = "Elixir", p = { 200, 1, 1 } } } },
                unknown = { { id = 3, name = "Enchant", icon = 7, learned = false, db = { s = 171, n = "Enchant" } } },
            })
        end
        ns.UI_Toggle()
        click(framesWith("profession")[1])
        local rows = framesWith("data")
        local product = rows[2].iconButton
        product._scripts.OnEnter(product)
        assert.are.same({ 200 }, GameTooltip._set.SetItemByID)
        local enchant = rows[4].iconButton
        enchant._scripts.OnEnter(enchant)
        assert.are.same({ 3 }, GameTooltip._set.SetSpellByID)
        assert.is_false(rows[1].iconButton:IsShown()) -- a header has no icon
    end)

    it("the search narrows both groups", function()
        ns.UI_Toggle()
        click(framesWith("profession")[1])
        local search = WowMock.Find(function(f) return f._template == "InputBoxTemplate" end)
        search:SetText("flask")
        search._scripts.OnTextChanged(search)
        local rows = framesWith("data")
        assert.are.equal(2, #rows)
        assert.are.equal("Flask", rows[2].text._text)
    end)

    it("going back shows the professions again", function()
        ns.UI_Toggle()
        click(framesWith("profession")[1])
        assert.are.equal(0, #framesWith("profession"))
        local back
        for _, f in ipairs(WowMock.frames) do
            if f._scripts.OnClick and f._text == "< Professions" then back = f end
        end
        click(back)
        assert.are.equal(3, #framesWith("profession"))
    end)
end)
