local ADDON, ns = ...

-- Addon entry point: events and /fabrikao. Loaded last, once the modules (Modules/) are in.

function ns.Print(...)
    print("|cff33ff99Fabrikao!!|r:", ...)
end

function ns.Version()
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return getMeta and getMeta(ADDON, "Version") or "?"
end

-- Chat notice, like Embolsao, Completao and Aggreao: "Fabrikao!! vX -- initializing..." when the addon loads and
-- "... initialization complete" once the player is in the world.
local function announce(text)
    if ns.char and ns.char.quiet then return end -- chat messages turned off
    print(("|cff33ff99Fabrikao!!|r v%s -- %s"):format(ns.Version(), text))
end

local announcedReady = false
local function announceReady()
    if announcedReady then return end
    announcedReady = true
    announce(ns.L["initialization complete"])
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ns.InitSettings()
        announce(ns.L["initializing..."])
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- also fires after /reload; announced once per UI load
        C_Timer.After(1, announceReady)
    end
end)

SLASH_FABRIKAO1 = "/fabrikao"
SLASH_FABRIKAO2 = "/fab"
SlashCmdList.FABRIKAO = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "version" then
        ns.Print("v" .. ns.Version())
    else
        ns.Print(ns.L["Usage: /fabrikao | version"])
    end
end
