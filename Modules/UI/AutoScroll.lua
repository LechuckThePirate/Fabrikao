local _, ns = ...

-- A scroll frame whose bar is only there when the content is taller than the frame: with nothing to scroll the bar goes away and the
-- space it took goes to the content (the frame is laid out again, wider). The place of the frame is up to the caller, as a function
-- of whether the bar is there (it is given the frame too, which does not exist yet for the caller while it is being made):
--   local scroll, content = ns.AutoScroll_Create(parent, function(withBar, frame) frame:ClearAllPoints() ... end)
--   ns.AutoScroll_SetHeight(scroll, contentHeight)        -- after the content is laid out
--   ns.AutoScroll_Bar(scroll)                             -- is the bar shown now?

local BAR_MIN_EXCESS = 1 -- a content a pixel taller than the frame is not worth a bar

local function apply(scroll, need)
    local auto = scroll.autoScroll
    if auto.withBar == need then return end
    auto.withBar = need
    auto.layout(need, scroll)
    local bar = scroll.ScrollBar
    if bar and bar.SetShown then bar:SetShown(need) end
    if not need then scroll:SetVerticalScroll(0) end
end

local function evaluate(scroll)
    local auto = scroll.autoScroll
    apply(scroll, auto.height > (scroll:GetHeight() or 0) + BAR_MIN_EXCESS)
end

-- Makes the frame and its content (the scroll child, which follows the frame's width). `layout(withBar)` places the frame.
function ns.AutoScroll_Create(parent, layout)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(100, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    scroll.scrollBarHideable = true -- (the game's own template hides it too when there is no range)
    scroll.autoScroll = { layout = layout, height = 0, withBar = nil }
    apply(scroll, true)
    scroll:HookScript("OnSizeChanged", function(self)
        content:SetWidth(math.max(50, self:GetWidth() or 0))
        evaluate(self)
    end)
    return scroll, content
end

-- The content is `height` tall: sets it and shows or hides the bar.
function ns.AutoScroll_SetHeight(scroll, height)
    local auto = scroll.autoScroll
    auto.height = height or 0
    scroll.content:SetHeight(math.max(1, auto.height))
    evaluate(scroll)
end

function ns.AutoScroll_Bar(scroll)
    return scroll.autoScroll ~= nil and scroll.autoScroll.withBar == true
end
