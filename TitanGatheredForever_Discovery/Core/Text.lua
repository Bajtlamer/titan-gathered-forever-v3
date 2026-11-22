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

local function core() return _G.TitanGatheredForeverV3 end

-- A color of the core style by its name (cyan, orange, gray, violet ...), plain text without the core.
function Text.Color(name, text)
    local alias = core()
    local style = alias and alias.Style
    if style and style.Text and style[name] then return style.Text(style[name], text) end
    return tostring(text)
end

-- 'Showing a-b of n' with the numbers as values.
function Text.Range(first, last, total)
    local alias = core()
    local style = alias and alias.Style
    if style and style.Range then return style.Range(first, last, total) end
    return string.format('Showing %s-%s of %s', first, last, total)
end

-- The name of an item as the core shows it, or a plain description.
function Text.Item(itemID)
    local alias = core()
    if alias and type(alias.ItemName) == 'function' then
        local ok, name = pcall(alias.ItemName, itemID)
        if ok and type(name) == 'string' then return name end
    end
    return 'item ' .. tostring(itemID)
end

-- A price in the game money format of the core (gold, silver and copper icons), plain copper without the core.
function Text.Coin(copper)
    local alias = core()
    if alias and alias.Economy and type(alias.Economy.Coin) == 'function' then
        local ok, value = pcall(alias.Economy.Coin, copper)
        if ok and type(value) == 'string' then return value end
    end
    return tostring(copper) .. ' copper'
end
