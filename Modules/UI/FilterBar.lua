local _, ns = ...
local L = ns.L

-- The two rows of filters and sorting of the recipe pages (the profession's page and the search of every recipe): a row
-- of checkboxes ("can make now", "hide grey") and a row of buttons that go to the next value on a click (source, color,
-- skill, sort) plus "Clear". The page owns the filters table:
--   { canMake = bool, hideGrey = bool, alts = bool (count the other characters' items too), difficulty = 0..3 or nil, skill = "learnable" | "higher" | nil,
--     sort = { key =, desc = } or nil, source = a source code or nil }
-- and gets onChange() after every change.

local SKILL_MODES = { nil, "learnable", "higher" }
local SORT_KEYS = { nil, "name", "level", "cost", "value", "craftable" } -- nil: the list's own order

-- the value after `current` in `values` (a list that may start with nil: "no filter"), wrapping around
function ns.FilterBar_NextValue(values, count, current)
    for i = 1, count do
        if values[i] == current then return values[i % count + 1] end
    end
    return values[1]
end

local function difficultyLabel(difficulty)
    if difficulty == nil then return L["All"] end
    local c = ns.DIFFICULTY_COLORS[difficulty]
    local names = { [0] = L["orange"], L["yellow"], L["green"], L["grey"] }
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), names[difficulty])
end

local function skillLabel(mode)
    return mode == "learnable" and L["Learnable now"] or mode == "higher" and L["Needs more skill"] or L["All"]
end

local function sortLabel(sort)
    if not sort then return L["Default"] end
    local names = { name = L["Name"], level = L["Level"], cost = L["Cost"], value = L["AH value"], craftable = L["Can make"] }
    return names[sort.key] .. (sort.desc and " v" or " ^")
end

-- Nothing filtered, nothing sorted.
function ns.FilterBar_Reset(filters)
    filters.canMake, filters.hideGrey, filters.alts = false, false, false
    filters.difficulty, filters.skill, filters.sort, filters.source = nil, nil, nil, nil
end

-- Is anything filtered? (not the sorting)
function ns.FilterBar_Active(filters)
    return filters.canMake or filters.hideGrey or filters.difficulty ~= nil or filters.skill ~= nil or filters.source ~= nil
end

-- A click on a column title or on the sort button's key: sorts by it, or turns the order around when it already is.
function ns.FilterBar_SortBy(filters, key)
    if filters.sort and filters.sort.key == key then
        filters.sort = { key = key, desc = not filters.sort.desc }
    else
        filters.sort = { key = key, desc = key == "craftable" or key == "value" }
    end
end

local function createCheck(parent, label, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.text = check.Text or check.text
    if check.text then check.text:SetText(label) end
    check:SetScript("OnClick", onClick)
    return check
end

local function createButton(parent, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", onClick)
    return button
end

-- Builds the rows under `anchor` (a frame of the page). config = { filters =, sources = function() returning the set of
-- source codes there are to pick from, onChange = function(), onClear = function() (optional, also on "Clear"),
-- x = where the rows start, relative to the anchor's left (-6 by default) }.
-- Returns the bar: .checks and .buttons (the two rows: anchor what comes next to .buttons, and add widgets to .checks),
-- and .Update() to show the filters in the controls.
function ns.FilterBar_Create(parent, anchor, config)
    local filters = config.filters
    local bar = {}

    local function changed()
        bar.Update()
        config.onChange()
    end

    local checks = CreateFrame("Frame", nil, parent)
    checks:SetHeight(26)
    checks:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", config.x or -6, -4)
    checks:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    bar.checks = checks
    bar.canMakeCheck = createCheck(checks, L["Can make now"], function(self)
        filters.canMake = self:GetChecked() and true or false
        changed()
    end)
    bar.canMakeCheck:SetPoint("LEFT", 0, 0)
    bar.hideGreyCheck = createCheck(checks, L["Hide grey"], function(self)
        filters.hideGrey = self:GetChecked() and true or false
        changed()
    end)
    local width = bar.canMakeCheck.text and bar.canMakeCheck.text:GetStringWidth() or 90
    bar.hideGreyCheck:SetPoint("LEFT", bar.canMakeCheck, "RIGHT", width + 14, 0)
    -- the items of the other characters count too (Embolsao's copies): only offered when there are any
    bar.altsCheck = createCheck(checks, L["Other characters"], function(self)
        filters.alts = self:GetChecked() and true or false
        changed()
    end)
    width = bar.hideGreyCheck.text and bar.hideGreyCheck.text:GetStringWidth() or 90
    bar.altsCheck:SetPoint("LEFT", bar.hideGreyCheck, "RIGHT", width + 14, 0)
    bar.altsCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Other characters"], 1, 1, 1)
        GameTooltip:AddLine(L["Count the bags and banks of your other characters too (saved by Embolsao)."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    bar.altsCheck:SetScript("OnLeave", GameTooltip_Hide)

    local buttons = CreateFrame("Frame", nil, parent)
    buttons:SetHeight(24)
    buttons:SetPoint("TOPLEFT", checks, "BOTTOMLEFT", 0, -2)
    buttons:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    bar.buttons = buttons

    bar.sourceButton = createButton(buttons, 130, function()
        local codes = {}
        for code in pairs(config.sources()) do codes[#codes + 1] = code end
        table.sort(codes)
        filters.source = ns.FilterBar_NextValue({ nil, unpack(codes) }, #codes + 1, filters.source)
        changed()
    end)
    bar.sourceButton:SetPoint("LEFT", 0, 0)
    bar.colorButton = createButton(buttons, 120, function()
        filters.difficulty = ns.FilterBar_NextValue({ nil, 0, 1, 2, 3 }, 5, filters.difficulty)
        changed()
    end)
    bar.colorButton:SetPoint("LEFT", bar.sourceButton, "RIGHT", 6, 0)
    bar.skillButton = createButton(buttons, 160, function()
        filters.skill = ns.FilterBar_NextValue(SKILL_MODES, 3, filters.skill)
        changed()
    end)
    bar.skillButton:SetPoint("LEFT", bar.colorButton, "RIGHT", 6, 0)
    bar.sortButton = createButton(buttons, 140, function(_, mouseButton)
        if mouseButton == "RightButton" and filters.sort then
            filters.sort = { key = filters.sort.key, desc = not filters.sort.desc }
        else
            local key = ns.FilterBar_NextValue(SORT_KEYS, 6, filters.sort and filters.sort.key)
            filters.sort = key and { key = key, desc = key == "craftable" or key == "value" } or nil
        end
        changed()
    end)
    bar.sortButton:SetPoint("LEFT", bar.skillButton, "RIGHT", 6, 0)
    bar.clearButton = createButton(buttons, 90, function()
        ns.FilterBar_Reset(filters)
        if config.onClear then config.onClear() end
        changed()
    end)
    bar.clearButton:SetPoint("RIGHT", 0, 0)
    bar.clearButton:SetText(L["Clear"])

    function bar.Update()
        bar.canMakeCheck:SetChecked(filters.canMake)
        bar.hideGreyCheck:SetChecked(filters.hideGrey)
        bar.altsCheck:SetChecked(filters.alts)
        bar.altsCheck:SetShown(ns.Inventory_Available and ns.Inventory_Available() or false)
        bar.sourceButton:SetText(L["Source: %s"]:format(filters.source and ns.Recipes_SourceLabel(filters.source) or L["All"]))
        bar.colorButton:SetText(L["Color: %s"]:format(difficultyLabel(filters.difficulty)))
        bar.skillButton:SetText(L["Skill: %s"]:format(skillLabel(filters.skill)))
        bar.sortButton:SetText(L["Sort: %s"]:format(sortLabel(filters.sort)))
    end
    bar.Update()
    return bar
end
