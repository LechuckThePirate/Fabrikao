local _, ns = ...

-- Approximate prices for the recipe tables: what the ingredients cost and what the product sells for. The auction
-- prices come from Auctionator's last scan when that addon is installed (its public API); without it, the
-- ingredients fall back to what a vendor pays for them (a floor) and the product shows no value.

local CALLER = "Fabrikao" -- Auctionator wants to know who asks

local function auctionator()
    return Auctionator and Auctionator.API and Auctionator.API.v1
end

function ns.Prices_HasAuctionData()
    return auctionator() ~= nil
end

-- Auction price of an item in copper (Auctionator's last scan), or nil.
function ns.Prices_AH(itemID)
    local api = auctionator()
    if not (api and api.GetAuctionPriceByItemID) then return nil end
    local ok, price = pcall(api.GetAuctionPriceByItemID, CALLER, itemID)
    if ok and type(price) == "number" and price > 0 then return price end
    return nil
end

-- What a vendor pays for the item, in copper, or nil (the item isn't known to the client yet).
function ns.Prices_Vendor(itemID)
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not info then return nil end
    local sell = select(11, info(itemID))
    if type(sell) == "number" and sell > 0 then return sell end
    return nil
end

-- The price of one unit: its auction price, else the vendor's.
function ns.Prices_Unit(itemID)
    return ns.Prices_AH(itemID) or ns.Prices_Vendor(itemID)
end

-- What the ingredients of a recipe cost, in copper. The second value is true when some ingredient has no price at
-- all, so the total is a floor. Nil for a recipe with no ingredients known.
function ns.Prices_RecipeCost(recipe)
    if not recipe.reagents or #recipe.reagents == 0 then return nil end
    local total, incomplete = 0, false
    for _, reagent in ipairs(recipe.reagents) do
        local unit -- the cheapest of the alternatives
        for _, itemID in ipairs(reagent.items) do
            local price = ns.Prices_Unit(itemID)
            if price and (not unit or price < unit) then unit = price end
        end
        if unit then total = total + unit * reagent.quantity else incomplete = true end
    end
    return total, incomplete
end

-- What the product of a recipe sells for at the auction house, in copper (an average when it makes a range), or nil.
function ns.Prices_RecipeValue(recipe)
    local product = recipe.db and recipe.db.p
    if not product then return nil end
    local price = ns.Prices_AH(product[1])
    if not price then return nil end
    local low = product[2] or 1
    local quantity = (low + (product[3] or low)) / 2
    return math.floor(price * quantity + 0.5)
end

-- "1g 20s", "35s 10c", "12c": the two biggest units that aren't zero, each in its color; "-" for no price.
function ns.FormatMoney(copper)
    if not copper then return "-" end
    local units = {
        { math.floor(copper / 10000), "ffd100", "g" },
        { math.floor(copper / 100) % 100, "c7c7cf", "s" },
        { copper % 100, "eda55f", "c" },
    }
    local parts = {}
    for _, unit in ipairs(units) do
        if unit[1] > 0 and #parts < 2 then parts[#parts + 1] = ("%d|cff%s%s|r"):format(unit[1], unit[2], unit[3]) end
    end
    return #parts > 0 and table.concat(parts, " ") or "0|cffeda55fc|r"
end
