local _, ns = ...
-- Text helpers that use the style of the core (gold labels, white values, green dates) when it is loaded, and plain
-- text otherwise, so a missing core never breaks a message.
local Text = {}
ns.Text = Text

local function core()
    local alias = _G.TitanGatheredForeverV3
    return alias and alias.Style
end

local function wrap(name)
    return function(text)
        local style = core()
        if style and style[name] then return style[name](text) end
        return tostring(text)
    end
end

Text.Label = wrap('Label')
Text.Value = wrap('Value')
Text.Date = wrap('Date')
