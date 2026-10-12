local _, ns = ...
local L = ns.L

-- The start screen of the window, in four quadrants under a welcome line, the search box and the picker of the character:
--   top left      the professions (icon, skill bar and name; "Can train: ..." when a trainer can teach the next rank)
--   top right     what can be learned: the ranks a trainer can teach, and the recipes the skill reaches that are not known, by
--                 profession and by level
--   bottom left   what the bags allow to craft now (a click opens the game's profession window on the recipe)
--   bottom right  the trainers close by that have something to teach and the vendors that sell a recipe of the profession that is
--                 not known, by profession, nearest first, with map and waypoint buttons
-- A quadrant scrolls when its content is taller than it; with nothing to scroll the bar is not there and the space goes to the content
-- (AutoScroll.lua). The groups of the two right quadrants are folded until they are opened, and it is kept (ns.char.folded).
--   ns.Overview_Create(parent, top) -> the frame      ns.Overview_Refresh()   all of it
--   ns.Overview_LayoutCraft()                         only "can craft now" (the bags changed)

local GAP, TITLE_H = 8, 26
local TOP_H = 84 -- the welcome line, the search box and the row of the picker
local PROFESSION_H, ROW_H, TRAINER_H, HEADER_H = 48, 28, 36, 26
local MAX_CRAFT, LEARN_PER_GROUP, TRAINERS_PER_GROUP = 100, 12, 6
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"
local DIM = "|cff9a9a9a"

local overview
local quadrants = {}

---------------------------------------------------------------------------------------------------
-- Small pieces
---------------------------------------------------------------------------------------------------
-- A pool of frames of one kind: next() hands out the next one shown, reset() hides what was handed out.
local function newPool(make)
    local pool = { items = {}, used = 0 }
    function pool.reset()
        for i = 1, pool.used do pool.items[i]:Hide() end
        pool.used = 0
    end
    function pool.next()
        pool.used = pool.used + 1
        local item = pool.items[pool.used]
        if not item then
            item = make()
            pool.items[pool.used] = item
        end
        item:Show()
        return item
    end
    return pool
end

-- A group is folded until it is opened: ns.char.folded[kind][key] is false once it has been (and true if folded again).
local function isFolded(kind, key)
    local folded = ns.char.folded
    return not (folded ~= nil and folded[kind] ~= nil and folded[kind][key] == false)
end

local function setFolded(kind, key, value)
    local folded = {}
    for k, v in pairs(ns.char.folded or {}) do folded[k] = v end
    local inKind = {}
    for k, v in pairs(folded[kind] or {}) do inKind[k] = v end
    inKind[key] = value and true or false
    folded[kind] = inKind
    ns.char.folded = folded
end

local function openProfession(profession)
    if ns.UI_ShowRecipes then ns.UI_ShowRecipes(profession) end
end

local function difficultyColor(difficulty)
    return ns.DIFFICULTY_COLORS[difficulty or ns.DIFFICULTY_LAST]
end

---------------------------------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------------------------------
local function showProfessionTooltip(button)
    local p = button.profession
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(p.name, 1, 1, 1)
    if p.learned == false then
        GameTooltip:AddLine(L["Not learned"], 1, 0.82, 0)
    else
        GameTooltip:AddLine(L["Skill: %d / %d"]:format(p.rank, p.maxRank), 1, 0.82, 0)
    end
    local nextRank = ns.Professions_NextRank(p)
    if nextRank then GameTooltip:AddLine(L["You can train %s at a trainer"]:format(nextRank), 0.25, 1, 0.25) end
    if p.hasRecipes then
        GameTooltip:AddLine(L["Click to see its recipes"], 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine(L["This profession has no recipes"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["Click to see its trainers"], 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function newProfessionRow(content)
    local b = CreateFrame("Button", nil, content)
    b:SetHeight(PROFESSION_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(38, 38)
    b.icon:SetPoint("LEFT", 6, 0)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -1)
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    b.bar:SetHeight(13)
    b.bar:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 1)
    b.bar:SetPoint("RIGHT", -10, 0)
    local back = b.bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.5)
    b.barText = b.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.barText:SetPoint("CENTER")
    -- "Can train: Journeyman": the skill is at the cap of its rank and a trainer can teach the next one
    b.train = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.train:SetPoint("TOPRIGHT", -10, -4)
    b.train:SetTextColor(0.25, 1, 0.25)
    b.train:Hide()
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self) openProfession(self.profession) end)
    b:SetScript("OnEnter", showProfessionTooltip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- A title inside a quadrant with a line under it (not clickable).
local function newSection(content)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    text.line = line
    function text:SetShownWithLine(shown)
        self:SetShown(shown)
        self.line:SetShown(shown)
    end
    return text
end

-- The title of a group a click folds: + or - in front, the name and a line under it.
local function newGroupHeader(content, onClick)
    local b = CreateFrame("Button", nil, content)
    b:SetHeight(HEADER_H - 2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 4, 0)
    b.profIcon = b:CreateTexture(nil, "ARTWORK")
    b.profIcon:SetSize(18, 18)
    b.profIcon:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", b.profIcon, "RIGHT", 6, 0)
    b.note = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.note:SetPoint("RIGHT", -8, 0)
    b.note:SetTextColor(0.25, 1, 0.25)
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 4, 0)
    line:SetPoint("BOTTOMRIGHT", -4, 0)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self) onClick(self.kind, self.key) end)
    return b
end

-- One line with an icon, a name that takes what is left and a small text on the right.
local function newLine(content)
    local b = CreateFrame("Button", nil, content)
    b:SetHeight(ROW_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(22, 22)
    b.icon:SetPoint("LEFT", 6, 0)
    b.skillText = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.skillText:SetPoint("RIGHT", -8, 0)
    b.skillText:SetJustifyH("RIGHT")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.name:SetPoint("RIGHT", b.skillText, "LEFT", -8, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- a row of "You can craft now": a click does what the Craft button of the recipe's panel does
local function newCraftRow(content)
    local b = newLine(content)
    b:SetScript("OnClick", function(self)
        local craft = self.craft
        if craft and not ns.Roster_ViewKey() then ns.Craft_Open(craft.recipe.id, craft.skillLine) end
    end)
    b:SetScript("OnEnter", function(self)
        local craft = self.craft
        if not craft then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not (craft.recipe.db and ns.RecipeDB_ShowProductTooltip(self, craft.recipe.id, craft.recipe.db)) then
            GameTooltip:SetText(craft.recipe.name, 1, 1, 1)
        end
        GameTooltip:AddLine(L["%d possible with your bags"]:format(craft.craftable), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["Click to open it in the profession window"], 1, 0.82, 0)
        GameTooltip:Show()
    end)
    return b
end

-- a recipe that can be learned: a click opens its panel next to the window
local function newLearnRow(content)
    local b = newLine(content)
    b:SetScript("OnClick", function(self)
        local learn = self.learn
        if learn and learn.recipe and _G.FabrikaoFrame then
            ns.RecipeDetail_Show(learn.recipe, { parent = _G.FabrikaoFrame, rank = learn.rank })
        end
    end)
    b:SetScript("OnEnter", function(self)
        local learn = self.learn
        if not (learn and learn.recipe) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not (learn.recipe.db and ns.RecipeDB_ShowProductTooltip(self, learn.recipe.id, learn.recipe.db)) then
            GameTooltip:SetText(learn.recipe.name, 1, 1, 1)
        end
        GameTooltip:AddLine(L["Click to see where to learn it"], 1, 0.82, 0)
        GameTooltip:Show()
    end)
    return b
end

-- a rank a trainer can teach (a click opens the profession's page, with its trainers)
local function newRankRow(content)
    local b = newLine(content)
    b.name:SetFontObject("GameFontNormal")
    b:SetScript("OnClick", function(self) if self.ofProfession then openProfession(self.ofProfession) end end)
    b:SetScript("OnEnter", function(self)
        if not self.ofProfession then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.ofProfession.name, 1, 1, 1)
        GameTooltip:AddLine(L["You can train %s at a trainer"]:format(self.rank), 0.25, 1, 0.25)
        GameTooltip:Show()
    end)
    return b
end

-- a trainer: the name and title, under them the zone and the distance, and the icons of the map and the waypoint
local function newTrainerRow(content)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(TRAINER_H)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 8, -2)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.where = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(false)
    row.tomButton = ns.IconButton_Create(row, "pointer", L["Set a TomTom waypoint"], function(npc) return ns.RecipeDetail_Waypoint(npc) end)
    row.mapButton = ns.IconButton_Create(row, "map", L["View on map"], function(npc) return ns.RecipeDetail_ViewOnMap(npc) end)
    return row
end

---------------------------------------------------------------------------------------------------
-- Quadrants
---------------------------------------------------------------------------------------------------
-- title, scroll (with its bar only when it is needed), a note for when there is nothing to list, and the pools of rows
local function newQuadrant(key, place)
    local q = { key = key }
    q.frame = CreateFrame("Frame", nil, overview)
    place(q.frame)
    local back = q.frame:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.22)
    q.title = q.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    q.title:SetPoint("TOPLEFT", 10, -6)
    q.title:SetJustifyH("LEFT")
    local line = q.frame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.5)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, -(TITLE_H + 2))
    line:SetPoint("RIGHT", q.frame, "RIGHT", -8, 0)
    q.scroll, q.content = ns.AutoScroll_Create(q.frame, function(withBar, scroll)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", q.frame, "TOPLEFT", 6, -(TITLE_H + 6))
        scroll:SetPoint("BOTTOMRIGHT", q.frame, "BOTTOMRIGHT", withBar and -26 or -6, 6)
    end)
    q.note = q.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    q.note:SetPoint("TOPLEFT", 8, -8)
    q.note:SetPoint("RIGHT", q.content, "RIGHT", -8, 0)
    q.note:SetJustifyH("LEFT")
    q.note:SetWordWrap(true)
    q.note:Hide()
    q.sections = newPool(function() return newSection(q.content) end)
    q.headers = newPool(function()
        return newGroupHeader(q.content, function(kind, groupKey)
            setFolded(kind, groupKey, not isFolded(kind, groupKey))
            if q.relayout then q.relayout() end
        end)
    end)
    quadrants[key] = q
    return q
end

local function startLayout(q)
    q.sections.reset()
    q.headers.reset()
    q.note:Hide()
    return 0
end

local function finishLayout(q, y, note)
    if note then
        q.note:SetText(note)
        q.note:Show()
        y = math.max(y, 40)
    end
    ns.AutoScroll_SetHeight(q.scroll, y + 8)
end

-- A header that folds its group: kind = "learn" / "trainers", key = the profession's skill line.
local function groupHeader(q, kind, profession, y, text, note)
    local h = q.headers.next()
    h.kind, h.key = kind, profession.skillLine
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -y)
    h:SetPoint("RIGHT", q.content, "RIGHT", 0, 0)
    local folded = isFolded(kind, profession.skillLine)
    h.icon:SetTexture(folded and PLUS or MINUS)
    h.profIcon:SetTexture(profession.icon)
    h.text:SetText(text)
    h.note:SetText(note or "")
    h.folded = folded
    return folded, y + HEADER_H
end

---------------------------------------------------------------------------------------------------
-- Laying out each quadrant
---------------------------------------------------------------------------------------------------
-- the professions: the ones the character has and, when asked, the ones with recipes in the data that it hasn't learned
local function layoutProfessions()
    local q = quadrants.professions
    q.rows.reset()
    local y = startLayout(q)
    local list = ns.Professions_List()
    local missing = ns.char.showMissing and ns.Professions_Missing(list) or {}
    local shown = {}
    for _, profession in ipairs(list) do shown[#shown + 1] = profession end
    for _, profession in ipairs(missing) do shown[#shown + 1] = profession end

    local lastGroup
    for _, profession in ipairs(shown) do
        local learned = profession.learned ~= false
        local group = not learned and "missing" or (profession.primary and "primary" or "secondary")
        if group ~= lastGroup then
            lastGroup = group
            -- the primary ones are what the quadrant's own title says: only the other groups are told apart
            if group ~= "primary" then
                local s = q.sections.next()
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", q.content, "TOPLEFT", 6, -y - 2)
                s:SetText(({ secondary = L["Secondary professions"], missing = L["Not learned"] })[group])
                s:SetShownWithLine(true)
                y = y + 24
            end
        end
        local b = q.rows.next()
        b.profession = profession
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -y)
        b:SetPoint("RIGHT", q.content, "RIGHT", 0, 0)
        b.icon:SetTexture(profession.icon)
        b.icon:SetDesaturated(not (profession.hasRecipes and learned))
        b.name:SetText(profession.name)
        if learned then
            b.bar:SetMinMaxValues(0, math.max(1, profession.maxRank))
            b.bar:SetValue(profession.rank)
            local full = profession.maxRank > 0 and profession.rank >= profession.maxRank
            b.bar:SetStatusBarColor(full and 0.2 or 0.1, full and 0.7 or 0.4, full and 0.2 or 0.9)
            b.barText:SetText(profession.rank .. " / " .. profession.maxRank)
        else
            b.bar:SetMinMaxValues(0, 1)
            b.bar:SetValue(0)
            b.barText:SetText(L["Not learned"])
        end
        b:SetAlpha((profession.hasRecipes and learned) and 1 or 0.6)
        local nextRank = ns.Professions_NextRank(profession)
        b.train:SetText(nextRank and L["Can train: %s"]:format(nextRank) or "")
        b.train:SetShown(nextRank ~= nil)
        y = y + PROFESSION_H + 4
    end
    finishLayout(q, y, #shown == 0 and L["No professions learned yet."] or nil)
end

-- what can be learned: the ranks a trainer can teach, then the recipes the skill reaches that are not known, by profession
local function layoutLearn()
    local q = quadrants.learn
    q.ranks.reset()
    q.recipes.reset()
    local y = startLayout(q)
    local professions = ns.Professions_List()

    local ranks = {}
    for _, p in ipairs(professions) do
        local name, cap = ns.Professions_NextRank(p)
        if name then ranks[#ranks + 1] = { profession = p, name = name, cap = cap } end
    end
    local groups = ns.Recipes_LearnableNow(professions, LEARN_PER_GROUP)
    local total = #ranks
    for _, group in ipairs(groups) do total = total + group.total end
    q.title:SetText(("%s (%d)"):format(L["You can learn"], total))

    if #ranks > 0 then
        local s = q.sections.next()
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", q.content, "TOPLEFT", 6, -y - 2)
        s:SetText(L["Skill ranges"])
        s:SetShownWithLine(true)
        y = y + 24
        for _, entry in ipairs(ranks) do
            local b = q.ranks.next()
            b.ofProfession, b.rank = entry.profession, entry.name
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -y)
            b:SetPoint("RIGHT", q.content, "RIGHT", 0, 0)
            b.icon:SetTexture(entry.profession.icon)
            b.name:SetText(("%s: |cff40ff40%s|r"):format(entry.profession.name, entry.name))
            b.skillText:SetText(L["skill %d"]:format(entry.cap))
            y = y + ROW_H
        end
        y = y + 6
    end

    for _, group in ipairs(groups) do
        local p = group.profession
        local folded
        folded, y = groupHeader(q, "learn", p, y, ("%s (%d)"):format(p.name, group.total))
        if not folded then
            for _, recipe in ipairs(group.recipes) do
                local b = q.recipes.next()
                b.learn = { recipe = recipe, rank = p.rank }
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -y)
                b:SetPoint("RIGHT", q.content, "RIGHT", 0, 0)
                b.icon:SetTexture(recipe.icon)
                local color = difficultyColor(ns.RecipeDB_Difficulty(recipe.db, p.rank))
                b.name:SetText(recipe.name)
                b.name:SetTextColor(color[1], color[2], color[3])
                local source = ns.RecipeDB_ShortSource(recipe.db)
                b.skillText:SetText(source and ("%d  %s"):format(recipe.required or 0, source) or tostring(recipe.required or ""))
                y = y + ROW_H
            end
            if group.total > #group.recipes then
                local more = q.sections.next()
                more:ClearAllPoints()
                more:SetPoint("TOPLEFT", q.content, "TOPLEFT", 28, -y - 2)
                more:SetText(DIM .. L["and %d more"]:format(group.total - #group.recipes) .. "|r")
                more:SetShownWithLine(true)
                more.line:Hide()
                y = y + 22
            end
            y = y + 4
        end
    end
    finishLayout(q, y, (#ranks == 0 and #groups == 0) and L["Nothing new to learn with your skill."] or nil)
end

-- what the bags allow to craft now, from the recipes known (not another character's: there is no crafting for them)
local function layoutCraft()
    local q = quadrants.craft
    q.rows.reset()
    local y = startLayout(q)
    if ns.Roster_ViewKey() then
        q.title:SetText(L["You can craft now"])
        finishLayout(q, y, L["There is no crafting for another character's professions."])
        return
    end
    local crafts, total = ns.Recipes_CraftableNow(ns.Professions_Mine(), MAX_CRAFT)
    q.title:SetText(("%s (%d)"):format(L["You can craft now"], total))
    for _, craft in ipairs(crafts) do
        local b = q.rows.next()
        b.craft = craft
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -y)
        b:SetPoint("RIGHT", q.content, "RIGHT", 0, 0)
        b.icon:SetTexture(craft.recipe.icon)
        local color = difficultyColor(craft.recipe.difficulty)
        b.name:SetText(("%s (%d)"):format(craft.recipe.name, craft.craftable))
        b.name:SetTextColor(color[1], color[2], color[3])
        b.skillText:SetText(craft.profession)
        y = y + ROW_H
    end
    if total > #crafts then
        local more = q.sections.next()
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", q.content, "TOPLEFT", 8, -y - 4)
        more:SetText(DIM .. L["and %d more"]:format(total - #crafts) .. "|r")
        more:SetShownWithLine(true)
        more.line:Hide()
        y = y + 24
    end
    finishLayout(q, y, #crafts == 0 and L["Nothing to craft with what your bags hold."] or nil)
end

-- the trainers and vendors close by that have something for the character, by profession (the one with the nearest first)
local function layoutTrainers()
    local q = quadrants.trainers
    q.rows.reset()
    local y = startLayout(q)
    local groups = ns.Recipes_TrainersNearby(ns.Professions_List(), TRAINERS_PER_GROUP)
    local withTomTom = ns.Map_HasTomTom and ns.Map_HasTomTom()

    -- one line of a trainer or a vendor: the name (and title, or what the vendor sells) and under it the kind, the zone and how far
    local function addRow(entry, kind)
        local row = q.rows.next()
        local spot = entry.id and ns.RecipeDB_NpcLocation(entry.id)
        row.trainer, row.vendor = nil, nil
        row[kind] = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", q.content, "RIGHT", 0, 0)
        local name = entry.name
        if kind == "trainer" and entry.title and entry.title ~= "" then
            name = name .. " " .. DIM .. "<" .. entry.title .. ">|r"
        elseif kind == "vendor" and entry.recipes and #entry.recipes > 0 then
            local sold = entry.recipes[1] .. (#entry.recipes > 1 and (" +" .. (#entry.recipes - 1)) or "")
            name = name .. " " .. DIM .. "<" .. sold .. ">|r"
        end
        local where = { kind == "trainer" and L["Trainer"] or L["Vendor"] }
        if entry.zones and entry.zones ~= "" then where[#where + 1] = entry.zones end
        local distance = entry.distance and ns.Map_FormatDistance and ns.Map_FormatDistance(entry.distance)
        if distance and distance ~= "" then where[#where + 1] = distance end
        row.name:SetText(name)
        row.where:SetText(table.concat(where, "  -  "))
        row.tomButton.npc, row.mapButton.npc = entry, entry
        row.tomButton:SetShown(spot ~= nil and withTomTom and true or false)
        row.mapButton:SetShown(spot ~= nil)
        local taken = ns.IconButton_Place(row.mapButton, row.tomButton, withTomTom, 4, 7)
        local reserved = spot and taken or 8 -- (the texts stop short of the icons)
        row.name:SetPoint("RIGHT", row, "RIGHT", -reserved, 0)
        row.where:SetPoint("RIGHT", row, "RIGHT", -reserved, 0)
        y = y + TRAINER_H
    end

    local function moreLine(text)
        local more = q.sections.next()
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", q.content, "TOPLEFT", 28, -y - 2)
        more:SetText(DIM .. text .. "|r")
        more:SetShownWithLine(true)
        more.line:Hide()
        y = y + 22
    end

    for _, group in ipairs(groups) do
        local p = group.profession
        local note = group.nextRank and L["Can train: %s"]:format(group.nextRank) or nil
        local folded
        folded, y = groupHeader(q, "trainers", p, y, ("%s (%d)"):format(p.name, group.total + group.vendorTotal), note)
        if not folded then
            for _, trainer in ipairs(group.trainers) do addRow(trainer, "trainer") end
            if group.total > #group.trainers then moreLine(L["and %d more"]:format(group.total - #group.trainers)) end
            for _, vendor in ipairs(group.vendors) do addRow(vendor, "vendor") end
            if group.vendorTotal > #group.vendors then moreLine(L["and %d more"]:format(group.vendorTotal - #group.vendors)) end
            y = y + 4
        end
    end
    finishLayout(q, y, #groups == 0 and L["No trainer or vendor has anything new for you."] or nil)
end

---------------------------------------------------------------------------------------------------
-- The whole screen
---------------------------------------------------------------------------------------------------
function ns.Overview_LayoutCraft()
    if overview then layoutCraft() end
end

function ns.Overview_Layout()
    if not overview then return end
    layoutProfessions()
    layoutLearn()
    layoutCraft()
    layoutTrainers()
end

function ns.Overview_Refresh()
    if not overview then return end
    ns.Overview_Layout()
    overview.picker.Update()
    overview.toggle:SetText(ns.char.showMissing and L["Hide professions not learned"] or L["Show professions not learned"])
end

-- Builds the screen as a child of `parent`, `top` below its top. Returns the frame, which has .search, .picker and .toggle.
function ns.Overview_Create(parent, top)
    overview = CreateFrame("Frame", nil, parent)
    overview:SetPoint("TOPLEFT", 12, -top)
    overview:SetPoint("BOTTOMRIGHT", -12, 12)

    -- the welcome line, the search box (what is typed goes to the search of every recipe) and the picker's row
    overview.welcome = overview:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    overview.welcome:SetPoint("TOPLEFT", 8, -2)
    overview.welcome:SetText(L["Welcome to Fabrikao!!"])

    local search = CreateFrame("EditBox", nil, overview, "InputBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", 6, -28)
    search:SetPoint("RIGHT", overview, "RIGHT", -6, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(60)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(L["Search any recipe in the game..."])
    local function startSearch(self)
        local text = self:GetText()
        if text == "" then return end
        self:SetText("")
        self:ClearFocus()
        ns.UI_ShowSearch(text)
    end
    search:SetScript("OnTextChanged", function(self, userInput)
        hint:SetShown(self:GetText() == "" and not self:HasFocus())
        if userInput then startSearch(self) end
    end)
    search:SetScript("OnEditFocusGained", function() hint:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", startSearch)
    overview.search = search

    overview.picker = ns.FilterBar_CreatePicker(overview, {
        width = 230,
        options = function()
            local options = { { value = nil, text = L["My professions"] } }
            for _, info in ipairs(ns.Roster_Others()) do options[#options + 1] = { value = info.key, text = info.label } end
            return options
        end,
        get = function() return ns.Roster_ViewKey() end,
        set = function(key) ns.UI_ViewCharacter(key) end,
        text = function()
            local viewed = ns.Roster_Viewed()
            return viewed and viewed.label or L["My professions"]
        end,
        extra = function(rootDescription)
            if #ns.Roster_Others() == 0 and rootDescription.CreateTitle then
                rootDescription:CreateTitle(L["Log in with your other characters to see their professions here."])
            end
        end,
    })
    overview.picker.frame:SetPoint("TOPLEFT", 0, -54)
    overview.toggle = CreateFrame("Button", nil, overview, "UIPanelButtonTemplate")
    overview.toggle:SetSize(230, 22)
    overview.toggle:SetPoint("TOPRIGHT", -6, -54)
    overview.toggle:SetScript("OnClick", function()
        ns.char.showMissing = not ns.char.showMissing
        ns.Overview_Refresh()
    end)

    -- the four quadrants
    local grid = CreateFrame("Frame", nil, overview)
    grid:SetPoint("TOPLEFT", overview, "TOPLEFT", 0, -TOP_H)
    grid:SetPoint("BOTTOMRIGHT", overview, "BOTTOMRIGHT", 0, 0)
    local half = GAP / 2

    local professions = newQuadrant("professions", function(f)
        f:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 0)
        f:SetPoint("BOTTOMRIGHT", grid, "CENTER", -half, half)
    end)
    professions.title:SetText(L["Professions"])
    professions.rows = newPool(function() return newProfessionRow(professions.content) end)

    local learn = newQuadrant("learn", function(f)
        f:SetPoint("TOPLEFT", grid, "TOP", half, 0)
        f:SetPoint("BOTTOMRIGHT", grid, "RIGHT", 0, half)
    end)
    learn.title:SetText(L["You can learn"])
    learn.ranks = newPool(function() return newRankRow(learn.content) end)
    learn.recipes = newPool(function() return newLearnRow(learn.content) end)
    learn.relayout = layoutLearn

    local craft = newQuadrant("craft", function(f)
        f:SetPoint("TOPLEFT", grid, "LEFT", 0, -half)
        f:SetPoint("BOTTOMRIGHT", grid, "BOTTOM", -half, 0)
    end)
    craft.title:SetText(L["You can craft now"])
    craft.rows = newPool(function() return newCraftRow(craft.content) end)

    local trainers = newQuadrant("trainers", function(f)
        f:SetPoint("TOPLEFT", grid, "CENTER", half, -half)
        f:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, 0)
    end)
    trainers.title:SetText(L["Trainers and vendors nearby"])
    trainers.rows = newPool(function() return newTrainerRow(trainers.content) end)
    trainers.relayout = layoutTrainers

    return overview
end
