local ADDON, ns = ...

-- The small icon buttons of an NPC: the map and the waypoint, and Completao!!'s for a quest, instead of wide text buttons (a few
-- of them per row, so they are 22 pixels).
--   ns.IconButton_Create(parent, kind, tooltip, action) -> a button. kind: "map" (a folded map with a pin), "pointer" (a
--   navigation arrow) or "quest" (Completao!!'s own icon). Its .npc, set by the row, is what the tooltip names and what
--   `action(npc)` is called with.
--   ns.IconButton_Row(right, top, ...) puts the buttons that are shown in a row from the right edge, in the order given.

local SIZE = 22
local TEXTURES = {
    map = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Map.png",
    pointer = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Pointer.png",
    quest = "Interface\\AddOns\\Completao\\Icons\\Completao.png", -- (it is the other addon's: only shown when Completao has the quest)
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
-- Puts the buttons that are shown at the right edge of a row, from the right in the order given, `right` and `top` pixels from the
-- row's edge. Returns how much room they take from the right edge, with a little air (right itself when none is shown).
function ns.IconButton_Row(right, top, ...)
    local x = right or 0
    local count = 0
    for i = 1, select("#", ...) do
        local button = select(i, ...)
        if button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", -x, -(top or 0))
            x = x + SIZE + 4
            count = count + 1
        end
    end
    if count == 0 then return right or 0 end
    return x + 2
end
