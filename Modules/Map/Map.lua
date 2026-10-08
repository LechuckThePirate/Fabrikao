local _, ns = ...

-- Where things are, on the map: a spot is { map = the game's map id, x =, y = } (x and y in percent of the map, as the data has them).
--   ns.Map_Show(spot)      opens the world map on the spot and marks it with a bouncing pin
--   ns.Map_HasTomTom()     is TomTom installed?
--   ns.Map_TomTom(spot, title)  sets a TomTom waypoint (with its arrow) at the spot

local pinState, pinHolder

local function canvas()
    if not WorldMapFrame then return nil end
    return (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
        or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
end

-- Our own marker on the world map: it hangs from the map's canvas (moves and zooms with it), is counter-scaled to keep its
-- size, is shown only while the visible map is the spot's, and goes away when the map closes.
local function ensurePin()
    if pinHolder then return true end
    local parent = canvas()
    if not parent then return false end

    pinHolder = CreateFrame("Frame", nil, parent)
    pinHolder:SetSize(1, 1)
    pinHolder:SetFrameStrata("DIALOG")
    local pin = CreateFrame("Frame", nil, pinHolder)
    pin:SetSize(32, 32)
    pin:SetPoint("BOTTOM", pinHolder, "CENTER", 0, 0) -- the point of the pin is on the spot
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Waypoint-MapPin-Tracked")
    if atlas then icon:SetAtlas("Waypoint-MapPin-Tracked") else icon:SetTexture("Interface\\Minimap\\Tracking\\Target") end

    local hop = icon:CreateAnimationGroup()
    hop:SetLooping("BOUNCE")
    local move = hop:CreateAnimation("Translation")
    move:SetOffset(0, 8)
    move:SetDuration(0.45)
    move:SetSmoothing("IN_OUT")
    hop:Play()

    pinHolder:SetScript("OnUpdate", function(self)
        local state, map = pinState, canvas()
        if not (state and map and WorldMapFrame:GetMapID() == state.map) then
            self:SetAlpha(0)
            return
        end
        self:SetAlpha(1)
        local w, h = map:GetWidth(), map:GetHeight()
        if w ~= self.w or h ~= self.h or state ~= self.state then
            self.w, self.h, self.state = w, h, state
            self:ClearAllPoints()
            self:SetPoint("CENTER", map, "TOPLEFT", state.x / 100 * w, -state.y / 100 * h)
        end
        local scale = WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale() or 1
        if scale and scale > 0 and scale ~= self.scale then
            self.scale = scale
            pin:SetScale(1 / scale)
        end
    end)
    WorldMapFrame:HookScript("OnHide", function() pinState = nil end)
    return true
end

-- Opens the world map on the spot's map, with the pin on it. False when the map could not be opened.
function ns.Map_Show(spot)
    if not (spot and spot.map) then return false end
    pinState = { map = spot.map, x = spot.x, y = spot.y }
    local opened = false
    if OpenWorldMap then opened = pcall(OpenWorldMap, spot.map) end
    if not opened and WorldMapFrame then
        opened = pcall(function()
            if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
            WorldMapFrame:SetMapID(spot.map)
        end)
    end
    ensurePin()
    return opened
end

function ns.Map_HasTomTom()
    return _G.TomTom ~= nil and _G.TomTom.AddWaypoint ~= nil
end

-- A TomTom waypoint at the spot, with its arrow; false without TomTom.
function ns.Map_TomTom(spot, title)
    if not (spot and ns.Map_HasTomTom()) then return false end
    _G.TomTom:AddWaypoint(spot.map, spot.x / 100, spot.y / 100, {
        title = title, from = "Fabrikao", persistent = false, minimap = true, world = true, crazy = true,
    })
    return true
end
