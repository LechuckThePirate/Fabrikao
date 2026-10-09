dofile("setupTests.lua")

describe("SearchPage", function()
    local ns

    local DATA = {
        recipes = {
            [100] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 }, g = 5000 },
            [101] = { s = 171, n = "Mighty Flask", c = { 250, 270, 290, 310 }, m = { { 12, 3 } }, k = { 2 }, i = 900 },
            [102] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, p = { 201, 1, 2 }, k = { 5 }, i = 901 },
        },
        items = {
            [900] = { n = "Recipe: Mighty Flask", lv = 50, k = { 2 }, d = { { id = 1, n = "Black Drake", z = { 46 }, lo = 55, hi = 57, pm = 125 } }, dn = 1 },
            [901] = { n = "Plans: Iron Sword", lv = 20, k = { 5 }, v = { { id = 3, n = "Smith Sam", z = { 1519 } } } },
        },
        trainers = { [171] = { { id = 7, n = "Alchemist Anna", z = { 1519 } } } },
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function searchBox()
        local boxes = WowMock.FindAll(function(f) return f._template == "InputBoxTemplate" and f:IsVisible() end)
        return boxes[#boxes]
    end

    local function typeInto(box, text)
        box:SetText(text)
        box._scripts.OnTextChanged(box, true)
    end

    before_each(function()
        WowMock.Reset()
        _G.UnitFactionGroup = function() return "Alliance" end
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [46] = "Burning Steppes" })[id] end }
        local names = { [10] = "Peacebloom", [11] = "Silverleaf", [12] = "Dreamfoil", [200] = "Wisdom Elixir", [201] = "Iron Blade" }
        _G.C_Item = {
            GetItemNameByID = function(id) return names[id] end,
            GetItemIconByID = function(id) return 9000 + id end,
            GetItemCount = function(id) return ({ [10] = 5, [11] = 0 })[id] or 0 end,
        }
        _G.C_SpellBook = { IsSpellKnown = function(id) return id == 100 end }
        _G.Enum = { SpellBookSpellBank = { Player = 0 } }
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 80, 300, 1, 10, 171, 0 end
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
    end)

    describe("the detail of a recipe", function()
        it("says if the character knows it, the skill it needs, its colors, the product and the ingredients with how many are in the bags", function()
            local name, body = ns.SearchPage_DetailText(100)
            assert.are.equal("Elixir of Wisdom", name)
            assert.matches("Alchemy", body)
            assert.matches("You know this recipe", body)
            assert.matches("Skill needed:|r 1  %(|cff40bf40you have 80", body)
            assert.matches("For your skill:|r |cff3fbf3fgreen|r", body)
            assert.matches("Wisdom Elixir x1", body)
            assert.matches("Peacebloom x2  %(|cff40bf40you have 5", body)
            assert.matches("Silverleaf x1  %(|cffff4040you have 0", body)
            assert.matches("Alchemist Anna %(Stormwind City%)", body)
        end)

        it("for a recipe of a profession the character doesn't have", function()
            local _, body = ns.SearchPage_DetailText(102)
            assert.matches("You don't have this profession", body)
            assert.matches("x1%-2", body)
            assert.matches("Smith Sam %(Stormwind City%)", body)
            assert.is_nil(body:find("you have 80", 1, true)) -- no skill of its own to compare
        end)

        it("for a recipe the character could learn but doesn't know, and one it can't yet", function()
            local _, body = ns.SearchPage_DetailText(101)
            assert.matches("You don't know this recipe yet", body)
            assert.matches("|cffff4040you have 80", body) -- needs 250
            assert.matches("Black Drake %(Burning Steppes%) level 55%-57", body)
            assert.is_nil(body:find("For your skill:", 1, true))
        end)

        it("asks the client for item names it doesn't have yet", function()
            local requested = {}
            _G.C_Item.GetItemNameByID = function() return nil end
            _G.C_Item.RequestLoadItemDataByID = function(id) requested[#requested + 1] = id end
            local _, body = ns.SearchPage_DetailText(100)
            assert.matches("item 10 x2", body)
            assert.is_true(#requested >= 2)
        end)
    end)

    describe("the page", function()
        it("opens with /fab find and lists what matches", function()
            SlashCmdList.FABRIKAO("find sword")
            assert.is_true(_G.FabrikaoFrame:IsShown())
            local results = ns.SearchPage_Results()
            assert.are.equal(1, #results)
            assert.are.equal("Iron Sword", results[1].recipe.name)
        end)

        it("lists a recipe the character can use in its difficulty color, and marks the ones it knows", function()
            ns.UI_ShowSearch("elixir")
            local rows = framesWith("recipe")
            assert.are.equal(1, #rows)
            assert.are.same({ 0.25, 0.75, 0.25 }, rows[1].text._set.SetTextColor)
            assert.matches("ReadyCheck", rows[1].info._text)
        end)

        it("over the icon of a result, the tooltip of what it makes", function()
            ns.UI_ShowSearch("elixir")
            local row = framesWith("recipe")[1]
            row.iconButton._scripts.OnEnter(row.iconButton)
            assert.are.same({ 200 }, GameTooltip._set.SetItemByID)
        end)

        it("selecting a result shows its detail", function()
            ns.UI_ShowSearch("i")
            local rows = framesWith("recipe")
            assert.are.equal(3, #rows)
            local flask
            for _, row in ipairs(rows) do if row.spellID == 101 then flask = row end end
            flask._scripts.OnClick(flask)
            local detail = WowMock.Find(function(f) return type(f._text) == "string" and f._text:find("Black Drake", 1, true) end)
            assert.is_not_nil(detail)
        end)

        it("a recipe the character knows has a Craft button, with how many the bags allow; one it doesn't know has none", function()
            local opened
            ns.Craft_Open = function(id, skillLine) opened = { id, skillLine } end
            ns.UI_ShowSearch("elixir") -- known; 5 Peacebloom for 2 each, no Silverleaf
            local button = WowMock.FindButton("Craft")
            assert.is_true(button:IsVisible())
            assert.matches("0 possible with your bags", WowMock.Find(function(f) return f._text and f._text:find("possible with your bags", 1, true) end)._text)
            button._scripts.OnClick(button)
            assert.are.same({ 100, 171 }, opened)

            ns.UI_ShowSearch("flask") -- not known
            assert.is_false(button:IsVisible())
        end)

        it("typing in the box over the professions goes to the search", function()
            ns.UI_Toggle()
            local box = searchBox()
            typeInto(box, "flask")
            assert.are.equal(1, #ns.SearchPage_Results())
            assert.are.equal("Mighty Flask", ns.SearchPage_Results()[1].recipe.name)
            assert.are.equal("", box:GetText())
            assert.are.equal(0, #framesWith("profession"))
        end)

        it("the profession button limits the search, and with no text lists the whole profession by skill", function()
            ns.UI_ShowSearch("")
            assert.are.equal(0, #ns.SearchPage_Results())
            local button = WowMock.FindButton("Profession: All")
            button._scripts.OnClick(button) -- alchemy
            local results = ns.SearchPage_Results()
            assert.are.equal(2, #results)
            assert.are.equal("Elixir of Wisdom", results[1].recipe.name) -- needs less skill
            button._scripts.OnClick(button) -- blacksmithing
            assert.are.equal(1, #ns.SearchPage_Results())
            button._scripts.OnClick(button) -- back to all
            assert.are.equal(0, #ns.SearchPage_Results())
        end)

        it("going back shows the professions again", function()
            ns.UI_ShowSearch("sword")
            local back = WowMock.Find(function(f) return f._text == "< Professions" and f:IsVisible() and f._scripts.OnClick end)
            back._scripts.OnClick(back)
            assert.are.equal(1, #framesWith("profession"))
        end)
    end)
end)
