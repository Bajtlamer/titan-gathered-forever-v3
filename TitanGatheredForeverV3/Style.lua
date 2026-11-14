local _, ns = ...
local Style = { gold = 'ffffd100', red = 'ffff2020', orange = 'ffff8020', brown = 'ffb87333', gray = 'ff9d9d9d',
                white = 'ffffffff', yellow = 'ffffff00', cyan = 'ff53c9ff', green = 'ff20ff20', violet = 'ffb48cfa', note = 'ff8fbaaa' }
ns.Style = Style

function Style.Text(color, text)
    return '|c' .. color .. tostring(text) .. '|r'
end

-- Resize only addon-owned supporting text, preserving native tooltip fonts. The original font is restored
-- when the tooltip is recycled.
local function shrink(tooltip, line)
    if not line or not line.SetFontObject then return end
    if not tooltip.tgfNoteFonts then
        tooltip.tgfNoteFonts = {}
        tooltip:HookScript('OnTooltipCleared', function(self)
            for region, font in pairs(self.tgfNoteFonts) do region:SetFontObject(font) end
            self.tgfNoteFonts = {}
        end)
    end
    if not tooltip.tgfNoteFonts[line] then
        tooltip.tgfNoteFonts[line] = line.GetFontObject and line:GetFontObject() or 'GameTooltipText'
    end
    line:SetFontObject('GameFontHighlightSmall')
end

function Style.Note(tooltip, value)
    tooltip:AddLine(value, 1, 1, 1, true)
    local name = tooltip.GetName and tooltip:GetName()
    shrink(tooltip, name and _G[name .. 'TextLeft' .. tooltip:NumLines()])
end

-- Shrink the line that was just added, in both columns of a two-column line.
function Style.Small(tooltip)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return end
    local index = tooltip:NumLines()
    shrink(tooltip, _G[name .. 'TextLeft' .. index])
    shrink(tooltip, _G[name .. 'TextRight' .. index])
end

function Style.MenuNote(parent, value)
    local description = parent:CreateTitle(value)
    if description and description.AddInitializer then
        description:AddInitializer(function(button)
            if button.fontString then button.fontString:SetFontObject('GameFontHighlightSmall') end
        end)
    end
    return description
end

function Style.ItemName(itemID)
    local _, _, quality = C_Item.GetItemInfo(itemID)
    local color = ns.IsPublic(quality) and ITEM_QUALITY_COLORS[quality]
    local hex = color and color.hex
    if type(hex) == 'string' then hex = hex:gsub('^|c', '') end
    if type(hex) ~= 'string' or not hex:match('^%x%x%x%x%x%x%x%x$') then hex = Style.white end
    return Style.Text(hex, ns.ItemName(itemID))
end

function Style.Separator(tooltip)
    tooltip:AddLine(' ')
    local name = tooltip:GetName()
    local line = name and _G[name .. 'TextLeft' .. tooltip:NumLines()]
    if not line then return end
    if not tooltip.tgForeverRules then
        tooltip.tgForeverRules, tooltip.tgForeverRuleCount = {}, 0
        tooltip:HookScript('OnSizeChanged', function(self)
            for _, rule in ipairs(self.tgForeverRules) do rule:SetWidth(math.max(1, self:GetWidth() - 20)) end
        end)
        tooltip:HookScript('OnTooltipCleared', function(self)
            for _, rule in ipairs(self.tgForeverRules) do rule:Hide() end
            self.tgForeverRuleCount = 0
        end)
    end
    local index = tooltip.tgForeverRuleCount + 1
    tooltip.tgForeverRuleCount = index
    local rule = tooltip.tgForeverRules[index]
    if not rule then
        rule = tooltip:CreateTexture(nil, 'ARTWORK')
        rule:SetColorTexture(0.62, 0.62, 0.62, 0.65)
        rule:SetHeight(1)
        tooltip.tgForeverRules[index] = rule
    end
    rule:ClearAllPoints()
    rule:SetPoint('TOPLEFT', line, 'TOPLEFT', 0, -6)
    rule:SetWidth(math.max(1, tooltip:GetWidth() - 20))
    rule:Show()
end

function Style.Section(tooltip, title)
    Style.Separator(tooltip)
    tooltip:AddLine(Style.Text(Style.gold, title))
end

function Style.SkillColor(rank, maximum)
    local ratio = maximum > 0 and rank / maximum or 0
    local color = ratio >= 0.75 and Style.green
        or (ratio >= 0.5 and Style.yellow or (ratio >= 0.25 and Style.brown or Style.red))
    return color
end

function Style.Skill(rank, maximum)
    return Style.Text(Style.SkillColor(rank, maximum), rank .. '/' .. maximum)
end

function Style.Count(value, field)
    value = value or 0
    local color = value == 0 and Style.gray
        or (field == 'total' and Style.green or (field == 'bank' and Style.violet or Style.cyan))
    return Style.Text(color, value)
end
