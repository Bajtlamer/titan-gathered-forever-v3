local _, ns = ...
local PinStyle = {}
ns.PinStyle = PinStyle
local labels = { Mining = 'TGF v3 Mining spot', Herbs = 'TGF v3 Herbalism spot', Skinning = 'TGF v3 Skinning area', Fishing = 'TGF v3 Fishing spot', Rare = 'TGF v3 Rare loot' }
local icons = { Mining = 'Interface\\Icons\\Trade_Mining', Herbs = 'Interface\\Icons\\Trade_Herbalism',
                Skinning = 'Interface\\Icons\\INV_Misc_Pelt_Wolf_01' }

function PinStyle.Label(kind) return labels[kind] or ('TGF v3 ' .. kind .. ' material source') end
function PinStyle.Icon(itemID, kind) return C_Item.GetItemIconByID(itemID) or icons[kind] or 'Interface\\Icons\\INV_Misc_Bag_10' end

function PinStyle.Offset(groups, node, spacing)
    local key = string.format('%.5f:%.5f', node.x, node.y)
    local index = groups[key] or 0
    groups[key] = index + 1
    if index == 0 then return 0 end
    return math.ceil(index / 2) * (index % 2 == 1 and spacing or -spacing)
end

function PinStyle.HistoryLines(node)
    local lines={}
    if not ns.history or not ns.Reports then return lines end
    for _,row in ipairs(ns.history:Rates((ns.characterID or UnitGUID('player')),node.itemID))do
        if row.mapID==node.mapID and (row.kind==node.kind or row.kind=='Loot') then
            lines[#lines+1]=string.format('%s: %.1f%% (%d / %d samples)',ns.Reports.Source(row),row.percent,row.hits,row.trials)
            if #lines==2 then break end
        end
    end
    return lines
end

local function circle(pin, texture)
    local mask = pin:CreateMaskTexture()
    mask:SetAtlas('CircleMaskScalable')
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
end

function PinStyle.Resize(pin)
    local width, height = pin:GetWidth(), pin:GetHeight()
    pin.rim:SetSize(width * 1.16, height * 1.16)
    for index, shadow in ipairs(pin.shadows) do
        local scale = 1.52 - index * 0.12
        shadow:SetSize(width * scale, height * scale)
        shadow:SetPoint('CENTER', pin, 'CENTER', width * 0.06, -height * 0.08)
    end
end

function PinStyle.Apply(pin)
    if pin.rim then return end
    pin.shadows = {}
    for index = 1, 3 do
        local shadow = pin:CreateTexture(nil, 'BACKGROUND', nil, index - 4)
        shadow:SetColorTexture(0, 0, 0, 0.08 + index * 0.07)
        circle(pin, shadow)
        pin.shadows[index] = shadow
    end
    pin.rim = pin:CreateTexture(nil, 'BACKGROUND', nil, 0)
    pin.rim:SetColorTexture(0.55, 0.43, 0.22, 1)
    pin.rim:SetPoint('CENTER', pin, 'CENTER')
    circle(pin, pin.rim)
    pin.texture = pin:CreateTexture(nil, 'ARTWORK')
    pin.texture:SetAllPoints(pin)
    circle(pin, pin.texture)
    pin:HookScript('OnSizeChanged', PinStyle.Resize)
    PinStyle.Resize(pin)
end
