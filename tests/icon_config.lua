local passed=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed=passed+1 end
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function region()
 local t={}
 for _,method in ipairs({'SetPoint','SetWidth','SetJustifyH','SetAllPoints','SetAtlas','SetSize','SetTexture','SetVertexColor'})do
  t[method]=function(self,...)self[method..'Args']={...}end
 end
 function t:SetText(text)self.text=text end
 function t:AddMaskTexture(mask)self.mask=mask end
 function t:RemoveMaskTexture()self.mask=nil end
 function t:Show()self.shown=true end
 function t:Hide()self.shown=false end
 return t
end
local frames={}
local function frame()
 local f={scripts={},TitleText=region(),shown=false,width=18,height=18}
 for _,method in ipairs({'SetPoint','ClearAllPoints','SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing'})do f[method]=function()end end
 function f:SetSize(w,h)self.width,self.height=w,h end
 function f:GetWidth()return self.width end
 function f:GetHeight()return self.height end
 function f:SetScript(event,fn)self.scripts[event]=fn end
 function f:SetText(text)self.text=text end
 function f:CreateTexture()return region()end
 function f:CreateMaskTexture()return region()end
 function f:CreateFontString()return region()end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self)end end
 function f:IsShown()return self.shown end
 frames[#frames+1]=f;return f
end
CreateFrame=frame;UIParent=frame();UISpecialFrames={}
C_Item={GetItemIconByID=function(id)return id end}
local refreshes={world=0,minimap=0,flight=0}
local ns={settings={},Map={Update=function()refreshes.world=refreshes.world+1 end},
 Minimap={Update=function()refreshes.minimap=refreshes.minimap+1 end},FlightPaths={Update=function()refreshes.flight=refreshes.flight+1 end}}
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TGF',ns)
local load=loadfile('TitanGatheredForeverV3/IconConfig.lua');assert(load,'Icon appearance window is not implemented');load('TGF',ns)
local function click(button)button.scripts.OnClick(button)end

test('opening window previews current settings without changing maps or saved values',function()
 ns.IconConfig.Show();local w=ns.IconConfig.window;assert(w:IsShown());eq(w.kind,'world');eq(w.draft.world.size,14)
 eq(ns.settings.iconAppearance,nil);eq(refreshes.world,0);eq(#UISpecialFrames,1)
 click(w.more);eq(w.draft.world.size,16);eq(w.previews[1]:GetWidth(),16);eq(ns.settings.iconAppearance,nil)
end)
test('shape and border preview changes stay draft until Apply',function()
 local w=ns.IconConfig.window;click(w.shape);eq(w.draft.world.shape,'square');eq(w.previews[1].texture.mask,nil)
 click(w.border);eq(w.draft.world.border,true);assert(w.previews[1].tgfAppearance.outline.shown)
 click(w.apply);eq(ns.settings.iconAppearance.world.size,16);eq(ns.settings.iconAppearance.world.shape,'square')
 eq(refreshes.world,1);eq(refreshes.minimap,1);eq(refreshes.flight,1)
end)
test('group selection has independent settings and Reset changes only draft target',function()
 local w=ns.IconConfig.window;click(w.groups.minimap);eq(w.kind,'minimap');eq(w.draft.minimap.size,14)
 click(w.more);click(w.more);eq(w.draft.minimap.size,18);eq(w.draft.world.size,16)
 click(w.reset);eq(w.draft.minimap.size,14);eq(ns.settings.iconAppearance.world.size,16)
end)
test('cancel close and reopen discard unapplied changes and reuse window frames',function()
 local w=ns.IconConfig.window;click(w.groups.world);click(w.more);eq(w.draft.world.size,18)
 click(w.cancel);eq(ns.settings.iconAppearance.world.size,16);eq(w.draft,nil)
 local count=#frames;ns.IconConfig.Show('flight');eq(ns.IconConfig.window,w);eq(#frames,count);eq(#UISpecialFrames,1)
 eq(w.kind,'flight');eq(w.draft.world.size,16);eq(w.draft.flight.shape,'square')
 w:Hide();eq(w.draft,nil)
end)
test('size controls clamp and flight previews retain full artwork by default',function()
 ns.IconConfig.Show('flight');local w=ns.IconConfig.window
 for i=1,30 do click(w.more)end;eq(w.draft.flight.size,40)
 for i=1,30 do click(w.less)end;eq(w.draft.flight.size,12)
 eq(w.previews[1].texture.mask,nil);eq(w.previews[2]:IsShown(),false)
end)
print('PASS '..passed..' icon appearance window checks')
