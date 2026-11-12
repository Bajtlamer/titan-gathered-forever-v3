local ns = {}
 C_Item={GetItemIconByID=function(id)return id and id+1000 end}
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TitanGatheredForeverV3', ns)
local function pin()
    local p = { width = 14, height = 14, regions = {}, hooks = {} }
    function p:GetWidth() return self.width end
    function p:GetHeight() return self.height end
    function p:HookScript(event, fn) self.hooks[event] = fn end
    function p:CreateTexture(_,layer)
        local r={layer=layer}
        function r:SetAllPoints(target)self.target=target end
        function r:SetSize(w,h)self.width,self.height=w,h end
        function r:SetPoint(...)self.point={...}end
        function r:SetTexture(path)self.path=path end
        function r:SetColorTexture(...)self.fill={...}end
        function r:AddMaskTexture(mask)self.mask=mask end
        self.regions[#self.regions+1]=r;return r
    end
    function p:CreateMaskTexture()
        local r={}
        function r:SetAtlas(atlas)self.atlas=atlas end
        function r:SetAllPoints(target)self.target=target end
        self.regions[#self.regions+1]=r;return r
    end
    return p
end
local borderFrames={}
CreateFrame=function(kind,name,parent,template)
    local b={parent=parent,template=template}
    function b:SetBackdrop(info)self.backdrop=info end
    function b:SetBackdropBorderColor(...)self.color={...}end
    function b:SetSize(w,h)self.width,self.height=w,h end
    function b:SetPoint(...)self.point={...}end
    borderFrames[#borderFrames+1]=b;return b
end
local p=pin();ns.PinStyle.Apply(p)
assert(not p.rim and not p.shadows,'Gathering icons still have filled backplates or shadows')
assert(#p.regions==2 and p.texture and not p.texture.fill,'A gathering marker should contain only its image and crop mask')
assert(p.texture.mask and p.texture.mask.atlas=='CircleMaskScalable' and p.texture.mask.target==p.texture,'Gathering artwork must be cropped to a circle with transparent corners')
assert(p.texture.target==p,'Image must remain the size of its marker')
p.texture:SetTexture('transparent-artwork.tga')
local count=#p.regions;ns.PinStyle.Apply(p)
assert(#p.regions==count and p.texture.path=='transparent-artwork.tga','Reusing a pin changed its artwork or recreated decoration')
local flight=pin();ns.PinStyle.Apply(flight,true)
assert(not flight.rim and not flight.shadows,'Flight artwork must not receive an addon border or background')
assert(not flight.texture.mask,'Native flight artwork must retain its original shape')
local allocated=#borderFrames;ns.PinStyle.Apply(flight,true)
assert(#borderFrames==allocated and #borderFrames==0,'Borderless flight pin allocated a decoration frame')
-- Highlight: two concentric gold rings that pulse, and a raised frame level, removed again when switched off.
local function ringPin()
    local p=pin();p.scripts={};p.level=3
    function p:GetParent()return {GetFrameLevel=function()return 10 end}end
    function p:SetFrameLevel(level)self.level=level end
    function p:SetScript(event,fn)self.scripts[event]=fn end
    local create=p.CreateTexture
    function p:CreateTexture(...)
        local r=create(self,...)
        function r:SetVertexColor(...)self.color={...}end
        function r:SetAlpha(alpha)self.alpha=alpha end
        function r:Show()self.shown=true end
        function r:Hide()self.shown=false end
        return r
    end
    return p
end
local clock=0;GetTime=function()return clock end
local plain=ringPin();ns.PinStyle.Highlight(plain,false)
assert(#plain.regions==0 and not plain.tgfRingOn,'Switching off an ordinary pin must not allocate anything')
local h=ringPin();ns.PinStyle.Highlight(h,true)
assert(h.tgfRingOn==true and #h.tgfRings==2,'A highlighted pin gets two rings')
for _,ring in ipairs(h.tgfRings)do
    assert(ring.path:find('PinOutlineCircle',1,true),'Rings reuse the circle outline artwork')
    assert(ring.color[1]==1 and ring.color[2]==0.82 and ring.color[3]==0,'Rings are gold')
    assert(ring.shown==true and ring.width>=34,'Rings are visible and larger than an ordinary pin')
end
assert(h.tgfRings[2].width>h.tgfRings[1].width,'The second ring is the outer one')
assert(h.level==60,'A highlighted pin is raised above its neighbours')
clock=1.0;h.scripts.OnUpdate(h)
for _,ring in ipairs(h.tgfRings)do assert(ring.alpha>=0.3 and ring.alpha<=1,'The pulse stays visible') end
local regions=#h.regions;ns.PinStyle.Highlight(h,true)
assert(#h.regions==regions,'Highlighting again must reuse the rings')
ns.PinStyle.Highlight(h,false)
for _,ring in ipairs(h.tgfRings)do assert(ring.shown==false,'Rings are hidden when the highlight ends') end
assert(h.level==11 and h.scripts.OnUpdate==nil and not h.tgfRingOn,'The pin returns to its normal level without a pulse')
assert(ns.PinStyle.Label('Skinning')=='TGF v3 Skinning area')
assert(ns.PinStyle.Label('PvP')=='TGF v3 PvP kill spot')
assert(ns.PinStyle.Icon(nil,'PvP')=='Interface\\Icons\\INV_Sword_04')
print('PASS 9 image alpha, transparent border and pooled pin checks')

-- Ore pins must expose byproducts from the same source, without mixing veins,
-- characters, zones or instance contexts, or counting partial loot as trials.
ns.characterID='miner'
ns.Style={ItemName=function(id)return 'Item '..id end}
ns.Reports={Source=function(row)return 'Vein '..row.source end}
assert(loadfile('TitanGatheredForeverV3/History.lua'))('TitanGatheredForeverV3',ns)
ns.history=ns.History.New({})
local function observe(id,items,source,map,complete,character,context)
    ns.history:Observe(character or 'miner','Miner',{id=id,kind='Mining',source=source or 'copper',
        mapID=map or 1,instanceType=context or 'none',items=items,complete=complete~=false,at=100})
end
observe('one',{[2770]=2,[2835]=1,[774]=1})
observe('two',{[2770]=3,[2835]=2})
observe('partial',{[2770]=1,[774]=10},nil,nil,false)
observe('tin',{[2771]=1,[1206]=1},'tin')
observe('elsewhere',{[2770]=1,[818]=1},nil,2)
observe('alt',{[2770]=1,[818]=1},nil,nil,true,'alt')
observe('instance',{[2770]=1,[818]=1},nil,nil,true,nil,'party')
local lines=table.concat(ns.PinStyle.HistoryLines({kind='Mining',itemID=2770,mapID=1,count=3}),'\n')
assert(lines:find('Complete mining loot samples: 2',1,true),'Missing complete mining sample count')
assert(lines:find('Item 774: 50.0% (1 / 2 samples); 1 items',1,true),'Gem drops or partial-loot exclusion missing')
assert(lines:find('Item 2835: 100.0% (2 / 2 samples); 3 items',1,true),'Stone drops missing')
assert(lines:find('Item 2770: 100.0% (2 / 2 samples); 5 items',1,true),'Ore quantities missing')
assert(not lines:find('1206',1,true) and not lines:find('818',1,true),'Unrelated source evidence leaked into ore pin')
local unknown=table.concat(ns.PinStyle.HistoryLines({kind='Mining',itemID=999,mapID=1,count=1}),'\n')
assert(unknown:find('Unknown',1,true),'Unobserved drop rates need explicit unknown evidence')
print('PASS mining pin drop lists, complete counts, partial exclusion and source isolation')
