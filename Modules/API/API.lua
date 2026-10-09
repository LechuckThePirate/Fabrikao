local _, ns = ...

-- Public API for other addons (Embolsao!! uses it for the "Recipes" entry of its item menu). A global table so that an
-- addon can use it without Fabrikao's private namespace. Each function is safe to call at any time and returns whether
-- it did something.
--
--   FabrikaoAPI.version                    the API's version (1)
--   FabrikaoAPI.ShowRecipesUsing(itemID)   opens the window on the search page, listing the recipes that use the item
--                                          as an ingredient

local API = { version = 1 }

function API.ShowRecipesUsing(itemID)
    if type(itemID) ~= "number" then return false end
    ns.UI_ShowSearch("", itemID)
    return true
end

FabrikaoAPI = API
