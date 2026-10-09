local _, ns = ...
local L = ns.L

-- Crafting from the addon's own window: ns.Craft_Make(recipeID, count) asks the game to craft a recipe (C_TradeSkillUI.CraftRecipe).
-- Whether the game does it with its own profession window closed is not known yet for Forever, so while this is tried out every
-- call says in the chat what happened: whether the profession API was ready, whether the call was accepted, and whether the
-- cast really started (or the error the game gave).

local WAIT = 1.5 -- seconds to see the cast start
local pending

local function say(text)
    ns.Print("|cff9a9a9a[craft test]|r " .. text)
end

-- The profession API is ready (its data is loaded: the game's profession window is, or was, open).
function ns.Craft_Ready()
    local T = C_TradeSkillUI
    return (T and T.IsTradeSkillReady and T.IsTradeSkillReady()) and true or false
end

-- Crafts `count` times (1 to 999) the recipe with that spell id. Returns false when the call could not even be made.
function ns.Craft_Make(recipeID, count)
    count = math.max(1, math.min(999, math.floor(tonumber(count) or 1)))
    local T = C_TradeSkillUI
    if not (T and T.CraftRecipe) then
        ns.Print(L["This client can't craft from here."])
        return false
    end
    local ready = ns.Craft_Ready()
    local ok, err = pcall(T.CraftRecipe, recipeID, count)
    pending = { id = recipeID, count = count, ready = ready, started = false, errors = {} }
    say(("recipe %d x%d: profession API %s, call %s%s"):format(recipeID, count, ready and "ready" or "NOT ready",
        ok and "accepted" or "failed", ok and "" or (": " .. tostring(err))))
    C_Timer.After(WAIT, function()
        local result = pending
        if not result or result.id ~= recipeID then return end
        if result.started then
            say("the cast started")
        else
            say("the cast did not start" .. (#result.errors > 0 and (": " .. table.concat(result.errors, "; ")) or " (no error given)"))
        end
    end)
    return ok
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
        -- any cast of the player's right after the call: the recipe's spell id may not be the cast's
        if (...) == "player" then pending.started = true end
    end
end)
