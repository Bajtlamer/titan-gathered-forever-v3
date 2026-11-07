local frames = {}
local function frame(parent)
    local f = { parent = parent, shown = false, scripts = {}, hooks = {}, width = 1000, height = 600 }
    function f:SetAllPoints() end
    function f:SetText(value) self.text = value end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetFrameLevel() return 1 end
    function f:GetEffectiveScale() return self.effectiveScale or 1 end
    function f:SetFrameLevel() end
    function f:SetFrameStrata(value) self.strata = value end
    function f:SetParent(value) self.parent = value end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:HookScript(name, fn) self.hooks[name] = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:ClearAllPoints() end
    function f:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function f:CreateTexture()
        return { SetAllPoints = function() end, SetTexture = function(_, value) self.icon = value end,
            SetColorTexture = function() end, AddMaskTexture = function() end,
            SetSize = function() end, SetPoint = function() end }
    end
    function f:CreateMaskTexture() return { SetAtlas = function() end, SetAllPoints = function() end } end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function(_, _, parent) return frame(parent) end
C_Item = { GetItemIconByID = function(id) return id + 1000 end }
GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
local ns = { settings = { gatheringMap = true }, IsPublic = function() return true end,
    Style = { ItemName = function(id) return 'Item ' .. id end } }
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TitanGatheredForeverV3', ns)
assert(loadfile('TitanGatheredForeverV3/Map.lua'))('TitanGatheredForeverV3', ns)
local canvas, world = frame(), frame()
world:Show()
world.mapID = 1
function world:GetCanvas() return canvas end
function world:GetMapID() return self.mapID end
local points = { { mapID = 1, x = 0.4, y = 0.6, itemID = 2770, kind = 'Mining', count = 1, lastSeen = 100 } }
local controller = { List = function(_, mapID) return mapID == 1 and points or {} end }
local map = ns.Map.New(world, controller)
assert(#map.pins == 1 and map.pins[1].shown)
assert(map.pins[1].strata == 'HIGH', 'Native world-map drawing covers icons in the default MEDIUM strata')
assert(map.pins[1].x == 400 and map.pins[1].y == -360)
assert(map.pins[1].icon == 3770, 'Resource icon was not used')
world.mapID = 2; map:Refresh(true); assert(not map.pins[1].shown)
world.mapID = 1; map:Refresh(true); assert(map.pins[1].shown)
local allocated = #frames
map:Refresh(true); assert(#frames == allocated, 'Pins were not reused')
canvas.width = 500; map:Refresh(); assert(map.pins[1].x == 200)
ns.settings.gatheringMap = false; map:Refresh(true); assert(not map.pins[1].shown)
ns.settings.gatheringMap = true; map:Refresh(true); assert(map.pins[1].shown)
world:Hide(); map:Refresh(true); assert(not map.pins[1].shown)
world:Show(); canvas.width = 0
local delayed = ns.Map.New(world, controller)
assert(not delayed.overlay.shown)
canvas.width = 1000
assert(canvas.hooks.OnSizeChanged, 'Canvas readiness has no refresh callback')
canvas.hooks.OnSizeChanged()
assert(delayed.pins[1].shown and delayed.pins[1].x == 400)
assert(loadfile('TitanGatheredForeverV3/Gathering.lua'))('TitanGatheredForeverV3', ns)
local sourceReady = false
ns.gathering = ns.Gathering.New({
    CanRecord = function() return true end,
    Now = function() return 100 end, Timestamp = function() return 10000 end,
    Position = function() return { mapID = 1, x = 0.25, y = 0.75 } end,
    Loot = function() return { { slot = 1, itemID = 765,
        sources = sourceReady and { 'GameObject-0-1-2-3-657380-9' } or {} } } end,
}, {}, function() return { [765] = 0 } end, function() return true end)
ns.Catalog = { modules = { Herbs = {} } }; WorldMapFrame = world
ns.Map.Attach()
ns.gathering:Cast('UNIT_SPELLCAST_START', 'player', 'herbCast', 2366)
ns.gathering:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'herbCast', 2366)
ns.gathering:LootReady(); sourceReady = true; ns.gathering:LootReady()
ns.gathering:SlotCleared(1); ns.gathering:LootClosed()
local herbPin = ns.Map.instance.pins[1]
assert(herbPin and herbPin.shown and herbPin.icon == 1765, 'Recorded herb did not draw its own item icon')
assert(herbPin.x == 250 and herbPin.y == -450, 'Herb icon is not at the recorded position')
canvas.effectiveScale = 0.125
ns.Map.instance:Refresh()
assert(herbPin.width * canvas:GetEffectiveScale() == 14, 'Zoomed-out canvas shrank the herb icon below 14 pixels')
canvas.effectiveScale = 0.25
ns.Map.instance:Refresh()
assert(herbPin.width * canvas:GetEffectiveScale() == 14, 'Zoom changes did not preserve icon size')
-- A player can browse a parent map while observations retain their zone map ID.
C_Map = { GetMapRectOnMap = function(child, parent)
    if child == 1 and parent == 2 then return 0.2, 0.6, 0.1, 0.5 end
end }
world.mapID = 2; ns.Map.instance:Refresh(true)
local projected = ns.Map.instance.pins[1]
assert(projected.shown, 'Parent map did not show the saved zone observation')
assert(math.abs(projected.x - 300) < 0.001 and math.abs(projected.y + 240) < 0.001)
ns.settings.mapWorld = false; ns.Map.instance:Refresh(true)
assert(not projected.shown, 'World map switch failed to hide projected icons')
ns.settings.mapWorld = true; ns.Map.instance:Refresh(true); assert(projected.shown)
local oldCanvas = canvas
canvas = frame(); canvas.width, canvas.height, canvas.effectiveScale = oldCanvas.width, oldCanvas.height, oldCanvas.effectiveScale
ns.Map.instance:Refresh()
assert(ns.Map.instance.overlay.parent == canvas, 'Same-size replacement canvas left icons on the old canvas')
ns.Catalog.modules = { Skinning = {} }; ns.Map.instance = nil
ns.gathering = ns.Gathering.New({}, { maps = { [2] = {
    { mapID = 2, x = 0.5, y = 0.5, kind = 'Skinning', itemID = 783, count = 1, lastSeen = 100 },
    { mapID = 2, x = 0.5, y = 0.5, kind = 'Skinning', itemID = 2318, count = 1, lastSeen = 100 },
} } }, function() return {} end, function() return true end)
ns.Map.Attach()
local skins = ns.Map.instance.pins
assert(#skins == 2 and skins[1].shown and skins[2].shown, 'Skinning-only module did not attach and render')
assert(skins[1].x ~= skins[2].x and skins[1].icon ~= skins[2].icon, 'Different skinning materials overlap')
assert(ns.gathering.saved.maps[2][1].x == ns.gathering.saved.maps[2][2].x, 'Display separation moved saved observations')
assert(map.clearButton and map.clearButton.parent == world)
assert(map.clearButton.text == 'TGF v3 spots')
local opened
ns.Titan = { ClearSpotsMenu = function(owner, target) opened = {owner, target} end }
map.clearButton.scripts.OnClick(map.clearButton)
assert(opened[1] == map.clearButton and opened[2] == world)
print('PASS 14 map rendering, scaling, projection, lifecycle, reuse, toggle and gathering-material checks')
