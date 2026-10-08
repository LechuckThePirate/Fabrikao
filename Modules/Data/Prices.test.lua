dofile("setupTests.lua")

describe("Prices", function()
    local ns, ah, vendor

    before_each(function()
        WowMock.Reset()
        ah, vendor = {}, {}
        _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(caller, id)
            assert(caller == "Fabrikao")
            return ah[id]
        end } } }
        _G.C_Item = { GetItemInfo = function(id) return "name", "link", 1, 1, 1, "t", "s", 1, "", 1, vendor[id] end }
        ns = LoadAddon({ files = { "Modules/Data/Prices.lua" } })
    end)

    it("takes auction prices from Auctionator, when it is there", function()
        ah[10] = 500
        assert.is_true(ns.Prices_HasAuctionData())
        assert.are.equal(500, ns.Prices_AH(10))
        assert.is_nil(ns.Prices_AH(11))
        _G.Auctionator = nil
        assert.is_false(ns.Prices_HasAuctionData())
        assert.is_nil(ns.Prices_AH(10))
    end)

    it("an error in Auctionator is no error here", function()
        _G.Auctionator.API.v1.GetAuctionPriceByItemID = function() error("boom") end
        assert.is_nil(ns.Prices_AH(10))
    end)

    it("falls back to what a vendor pays for an item", function()
        vendor[10] = 30
        assert.are.equal(30, ns.Prices_Vendor(10))
        assert.is_nil(ns.Prices_Vendor(11))
        assert.are.equal(30, ns.Prices_Unit(10))
        ah[10] = 500
        assert.are.equal(500, ns.Prices_Unit(10))
    end)

    describe("a recipe", function()
        local recipe

        before_each(function()
            recipe = {
                reagents = { { items = { 10 }, quantity = 2 }, { items = { 11, 12 }, quantity = 1 } },
                db = { p = { 200, 1, 3 } },
            }
        end)

        it("costs what its ingredients cost, the cheapest of the alternatives", function()
            ah[10], ah[11], ah[12] = 100, 80, 50
            local cost, incomplete = ns.Prices_RecipeCost(recipe)
            assert.are.equal(250, cost) -- 2 x 100 + 50
            assert.is_false(incomplete)
        end)

        it("says when an ingredient has no price, and the total is a floor", function()
            ah[10] = 100
            local cost, incomplete = ns.Prices_RecipeCost(recipe)
            assert.are.equal(200, cost)
            assert.is_true(incomplete)
        end)

        it("has no cost without ingredients", function()
            assert.is_nil(ns.Prices_RecipeCost({}))
            assert.is_nil(ns.Prices_RecipeCost({ reagents = {} }))
        end)

        it("is worth the auction price of what it makes (an average for a range)", function()
            ah[200] = 1000
            assert.are.equal(2000, ns.Prices_RecipeValue(recipe)) -- 1 to 3 -> 2
            assert.is_nil(ns.Prices_RecipeValue({}))
            ah[200] = nil
            assert.is_nil(ns.Prices_RecipeValue(recipe))
        end)
    end)

    it("formats money with the two biggest units", function()
        assert.are.equal("-", ns.FormatMoney(nil))
        assert.matches("^0", ns.FormatMoney(0))
        assert.are.equal("12|cffeda55fc|r", ns.FormatMoney(12))
        assert.are.equal("35|cffc7c7cfs|r 10|cffeda55fc|r", ns.FormatMoney(3510))
        assert.are.equal("1|cffffd100g|r 20|cffc7c7cfs|r", ns.FormatMoney(12034))
        assert.are.equal("5|cffffd100g|r 3|cffeda55fc|r", ns.FormatMoney(50003))
    end)
end)
