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

    it("does nothing for TomTom when it is not installed", function()
        assert.is_false(ns.Map_HasTomTom())
        assert.is_false(ns.Map_TomTom(spot, "Kendor"))
    end)
end)
