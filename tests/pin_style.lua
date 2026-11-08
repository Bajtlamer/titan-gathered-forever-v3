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
assert(ns.PinStyle.Label('Skinning')=='TGF v3 Skinning area')
assert(ns.PinStyle.Label('PvP')=='TGF v3 PvP kill spot')
assert(ns.PinStyle.Icon(nil,'PvP')=='Interface\\Icons\\INV_Sword_04')
print('PASS 9 image alpha, transparent border and pooled pin checks')
