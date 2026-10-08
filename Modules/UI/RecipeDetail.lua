local _, ns = ...
local L = ns.L

-- The panel of a recipe, next to the main window: everything the addon knows about it (status, skill and colors, what it makes,
-- the ingredients with how many you have, cost and profit, the item that teaches it, where it is learned). A click on a
-- recipe of the lists opens it; ns.RecipeDetail_Show(recipe, opts) fills it, with `recipe` as the lists see it (ns.Recipes_FromData...)
-- and opts = { parent = the window to dock to, alts = count the other characters too, rank = the character's skill in the
-- profession (when the recipe has none of its own), onClose = function() }.

local WIDTH = 340
local MARGIN = 14
local TEXT_W = WIDTH - MARGIN - 34 -- the scroll bar is on the right
local ROW_H = 28
local ICON = 22
local GOLD = "|cffffd100"
local WHITE = "|cffffffff"
local GREEN, RED = "|cff40bf40", "|cffff4040"
local DIM = "|cff909090"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"

local panel, current
local rowPool = {}

local function colorCode(color)
    return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

local function itemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if name then return name end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return L["item %d"]:format(itemID)
end

local function itemIcon(itemID)
    return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or 134400
end

local function iconText(texture)
    return texture and ("|T%s:14|t "):format(tostring(texture)) or ""
end

-- how many of an item: the bags, the bank and the other characters
local function holdings(itemID, alts)
    local bags, bank = 0, 0
    if ns.Inventory_Mine then bags, bank = ns.Inventory_Mine(itemID) end
    local others = (alts ~= false and ns.Inventory_OthersTotal) and ns.Inventory_OthersTotal(itemID) or 0
    return bags, bank, others
end

---------------------------------------------------------------------------------------------------
-- What the panel says
---------------------------------------------------------------------------------------------------
-- The panel's content as data: { name =, color =, icon =, subtitle =, info = text, reagents = { { itemID =, items =, needed =, have =,
-- bank =, others =, unit =, text = }... }, summary = text, tail = text }.
function ns.RecipeDetail_Build(recipe, opts)
    opts = opts or {}
    local db = recipe.db
    local rank = recipe.rank or opts.rank
    local out = { name = recipe.name, icon = recipe.icon }
    out.color = recipe.learned and ns.DIFFICULTY_COLORS[recipe.difficulty or ns.DIFFICULTY_LAST] or { 0.85, 0.85, 0.85 }

    local subtitle = {}
    if db then subtitle[#subtitle + 1] = ns.RecipeDB_SkillName(db.s) end
    if recipe.category then subtitle[#subtitle + 1] = recipe.category end
    out.subtitle = table.concat(subtitle, "  -  ")

    local lines = {}
    local function add(label, text) lines[#lines + 1] = ("%s%s|r %s"):format(GOLD, label, text) end

    if recipe.learned then
        lines[#lines + 1] = GREEN .. CHECK .. " " .. L["You know this recipe"] .. "|r"
    elseif rank then
        lines[#lines + 1] = L["You don't know this recipe yet"]
    else
        lines[#lines + 1] = L["You don't have this profession"]
    end

    local required = recipe.required or (db and ns.RecipeDB_Required(db))
    if required then
        local text = tostring(required)
        if rank then
            text = text .. ("  (%s)"):format((rank >= required and GREEN or RED) .. L["you have %d"]:format(rank) .. "|r")
        end
        add(L["Skill needed:"], text)
    end

    local colors = recipe.colors or (db and ns.RecipeDB_Colors(db))
    if colors then
        add(L["Difficulty:"], ns.DifficultyColorsText(colors))
        if db and rank and required and rank >= required then
            local d = ns.RecipeDB_Difficulty(db, rank)
            local names = { [0] = L["orange"], L["yellow"], L["green"], L["grey"] }
            add(L["For your skill:"], ("%s%s|r"):format(colorCode(ns.DIFFICULTY_COLORS[d]), names[d]))
        end
    end

    local product = db and db.p
    if product then
        local quantity = product[2] == product[3] and tostring(product[2]) or ("%d-%d"):format(product[2], product[3])
        add(L["Makes:"], ("%s%s x%s"):format(iconText(itemIcon(product[1])), itemName(product[1]), quantity))
    end

    local alts = opts.alts and ns.Inventory_Available and ns.Inventory_Available()
    if recipe.reagents and #recipe.reagents > 0 and ns.Recipes_Craftable then
        local now = ns.Recipes_Craftable(recipe, false)
        if alts then
            add(L["Crafts possible:"], L["%d (%d counting your other characters)"]:format(now, ns.Recipes_Craftable(recipe, true)))
        else
            add(L["Crafts possible:"], tostring(now))
        end
    end

    if db and db.g and db.g > 0 then add(L["Training cost:"], ns.FormatMoney(db.g)) end
    if db and db.u then add(L["New in Forever"], "") end
    local teacher = db and ns.RecipeDB_Item(db)
    if db and db.i then
        local text = itemName(db.i)
        if teacher and teacher.lv then text = text .. " (" .. L["item level %d"]:format(teacher.lv) .. ")" end
        add(L["Taught by:"], text)
    end
    out.info = table.concat(lines, "\n")

    -- ingredients, one row each
    out.reagents = {}
    for _, reagent in ipairs(recipe.reagents or {}) do
        local itemID = reagent.items[1]
        local have, bank, others = 0, 0, 0
        for _, id in ipairs(reagent.items) do
            local b, k, o = holdings(id, opts.alts)
            have, bank, others = have + b, bank + k, others + o
        end
        local unit = ns.Prices_Unit and ns.Prices_Unit(itemID)
        local parts = { L["you have %d"]:format(have) }
        if bank > 0 then parts[#parts + 1] = L["%d in your bank"]:format(bank) end
        if others > 0 then parts[#parts + 1] = L["+%d on other characters"]:format(others) end
        local status = (have >= reagent.quantity and GREEN or (have + bank >= reagent.quantity and "|cffffd100" or RED))
            .. table.concat(parts, ", ") .. "|r"
        local text = ("%s x%d\n%s"):format(itemName(itemID), reagent.quantity, status)
        if unit then text = text .. DIM .. "  -  " .. L["each %s"]:format(ns.FormatMoney(unit)) .. "|r" end
        out.reagents[#out.reagents + 1] = { itemID = itemID, items = reagent.items, needed = reagent.quantity, have = have, bank = bank,
            others = others, unit = unit, text = text }
    end

    -- what it costs and brings
    local summary = {}
    local cost, incomplete = ns.Prices_RecipeCost and ns.Prices_RecipeCost(recipe)
    local value = ns.Prices_RecipeValue and ns.Prices_RecipeValue(recipe)
    if cost then
        summary[#summary + 1] = ("%s%s|r %s%s"):format(GOLD, L["Ingredients cost:"], ns.FormatMoney(cost), incomplete and "+" or "")
    end
    if value then summary[#summary + 1] = ("%s%s|r %s"):format(GOLD, L["Sells for about:"], ns.FormatMoney(value)) end
    if cost and value then
        local profit = value - cost
        summary[#summary + 1] = ("%s%s|r %s%s|r"):format(GOLD, L["Profit:"], profit >= 0 and GREEN or RED,
            (profit < 0 and "-" or "") .. ns.FormatMoney(math.abs(profit)))
    end
    if (cost or value) and ns.Prices_HasAuctionData and not ns.Prices_HasAuctionData() then
        summary[#summary + 1] = DIM .. L["No auction data (Auctionator): the cost uses what vendors pay."] .. "|r"
    end
    out.summary = table.concat(summary, "\n")

    -- where it is learned, and the ids
    local tail = {}
    if db then
        tail[#tail + 1] = GOLD .. L["Where to learn it"] .. "|r"
        for _, line in ipairs(ns.RecipeDB_Where(db, true)) do
            tail[#tail + 1] = ("%s%s:|r %s"):format(WHITE, line.title, line.text)
        end
    elseif recipe.sourceText and recipe.sourceText ~= "" then
        tail[#tail + 1] = GOLD .. L["Where to learn it"] .. "|r"
        tail[#tail + 1] = recipe.sourceText
    end
    local ids = { L["Recipe ID: %d"]:format(recipe.id) }
    if product then ids[#ids + 1] = L["Item ID: %d"]:format(product[1]) end
    tail[#tail + 1] = ""
    tail[#tail + 1] = DIM .. table.concat(ids, "   ") .. "|r"
    out.tail = table.concat(tail, "\n")
    return out
end

---------------------------------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------------------------------
local function newReagentRow(child)
    local row = CreateFrame("Button", nil, child)
    row:SetSize(TEXT_W, ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 0, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:SetText(itemName(self.itemID), 1, 1, 1) end
        if ns.Inventory_AddTooltipLines then ns.Inventory_AddTooltipLines(GameTooltip, self.itemID) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local info = C_Item and C_Item.GetItemInfo or GetItemInfo
            local link = info and select(2, info(self.itemID))
            if link then ChatEdit_InsertLink(link) end
        end
    end)
    return row
end

local function render()
    if not (panel and current) then return end
    local data = ns.RecipeDetail_Build(current.recipe, current.opts)
    panel.name:SetText(data.name)
    panel.name:SetTextColor(data.color[1], data.color[2], data.color[3])
    panel.subtitle:SetText(data.subtitle)
    panel.icon:SetTexture(data.icon)
    panel.info:SetText(data.info)
    panel.summary:SetText(data.summary)
    panel.tail:SetText(data.tail)

    panel.info:ClearAllPoints()
    panel.info:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, 0)
    local y = panel.info:GetStringHeight() + 10

    panel.reagentsTitle:ClearAllPoints()
    panel.reagentsTitle:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
    panel.reagentsTitle:SetShown(#data.reagents > 0)
    if #data.reagents > 0 then y = y + 18 end
    for i, reagent in ipairs(data.reagents) do
        local row = rowPool[i]
        if not row then
            row = newReagentRow(panel.child)
            rowPool[i] = row
        end
        row.itemID = reagent.itemID
        row.icon:SetTexture(itemIcon(reagent.itemID))
        row.text:SetText(reagent.text)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
        row:Show()
        y = y + ROW_H
    end
    for i = #data.reagents + 1, #rowPool do rowPool[i]:Hide() end

    if data.summary ~= "" then
        y = y + 8
        panel.summary:ClearAllPoints()
        panel.summary:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
        panel.summary:Show()
        y = y + panel.summary:GetStringHeight() + 10
    else
        panel.summary:Hide()
        y = y + 8
    end

    panel.tail:ClearAllPoints()
    panel.tail:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
    y = y + panel.tail:GetStringHeight() + 8
    panel.child:SetHeight(math.max(1, y))
    panel.scroll:SetVerticalScroll(0)
end

local function fontString(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetWidth(TEXT_W)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    return fs
end

local function create(parent)
    panel = CreateFrame("Frame", "FabrikaoDetailFrame", UIParent, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetFrameStrata(parent:GetFrameStrata())
    parent:HookScript("OnHide", function() ns.RecipeDetail_Hide() end) -- it goes away with the window
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.92)
    panel:SetToplevel(true)
    panel:EnableMouse(true) -- clicks must not fall through to what is behind it

    local okClose, close = pcall(CreateFrame, "Button", nil, panel, "UIPanelCloseButtonDefaultAnchors")
    if not okClose or not close then close = CreateFrame("Button", nil, panel, "UIPanelCloseButton") end
    close:SetPoint("TOPRIGHT", -2, -2)

    -- the icon of what it makes, with that item's tooltip
    local iconButton = CreateFrame("Button", nil, panel)
    iconButton:SetSize(40, 40)
    iconButton:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    panel.icon = iconButton:CreateTexture(nil, "ARTWORK")
    panel.icon:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        local recipe = current and current.recipe
        if not (recipe and recipe.db and ns.RecipeDB_ShowProductTooltip(self, recipe.id, recipe.db)) then GameTooltip:Hide() end
    end)
    iconButton:SetScript("OnLeave", GameTooltip_Hide)
    iconButton:SetScript("OnClick", function()
        local recipe = current and current.recipe
        if recipe and recipe.link and IsModifiedClick and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(recipe.link) end
    end)

    panel.name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 10, -2)
    panel.name:SetPoint("RIGHT", close, "LEFT", -4, 0)
    panel.name:SetJustifyH("LEFT")
    panel.name:SetWordWrap(false)
    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -4)
    panel.subtitle:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
    panel.subtitle:SetJustifyH("LEFT")
    panel.subtitle:SetWordWrap(false)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", MARGIN, -(MARGIN + 52))
    panel.scroll:SetPoint("BOTTOMRIGHT", -30, MARGIN)
    panel.child = CreateFrame("Frame", nil, panel.scroll)
    panel.child:SetSize(TEXT_W, 1)
    panel.scroll:SetScrollChild(panel.child)
    panel.info = fontString(panel.child)
    panel.reagentsTitle = fontString(panel.child)
    panel.reagentsTitle:SetText(GOLD .. L["Ingredients:"] .. "|r")
    panel.summary = fontString(panel.child)
    panel.tail = fontString(panel.child)

    -- item names arrive late: draw again once (a burst of them makes one redraw)
    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local waiting = false
    events:SetScript("OnEvent", function()
        if waiting or not panel:IsShown() then return end
        waiting = true
        C_Timer.After(0.3, function()
            waiting = false
            if panel:IsShown() then
                local offset = panel.scroll:GetVerticalScroll()
                render()
                panel.scroll:SetVerticalScroll(offset)
            end
        end)
    end)

    panel:SetScript("OnHide", function()
        local onClose = current and current.opts and current.opts.onClose
        current = nil
        if onClose then onClose() end
    end)
    tinsert(UISpecialFrames, "FabrikaoDetailFrame")
    panel:Hide()
end

-- Docks the panel to the window's right side, or to its left when there is no room on the right.
local function dock(window)
    panel:ClearAllPoints()
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local room = (UIParent:GetRight() or 0) - (window:GetRight() or 0) * scale
    if room >= WIDTH * scale or (window:GetLeft() or 0) * scale < WIDTH * scale then
        panel:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, 0)
        panel:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", 0, 0)
    else
        panel:SetPoint("TOPRIGHT", window, "TOPLEFT", 0, 0)
        panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 0, 0)
    end
end

-- Opens the panel with a recipe (or fills it again when it is open).
function ns.RecipeDetail_Show(recipe, opts)
    opts = opts or {}
    local window = opts.parent or _G.FabrikaoFrame
    if not window then return end
    if not panel then create(window) end
    panel:SetScale(window:GetScale())
    dock(window)
    current = { recipe = recipe, opts = opts }
    render()
    panel:Show()
end

function ns.RecipeDetail_Hide()
    if panel and panel:IsShown() then panel:Hide() end
    current = nil
end

-- The recipe it shows, or nil when closed.
function ns.RecipeDetail_Current()
    return panel and panel:IsShown() and current and current.recipe or nil
end

-- The window's recipe was drawn again (inventory or filters changed): the panel follows.
function ns.RecipeDetail_Refresh()
    if panel and panel:IsShown() and current then render() end
end
