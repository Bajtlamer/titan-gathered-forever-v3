local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local frames, clock, faction, rows, native = {}, 0, 'Alliance', {}, {}
local function frame(parent)
    local f = { parent = parent, shown = false, scripts = {}, hooks = {}, events = {}, width = 1000, height = 600 }
    function f:SetAllPoints() end
    function f:SetBackdrop(info) self.backdrop=info end
    function f:SetBackdropBorderColor(...) self.color={...} end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetEffectiveScale() return (self.scale or 1)*(self.localScale or 1) end
    function f:GetScale() return self.localScale or 1 end
    function f:SetScale(value) self.localScale=value end
    function f:GetFrameLevel() return 1 end
    function f:SetFrameLevel() end
    function f:SetFrameStrata(s) self.strata=s end
    function f:SetParent(p) self.parent=p end
    function f:SetScript(e,fn) self.scripts[e]=fn end
    function f:HookScript(e,fn) self.hooks[e]=fn end
    function f:RegisterEvent(e) self.events[e]=true end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:IsShown() return self.shown end
    function f:ClearAllPoints() end
    function f:SetPoint(_,_,_,x,y) self.x,self.y=x,y end
    function f:CreateTexture()
        local r={}
        function r:SetAllPoints() end
        function r:SetSize(w,h) self.width,self.height=w,h end
        function r:SetPoint() end
        function r:SetTexture(v) self.texture=v end
        function r:SetAtlas(v) self.atlas=v end
        function r:SetVertexColor(...) self.vertex={...} end
        function r:GetVertexColor() return unpack(self.vertex or {1,1,1,1}) end
        function r:SetColorTexture(...) self.color={...} end
        function r:AddMaskTexture(mask) self.mask=mask end
        function r:RemoveMaskTexture() self.mask=nil end
        function r:Show() self.shown=true end
        function r:Hide() self.shown=false end
        return r
    end
    function f:CreateMaskTexture() return self:CreateTexture() end
    frames[#frames+1]=f; return f
end
CreateFrame=function(_,_,parent) return frame(parent) end
GetTime=function() return clock end
UnitFactionGroup=function() return faction end
local character='a'
UnitGUID=function()return character end
C_Map={GetBestMapForUnit=function()return 1 end,GetMapInfo=function()return{parentMapID=0}end}
Enum={FlightPathState={Current=0,Reachable=1,Unreachable=2}}
local taxiRows={}
local apiCalls=0
C_TaxiMap={GetTaxiNodesForMap=function(mapID) apiCalls=apiCalls+1; return rows[mapID] or {} end,
    GetAllTaxiNodes=function()return taxiRows end}
GameTooltip={lines={}, SetOwner=function(self,p) self.owner=p;self.lines={} end,
    GetOwner=function(self)return self.owner end, AddLine=function(self,line)self.lines[#self.lines+1]=line end,
    Show=function(self)self.shown=true end, Hide=function(self)self.shown=false;self.owner=nil end}
local secret={}
local ns={db={flightVisits={a={[1]=true,[4]=true}}},settings={flightPoints=true,gatheringMap=false},IsPublic=function(v)return v~=secret end}
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TitanGatheredForeverV3',ns)
local source=loadfile('TitanGatheredForeverV3/FlightPaths.lua')
assert(source, 'Faction-aware flight points are not implemented')
source('TitanGatheredForeverV3',ns)
local function node(id,side,undiscovered,x,y)
    return {nodeID=id,faction=side,isUndiscovered=undiscovered,name='Flight '..id,atlasName='FlightPath',
        position={GetXY=function()return x or .4,y or .6 end}}
end
local canvas,world=frame(),frame();world:Show()
world.mapID=1
function world:GetCanvas()return canvas end
function world:GetMapID()return self.mapID end
function world:EnumeratePinsByTemplate(template)
    eq(template,'FlightPointPinTemplate');local i=0;return function()i=i+1;return native[i]end
end
local map
local function reset()
    ns.FlightPaths.tracker=nil
    character='a';taxiRows={};ns.db.flightVisits={a={[1]=true,[4]=true}}
    faction='Alliance';rows={[1]={node(1,2,false),node(2,2,true),node(3,1,true),node(4,0,false)}}
    native={};ns.settings.flightPoints=true;world.mapID=1;world:Show();canvas.width=1000;canvas.height=600;canvas.scale=1
    map=ns.FlightPaths.New(world)
end

test('Alliance sees all Alliance and neutral states including undiscovered',function()
    reset();local list=ns.FlightPaths.Read(1);eq(#list,3);eq(list[1].status,'discovered');eq(list[2].status,'undiscovered');eq(list[3].nodeID,4)
end)
test('Horde faction and unavailable faction do not expose Alliance',function()
    faction='Horde';local list=ns.FlightPaths.Read(1);eq(#list,2);eq(list[1].nodeID,3)
    faction=nil;list=ns.FlightPaths.Read(1);eq(#list,1);eq(list[1].nodeID,4)
    faction=secret;list=ns.FlightPaths.Read(1);eq(#list,1)
end)
test('missing malformed and restricted discovery flags remain unknown',function()
    ns.db.flightVisits={};faction='Alliance';rows[1]={node(1,2,nil),node(2,2,'false'),node(3,2,secret)}
    for _,n in ipairs(ns.FlightPaths.Read(1))do eq(n.status,'unknown')end
end)
test('malformed positions IDs and faction values are excluded',function()
    rows[1]={node(1,9,true),node(0,2,true),node(3,2,true,2,.3),node(4,2,true,0/0,.2),node(5,secret,true)}
    rows[1][6]=node(6,2,true);rows[1][6].position.GetXY=function()error('restricted')end
    eq(#ns.FlightPaths.Read(1),0)
end)
test('missing and failing API produce no invented locations',function()
    local api=C_TaxiMap;C_TaxiMap=nil;local list,status=ns.FlightPaths.Read(1);eq(#list,0);eq(status,'unsupported')
    C_TaxiMap={GetTaxiNodesForMap=function()error('not ready')end};list,status=ns.FlightPaths.Read(1);eq(#list,0);eq(status,'unavailable')
    C_TaxiMap=api
end)
test('independent overlay works with gathering disabled and no profession modules',function()
    reset();eq(map.visibleCount,3);eq(map.pins[1].x,400);eq(map.pins[1].y,-360);eq(map.pins[1].strata,'HIGH')
end)
test('borderless flight artwork retains tooltip discovery states',function()
    reset();local known,unknown=map.pins[1],map.pins[2]
    assert(not known.rim and not unknown.rim,'Flight markers still have an addon border')
    known.scripts.OnEnter(known);eq(GameTooltip.lines[3],'Discovered')
    unknown.scripts.OnEnter(unknown);eq(GameTooltip.lines[2],'Alliance flight point');eq(GameTooltip.lines[3],'Undiscovered')
    ns.db.flightVisits={};rows[1]={node(1,2,nil)};map:Refresh(true);map.pins[1].scripts.OnEnter(map.pins[1]);eq(GameTooltip.lines[3],'Discovery not confirmed')
end)
test('discovery updates and faction changes immediately refresh status and refilter',function()
    reset();rows[1][2].isUndiscovered=false;taxiRows={{nodeID=2,state=0}};map.events.scripts.OnEvent(map.events,'TAXIMAP_OPENED')
    eq(map.pins[2].node.status,'discovered');faction='Horde';map:Refresh();eq(map.visibleCount,2);eq(map.pins[1].node.nodeID,3)
end)
test('an open tooltip updates when its flight point becomes discovered',function()
    reset();local pin=map.pins[2];pin.scripts.OnEnter(pin);eq(GameTooltip.lines[3],'Undiscovered')
    rows[1][2].isUndiscovered=false;taxiRows={{nodeID=2,state=0}};map.events.scripts.OnEvent(map.events,'TAXIMAP_OPENED')
    eq(GameTooltip.lines[3],'Discovered')
end)
test('toggle removes own markers without changing gathering or data',function()
    reset();ns.settings.flightPoints=false;map:Refresh();eq(map.visibleCount,0);assert(not map.pins[1].shown);eq(#rows[1],4)
    ns.settings.flightPoints=true;map:Refresh();eq(map.visibleCount,3)
end)
test('zoom and same-sized replacement canvas preserve icon size and parent',function()
    reset();canvas.scale=.25;map:Refresh();eq(map.pins[1].width*canvas.scale,18)
    assert(not map.pins[1].rim,'Zoom restored an unwanted flight border')
    local previous=canvas;canvas=frame();canvas.scale=.25;map:Refresh();eq(map.overlay.parent,canvas)
    canvas=previous
end)
test('map switch empty data and map hiding remove stale pins and own tooltip',function()
    reset();map.pins[1].scripts.OnEnter(map.pins[1]);world.mapID=2;map:Refresh();eq(map.visibleCount,0);assert(not GameTooltip.shown)
    world.mapID=1;map:Refresh();eq(map.visibleCount,3);world:Hide();map:Refresh();eq(map.visibleCount,0)
end)
test('pin frames are pooled and successful data is cached between refreshes',function()
    reset();local count,calls=#frames,apiCalls;map:Refresh();map:Refresh();eq(#frames,count);eq(apiCalls,calls)
end)
test('native markers are decorated instead of duplicated and click handlers survive',function()
    reset();local pin=frame(world);pin:Show();pin.poiInfo={nodeID=1};local click=function()end;pin.scripts.OnClick=click
    native={pin};map:Refresh();eq(map.visibleCount,3);eq(map.customCount,2);assert(not pin.tgfFlightRim,'Native flight marker received an addon border');eq(pin.scripts.OnClick,click)
    GameTooltip:SetOwner(pin);pin.hooks.OnEnter(pin);eq(GameTooltip.lines[#GameTooltip.lines],'Flight point: Discovered')
    ns.settings.flightPoints=false;map:Refresh();assert(not pin.tgfFlightRim);eq(pin.tgfFlightStatus,nil);assert(pin.shown)
end)
test('recycled native pin loses decoration when it no longer matches a node',function()
    reset();local pin=frame(world);pin:Show();pin.poiInfo={nodeID=1};native={pin};map:Refresh()
    pin.poiInfo={nodeID=999};map:Refresh();assert(not pin.tgfFlightRim);eq(pin.tgfFlightStatus,nil);eq(map.customCount,3)
end)
test('world transitions suspend markers and retry unready API without a busy loop',function()
    reset();map.events.scripts.OnEvent(map.events,'PLAYER_LEAVING_WORLD');map:Refresh();eq(map.visibleCount,0)
    map.events.scripts.OnEvent(map.events,'PLAYER_ENTERING_WORLD');eq(map.visibleCount,3)
    local api=C_TaxiMap;C_TaxiMap={GetTaxiNodesForMap=function()apiCalls=apiCalls+1;return nil end}
    map:Refresh(true);eq(map.visibleCount,0);local calls=apiCalls;map:Refresh();eq(apiCalls,calls)
    C_TaxiMap=api;clock=clock+2.1;map:Refresh();eq(map.visibleCount,3)
end)
test('late world-map attachment needs neither gathering nor a profession addon',function()
    reset();WorldMapFrame=nil;ns.FlightPaths.instance=nil;ns.FlightPaths.Attach();eq(ns.FlightPaths.instance,nil)
    WorldMapFrame=world;ns.FlightPaths.Attach();assert(ns.FlightPaths.instance);local first=ns.FlightPaths.instance
    ns.FlightPaths.Attach();eq(ns.FlightPaths.instance,first)
end)
test('first attachment recovers when a zero-sized canvas finishes layout',function()
    reset();local previous=canvas;canvas=frame();canvas.width=0
    local waiting=ns.FlightPaths.New(world);eq(waiting.visibleCount,0)
    canvas.width=1000
    assert(canvas.hooks.OnSizeChanged,'Zero-sized initial canvas has no readiness hook')
    canvas.hooks.OnSizeChanged();eq(waiting.visibleCount,3);assert(waiting.pins[1].shown)
    canvas=previous
end)
test('hovered native tooltip cannot retain addon status after a change or removal',function()
    local stale={}
    for _,action in ipairs({'discovery','disable','recycle'})do
        reset();local pin=frame(world);pin:Show();pin.poiInfo={nodeID=2};native={pin};map:Refresh()
        GameTooltip:SetOwner(pin);GameTooltip:AddLine('Native flight name');pin.hooks.OnEnter(pin)
        eq(GameTooltip.lines[#GameTooltip.lines],'Flight point: Undiscovered')
        if action=='discovery'then rows[1][2].isUndiscovered=false;ns.db.flightVisits.a[2]=true
        elseif action=='disable'then ns.settings.flightPoints=false
        else pin.poiInfo={nodeID=999}end
        map:Refresh(true)
        if GameTooltip.shown then stale[#stale+1]=action end
    end
    assert(#stale==0,'Stale native tooltip remains visible after '..table.concat(stale,', '))
end)
test('flight appearance updates native and custom markers then restores native styling on disable',function()
    reset();local pin=frame(world);pin:SetSize(18,18);pin.Texture=pin:CreateTexture();pin.poiInfo={nodeID=1};pin:Show()
    native={pin};ns.settings.iconAppearance={flight={size=28,shape='circle',border=false}}
    map:Refresh(true)
    assert(math.abs(pin:GetWidth()*pin:GetEffectiveScale()-28)<.001);assert(pin.Texture.mask)
    eq(map.pins[1].width,28);assert(map.pins[1].texture.mask);eq(ns.PinStyle.Get('world').size,14)
    ns.settings.flightPoints=false;map:Refresh();eq(pin:GetScale(),1);eq(pin.Texture.mask,nil)
    ns.settings.iconAppearance=nil
end)
test('map-wide false discovery flags cannot invent confirmed visits',function()
 reset();ns.db.flightVisits={};map:Refresh(true)
 eq(map.pins[1].node.status,'unknown');eq(map.pins[2].node.status,'undiscovered')
 rows[1][2].isUndiscovered=false;map.events.scripts.OnEvent(map.events,'TAXI_NODE_STATUS_CHANGED')
 eq(map.pins[2].node.status,'unknown')
end)
test('only interacting with the current flight master confirms discovery per character',function()
 reset();ns.db.flightVisits={};world:Hide();ns.settings.flightPoints=false
 taxiRows={{nodeID=1,state=0},{nodeID=2,state=1},{nodeID=4,state=2}}
 map.events.scripts.OnEvent(map.events,'TAXI_NODE_STATUS_CHANGED');eq(ns.db.flightVisits.a,nil)
 map.events.scripts.OnEvent(map.events,'TAXIMAP_OPENED')
 assert(ns.db.flightVisits.a[1]);eq(ns.db.flightVisits.a[2],nil);eq(ns.db.flightVisits.a[4],nil)
 ns.settings.flightPoints=true;world:Show();map:Refresh(true);eq(map.pins[1].node.status,'discovered')
 character='b';map:Refresh(true);eq(map.pins[1].node.status,'unknown')
 character='a';map=ns.FlightPaths.New(world);eq(map.pins[1].node.status,'discovered')
end)
test('taxi close rejects later status notifications and unready or ambiguous current data',function()
 reset();ns.db.flightVisits={};taxiRows={};map.events.scripts.OnEvent(map.events,'TAXIMAP_OPENED')
 taxiRows={{nodeID=2,state=0}};map.events.scripts.OnEvent(map.events,'TAXI_NODE_STATUS_CHANGED')
 assert(ns.db.flightVisits.a[2]);map.events.scripts.OnEvent(map.events,'TAXIMAP_CLOSED')
 taxiRows={{nodeID=4,state=0}};map.events.scripts.OnEvent(map.events,'TAXI_NODE_STATUS_CHANGED')
 eq(ns.db.flightVisits.a[4],nil)
 ns.db.flightVisits={};taxiRows={{nodeID=1,state=0},{nodeID=2,state=0}}
 map.events.scripts.OnEvent(map.events,'TAXIMAP_OPENED');eq(ns.db.flightVisits.a,nil)
 taxiRows={{nodeID=secret,state=0},{nodeID=3,state=secret}}
 map.events.scripts.OnEvent(map.events,'TAXI_NODE_STATUS_CHANGED');eq(ns.db.flightVisits.a,nil)
end)
test('flight textures distinguish statuses and restore native tint on disable and reuse',function()
 reset();rows[1][4].isUndiscovered=nil;ns.db.flightVisits.a[4]=nil;map:Refresh(true)
 local known,unknown,unconfirmed=map.pins[1].texture.vertex,map.pins[2].texture.vertex,map.pins[3].texture.vertex
 assert(known[2]>known[1]);assert(unknown[1]>unknown[2]);eq(unconfirmed[1],unconfirmed[2])
 local pin=frame(world);pin.Texture=pin:CreateTexture();pin.Texture:SetVertexColor(.3,.4,.5,.6)
 pin.poiInfo={nodeID=1};pin:Show();native={pin};map:Refresh(true)
 assert(pin.Texture.vertex[2]>pin.Texture.vertex[1]);ns.settings.flightPoints=false;map:Refresh()
 eq(pin.Texture.vertex[1],.3);eq(pin.Texture.vertex[4],.6)
 ns.settings.flightPoints=true;map:Refresh();pin.poiInfo={nodeID=999};map:Refresh()
 eq(pin.Texture.vertex[2],.4)
end)
test('flight master visits are observed before the world map is ever loaded',function()
 reset();WorldMapFrame=nil;ns.FlightPaths.instance=nil;ns.FlightPaths.tracker=nil;ns.db.flightVisits={}
 ns.FlightPaths.Attach();eq(ns.FlightPaths.instance,nil)
 local tracker=ns.FlightPaths.tracker;assert(tracker and tracker.events)
 taxiRows={{nodeID=2,state=0}};tracker.events.scripts.OnEvent(tracker.events,'TAXIMAP_OPENED')
 assert(ns.db.flightVisits.a[2]);WorldMapFrame=world;ns.FlightPaths.Attach()
 eq(ns.FlightPaths.instance.pins[2].node.status,'discovered')
 eq(ns.FlightPaths.instance.events,tracker.events)
end)
test('native recoloring during pin reuse or removal survives addon cleanup',function()
 reset();local pin=frame(world);pin.Texture=pin:CreateTexture();pin.Texture:SetVertexColor(.3,.4,.5,.6)
 pin.poiInfo={nodeID=1};pin:Show();native={pin};map:Refresh(true)
 pin.Texture:SetVertexColor(.9,.8,.7,.6);pin.poiInfo={nodeID=2};map:Refresh(true)
 ns.settings.flightPoints=false;map:Refresh();eq(pin.Texture.vertex[1],.9)
 ns.settings.flightPoints=true;map:Refresh()
 pin.Texture:SetVertexColor(.2,.3,.4,.5);pin.poiInfo={nodeID=999};map:Refresh()
 eq(pin.Texture.vertex[1],.2);eq(pin.Texture.vertex[4],.5)
end)
local failures=0
for _,t in ipairs(tests)do
    local ok,err=pcall(t[2])
    if not ok then failures=failures+1;io.stderr:write('FAIL '..t[1]..': '..tostring(err)..'\n')end
end
assert(failures==0,tostring(failures)..' flight-point checks failed')
print('PASS '..#tests..' faction-aware flight-point checks')
