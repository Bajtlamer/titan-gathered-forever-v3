local ns = { IsPublic = function() return true end, ItemName = function(id) return 'Item ' .. id end }
ITEM_QUALITY_COLORS = { [0] = { hex = 'ff9d9d9d' }, [2] = { hex = 'ff1eff00' },
                        [3] = { hex = 'ff0070dd' }, [4] = { hex = 'ffa335ee' } }
C_Item = { GetItemInfo = function(id) return 'Item ' .. id, nil, id end }
assert(loadfile('TitanGatheredForeverV3/Style.lua'))('TitanGatheredForeverV3', ns)
assert(ns.Style.ItemName(0) == '|cff9d9d9dItem 0|r', 'Poor-quality gray was lost')
assert(ns.Style.ItemName(2) == '|cff1eff00Item 2|r', 'Uncommon rarity color missing')
assert(ns.Style.ItemName(3) == '|cff0070ddItem 3|r', 'Rare rarity color missing')
assert(ns.Style.ItemName(4) == '|cffa335eeItem 4|r', 'Epic rarity color missing')
assert(ns.Style.ItemName(99) == '|cffffffffItem 99|r', 'Uncached quality needs a safe default')
local lines = {}
local tip = { width = 240, hooks = {}, textures = {} }
function tip:AddLine(text) lines[#lines + 1] = text; _G.TestTipTextLeft[#lines] = {} end
function tip:GetName() return 'TestTip' end
function tip:NumLines() return #lines end
function tip:GetWidth() return self.width end
function tip:HookScript(event, fn) self.hooks[event] = fn end
function tip:CreateTexture()
    local texture = {}
    function texture:SetColorTexture() end
    function texture:SetHeight(height) self.height = height end
    function texture:SetWidth(width) self.width = width end
    function texture:SetPoint(...) self.point = { ... } end
    function texture:ClearAllPoints() end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    self.textures[#self.textures + 1] = texture
    return texture
end
_G.TestTipTextLeft = {}
-- Mirror the named font strings exposed by GameTooltipTemplate.
local addLine = tip.AddLine
function tip:AddLine(text) addLine(self, text); _G['TestTipTextLeft' .. #lines] = _G.TestTipTextLeft[#lines] end
ns.Style.Section(tip, 'Mining')
assert(lines[2]:find('|cffff8020', 1, true))
assert(#tip.textures == 1 and tip.textures[1].width == 220, 'Rule must fill the inner tooltip width')
tip.width = 420; tip.hooks.OnSizeChanged(tip)
assert(tip.textures[1].width == 400, 'Rule did not resize with the tooltip')
tip.hooks.OnTooltipCleared(tip)
assert(not tip.textures[1].shown, 'Cleared tooltip retained a stale rule')

local learned = {
    [186] = { skillID = 186, name = 'Localized Mining', rank = 75, maxRank = 150 },
    [185] = { skillID = 185, name = 'Localized Cooking', rank = 1, maxRank = 75 },
    [164] = { skillID = 164, name = 'Unlearned Smithing', rank = 0, maxRank = 0 },
}
C_SkillInfo = { GetSkillLineInfoByID = function(id) return learned[id] end }
assert(loadfile('TitanGatheredForeverV3/Professions.lua'))('TitanGatheredForeverV3', ns)
local rows = ns.Professions.Rows()
assert(#rows == 2, 'Must show learned skills only, independent of installed data addons')
assert(rows[1].name == 'Localized Mining' and rows[1].rank == 75 and rows[1].maxRank == 150)
assert(rows[2].name == 'Localized Cooking' and rows[2].secondary == true)
learned[186].rank = 76
assert(ns.Professions.Rows()[1].rank == 76, 'Skill rank did not update')
local titleFont
local description = {AddInitializer=function(_,fn)
    fn({fontString={SetFontObject=function(_,font)titleFont=font end}})
end}
ns.Style.MenuNote({CreateTitle=function(_,value)assert(value=='Explanation');return description end},'Explanation')
assert(titleFont=='GameFontHighlightSmall','Informational menu titles should use small fonts')
local region={font='OriginalFont'}
function region:GetFontObject()return self.font end
function region:SetFontObject(font)self.font=font end
local originalAddLine=tip.AddLine
function tip:AddLine(value)originalAddLine(self,value);_G['TestTipTextLeft'..#lines]=region end
ns.Style.Note(tip,'Small explanatory note')
assert(region.font=='GameFontHighlightSmall')
tip.hooks.OnTooltipCleared(tip)
assert(region.font=='OriginalFont','Tooltip recycling leaked a small font into native item content')
print('PASS 10 rarity, separator and learned-profession checks')
