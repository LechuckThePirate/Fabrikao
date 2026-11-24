dofile("setupTests.lua")

describe("Theme fonts", function()
    -- T.fonts as Theme.lua builds it on a client with that locale and standard font
    local function fontsOn(locale, standard)
        WowMock.locale = locale
        _G.STANDARD_TEXT_FONT = standard
        local ns = {}
        assert(loadfile("Modules/UI/Theme.lua"))("Fabrikao", ns)
        return ns.Theme.fonts
    end

    after_each(function()
        WowMock.locale = nil
        _G.STANDARD_TEXT_FONT = nil
    end)

    it("keeps Morpheus and Arial Narrow on the Latin clients", function()
        local fonts = fontsOn("enUS", "Fonts\\FRIZQT__.TTF")
        assert.are.equal("Fonts\\FRIZQT__.TTF", fonts.title[1])
        assert.are.equal("Fonts\\MORPHEUS.TTF", fonts.logo[1])
        assert.are.equal("Fonts\\ARIALN.TTF", fonts.data[1])
    end)

    it("writes the readable text in the client's Cyrillic font on ruRU", function()
        local fonts = fontsOn("ruRU", "Fonts\\FRIZQT___CYR.TTF")
        for _, kind in ipairs({ "title", "heading", "body", "small" }) do
            assert.are.equal("Fonts\\FRIZQT___CYR.TTF", fonts[kind][1])
        end
        assert.are.equal("Fonts\\ARIALN.TTF", fonts.data[1]) -- numbers stay Latin-safe
        assert.are.equal("Fonts\\MORPHEUS.TTF", fonts.logo[1]) -- the logo is Latin text, drawn the same everywhere
    end)

    it("uses only the client's own font on the Asian clients", function()
        local fonts = fontsOn("zhCN", "Fonts\\ARKai_T.ttf")
        for _, f in pairs(fonts) do assert.are.equal("Fonts\\ARKai_T.ttf", f[1]) end
    end)

    it("falls back to Friz Quadrata when the client has no standard font", function()
        assert.are.equal("Fonts\\FRIZQT__.TTF", fontsOn("enUS", nil).body[1])
    end)
end)

describe("Theme palette", function()
    local ns

    setup(function()
        ns = LoadAddon({ files = { "Modules/UI/Theme.lua" } })
    end)

    it("decodes the style book's hex colors (La Forja del Maestro Artesano)", function()
        local r, g, b, a = ns.Theme.rgba("bronze")
        assert.is_true(math.abs(r - 0xD9 / 255) < 0.001)
        assert.is_true(math.abs(g - 0x77 / 255) < 0.001)
        assert.is_true(math.abs(b - 0x06 / 255) < 0.001)
        assert.are.equal(1, a)
    end)

    it("overrides the alpha when one is given", function()
        local _, _, _, a = ns.Theme.rgba("brass", 0.4)
        assert.are.equal(0.4, a)
    end)

    it("formats a palette color as inline text", function()
        assert.are.equal("|cffd97706", ns.Theme.code("bronze"))
    end)
end)

describe("Theme widgets", function()
    local ns

    before_each(function()
        ns = LoadAddon({ files = { "Modules/UI/Theme.lua" } })
    end)

    it("builds a forged panel with a brass border by default", function()
        local f = ns.Theme.CreateForgedFrame(UIParent)
        assert.are.same({ ns.Theme.rgba("brass") }, { unpack(f._set.SetBackdropBorderColor) })
    end)

    it("paints a bronze button enabled, gold border, dark text", function()
        local b = ns.Theme.CreateBronzeButton(UIParent, "Craft")
        assert.are.equal("Craft", b:GetText())
        assert.are.same({ ns.Theme.rgba("bronzeLight") }, { unpack(b._set.SetBackdropBorderColor) })
    end)

    it("dims a bronze button once disabled", function()
        local b = ns.Theme.CreateBronzeButton(UIParent, "Craft")
        b:SetEnabled(false)
        assert.are.same({ ns.Theme.rgba("brass") }, { unpack(b._set.SetBackdropBorderColor) })
    end)

    it("tracks the selected segment of a toggle", function()
        local picked
        local toggle = ns.Theme.CreateSegmentedToggle(UIParent, { { value = "table", text = "Table" }, { value = "detailed", text = "Detailed" } },
            function(value) picked = value end)
        toggle:SetValue("table")
        -- clicking the second segment's button (its label is a child font string) selects "detailed" and calls back
        local label = WowMock.FindByText("Detailed")
        local button = label:GetParent()
        button._scripts.OnClick(button)
        assert.are.equal("detailed", picked)
    end)

    it("fills a skill bar in proportion to its progress", function()
        local bar = ns.Theme.CreateSkillBar(UIParent)
        bar:SetSize(200, 13)
        bar:SetProgress(50, 100)
        assert.are.equal((200 - 2) * 0.5, bar.fill._w)
    end)
end)
