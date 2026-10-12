dofile("setupTests.lua")

-- The start screen in four quadrants, and the scroll bars that are only there when they are needed.
describe("The start screen", function()
    local ns, known, distances, mapped, bag

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 100, 120, 140, 160 }, m = { { 11, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Mana Potion", c = { 30, 50, 70, 90 }, m = { { 11, 1 } }, k = { 6 } },
            [4] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, m = { { 11, 1 } }, k = { 6 } },
            [5] = { s = 164, n = "Iron Sword", c = { 50, 70, 90, 110 }, m = { { 12, 1 } }, k = { 6 } },
            [6] = { s = 164, n = "Steel Axe", c = { 150, 170, 190, 210 }, m = { { 12, 1 } }, k = { 6 } },
            -- taught by an item a vendor sells
            [7] = { s = 164, n = "Dropped Dagger", c = { 40, 60, 80, 100 }, m = { { 12, 1 } }, k = { 5 }, i = 900 },
            -- the same, but it asks for more skill than the smith has
            [8] = { s = 164, n = "Vendor Hammer", c = { 140, 160, 180, 200 }, m = { { 12, 1 } }, k = { 5 }, i = 901 },
        },
        items = {
            [900] = { n = "Plans: Dropped Dagger", k = { 5 }, v = { { id = 13, n = "Vendor Vic", z = { 1519 }, g = 500 }, { id = 14, n = "Horde Hank", z = { 1637 }, f = "H" } } },
            [901] = { n = "Plans: Vendor Hammer", k = { 5 }, v = { { id = 15, n = "Hammer Hal", z = { 1519 } } } },
        },
        trainers = {
            [171] = { { id = 9, n = "Near Anna", t = "Alchemist", z = { 1519 } }, { id = 10, n = "Far Ben", z = { 46 } } },
            [164] = { { id = 11, n = "Smith Sam", t = "Blacksmith", z = { 1519 } } },
            [185] = { { id = 12, n = "Cook Cora", z = { 1519 } } },
        },
        npcs = { [9] = { 1453, 40, 60 }, [10] = { 36, 30, 20 }, [11] = { 1453, 20, 20 }, [12] = { 1453, 30, 30 }, [13] = { 1453, 60, 60 } },
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function text(pattern)
        return WowMock.FindAll(function(f) return f._text and f._text:match(pattern) and f:IsVisible() end)
    end

    local function learnNames()
        local out = {}
        for _, f in ipairs(framesWith("learn")) do out[#out + 1] = f.name._text end
        return out
    end

    local function headers(kind)
        local out = {}
        for _, f in ipairs(framesWith("kind")) do
            if kind == nil or f.kind == kind then out[#out + 1] = { kind = f.kind, key = f.key, text = f.text._text, frame = f } end
        end
        return out
    end

    -- the groups are folded until they are opened: this opens every group of a kind ("learn" or "trainers")
    local function open(kind)
        for _ = 1, 10 do
            local closed
            for _, header in ipairs(headers(kind)) do
                if header.frame.folded then closed = header.frame break end
            end
            if not closed then return end
            click(closed)
        end
    end

    local function trainerRows() return framesWith("trainer") end
    local function vendorRows() return framesWith("vendor") end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        WowMock.level = 10
        bag = { [10] = 5, [11] = 0, [12] = 0 }
        known = { [1] = true, [5] = false }
        _G.GetProfessions = function() return 1, 2 end
        _G.GetProfessionInfo = function(index)
            if index == 1 then return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
            return "Blacksmithing", 222, 75, 75, 1, 20, 164, 0
        end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = {
            GetSpellBookItemInfo = function(slot) return { spellID = slot } end,
            IsSpellKnown = function(id) return known[id] == true end,
        }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function(id) return bag[id] or 0 end, GetItemNameByID = function(id) return "Item" .. id end,
            GetItemIconByID = function() return 1 end }
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [46] = "Burning Steppes", [1637] = "Orgrimmar" })[id] end,
            GetBestMapForUnit = function() return 1453 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB, _G.TomTom = nil, nil, nil
        _G.FabrikaoDetailFrame = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        -- yards from the character by the map of the spot
        distances = { [1453] = 400, [36] = 4000 }
        ns.Map_Distance = function(spot)
            if spot.map == 1453 and spot.x == 20 then return 100 end -- the smith is the nearest of all
            return distances[spot.map]
        end
        mapped = {}
        ns.Map_Show = function(spot) mapped[#mapped + 1] = spot return true end
        StartAddon(ns)
        ns.UI_Show()
    end)

    describe("what is on it", function()
        it("welcomes, and keeps the search, the picker of the character and the button of the professions not learned", function()
            assert.are.equal(1, #text("^Welcome to Fabrikao"))
            assert.is_not_nil(WowMock.Find(function(f) return f._template == "InputBoxTemplate" and f:IsVisible() end))
            assert.is_not_nil(WowMock.Find(function(f) return f._template == "WowStyle1DropdownTemplate" and f:IsVisible() end)
                or WowMock.Find(function(f) return f._text == "My professions" and f:IsVisible() end))
            assert.are.equal(1, #text("professions not learned$"))
        end)

        it("has the four quadrants with their titles", function()
            assert.is_true(#text("^Professions$") >= 1) -- (and the title of its group of primary professions)
            assert.are.equal(1, #text("^You can learn %("))
            assert.are.equal(1, #text("^You can craft now %("))
            assert.are.equal(1, #text("^Trainers and vendors nearby$"))
        end)

        it("the top left lists the professions with their bar and skill", function()
            local list = framesWith("profession")
            assert.are.equal(2, #list)
            assert.are.equal("Alchemy", list[1].profession.name)
            assert.are.equal("150 / 300", list[1].barText._text)
            assert.are.equal("Blacksmithing", list[2].profession.name)
            assert.are.equal("75 / 75", list[2].barText._text)
        end)
    end)

    describe("what can be learned (top right)", function()
        it("tells the ranks a trainer can teach", function()
            -- the smith's skill is at the cap of its rank and the character is level 10
            local ranks = framesWith("ofProfession")
            assert.are.equal(1, #ranks)
            assert.matches("Blacksmithing: .*Journeyman", ranks[1].name._text)
            assert.are.equal("skill 150", ranks[1].skillText._text)
        end)

        it("has the groups folded at first, with how many each has", function()
            assert.are.same({}, learnNames())
            local h = headers("learn")
            assert.are.equal(2, #h)
            assert.matches("^Alchemy %(2%)", h[1].text)
            assert.matches("^Blacksmithing %(2%)", h[2].text)
        end)

        it("lists the recipes the skill reaches that are not known, by profession and by level, once opened", function()
            -- Alchemy (skill 150): Mana Potion needs 30, Healing Potion 100; the Elixir is known, the Flask asks for 250.
            -- Blacksmithing (skill 75): the Sword needs 50 and the Dagger 40; the Axe and the Hammer ask for more
            open("learn")
            assert.are.same({ "Mana Potion", "Healing Potion", "Dropped Dagger", "Iron Sword" }, learnNames())
        end)

        it("each recipe has its level and where it is learned", function()
            open("learn")
            local first = framesWith("learn")[1]
            assert.matches("^30", first.skillText._text)
            assert.matches("Trainer", first.skillText._text)
        end)

        it("a click on a recipe opens its panel", function()
            open("learn")
            click(framesWith("learn")[1])
            assert.is_true(_G.FabrikaoDetailFrame:IsShown())
            assert.are.equal("Mana Potion", _G.FabrikaoDetailFrame.name._text)
        end)

        it("a group opens and folds with a click on its title, and it is kept", function()
            click(headers("learn")[1].frame)
            assert.are.same({ "Mana Potion", "Healing Potion" }, learnNames())
            assert.is_false(FabrikaoCharDB.folded.learn[171])
            click(headers("learn")[1].frame)
            assert.are.same({}, learnNames())
            assert.is_true(FabrikaoCharDB.folded.learn[171])
        end)

        it("what was opened stays open when the screen is drawn again", function()
            click(headers("learn")[1].frame)
            ns.UI_ShowOverview()
            assert.are.same({ "Mana Potion", "Healing Potion" }, learnNames())
        end)

        it("a reset of the settings folds them all again", function()
            open("learn")
            ns.ResetSettings()
            assert.is_nil(FabrikaoCharDB.folded)
            assert.are.same({}, learnNames())
        end)

        it("says so when there is nothing", function()
            known = { [1] = true, [2] = true, [3] = true, [5] = true, [7] = true }
            WowMock.level = 5 -- no rank to train either
            ns.UI_ShowOverview()
            assert.are.equal(1, #text("^Nothing new to learn"))
        end)
    end)

    describe("the trainers and vendors close by (bottom right)", function()
        local function groupTexts()
            local out = {}
            for _, header in ipairs(headers("trainers")) do out[#out + 1] = header.text end
            return out
        end

        it("are grouped by profession, folded at first, the one with the nearest first", function()
            -- the smith: its trainer (100 yards) and its vendor (400); alchemy: its trainers (400 and 4000)
            assert.are.same({ "Blacksmithing (2)", "Alchemy (2)" }, groupTexts())
            assert.are.equal(0, #trainerRows() + #vendorRows())
        end)

        it("once opened, the trainers come nearest first and then the vendors", function()
            open("trainers")
            local names = {}
            for _, row in ipairs(trainerRows()) do names[#names + 1] = row.trainer.name end
            assert.are.same({ "Smith Sam", "Near Anna", "Far Ben" }, names)
            assert.are.equal(1, #vendorRows())
            assert.are.equal("Vendor Vic", vendorRows()[1].vendor.name)
        end)

        it("a vendor is only there for what it sells of the profession: a recipe that is not known and that the skill reaches", function()
            open("trainers")
            -- Hammer Hal sells the plans of a recipe that asks for more skill than the smith has; Horde Hank is the Horde's
            local names = {}
            for _, row in ipairs(vendorRows()) do names[#names + 1] = row.vendor.name end
            assert.are.same({ "Vendor Vic" }, names)
            assert.is_nil(WowMock.Find(function(f) return f.vendor and f.vendor.name == "Hammer Hal" end))
        end)

        it("says what the vendor sells and what it is, in the line of the vendor", function()
            open("trainers")
            local row = vendorRows()[1]
            assert.matches("Vendor Vic", row.name._text)
            assert.matches("Dropped Dagger", row.name._text)
            assert.matches("^Vendor", row.where._text)
            assert.matches("Stormwind City", row.where._text)
        end)

        it("a vendor that sells nothing of what is left to learn is gone", function()
            known = { [1] = true, [7] = true } -- the dagger is known now
            ns.UI_ShowOverview()
            open("trainers")
            assert.are.equal(0, #vendorRows())
        end)

        it("says the rank in the group that can train it", function()
            local noted
            for _, header in ipairs(headers("trainers")) do
                if header.text:match("^Blacksmithing") then noted = header.frame.note._text end
            end
            assert.matches("Can train: .*Journeyman", noted)
        end)

        it("only the professions whose trainers teach something that is not known yet, or whose vendors sell something", function()
            -- cooking has trainers in the data but the character has no cooking; alchemy has nothing left for a trainer
            known = { [1] = true, [2] = true, [3] = true, [4] = true, [7] = true }
            ns.UI_ShowOverview()
            assert.are.same({ "Blacksmithing (1)" }, groupTexts())
        end)

        it("each one has the map and waypoint icons, and the map one shows it on the map", function()
            open("trainers")
            local row = trainerRows()[1]
            assert.is_true(row.mapButton:IsShown())
            assert.are.equal("map", row.mapButton.iconKind)
            assert.are.equal("pointer", row.tomButton.iconKind)
            click(row.mapButton)
            assert.are.same({ { map = 1453, x = 20, y = 20 } }, mapped)
        end)

        it("has the waypoint icon with TomTom installed", function()
            _G.TomTom = { AddWaypoint = function() return {} end }
            ns.UI_ShowOverview()
            open("trainers")
            assert.is_true(trainerRows()[1].tomButton:IsShown())
        end)

        it("each one takes two lines: the name, and under it what it is, where and how far", function()
            open("trainers")
            local row = trainerRows()[1]
            assert.matches("Smith Sam", row.name._text)
            assert.matches("^Trainer", row.where._text)
            assert.matches("Stormwind City", row.where._text)
            assert.is_true(row:GetHeight() <= 40) -- (not the roomy lines of before)
        end)

        it("says so when nothing has anything for the character", function()
            known = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true }
            WowMock.level = 5 -- and no rank to train
            ns.UI_ShowOverview()
            assert.are.equal(0, #headers("trainers"))
            assert.are.equal(1, #text("^No trainer or vendor has anything new"))
        end)
    end)

    describe("another character's professions", function()
        before_each(function()
            FabrikaoDB.characters = { ["Elsa-Realm"] = { name = "Elsa", realm = "Realm", class = "MAGE", level = 12, time = 1, professions = {
                { skillLine = 171, name = "Alchemy", icon = 111, rank = 40, maxRank = 75, primary = true, hasRecipes = true, known = { 3 } },
            } } }
            ns.UI_ViewCharacter("Elsa-Realm")
        end)

        it("the learnable recipes are the alt's: its skill and what it knows", function()
            -- skill 40: the Elixir (1) and the Mana Potion (30) are within reach; the alt knows the potion, not the elixir (the
            -- playing character does)
            open("learn")
            assert.are.same({ "Elixir of Wisdom" }, learnNames())
        end)

        it("the craft quadrant says there is no crafting", function()
            assert.are.equal(1, #text("^There is no crafting"))
            assert.are.equal(1, #text("^You can craft now$"))
        end)
    end)
end)

-- The scroll bar that is only there when there is something to scroll
describe("AutoScroll", function()
    local ns, scroll, placed

    before_each(function()
        WowMock.Reset()
        ns = LoadAddon({ files = { "Modules/UI/AutoScroll.lua" } })
        placed = {}
        local parent = CreateFrame("Frame")
        scroll = ns.AutoScroll_Create(parent, function(withBar) placed[#placed + 1] = withBar end)
        scroll._h = 100 -- what the game would say of the frame
    end)

    it("starts with the bar, until it knows the content", function()
        assert.are.same({ true }, placed)
        assert.is_true(ns.AutoScroll_Bar(scroll))
    end)

    it("hides the bar and takes its room when the content fits", function()
        ns.AutoScroll_SetHeight(scroll, 60)
        assert.is_false(ns.AutoScroll_Bar(scroll))
        assert.are.same({ true, false }, placed)
        assert.is_false(scroll.ScrollBar:IsShown())
    end)

    it("shows it when the content is taller than the frame, and goes back to the top when it is not", function()
        ns.AutoScroll_SetHeight(scroll, 60)
        ns.AutoScroll_SetHeight(scroll, 400)
        assert.is_true(ns.AutoScroll_Bar(scroll))
        assert.is_true(scroll.ScrollBar:IsShown())
        scroll:SetVerticalScroll(120)
        ns.AutoScroll_SetHeight(scroll, 30)
        assert.are.equal(0, scroll:GetVerticalScroll())
    end)

    it("does not lay the frame out again while nothing changes", function()
        ns.AutoScroll_SetHeight(scroll, 400)
        ns.AutoScroll_SetHeight(scroll, 500)
        assert.are.same({ true }, placed)
    end)

    it("judges again when the frame is resized", function()
        ns.AutoScroll_SetHeight(scroll, 150)
        assert.is_true(ns.AutoScroll_Bar(scroll))
        scroll._h = 300
        WowMock.Fire(scroll, "OnSizeChanged")
        assert.is_false(ns.AutoScroll_Bar(scroll))
    end)
end)

-- The list of recipes of a profession's page: its bar goes when the rows fit and the room goes to them
describe("The bar of the list of recipes", function()
    local ns

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 100, 120, 140, 160 }, m = { { 11, 1 } }, k = { 6 } },
        },
        items = {}, trainers = {}, npcs = {},
    }

    local function visibleScrolls()
        return WowMock.FindAll(function(f)
            return f._template == "UIPanelScrollFrameTemplate" and f.autoScroll == nil and f:IsVisible()
        end)
    end

    -- where the column titles end on the right: -24 with the bar, -4 without it
    local function headerRight()
        local header = ns.RecipeList_HeaderFrame()
        local right
        for _, point in ipairs(header._points) do
            if point[1] == "RIGHT" then right = point[4] end
        end
        return right
    end

    before_each(function()
        WowMock.Reset()
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end, IsSpellKnown = function() return false end }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function() return 0 end, GetItemNameByID = function(id) return "Item" .. id end, GetItemIconByID = function() return 1 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        ns.UI_Show()
        for _, f in ipairs(WowMock.frames) do
            if f.profession ~= nil and f:IsVisible() and f.profession.skillLine == 171 then f._scripts.OnClick(f) end
        end
    end)

    it("is there when the rows are taller than the list", function()
        local scroll = visibleScrolls()[1]
        scroll._h = 20 -- two recipes and their titles do not fit in that
        ns.RecipeList_Relayout()
        assert.are.equal(-24, headerRight())
        assert.is_true(scroll.ScrollBar:IsShown())
    end)

    it("goes when they fit, and the rows take its room", function()
        local scroll = visibleScrolls()[1]
        scroll._h = 2000
        ns.RecipeList_Relayout()
        assert.are.equal(-4, headerRight())
        assert.is_false(scroll.ScrollBar:IsShown())
        scroll._h = 20
        ns.RecipeList_Relayout()
        assert.are.equal(-24, headerRight())
        assert.is_true(scroll.ScrollBar:IsShown())
    end)
end)
