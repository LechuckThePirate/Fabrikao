local _, ns = ...

-- Recipes that can only be learned while a world event runs: whoever teaches them (a holiday vendor, a gift, an event quest) is only
-- there in that season. "You can learn" leaves them out, since nobody can teach them the rest of the year.
-- [recipe spell id] = the event. Not in the generated data, which has no event information. Each one was checked against the item
-- that teaches it: sold only by the "Smokywood Pastures" vendors, contained in the "Smokywood Pastures Special Gift" or the
-- "Ticking Present", or the reward of a quest in the Lunar Festival category.
local WINTER_VEIL, LUNAR_FESTIVAL = "Feast of Winter Veil", "Lunar Festival"
local SEASONAL = {
    [21143] = WINTER_VEIL,    -- Gingerbread Cookie (Cooking)
    [21144] = WINTER_VEIL,    -- Egg Nog (Cooking)
    [21945] = WINTER_VEIL,    -- Green Holiday Shirt (Tailoring)
    [21913] = WINTER_VEIL,    -- Edge of Winter (Blacksmithing)
    [21931] = WINTER_VEIL,    -- Enchant Weapon - Winter's Might (Enchanting)
    [44950] = WINTER_VEIL,    -- Green Winter Clothes (Tailoring)
    [44958] = WINTER_VEIL,    -- Red Winter Clothes (Tailoring)
    [44953] = WINTER_VEIL,    -- Winter Boots (Leatherworking)
    [26442] = LUNAR_FESTIVAL, -- Firework Launcher (Engineering)
    [26443] = LUNAR_FESTIVAL, -- Firework Cluster Launcher (Engineering)
}

-- The event a recipe (its spell id) is tied to, or nil when it can be learned all year.
function ns.Seasonal_Event(spellID)
    return SEASONAL[spellID]
end
