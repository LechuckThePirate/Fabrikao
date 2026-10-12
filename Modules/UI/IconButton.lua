local ADDON, ns = ...

-- The small icon buttons of an NPC with a place: the map and the waypoint, instead of two wide text buttons (a few of them per
-- row, so they are 22 pixels).
--   ns.IconButton_Create(parent, kind, tooltip, action) -> a button. kind: "map" (a folded map with a pin) or "pointer" (a
--   navigation arrow). Its .npc, set by the row, is what the tooltip names and what `action(npc)` is called with.

local SIZE = 22
local TEXTURES = {
    map = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Map.png",
    pointer = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Pointer.png",
}

function ns.IconButton_Create(parent, kind, tooltip, action)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIZE, SIZE)
    b.iconKind = kind
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(TEXTURES[kind])
    b:SetHighlightTexture(TEXTURES[kind], "ADD")
    b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("TOPLEFT", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.icon:SetAllPoints() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(tooltip, 1, 1, 1)
        if self.npc and self.npc.name then GameTooltip:AddLine(self.npc.name, 1, 0.82, 0) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self) if self.npc then action(self.npc) end end)
    return b
end

-- Puts the two buttons of a row at its right edge: the waypoint one last (the right), the map one before it. `tomtom`: is there a
-- waypoint button at all. Returns how much room the buttons take from the right edge.
function ns.IconButton_Place(mapButton, tomButton, tomtom, right, top)
    right, top = right or 0, top or 0
    tomButton:ClearAllPoints()
    tomButton:SetPoint("TOPRIGHT", -right, -top)
    mapButton:ClearAllPoints()
    mapButton:SetPoint("TOPRIGHT", -(right + (tomtom and SIZE + 4 or 0)), -top)
    return right + SIZE + (tomtom and SIZE + 4 or 0) + 6
end
