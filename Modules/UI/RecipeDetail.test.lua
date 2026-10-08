dofile("setupTests.lua")

-- The panel of a recipe: what it says, and how a click on a recipe of the list opens and closes it.
describe("Recipe detail", function()
    local ns, known, prices

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 2 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 }, g = 5000, u = true },
            [2] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, l = 240, p = { 201, 1, 1 }, m = { { 12, 3 } }, k = { 5 }, i = 900 },
            [3] = { s = 171, n = "Plain", c = { 1, 2, 3, 4 } },
        },
        items = {
            [900] = { n = "Recipe: Flask of the Titans", lv = 50, k = { 5 }, v = {
                { id = 1, n = "Alliance Vendor", z = { 1519 }, g = 12345 }, { id = 2, n = "Horde Vendor", z = { 1637 }, f = "H" },
                { id = 3, n = "Vendor 3", z = { 46 } }, { id = 4, n = "Vendor 4", z = { 46 } }, { id = 5, n = "Vendor 5", z = { 46 } },
                { id = 6, n = "Vendor 6", z = { 46 } }, { id = 7, n = "Vendor 7", z = { 46 } },
            } },
        },
        trainers = { [171] = { { id = 9, n = "Alchemist Anna", z = { 1519 }, f = "A" } } },
    }

    local function visible(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function recipeRow(name)
        for _, row in ipairs(visible("data")) do
            if row.data.kind == "recipe" and row.data.recipe.name == name then return row end
        end
    end

    local function panel() return _G.FabrikaoDetailFrame end

    before_each(function()
        WowMock.Reset()
        _G.FabrikaoDetailFrame, _G.IsModifiedClick, _G.ChatEdit_InsertLink = nil, nil, nil -- (the game's globals outlive a test)
        known = { [1] = true }
        prices = { [10] = 100, [11] = 200, [200] = 5000 }
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 100, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
        _G.UnitFactionGroup = function() return "Alliance" end
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [1637] = "Orgrimmar", [46] = "Burning Steppes" })[id] end }
        local bag = { [10] = 5, [11] = 0, [12] = 1 }
        _G.C_Item = {
            GetItemCount = function(id) return bag[id] or 0 end,
            GetItemNameByID = function(id) return "Item" .. id end,
            GetItemIconByID = function() return 12345 end,
        }
        _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return prices[id] end } } }
        _G.C_TradeSkillUI = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        ns.UI_Toggle()
        click(visible("profession")[1])
    end)

    describe("what it says", function()
        local function build(id, learned, opts)
            local recipe = ns.Recipes_FromRecord(id, DATA.recipes[id], learned, 100)
            return ns.RecipeDetail_Build(recipe, opts)
        end

        it("tells the status, the skill needed and how the colors look for the character", function()
            local detail = build(1, true)
            assert.are.equal("Elixir of Wisdom", detail.name)
            assert.matches("You know this recipe", detail.info)
            assert.matches("Skill needed:|r 1  %(.-you have 100", detail.info)
            assert.matches("Difficulty:", detail.info)
            assert.matches("For your skill:", detail.info)
            assert.matches("Alchemy", detail.subtitle)
            detail = build(2, false)
            assert.matches("You don't know this recipe yet", detail.info)
            assert.matches("Skill needed:|r 240", detail.info)
        end)

        it("without the profession it says so", function()
            local recipe = ns.Recipes_FromRecord(1, DATA.recipes[1], false, nil)
            assert.matches("You don't have this profession", ns.RecipeDetail_Build(recipe).info)
        end)

        it("tells what it makes, how many can be made, the training cost, the teacher and what is new", function()
            local info = build(1, true).info
            assert.matches("Makes:|r .-Item200 x1%-2", info)
            assert.matches("Crafts possible:|r 0", info) -- no Silverleaf
            assert.matches("Training cost:", info)
            assert.matches("New in Forever", info)
            info = build(2, false).info
            assert.matches("Taught by:|r Item900 %(item level 50%)", info)
        end)

        it("lists the ingredients with how many the character has, and the price of each", function()
            local reagents = build(1, true).reagents
            assert.are.equal(2, #reagents)
            assert.are.equal(10, reagents[1].itemID)
            assert.are.equal(5, reagents[1].have)
            assert.matches("Item10 x2", reagents[1].text)
            assert.matches("you have 5", reagents[1].text)
            assert.matches("|cff40bf40", reagents[1].text) -- enough
            assert.matches("|cffff4040", reagents[2].text) -- none
            assert.matches("each", reagents[1].text)
        end)

        it("counts the bank and the other characters", function()
            ns.Inventory_Mine = function() return 1, 4 end
            ns.Inventory_OthersTotal = function() return 7 end
            ns.Inventory_Available = function() return true end
            local reagents = build(1, true, { alts = true }).reagents
            assert.matches("4 in your bank", reagents[1].text)
            assert.matches("%+7 on other characters", reagents[1].text)
            assert.matches("counting your other characters", build(1, true, { alts = true }).info)
        end)

        it("shows the cost, what it sells for and the profit", function()
            local summary = build(1, true).summary
            assert.matches("Ingredients cost:", summary)
            assert.matches("Sells for about:", summary)
            assert.matches("Profit:|r |cff40bf40", summary)
        end)

        it("says when there is no auction data", function()
            _G.Auctionator = nil
            assert.matches("No auction data", build(1, true).summary)
        end)

        it("lists where it is learned, in full: the vendors of the character's side with their zones", function()
            local tail = build(2, false).tail
            assert.matches("Where to learn it", tail)
            assert.matches("Alliance Vendor %(Stormwind City%)", tail)
            assert.is_nil(tail:find("Horde Vendor", 1, true))
            assert.matches("Vendor 7", tail) -- more than the tooltips list
            assert.matches("Recipe ID: 2", tail)
            assert.matches("Item ID: 201", tail)
        end)

        it("copes with a recipe the data does not know", function()
            local detail = ns.RecipeDetail_Build({ id = 99, name = "Odd", icon = 1, learned = true, reagents = {} })
            assert.are.equal("Odd", detail.name)
            assert.matches("Recipe ID: 99", detail.tail)
        end)
    end)

    describe("opening and closing", function()
        it("a click on a recipe opens the panel with it, next to the window", function()
            assert.is_nil(panel())
            click(recipeRow("Elixir of Wisdom"))
            assert.is_true(panel():IsShown())
            assert.are.equal("Elixir of Wisdom", panel().name._text)
            assert.are.equal("Elixir of Wisdom", ns.RecipeDetail_Current().name)
            assert.matches("You know this recipe", panel().info._text)
            local anchors = {}
            for _, point in ipairs(panel()._points) do anchors[point[1]] = point[3] end
            assert.are.same({ TOPLEFT = "TOPRIGHT", BOTTOMLEFT = "BOTTOMRIGHT" }, anchors)
        end)

        it("marks the recipe in the list, and another click changes the recipe", function()
            click(recipeRow("Elixir of Wisdom"))
            assert.is_true(recipeRow("Elixir of Wisdom").selected:IsShown())
            assert.is_false(recipeRow("Flask of the Titans").selected:IsShown())
            click(recipeRow("Flask of the Titans"))
            assert.are.equal("Flask of the Titans", panel().name._text)
            assert.is_true(recipeRow("Flask of the Titans").selected:IsShown())
            assert.is_false(recipeRow("Elixir of Wisdom").selected:IsShown())
        end)

        it("draws a row for every ingredient, with the item's tooltip", function()
            click(recipeRow("Elixir of Wisdom"))
            local rows = {}
            for _, f in ipairs(WowMock.frames) do
                if f.itemID and f.icon and f._parent == panel().child and f:IsShown() then rows[#rows + 1] = f end
            end
            assert.are.equal(2, #rows)
            local row = rows[1]
            row._scripts.OnEnter(row)
            assert.are.same({ row.itemID }, GameTooltip._set.SetItemByID)
        end)

        it("the group titles do not open it", function()
            click(visible("data")[1]) -- the title of the known recipes
            assert.is_nil(panel())
        end)

        it("a shift-click puts the link in the chat instead", function()
            _G.IsModifiedClick = function() return true end
            local inserted
            _G.ChatEdit_InsertLink = function(link) inserted = link end
            local row = recipeRow("Elixir of Wisdom")
            row.data.recipe.link = "|Hspell:1|h[Elixir]|h"
            click(row)
            assert.are.equal("|Hspell:1|h[Elixir]|h", inserted)
            assert.is_nil(panel())
        end)

        it("closing it clears the mark in the list", function()
            click(recipeRow("Elixir of Wisdom"))
            panel():Hide()
            assert.is_nil(ns.RecipeDetail_Current())
            assert.is_false(recipeRow("Elixir of Wisdom").selected:IsShown())
        end)

        it("going back to the professions closes it", function()
            click(recipeRow("Elixir of Wisdom"))
            ns.UI_ShowOverview()
            assert.is_false(panel():IsShown())
        end)

        it("closing the window closes it too", function()
            click(recipeRow("Elixir of Wisdom"))
            ns.UI_Hide()
            assert.is_false(panel():IsShown())
        end)

        it("also opens from a click on an ingredient icon of the table", function()
            local row = recipeRow("Elixir of Wisdom")
            click(row.compIcons[1])
            assert.is_true(panel():IsShown())
        end)
    end)
end)
