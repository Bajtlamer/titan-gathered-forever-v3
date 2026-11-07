local ns = {}
assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TitanGatheredForeverV3', ns)
local pin = { width = 14, height = 14, regions = {}, hooks = {} }
function pin:GetWidth() return self.width end
function pin:GetHeight() return self.height end
function pin:HookScript(event, fn) self.hooks[event] = fn end
local function region(kind, layer, level)
    local r = { kind = kind, layer = layer, level = level }
    function r:SetSize(w, h) self.width, self.height = w, h end
    function r:SetPoint(...) self.point = { ... } end
    function r:SetAllPoints(target) self.target = target end
    function r:SetTexture(path) self.path = path end
    function r:SetAtlas(atlas) self.atlas = atlas end
    function r:SetColorTexture(...) self.color = { ... } end
    function r:AddMaskTexture(mask) self.mask = mask end
    return r
end
function pin:CreateTexture(_, layer, _, level)
    local r = region('texture', layer, level); self.regions[#self.regions + 1] = r; return r
end
function pin:CreateMaskTexture() local r = region('mask'); self.regions[#self.regions + 1] = r; return r end
ns.PinStyle.Apply(pin)
assert(pin.texture.mask and pin.texture.mask.target == pin.texture, 'Resource image needs a circular mask')
assert(pin.texture.mask.atlas == 'CircleMaskScalable')
assert(pin.rim.mask and pin.rim.width > pin.width, 'Missing circular rim')
assert(#pin.shadows == 3, 'Soft shadow layers missing')
for _, shadow in ipairs(pin.shadows) do
    assert(shadow.mask and shadow.color[1] == 0 and shadow.color[4] < 0.5)
    assert(shadow.point[4] > 0 and shadow.point[5] < 0, 'Shadow must drop down and right')
end
local count = #pin.regions
ns.PinStyle.Apply(pin); assert(#pin.regions == count, 'Pooled pins recreated style regions')
pin.width, pin.height = 56, 56; pin.hooks.OnSizeChanged(pin)
assert(pin.rim.width == 56 * 1.16 and pin.shadows[1].width == 56 * 1.4, 'Decoration did not scale with icon')
local groups = {}
local node = { kind = 'Skinning', x = 0.4, y = 0.6 }
assert(ns.PinStyle.Offset(groups, node, 18) == 0)
assert(ns.PinStyle.Offset(groups, node, 18) == 18)
assert(ns.PinStyle.Offset(groups, node, 18) == -18)
assert(ns.PinStyle.Offset(groups, { kind = 'Mining', x = 0.4, y = 0.6 }, 18) == 36)
assert(ns.PinStyle.Label('Skinning') == 'TGF v3 Skinning area')
print('PASS 8 circular mask, rim, shadow, reuse, size and material-separation checks')
