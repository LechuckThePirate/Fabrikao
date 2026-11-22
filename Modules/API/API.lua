local _, ns = ...

-- Public API for other addons (Embolsao!! uses it for the "Recipes" entry of its item menu, Enfocao!! for the menu of
-- an "items" goal). A global table so that an addon can use it without Fabrikao's private namespace. Each function is
-- safe to call at any time and returns whether it did something. New functions keep the version: callers check that
-- the function is there.
--
--   FabrikaoAPI.version                    the API's version (1)
--   FabrikaoAPI.ShowRecipesUsing(itemID)   opens the window on the search page, listing the recipes that use the item
--                                          as an ingredient
--   FabrikaoAPI.HasRecipeFor(itemID)       does any recipe of the data make the item?
--   FabrikaoAPI.ShowRecipeFor(itemID)      how to craft it: the window on the search page with the recipes that make it,
--                                          and the panel of the best one open (one the character or an alt knows, else
--                                          the one learned at the lowest skill): its ingredients and where to learn it

local API = { version = 1 }

function API.ShowRecipesUsing(itemID)
    if type(itemID) ~= "number" then return false end
    ns.UI_ShowSearch("", itemID)
    return true
end

local function knows(spellID)
    if ns.Roster_Knows then return ns.Roster_Knows(spellID) end
    return ns.RecipeDB_Known(spellID)
end

-- The recipes that make an item, the best first: known ones, then by the skill they are learned at.
local function makers(itemID)
    local found = ns.RecipeDB_Search("", { product = itemID })
    table.sort(found, function(a, b)
        local ka, kb = knows(a.id) and true or false, knows(b.id) and true or false
        if ka ~= kb then return ka end
        local ra, rb = ns.RecipeDB_Required(a.recipe), ns.RecipeDB_Required(b.recipe)
        if ra ~= rb then return ra < rb end
        return a.id < b.id
    end)
    return found
end

function API.HasRecipeFor(itemID)
    if type(itemID) ~= "number" then return false end
    return #makers(itemID) > 0
end

function API.ShowRecipeFor(itemID)
    if type(itemID) ~= "number" then return false end
    local found = makers(itemID)
    if #found == 0 then return false end
    ns.UI_ShowSearch("", nil, itemID)
    local best = found[1]
    if not ns.SearchPage_Open(best.id) then
        -- a filter of the page hides it: the panel opens all the same
        local profession
        for _, p in ipairs(ns.Professions_List()) do
            if p.skillLine == best.recipe.s then profession = p end
        end
        local rank = profession and profession.rank
        ns.RecipeDetail_Show(ns.Recipes_FromRecord(best.id, best.recipe, knows(best.id), rank),
            { parent = _G.FabrikaoFrame, rank = rank })
    end
    return true
end

FabrikaoAPI = API
