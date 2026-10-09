dofile("setupTests.lua")

describe("FabrikaoAPI", function()
    local ns

    local DATA = {
        recipes = {
            [100] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 } },
            [101] = { s = 171, n = "Mighty Flask", c = { 250, 270, 290, 310 }, m = { { 12, 3 }, { 10, 1 } }, k = { 6 } },
            [102] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, m = { { 13, 4 } }, k = { 5 } },
        },
        items = {},
        trainers = {},
    }

    before_each(function()
        WowMock.Reset()
        _G.C_Item = {
            GetItemNameByID = function(id) return ({ [10] = "Peacebloom" })[id] end,
            GetItemIconByID = function(id) return 9000 + id end,
            GetItemCount = function() return 0 end,
        }
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 80, 300, 1, 10, 171, 0 end
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
    end)

    local function names(results)
        local found = {}
        for _, row in ipairs(results) do found[#found + 1] = row.recipe.name end
        table.sort(found)
        return found
    end

    it("is a global with a version", function()
        assert.are.equal(1, FabrikaoAPI.version)
    end)

    it("lists the recipes that use an item, in the search page", function()
        assert.is_true(FabrikaoAPI.ShowRecipesUsing(10))
        assert.is_true(_G.FabrikaoFrame:IsShown())
        assert.are.same({ "Elixir of Wisdom", "Mighty Flask" }, names(ns.SearchPage_Results()))
        local count = WowMock.Find(function(f) return f._text == "2 recipes using Peacebloom" end)
        assert.is_not_nil(count)
    end)

    it("an item no recipe uses lists nothing", function()
        assert.is_true(FabrikaoAPI.ShowRecipesUsing(999))
        assert.are.same({}, ns.SearchPage_Results())
    end)

    it("takes the profession picked in the search page out of the way", function()
        ns.UI_ShowSearch("i")
        local skillButton = WowMock.Find(function(f) return f._template == "UIPanelButtonTemplate" and f:GetText() == "Profession: All" end)
        skillButton._scripts.OnClick(skillButton) -- Alchemy first
        FabrikaoAPI.ShowRecipesUsing(13)
        assert.are.same({ "Iron Sword" }, names(ns.SearchPage_Results()))
    end)

    it("typing in the box goes back to an ordinary search", function()
        FabrikaoAPI.ShowRecipesUsing(10)
        local boxes = WowMock.FindAll(function(f) return f._template == "InputBoxTemplate" and f:IsVisible() end)
        local box = boxes[#boxes]
        box:SetText("sword")
        box._scripts.OnTextChanged(box, true)
        assert.are.same({ "Iron Sword" }, names(ns.SearchPage_Results()))
    end)

    it("refuses what is not an item id", function()
        assert.is_false(FabrikaoAPI.ShowRecipesUsing(nil))
        assert.is_false(FabrikaoAPI.ShowRecipesUsing("Peacebloom"))
    end)
end)
