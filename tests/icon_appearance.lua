local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed=passed+1 end
local ns={settings={}}
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TGF',ns)
assert(ns.PinStyle.Get,'Icon appearance settings are not implemented')
local function frame()
 local f={width=18,height=18,scale=1,regions={},shown=true}
 function f:GetWidth()return self.width end
 function f:GetHeight()return self.height end
 function f:GetScale()return self.scale end
 function f:GetEffectiveScale()return self.scale*.5 end
 function f:SetScale(v)self.scale=v end
 function f:CreateTexture()
  local t={}
  function t:SetAllPoints(target)self.target=target end
  function t:SetPoint()end
  function t:SetSize(w,h)self.width,self.height=w,h end
  function t:SetTexture(path)self.path=path end
  function t:SetVertexColor(...)self.color={...}end
  function t:AddMaskTexture(mask)self.mask=mask end
  function t:RemoveMaskTexture(mask)assert(self.mask==mask);self.mask=nil end
  function t:Show()self.shown=true end
  function t:Hide()self.shown=false end
  self.regions[#self.regions+1]=t;return t
 end
 function f:CreateMaskTexture()
  local m={}
  function m:SetAtlas(atlas)self.atlas=atlas end
  function m:SetAllPoints(target)self.target=target end
  self.regions[#self.regions+1]=m;return m
 end
 return f
end
test('defaults preserve existing material circles and full-image flight artwork',function()
 eq(ns.PinStyle.Get('world').size,14);eq(ns.PinStyle.Get('minimap').shape,'circle');eq(ns.PinStyle.Get('flight').size,18)
 eq(ns.PinStyle.Get('flight').shape,'square');eq(ns.PinStyle.Get('world').border,false);eq(ns.settings.iconAppearance,nil)
end)
test('corrupt and nonfinite saved settings cannot reach icon geometry',function()
 ns.settings.iconAppearance={world={size=0/0,shape='bad',border='yes'},minimap={size=1000},flight={size=-10}}
 eq(ns.PinStyle.Get('world').size,14);eq(ns.PinStyle.Get('world').shape,'circle');eq(ns.PinStyle.Get('world').border,false)
 eq(ns.PinStyle.Get('minimap').size,40);eq(ns.PinStyle.Get('flight').size,12)
 ns.settings.iconAppearance.world.size=math.huge;eq(ns.PinStyle.Get('world').size,14)
end)
test('settings are independent copies and Apply saves only supported fields',function()
 ns.settings.iconAppearance=nil;local draft=ns.PinStyle.Config();draft.world.size=28;draft.world.extra='no'
 eq(ns.PinStyle.Get('world').size,14);ns.PinStyle.Save(draft)
 eq(ns.PinStyle.Get('world').size,28);eq(ns.PinStyle.Get('minimap').size,14);eq(ns.settings.iconAppearance.world.extra,nil)
 draft.world.size=40;eq(ns.PinStyle.Get('world').size,28)
end)
test('pooled image switches circle and full image without accumulating masks or moving',function()
 local p=frame();p.x,p.y=100,-200
 ns.PinStyle.Apply(p,'world',{size=20,shape='circle',border=false});assert(p.texture.mask)
 local count=#p.regions
 ns.PinStyle.Apply(p,'world',{size=20,shape='square',border=false});eq(p.texture.mask,nil)
 ns.PinStyle.Apply(p,'world',{size=20,shape='circle',border=false});eq(#p.regions,count);eq(p.x,100);eq(p.y,-200)
end)
test('optional outline is an alpha texture and clears when border is disabled',function()
 local p=frame();ns.PinStyle.Apply(p,'world',{shape='circle',size=18,border=true})
 local outline=p.tgfAppearance.outline;assert(outline.shown);assert(outline.path:find('PinOutlineCircle.tga',1,true))
 ns.PinStyle.Apply(p,'world',{shape='square',size=18,border=true});assert(outline.path:find('PinOutlineSquare.tga',1,true))
 ns.PinStyle.Apply(p,'world',{shape='square',size=18,border=false});eq(outline.shown,false)
end)
test('native flight customization scales artwork and restores original scale and mask',function()
 local p=frame();p.Texture=p:CreateTexture();p.originalClick=function()end;p.OnClick=p.originalClick
 ns.PinStyle.Native(p,{size=30,shape='circle',border=true},1)
 eq(p:GetWidth()*p:GetEffectiveScale(),30);assert(p.Texture.mask);eq(p.OnClick,p.originalClick)
 ns.PinStyle.RestoreNative(p);eq(p:GetScale(),1);eq(p.Texture.mask,nil);eq(p.tgfAppearance.outline.shown,false)
end)
test('native scale updates from Blizzard are retained when reverting styling',function()
 local p=frame();p.Texture=p:CreateTexture()
 ns.PinStyle.Native(p,{size=24,shape='square',border=false},1)
 p:SetScale(2);ns.PinStyle.Native(p,{size=24,shape='square',border=false},1)
 ns.PinStyle.RestoreNative(p);eq(p:GetScale(),2)
end)
test('native marker without texture or scale capabilities is left unchanged',function()
 local p={GetWidth=function()return 20 end};eq(ns.PinStyle.Native(p,{size=24,shape='square',border=false},1),false)
end)
print('PASS '..passed..' icon appearance model and renderer checks')
