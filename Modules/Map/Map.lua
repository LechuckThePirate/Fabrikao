local ADDON, ns = ...

-- Where things are, on the map: a spot is { map = the game's map id, x =, y = } (x and y in percent of the map, as the data has them).
--   ns.Map_Show(spot)      opens the world map on the spot and marks it with a bouncing pin
--   ns.Map_HasTomTom()     is TomTom installed?
--   ns.Map_TomTom(spot, title)  sets a TomTom waypoint (with its arrow) at the spot
--   ns.Map_Distance(spot)  yards from the character to the spot, nil when that can't be told (another continent, no position)
--   ns.Map_FormatDistance(yards)  "350 yd" or "350 m" (meters except in the English locales)

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
    -- a map pin with the addon's icon in its head: the point of the pin is on the spot
    local pin = CreateFrame("Frame", nil, pinHolder)
    pin:SetSize(44, 44)
    pin:SetPoint("BOTTOM", pinHolder, "CENTER", 0, 0)
    local base = pin:CreateTexture(nil, "ARTWORK")
    base:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Icons\\PinBase.png")
    base:SetAllPoints()
    local icon = pin:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Icons\\" .. ADDON .. ".png")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", pin, "TOP", 0, -18)

    local hop = pin:CreateAnimationGroup()
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

local function worldPos(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local continent, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
    if continent and pos then return continent, pos.x, pos.y end
end

-- The map the character is on and where, 0-1 on it; nil when the game doesn't say (some cities, instances).
local function playerPosition()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local position = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if not position then return nil end
    local x, y = position:GetXY()
    return map, x, y
end

function ns.Map_Distance(spot)
    if not (spot and spot.map) then return nil end
    local map, px, py = playerPosition()
    if not map then return nil end
    local c1, x1, y1 = worldPos(map, px, py)
    local c2, x2, y2 = worldPos(spot.map, spot.x / 100, spot.y / 100)
    if not (c1 and c2 and c1 == c2) then return nil end
    local d = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
    if d ~= d or d == math.huge then return nil end -- the client gave no real position (e.g. a city map)
    return d
end

local YARD = 0.9144
function ns.Map_FormatDistance(yards)
    if not yards then return "" end
    local locale = GetLocale and GetLocale() or "enUS"
    local metric = locale ~= "enUS" and locale ~= "enGB"
    local d = metric and yards * YARD or yards
    local small, big = metric and "%d m" or "%d yd", metric and "%.1f km" or "%.1fk yd"
    return d < 1000 and small:format(math.floor(d)) or big:format(d / 1000)
end

function ns.Map_HasTomTom()
    return _G.TomTom ~= nil and _G.TomTom.AddWaypoint ~= nil
end

-- A TomTom waypoint at the spot, with its arrow; false without TomTom. TomTom keeps every waypoint it is given: the one set before
-- goes away, so they don't pile up on the map.
local lastWaypoint
function ns.Map_TomTom(spot, title)
    if not (spot and ns.Map_HasTomTom()) then return false end
    local tomtom = _G.TomTom
    if lastWaypoint and tomtom.RemoveWaypoint then pcall(tomtom.RemoveWaypoint, tomtom, lastWaypoint) end
    lastWaypoint = tomtom:AddWaypoint(spot.map, spot.x / 100, spot.y / 100, {
        title = title, from = "Fabrikao", persistent = false, minimap = true, world = true, crazy = true,
    })
    return true
end
