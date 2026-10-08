local _, ns = ...

-- Settings per character or for the whole account, as in Embolsao, Completao and Aggreao ("Character specific
-- preferences"). The SWITCHABLE keys are read from and written to the active store: the character's
-- (FabrikaoCharDB) or the account's shared one (FabrikaoDB.shared). The rest of ns.char always belongs to the
-- character. The rest of the addon uses ns.char without knowing which one is behind it, and reads a key
-- that was never set as its default (DEFAULTS), so a checkbox can store a plain true / false.
ns.DEFAULTS = {
}

local SWITCHABLE = {
    quiet = true, minimap = true,
}

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = deepCopy(v) end
    return copy
end

local function activeStore()
    return FabrikaoCharDB.perCharacter and FabrikaoCharDB or FabrikaoDB.shared
end

-- On load (ADDON_LOADED): prepares the saved variables and ns.db / ns.char.
function ns.InitSettings()
    FabrikaoDB = FabrikaoDB or {}
    FabrikaoCharDB = FabrikaoCharDB or {}
    ns.db = FabrikaoDB
    -- the first time, the shared settings come from the character that first uses them
    if not FabrikaoDB.shared then
        FabrikaoDB.shared = {}
        for key in pairs(SWITCHABLE) do FabrikaoDB.shared[key] = deepCopy(FabrikaoCharDB[key]) end
    end
    -- per character by default; a new one starts with a copy of the shared ones
    if FabrikaoCharDB.perCharacter == nil then
        for key in pairs(SWITCHABLE) do
            if FabrikaoCharDB[key] == nil then FabrikaoCharDB[key] = deepCopy(FabrikaoDB.shared[key]) end
        end
        FabrikaoCharDB.perCharacter = true
    end
    ns.char = setmetatable({}, {
        __index = function(_, key)
            local value
            if SWITCHABLE[key] then value = activeStore()[key] else value = FabrikaoCharDB[key] end
            if value == nil then return ns.DEFAULTS[key] end
            return value
        end,
        __newindex = function(_, key, value)
            if SWITCHABLE[key] then activeStore()[key] = value else FabrikaoCharDB[key] = value end
        end,
    })
end

function ns.IsPerCharacter()
    return FabrikaoCharDB.perCharacter and true or false
end

-- Switching to per character copies the shared settings, so the change isn't noticed; switching back to
-- shared leaves the character's copy saved, unused. Then whatever is in the new store is applied.
function ns.SetPerCharacter(enabled)
    enabled = enabled and true or false
    if enabled == ns.IsPerCharacter() then return end
    if enabled then
        for key in pairs(SWITCHABLE) do FabrikaoCharDB[key] = deepCopy(FabrikaoDB.shared[key]) end
    end
    FabrikaoCharDB.perCharacter = enabled
    if ns.Minimap_Init then ns.Minimap_Init() end
end
