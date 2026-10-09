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

    local function recipeRows()
        local out = {}
        for _, row in ipairs(framesWith("data")) do
            if row.data.kind == "recipe" then out[#out + 1] = row end
        end
        return out
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

    describe("the page", function()
        it("opens with /fab find and lists what matches", function()
            SlashCmdList.FABRIKAO("find sword")
            assert.is_true(_G.FabrikaoFrame:IsShown())
            local results = ns.SearchPage_Results()
            assert.are.equal(1, #results)
            assert.are.equal("Iron Sword", results[1].recipe.name)
        end)

        it("lists the matches like a profession's page does, in the table and in the detailed view", function()
            ns.UI_ShowSearch("elixir")
            local rows = recipeRows()
            assert.are.equal(1, #rows)
            assert.are.equal("Elixir of Wisdom", rows[1].data.recipe.name)
            assert.is_true(rows[1].data.recipe.learned)
            local view = WowMock.FindButton("View: Table")
            view._scripts.OnClick(view)
            assert.are.equal("detailed", ns.char.view)
            assert.are.equal(1, #recipeRows())
        end)

        it("a click on a result opens its panel next to the window, and the panel follows what is listed", function()
            ns.UI_ShowSearch("i")
            local flask
            for _, row in ipairs(recipeRows()) do if row.data.recipe.id == 101 then flask = row end end
            flask._scripts.OnClick(flask, "LeftButton")
            assert.are.equal(101, ns.RecipeDetail_Current().id)
            -- narrowing the search to something else closes it
            local box = searchBox()
            typeInto(box, "sword")
            assert.is_nil(ns.RecipeDetail_Current())
        end)

        it("the panel of a recipe the character knows has the Craft button", function()
            ns.UI_ShowSearch("elixir")
            local row = recipeRows()[1]
            row._scripts.OnClick(row, "LeftButton")
            local craft = WowMock.FindButton("Craft")
            assert.is_true(craft:IsVisible())
        end)

        it("the profession's page takes the list back", function()
            ns.UI_ShowSearch("elixir")
            ns.UI_ShowOverview()
            ns.UI_ShowRecipes(ns.Professions_List()[1])
            assert.is_true(#recipeRows() > 0)
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
