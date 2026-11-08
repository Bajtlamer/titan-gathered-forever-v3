local _, ns = ...
local PinStyle = {}
ns.PinStyle = PinStyle
local labels = { Mining = 'TGF v3 Mining spot', Herbs = 'TGF v3 Herbalism spot', Skinning = 'TGF v3 Skinning area', Fishing = 'TGF v3 Fishing spot', Rare = 'TGF v3 Rare loot' }
local icons = { Mining = 'Interface\\Icons\\Trade_Mining', Herbs = 'Interface\\Icons\\Trade_Herbalism',
                Skinning = 'Interface\\Icons\\INV_Misc_Pelt_Wolf_01' }

function PinStyle.Label(kind) return labels[kind] or ('TGF v3 ' .. kind .. ' material source') end
function PinStyle.Icon(itemID, kind) return C_Item.GetItemIconByID(itemID) or icons[kind] or 'Interface\\Icons\\INV_Misc_Bag_10' end

function PinStyle.HistoryLines(node)
    local lines={}
    if not ns.history or not ns.Reports then return lines end
    for _,row in ipairs(ns.history:Rates((ns.characterID or UnitGUID('player')),node.itemID))do
        if row.mapID==node.mapID and (row.kind==node.kind or row.kind=='Loot') then
            lines[#lines+1]=string.format('%s: %.1f%% (%d / %d samples)',ns.Reports.Source(row),row.percent,row.hits,row.trials)
            if #lines==2 then break end
        end
    end
    if #lines>0 then lines[#lines+1]='Source/zone observations, not a chance at this coordinate.'end
    return lines
end

local defaults = {
    world = { size = 14, shape = 'circle', border = false },
    minimap = { size = 14, shape = 'circle', border = false },
    flight = { size = 18, shape = 'square', border = false },
}
local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

function PinStyle.Get(kind, source)
    local fallback = defaults[kind] or defaults.world
    local config = source
    if config == nil then
        local all = ns.settings and ns.settings.iconAppearance
        config = type(all) == 'table' and all[kind]
    end
    if type(config) ~= 'table' then config = {} end
    local size = finite(config.size) and config.size or fallback.size
    size = math.max(12, math.min(40, math.floor(size / 2 + 0.5) * 2))
    return { size = size, shape = (config.shape == 'circle' or config.shape == 'square') and config.shape or fallback.shape,
        border = config.border == true }
end

function PinStyle.Config(source)
    local result = {}
    for kind in pairs(defaults) do result[kind] = PinStyle.Get(kind, source and source[kind]) end
    return result
end

function PinStyle.Default(kind) return PinStyle.Get(kind, {}) end

function PinStyle.Save(config)
    local result = {}
    for kind in pairs(defaults) do result[kind] = PinStyle.Get(kind, type(config) == 'table' and config[kind] or {}) end
    ns.settings.iconAppearance = result
end

function PinStyle.Clear(pin)
    local state = pin.tgfAppearance
    if not state then return end
    if state.masked then state.texture:RemoveMaskTexture(state.mask); state.masked = false end
    if state.outline then state.outline:Hide() end
end

function PinStyle.Texture(pin, texture, style)
    local state = pin.tgfAppearance
    if not state then state = {}; pin.tgfAppearance = state end
    if state.texture ~= texture then PinStyle.Clear(pin); state.texture = texture end
    if style.shape == 'circle' then
        if not state.mask then
            state.mask = pin:CreateMaskTexture()
            state.mask:SetAtlas('CircleMaskScalable')
        end
        state.mask:SetAllPoints(texture)
        if not state.masked then texture:AddMaskTexture(state.mask); state.masked = true end
    elseif state.masked then texture:RemoveMaskTexture(state.mask); state.masked = false end
    if style.border then
        if not state.outline then
            state.outline = pin:CreateTexture(nil, 'OVERLAY')
            state.outline:SetPoint('CENTER', pin, 'CENTER')
        end
        local shape = style.shape == 'circle' and 'Circle' or 'Square'
        state.outline:SetTexture('Interface\\AddOns\\TitanGatheredForeverV3\\Artwork\\PinOutline' .. shape .. '.tga')
        state.outline:SetVertexColor(1, 0.82, 0, 1)
        state.outline:SetSize(pin:GetWidth() * 1.1, pin:GetHeight() * 1.1)
        state.outline:Show()
    elseif state.outline then state.outline:Hide() end
end

function PinStyle.Apply(pin, kind, override)
    -- Preserve callers of the earlier gathering/native-shape helper.
    if kind == true then kind = 'flight' elseif not kind then kind = 'world' end
    if not pin.texture then
        pin.texture = pin:CreateTexture(nil, 'ARTWORK')
        pin.texture:SetAllPoints(pin)
    end
    PinStyle.Texture(pin, pin.texture, PinStyle.Get(kind, override))
end

function PinStyle.RestoreNative(pin)
    PinStyle.Clear(pin)
    if pin.tgfFlightOriginalScale then
        if pin:GetScale() == pin.tgfFlightAppliedScale then pin:SetScale(pin.tgfFlightOriginalScale) end
        pin.tgfFlightOriginalScale, pin.tgfFlightAppliedScale = nil, nil
    end
end

function PinStyle.Native(pin, style, worldScale)
    if not pin.Texture or not pin.GetScale or not pin.SetScale or not pin.GetEffectiveScale then return false end
    local width, scale, effective = pin:GetWidth(), pin:GetScale(), pin:GetEffectiveScale()
    if not finite(width) or not finite(scale) or not finite(effective) or not finite(worldScale)
        or width <= 0 or scale <= 0 or effective <= 0 or worldScale <= 0 then return false end
    local nextScale = scale * style.size * worldScale / (width * effective)
    if not finite(nextScale) or nextScale <= 0 or nextScale > 10000 then return false end
    if not pin.tgfFlightAppliedScale or scale ~= pin.tgfFlightAppliedScale then pin.tgfFlightOriginalScale = scale end
    pin:SetScale(nextScale); pin.tgfFlightAppliedScale = pin:GetScale()
    PinStyle.Texture(pin, pin.Texture, style)
    return true
end
