local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then io.stderr:write('FAIL ' .. name .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
    passed = passed + 1
end
local state = { x = 0.5, y = 0.5, radius = 100, facing = 0, rotate = false, mapID = 1412 }
local function frame()
    local f = { scripts = {}, shown = true, width = 200, height = 200 }
    function f:SetAllPoints() end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetFrameLevel() return 1 end
    function f:SetFrameLevel() end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript() end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:ClearAllPoints() end
    function f:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function f:CreateTexture() return { SetAllPoints = function() end, SetTexture = function(_, icon) f.icon = icon end,
        SetColorTexture = function() end, AddMaskTexture = function(self,mask) self.mask=mask end, RemoveMaskTexture = function(self) self.mask=nil end,
        SetSize = function() end, SetPoint = function() end } end
    function f:CreateMaskTexture() return { SetAtlas = function() end, SetAllPoints = function() end } end
    return f
end
CreateFrame = frame
Minimap = frame()
C_Map = { GetBestMapForUnit = function() return state.mapID end,
    GetPlayerMapPosition = function() return state.x and { GetXY = function() return state.x, state.y end } end,
    GetMapWorldSize = function() return 1000, 1000 end }
C_Minimap = { GetViewRadius = function() return state.radius end, IsRotateMinimapIgnored = function() return false end }
GetCVar = function() return state.rotate and '1' or '0' end
GetPlayerFacing = function() return state.facing end
C_Item = { GetItemIconByID = function(id) return id + 1000 end }
GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
local ns = { settings = { gatheringMap = true, mapMinimap = true }, IsPublic = function() return true end,
    Catalog = { modules = { Herbs = {} } },
    Style = { Separator = function(tooltip) tooltip:AddLine(' ') end, ItemName = function(id) return 'Item ' .. id end } }
local nodes = { { mapID = 1412, itemID = 765, kind = 'Herbs', x = 0.55, y = 0.5, count = 1 } }
ns.gathering = { List = function(_, mapID) return mapID == 1412 and nodes or {} end }
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TitanGatheredForeverV3', ns)
assert(loadfile('TitanGatheredForeverV3/Minimap.lua'))('TitanGatheredForeverV3', ns)
ns.Minimap.Attach()
local map = assert(ns.Minimap.instance)
local function near(a, b) assert(math.abs(a - b) < 0.001, tostring(a) .. ' != ' .. tostring(b)) end

test('nearby saved herb draws its item icon east of the player', function()
    map:Refresh()
    local pin = assert(map.pins[1]); assert(pin.shown and pin.icon == 1765)
    near(pin.x, 50); near(pin.y, 0)
end)
test('zoom radius and player movement reposition the same pooled pin', function()
    local pin = map.pins[1]
    state.radius = 200; map:Refresh(); near(pin.x, 25)
    state.x = 0.55; map:Refresh(); near(pin.x, 0)
    assert(map.pins[1] == pin and #map.pins == 1)
end)
test('rotating minimap turns a western node toward the top when facing west', function()
    state.x, state.radius, state.rotate, state.facing = 0.6, 100, true, math.pi / 2
    map:Refresh(); near(map.pins[1].x, 0); near(map.pins[1].y, 50)
end)
test('distant spots, other zones and unavailable positions are hidden', function()
    state.rotate = false; state.x = 0.1; map:Refresh(); assert(not map.pins[1].shown)
    state.x = 0.5; state.mapID = 2; map:Refresh(); assert(not map.pins[1].shown)
    state.mapID = 1412; state.x = nil; map:Refresh(); assert(not map.pins[1].shown)
    state.x = 0.5
end)
test('master and minimap visibility switches hide icons without deleting saved spots', function()
    map:Refresh(); assert(map.pins[1].shown)
    ns.settings.mapMinimap = false; map:Refresh(); assert(not map.pins[1].shown)
    ns.settings.mapMinimap = true; ns.settings.gatheringMap = false
    map:Refresh(); assert(not map.pins[1].shown)
    ns.settings.gatheringMap = true; map:Refresh(); assert(map.pins[1].shown and #nodes == 1)
end)
test('hidden minimap and zero radius fail closed without stale icons', function()
    Minimap:Hide(); map:Refresh(); assert(not map.pins[1].shown)
    Minimap:Show(); state.radius = 0; map:Refresh(); assert(not map.pins[1].shown)
end)
test('skinning-only module keeps co-located materials at their true projected position', function()
    state.radius, state.x, state.y = 100, 0.5, 0.5
    nodes = { { mapID = 1412, x = 0.5, y = 0.5, kind = 'Skinning', itemID = 783, count = 1 },
              { mapID = 1412, x = 0.5, y = 0.5, kind = 'Skinning', itemID = 2318, count = 1 } }
    ns.Catalog.modules = { Skinning = {} }; ns.Minimap.instance = nil
    ns.Minimap.Attach()
    local pins = ns.Minimap.instance.pins
    assert(#pins == 2 and pins[1].shown and pins[2].shown)
    near(pins[1].x,0);near(pins[2].x,0);near(pins[1].y,0);near(pins[2].y,0)
    assert(pins[1].icon ~= pins[2].icon)
    nodes[1].count=50;ns.Minimap.instance:Refresh();near(pins[1].x,0);near(pins[2].x,0)
end)
test('hovering a mapped material shows observed history without losing native tooltip',function()
    local lines={};GameTooltip.AddLine=function(_,line)lines[#lines+1]=line end
    UnitGUID=function()return'player'end
    ns.Reports={Source=function()return'Skinning source'end};ns.history={Rates=function()return{{itemID=783,mapID=1412,kind='Skinning',percent=50,hits=1,trials=2}}end}
    local pin=ns.Minimap.instance.pins[1];pin.scripts.OnEnter(pin)
    local found=false;for _,line in ipairs(lines)do if line:find('50.0%',1,true)then found=true end end
    assert(found)
    local countFound=false
    for _,line in ipairs(lines)do if line:find('Observed '..pin.node.count..' times',1,true)then countFound=true end end
    assert(countFound,'Minimap hover omitted the saved gathering count')
end)
test('minimap appearance applies independently and large icons remain within its edge',function()
    ns.settings.iconAppearance={minimap={size=30,shape='square',border=false}}
    ns.Minimap.instance:Refresh();local pin=ns.Minimap.instance.pins[1]
    assert(pin.width==30 and pin.height==30 and pin.texture.mask==nil)
    near(pin.x,0);near(pin.y,0);assert(ns.PinStyle.Get('world').size==14)
    ns.settings.iconAppearance.minimap.size=40;nodes[1].x=.585
    ns.Minimap.instance:Refresh();assert(ns.Minimap.instance.visibleCount==1)
    assert(ns.Minimap.instance.pins[1].node.itemID==2318,'Large edge icon was not clipped')
    ns.settings.iconAppearance=nil
end)
test('large square corners and enabled outlines do not cross the circular minimap boundary',function()
    Minimap.width,Minimap.height=140,140
    state.x,state.y,state.radius,state.rotate=.5,.5,100,false
    nodes={{mapID=1412,x=.5495,y=.4505,kind='Skinning',itemID=783,count=1}}
    ns.settings.iconAppearance={minimap={size=40,shape='square',border=false}}
    ns.Minimap.instance:Refresh();assert(ns.Minimap.instance.visibleCount==0,'Square corner overflows the minimap')
    ns.settings.iconAppearance.minimap.shape='circle'
    ns.Minimap.instance:Refresh();assert(ns.Minimap.instance.visibleCount==1,'Unbordered circle should fit')
    ns.settings.iconAppearance.minimap.border=true
    ns.Minimap.instance:Refresh();assert(ns.Minimap.instance.visibleCount==0,'Outline overflows the minimap')
    ns.settings.iconAppearance=nil
end)
test('outdoor PvP markers render and provide a tooltip without an item ID',function()
    state.x,state.y,state.radius,state.rotate=.5,.5,100,false
    nodes={{mapID=1412,x=.501,y=.5,kind='PvP',count=3,honorEstimate=60,lastSeen=100}}
    ns.settings.iconAppearance=nil;ns.Minimap.instance:Refresh()
    local pin=assert(ns.Minimap.instance.pins[1]);assert(pin.shown)
    assert(pin.icon=='Interface\\Icons\\INV_Sword_04')
    local lines={};GameTooltip.AddLine=function(_,line)lines[#lines+1]=line end
    pin.scripts.OnEnter(pin)
    local count=false;for _,line in ipairs(lines)do if line:find('3 honorable kills',1,true)then count=true end end
    assert(count,'PvP minimap tooltip omitted its total')
end)
print('PASS ' .. passed .. ' minimap icon projection, rotation, zoom, reuse and toggle checks')
