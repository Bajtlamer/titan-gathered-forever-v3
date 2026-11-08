local _, ns = ...
local View = {}; ns.IconConfig = View
local names = { world = 'World map materials', minimap = 'Minimap materials', flight = 'Flight points' }
local function text(parent, x, y, width, font)
    local label = parent:CreateFontString(nil, 'OVERLAY', font or 'GameFontHighlightSmall')
    label:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    label:SetWidth(width); label:SetJustifyH('LEFT')
    return label
end
local function button(parent, label, x, y, width, callback)
    local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    b:SetSize(width, 24); b:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    b:SetText(label); b:SetScript('OnClick', callback)
    return b
end

function View.Refresh()
    local w = View.window
    if not w or not w:IsShown() or not w.draft then return end
    local style = w.draft[w.kind]
    w.target:SetText(names[w.kind]); w.size:SetText(style.size .. ' px')
    w.shape:SetText(style.shape == 'circle' and 'Shape: Circle' or 'Shape: Full image')
    w.border:SetText(style.border and 'Border: Thin gold' or 'Border: None')
    for index, pin in ipairs(w.previews) do
        if w.kind ~= 'flight' or index == 1 then
            pin:Show(); pin:SetSize(style.size, style.size)
            ns.PinStyle.Apply(pin, w.kind, style)
            pin:ClearAllPoints()
            local x = w.kind == 'flight' and 215 or 143 + (index - 1) * 72
            pin:SetPoint('CENTER', w, 'TOPLEFT', x, -219)
            if w.kind == 'flight' then pin.texture:SetAtlas('FlightPath')
            else pin.texture:SetTexture(ns.PinStyle.Icon(({ 2770, 765, 2318 })[index], 'Mining')) end
        else pin:Hide() end
    end
end

function View.Show(kind)
    local w = View.window
    if not w then
        local name = 'TitanGatheredForeverV3IconWindow'
        w = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset'); View.window = w
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        w:SetSize(430, 340); w:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        w:SetClampedToScreen(true); w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart', function(self) self:StartMoving() end)
        w:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
        w:SetScript('OnHide', function(self) self.draft = nil end)
        w.TitleText:SetText('TGF v3 Icon appearance')
        w.groups = {}
        for index, key in ipairs({ 'world', 'minimap', 'flight' }) do
            local group = key
            w.groups[group] = button(w, ({ 'World map', 'Minimap', 'Flights' })[index], 15 + (index - 1) * 135, -36, 126,
                function() w.kind = group; w.message:SetText(''); View.Refresh() end)
        end
        w.target = text(w, 15, -74, 390, 'GameFontNormal')
        w.less = button(w, '-', 15, -101, 36, function()
            w.draft[w.kind].size = math.max(12, w.draft[w.kind].size - 2); w.message:SetText(''); View.Refresh()
        end)
        w.size = text(w, 66, -107, 100, 'GameFontHighlight')
        w.more = button(w, '+', 150, -101, 36, function()
            w.draft[w.kind].size = math.min(40, w.draft[w.kind].size + 2); w.message:SetText(''); View.Refresh()
        end)
        w.shape = button(w, '', 15, -143, 195, function()
            local style = w.draft[w.kind]; style.shape = style.shape == 'circle' and 'square' or 'circle'
            w.message:SetText(''); View.Refresh()
        end)
        w.border = button(w, '', 220, -143, 195, function()
            local style = w.draft[w.kind]; style.border = not style.border; w.message:SetText(''); View.Refresh()
        end)
        text(w, 15, -181, 390):SetText('Preview')
        w.previews = {}
        for index = 1, 3 do w.previews[index] = CreateFrame('Frame', nil, w) end
        text(w, 15, -258, 400):SetText('Full image shows all artwork; Circle crops corners.\nApply saves your changes. Close or Cancel discards edits.')
        w.apply = button(w, 'Apply', 15, -301, 80, function()
            ns.PinStyle.Save(w.draft)
            ns.Map.Update(); ns.Minimap.Update(); ns.FlightPaths.Update()
            w.message:SetText('Applied')
        end)
        w.cancel = button(w, 'Cancel', 105, -301, 80, function() w:Hide() end)
        w.reset = button(w, 'Reset group', 195, -301, 110, function()
            w.draft[w.kind] = ns.PinStyle.Default(w.kind); w.message:SetText(''); View.Refresh()
        end)
        w.message = text(w, 320, -307, 90)
    end
    w.draft = ns.PinStyle.Config()
    w.kind = names[kind] and kind or 'world'
    w:Show(); w.message:SetText(''); View.Refresh()
end
