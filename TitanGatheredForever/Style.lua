local _, ns = ...
local Style = { gold = 'ffffd100', red = 'ffff2020', orange = 'ffff8020', brown = 'ffb87333', gray = 'ff9d9d9d',
                white = 'ffffffff', yellow = 'ffffff00', cyan = 'ff53c9ff', green = 'ff20ff20', violet = 'ffb48cfa', note = 'ff8fbaaa' }
ns.Style = Style

function Style.Text(color, text)
    return '|c' .. color .. tostring(text) .. '|r'
end

-- Informational text is small and gold (the font of a note already is); the data in it is white, so that a label and
-- its value, or a sentence and its numbers, never run together. Label is for the words, Value for the data.
-- A date or time of day is green, so it stands out from both the labels and the other values.
function Style.Date(text) return Style.Text(Style.green, text) end
function Style.Label(text) return Style.Text(Style.gold, text) end
function Style.Value(text) return Style.Text(Style.white, text) end
-- 'Showing 1-18 of 40' with the numbers as values.
function Style.Range(first, last, total, what)
    return Style.Label('Showing ') .. Style.Value(first .. '-' .. last) .. Style.Label(' of ') .. Style.Value(total)
        .. (what and Style.Label(' ' .. what) or '')
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

-- Icons before the names in list rows: inline texture text with the icon border cropped, '' when the client has no
-- icon. Lists use ItemLabel (icon and name); sorting and search keep using the plain name.
Style.ICON_SIZE = 14
function Style.Icon(texture, size, whole)
    if texture == nil or (ns.IsPublic and not ns.IsPublic(texture)) then return '' end
    if type(texture) ~= 'number' and type(texture) ~= 'string' then return '' end
    if texture == '' or texture == 0 then return '' end
    size = size or Style.ICON_SIZE
    -- whole: a mark such as a quest sign is drawn as it is; an item icon loses its border.
    if whole then return string.format('|T%s:%d:%d:0:0|t ', tostring(texture), size, size) end
    return string.format('|T%s:%d:%d:0:0:64:64:5:59:5:59|t ', tostring(texture), size, size)
end

function Style.ItemIcon(itemID, size)
    if type(itemID) ~= 'number' or not C_Item or not C_Item.GetItemIconByID then return '' end
    local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
    return ok and Style.Icon(icon, size) or ''
end

function Style.SpellIcon(spellID, size)
    if type(spellID) ~= 'number' then return '' end
    local ok, icon = pcall(function()
        if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
        if C_Spell and C_Spell.GetSpellInfo then local info = C_Spell.GetSpellInfo(spellID); return info and info.iconID end
        if GetSpellTexture then return GetSpellTexture(spellID) end
    end)
    return ok and Style.Icon(icon, size) or ''
end

-- The icon of a profession (the kinds of the catalogue, the actions and the NPC sources), for profession columns
-- and the trainers, who have no icon of their own.
Style.PROFESSION_ICONS = {
    Alchemy = 'Interface\\Icons\\Trade_Alchemy', Blacksmithing = 'Interface\\Icons\\Trade_BlackSmithing',
    Cooking = 'Interface\\Icons\\INV_Misc_Food_15', Enchanting = 'Interface\\Icons\\Trade_Engraving',
    Engineering = 'Interface\\Icons\\Trade_Engineering', FirstAid = 'Interface\\Icons\\Spell_Holy_SealOfSacrifice',
    Fishing = 'Interface\\Icons\\Trade_Fishing', Herbs = 'Interface\\Icons\\Trade_Herbalism',
    Leatherworking = 'Interface\\Icons\\Trade_LeatherWorking', Mining = 'Interface\\Icons\\Trade_Mining',
    Skinning = 'Interface\\Icons\\INV_Misc_Pelt_Wolf_01', Tailoring = 'Interface\\Icons\\Trade_Tailoring',
    WeaponMaster = 'Interface\\Icons\\INV_Sword_27',
}
local professionAliases = { Herbalism = 'Herbs', ['First Aid'] = 'FirstAid', Disenchanting = 'Enchanting' }
function Style.ProfessionIcon(kind, size)
    local icon = Style.PROFESSION_ICONS[professionAliases[kind] or kind]
    return icon and Style.Icon(icon, size) or ''
end

function Style.ItemLabel(itemID)
    return Style.ItemIcon(itemID) .. Style.ItemName(itemID)
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
