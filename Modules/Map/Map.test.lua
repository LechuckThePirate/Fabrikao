dofile("setupTests.lua")

describe("Map", function()
    local ns
    local spot = { map = 1453, x = 74.4, y = 36.4 }

    before_each(function()
        WowMock.Reset()
        _G.TomTom, _G.OpenWorldMap = nil, nil
        _G.WorldMapFrame = WowMock.NewFrame("Frame", "WorldMapFrame")
        _G.WorldMapFrame._shown = false
        ns = LoadAddon({ files = { "Modules/Map/Map.lua" } })
    end)

    after_each(function() _G.TomTom, _G.OpenWorldMap = nil, nil end)

    it("opens the world map on the spot", function()
        local opened
        _G.OpenWorldMap = function(map) opened = map end
        assert.is_true(ns.Map_Show(spot))
        assert.are.equal(1453, opened)
    end)

    it("falls back to showing the map frame on its map", function()
        local shown, mapID
        _G.ShowUIPanel = function(frame) shown = frame end
        _G.WorldMapFrame.SetMapID = function(_, id) mapID = id end
        assert.is_true(ns.Map_Show(spot))
        assert.are.equal(_G.WorldMapFrame, shown)
        assert.are.equal(1453, mapID)
    end)

    it("puts a pin on the map's canvas", function()
        _G.OpenWorldMap = function() end
        _G.WorldMapFrame.GetCanvas = function() return WowMock.NewFrame("Frame", nil, _G.WorldMapFrame) end
        _G.WorldMapFrame.GetMapID = function() return 1453 end
        ns.Map_Show(spot)
        local holder = WowMock.Find(function(f) return f._scripts.OnUpdate ~= nil end)
        assert.is_not_nil(holder)
        holder._scripts.OnUpdate(holder)
        assert.are.equal(1, holder:GetAlpha())
        _G.WorldMapFrame.GetMapID = function() return 36 end -- another map is showing
        holder._scripts.OnUpdate(holder)
        assert.are.equal(0, holder:GetAlpha())
    end)

    it("shows nothing for a spot without a map", function()
        assert.is_false(ns.Map_Show(nil))
        assert.is_false(ns.Map_Show({ x = 1, y = 2 }))
    end)

    it("sets a TomTom waypoint, with the coordinates as fractions of the map", function()
        local added
        _G.TomTom = { AddWaypoint = function(_, map, x, y, options) added = { map = map, x = x, y = y, options = options } end }
        assert.is_true(ns.Map_HasTomTom())
        assert.is_true(ns.Map_TomTom(spot, "Kendor"))
        assert.are.equal(1453, added.map)
        assert.is_true(math.abs(added.x - 0.744) < 1e-9)
        assert.are.equal("Kendor", added.options.title)
        assert.is_true(added.options.crazy)
    end)

    describe("distance", function()
        before_each(function()
            _G.CreateVector2D = function(x, y) return { x = x, y = y } end
            _G.C_Map = {
                GetBestMapForUnit = function() return 1453 end,
                GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
                GetWorldPosFromMapPos = function(map, v) return map == 99 and 2 or 1, { x = v.x * 1000, y = v.y * 1000 } end,
            }
        end)

        it("is the yards from the character to a spot on the same continent", function()
            assert.is_true(math.abs(ns.Map_Distance({ map = 1453, x = 80, y = 90 }) - 500) < 0.001) -- 300 and 400 away
        end)

        it("is unknown for another continent, a missing spot or an unknown position", function()
            assert.is_nil(ns.Map_Distance({ map = 99, x = 10, y = 10 }))
            assert.is_nil(ns.Map_Distance(nil))
            _G.C_Map.GetPlayerMapPosition = function() return nil end
            assert.is_nil(ns.Map_Distance({ map = 1453, x = 80, y = 90 }))
        end)

        it("reads in yards in the English locales and in meters elsewhere", function()
            _G.GetLocale = function() return "enUS" end
            assert.are.equal("350 yd", ns.Map_FormatDistance(350))
            assert.are.equal("1.5k yd", ns.Map_FormatDistance(1500))
            _G.GetLocale = function() return "esES" end
            assert.are.equal("320 m", ns.Map_FormatDistance(350))
            assert.are.equal("", ns.Map_FormatDistance(nil))
        end)
    end)

    it("a new waypoint replaces the one set before, so they don't pile up", function()
        local removed, n = {}, 0
        _G.TomTom = {
            AddWaypoint = function() n = n + 1; return "uid" .. n end,
            RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
        }
        ns.Map_TomTom(spot, "A")
        assert.are.same({}, removed)
        ns.Map_TomTom(spot, "B")
        ns.Map_TomTom(spot, "C")
        assert.are.same({ "uid1", "uid2" }, removed)
    end)

    it("does nothing for TomTom when it is not installed", function()
        assert.is_false(ns.Map_HasTomTom())
        assert.is_false(ns.Map_TomTom(spot, "Kendor"))
    end)
end)
