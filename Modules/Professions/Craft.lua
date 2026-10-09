local _, ns = ...
local L = ns.L

-- Crafting from the addon's own window: ns.Craft_Make(recipeID, count, skillLine) asks the game to craft a recipe
-- (C_TradeSkillUI.CraftRecipe). The game only crafts while that profession is open in its own profession window (the trade
-- skill data is loaded then: with it closed the call is accepted and nothing happens), so the window is opened first when it is
-- not open on the profession already, and the craft starts as soon as the game says it is ready.
-- While this is tried out every call says in the chat what happened: whether the window had to be opened, whether the call was
-- accepted, and whether the cast really started (or the error the game gave).

local WAIT = 1.5 -- seconds to see the cast start
local READY_TRIES, READY_STEP = 20, 0.25 -- how long to wait for the profession to load (5 s)
local pending

local function say(text)
    ns.Print("|cff9a9a9a[craft test]|r " .. text)
end

-- Is that profession (skill line) open and ready in the game's profession window?
local function isOpen(skillLine)
    return ns.Recipes_IsReady and ns.Recipes_IsReady(skillLine, skillLine and ns.RecipeDB_SkillName(skillLine)) or false
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

local function whenReady(skillLine, tries, callback)
    if isOpen(skillLine) then return callback(true) end
    if tries <= 0 then return callback(false) end
    C_Timer.After(READY_STEP, function() whenReady(skillLine, tries - 1, callback) end)
end

local function cast(recipeID, count, note)
    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, recipeID, count)
    pending = { id = recipeID, started = false, errors = {} }
    say(("recipe %d x%d: %s, call %s%s"):format(recipeID, count, note, ok and "accepted" or "failed", ok and "" or (": " .. tostring(err))))
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

-- Crafts `count` times (1 to 999) the recipe with that spell id of the profession `skillLine`. False when the call could not be made
-- (this client has no way to craft, or the profession had not been opened and it is being opened: the craft follows by itself).
function ns.Craft_Make(recipeID, count, skillLine)
    count = math.max(1, math.min(999, math.floor(tonumber(count) or 1)))
    if not (C_TradeSkillUI and C_TradeSkillUI.CraftRecipe) then
        ns.Print(L["This client can't craft from here."])
        return false
    end
    if isOpen(skillLine) or not skillLine then
        return cast(recipeID, count, isOpen(skillLine) and "profession window open" or "profession unknown")
    end
    local opened = open(skillLine)
    say(("opening the profession window (skill line %d): %s"):format(skillLine, opened and "asked" or "NOT possible"))
    whenReady(skillLine, READY_TRIES, function(ready)
        if ready then
            cast(recipeID, count, "profession window opened")
        else
            say("the profession did not get ready in time: nothing crafted")
        end
    end)
    return opened
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
