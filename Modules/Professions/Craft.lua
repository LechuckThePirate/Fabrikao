local _, ns = ...
local L = ns.L

-- Crafting from the addon's own window. The game does not let an addon call its crafting function (C_TradeSkillUI.CraftRecipe is
-- blocked: "Interface action failed because of an AddOn"); what an addon can do is cast the recipe's spell, which every known
-- recipe is in the spell book, through a secure button (RecipeDetail.lua). That cast only works while the game's profession window is
-- open on the profession (its data is loaded then), so a click that finds it closed opens it, and the next click crafts.
-- ns.Craft_Clicked(recipeID, skillLine) is what the button calls after the click.

local WAIT = 1.5 -- seconds to see the cast start
local pending

-- Is that profession (skill line) open in the game's profession window, with its data loaded and the recipe known to it?
local function isLoaded(skillLine, recipeID)
    if not (ns.Recipes_IsReady and ns.Recipes_IsReady(skillLine, skillLine and ns.RecipeDB_SkillName(skillLine))) then return false end
    local T = C_TradeSkillUI
    if T.IsDataSourceChanging and T.IsDataSourceChanging() then return false end
    if T.GetRecipeInfo and not T.GetRecipeInfo(recipeID) then return false end
    return true
end

-- Opens the game's profession window on the profession, the way the game does it. False when there is no way.
local function open(skillLine)
    if _G.OpenProfessionUIToSkillLine then
        return pcall(_G.OpenProfessionUIToSkillLine, skillLine)
    end
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        return pcall(C_TradeSkillUI.OpenTradeSkill, skillLine)
    end
    return false
end

-- The secure button was clicked on a recipe (its cast has been asked for). With the profession's window closed the cast can't have worked:
-- the window opens and the player is told to click again. With it open, a moment later, say why if the cast did not start.
function ns.Craft_Clicked(recipeID, skillLine)
    if skillLine and not isLoaded(skillLine, recipeID) then
        ns.Print(open(skillLine) and L["Opening the profession window: click Craft again."]
            or L["Open the profession window to craft."])
        return
    end
    pending = { id = recipeID, started = false, errors = {} }
    C_Timer.After(WAIT, function()
        local result = pending
        if not result or result.id ~= recipeID or result.started then return end
        ns.Print(#result.errors > 0 and L["The game did not start crafting: %s"]:format(table.concat(result.errors, "; "))
            or L["The game did not start crafting."])
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("UNIT_SPELLCAST_START")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:SetScript("OnEvent", function(_, event, ...)
    if not pending then return end
    if event == "UI_ERROR_MESSAGE" then
        local _, message = ...
        if message then pending.errors[#pending.errors + 1] = tostring(message) end
    else
        -- any cast of the player's right after the click: the recipe's spell id may not be the cast's
        if (...) == "player" then pending.started = true end
    end
end)
