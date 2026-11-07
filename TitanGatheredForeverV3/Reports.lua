local _, ns = ...
local Reports={windows={}};ns.Reports=Reports
local labels={Mining='Mining',Herbs='Herbalism',Skinning='Skinning',Fishing='Fishing',Loot='Loot',Enchanting='Disenchanting'}
function Reports.Zone(mapID)
    if not mapID or mapID==0 then return 'No map location' end
    local info=C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or ('Map '..mapID)
end
function Reports.Source(row)
    if row.kind=='Enchanting'then
        local id=tonumber(row.source)
        return 'Disenchant: '..(id and ns.ItemName(id)or'unknown input item')
    end
    local source=labels[row.kind]or row.kind
    if row.kind~='Fishing'then source=source..' - '..(row.sourceName or ('source #'..tostring(row.source)))end
    local context=row.instanceType and row.instanceType~='none'and (' ('..row.instanceType..')')or''
    return source..' - '..Reports.Zone(row.mapID)..context
end
function Reports.Matches(itemID,filter,kind)
    if not filter then return true end
    local m=ns.Catalog.modules[filter]
    return kind==filter or (m and m.items[itemID]~=nil)or false
end
function Reports.Rows(mode,character,filter)
    local result={}
    local rows=mode=='chances'and ns.history:Rates(character)or ns.history:Totals(character)
    local obtained=filter and ns.history:ItemsFor(filter,character)or{}
    for _,row in ipairs(rows)do if Reports.Matches(row.itemID,filter,row.kind)or obtained[row.itemID]then result[#result+1]=row end end
    return result
end
local function text(frame,font,x,y,width)
    local t=frame:CreateFontString(nil,'OVERLAY',font);t:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y)
    t:SetWidth(width);t:SetJustifyH('LEFT');return t
end
local function button(frame,label,x,y,width,callback)
    local b=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate');b:SetSize(width,22)
    b:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',callback);return b
end
function Reports.ItemSources(owner,itemID,character)
    local rates=ns.history:Rates(character,itemID)
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(ns.Style.ItemName(itemID));root:CreateTitle('Observed sources; complete loot samples only')
        if #rates==0 then root:CreateTitle('No complete source samples recorded yet.')end
        for _,r in ipairs(rates)do
            local mapID=r.mapID
            local label=string.format('%s: %.1f%% (%d / %d)',Reports.Source(r),r.percent,r.hits,r.trials)
            if mapID and mapID>0 then
                root:CreateButton(label,function()if WorldMapFrame then WorldMapFrame:Show();WorldMapFrame:SetMapID(mapID)end end)
            else root:CreateTitle(label)end
        end
        root:SetScrollMode(350)
    end)
end
function Reports.Update(window)
    if not ns.history then return end
    local character=not window.combined and (ns.characterID or UnitGUID('player'))or nil
    local rows=Reports.Rows(window.mode,character,window.filter)
    local pages=math.max(1,math.ceil(#rows/10));window.page=math.min(pages,math.max(1,window.page))
    window.scope:SetText(window.combined and 'All characters' or 'This character')
    local module=window.filter and ns.Catalog.modules[window.filter]
    window.filterButton:SetText(module and module.label or 'All professions')
    window.pageText:SetText(string.format('Page %d / %d - %d entries',window.page,pages,#rows))
    for i,view in ipairs(window.rows)do
        local row=rows[(window.page-1)*10+i];view.data=row;view.character=character
        if row then
            view:Show();view.name:SetText(ns.Style.ItemName(row.itemID))
            if window.mode=='chances'then
                view.detail:SetText(string.format('%.1f%% (%d / %d samples), %d items\n%s',row.percent,row.hits,row.trials,row.quantity,Reports.Source(row)))
            else
                local location=Reports.Zone(row.mapID)
                if row.x and row.y then location=location..string.format(' (%.1f, %.1f)',row.x*100,row.y*100)end
                view.detail:SetText(string.format('%d obtained lifetime\nLast obtained: %s',row.quantity,location))
            end
        else view:Hide()end
    end
    window.empty:SetText(#rows==0 and 'No recorded observations for this view yet. History starts with this version.'or'')
end
function Reports.Show(mode)
    mode=mode=='chances'and'chances'or'history'
    local w=Reports.windows[mode]
    if not w then
        local name='TitanGatheredForeverV3'..(mode=='chances'and'Chances'or'History')..'Window'
        w=CreateFrame('Frame',name,UIParent,'BasicFrameTemplateWithInset');Reports.windows[mode]=w
        if UISpecialFrames then table.insert(UISpecialFrames,name)end
        w.mode,w.page,w.rows=mode,1,{}
        w:SetSize(800,560);w:SetPoint('CENTER',UIParent,'CENTER',mode=='chances'and 35 or-35,0)
        w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true);w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart',function(self)self:StartMoving()end)
        w:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
        w.TitleText:SetText(mode=='chances'and'TGF v3 Observed acquisition chances'or'TGF v3 Lifetime material history')
        local note=text(w,'GameFontHighlightSmall',15,-33,765)
        note:SetText(mode=='chances'and'Observed outcomes / complete looted sources. Not a guaranteed drop rate. Click a material for sources.'
            or'Obtained items, separate from current inventory. Clearing map spots preserves history. Click for sources.')
        w.scope=button(w,'This character',15,-65,150,function()w.combined=not w.combined;w.page=1;Reports.Update(w)end)
        w.filterButton=button(w,'All professions',175,-65,190,function(owner)
            MenuUtil.CreateContextMenu(owner,function(_,root)
                root:CreateButton('All professions',function()w.filter=nil;w.page=1;Reports.Update(w)end)
                for _,module in ipairs(ns.Catalog.Modules())do
                    local id=module.id
                    root:CreateButton(module.label,function()w.filter=id;w.page=1;Reports.Update(w)end)
                end
            end)
        end)
        for i=1,10 do
            local row=CreateFrame('Button',nil,w);row:SetSize(765,37);row:SetPoint('TOPLEFT',w,'TOPLEFT',15,-100-(i-1)*40)
            row.name=text(row,'GameFontNormal',0,0,230);row.detail=text(row,'GameFontHighlightSmall',240,0,520)
            row:SetScript('OnClick',function(self)if self.data then Reports.ItemSources(self,self.data.itemID,self.character)end end)
            row:SetScript('OnEnter',function(self)
                if self.data then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.data.itemID)end;GameTooltip:Show()end
            end)
            row:SetScript('OnLeave',function()GameTooltip:Hide()end);w.rows[i]=row
        end
        w.empty=text(w,'GameFontHighlight',15,-110,760)
        button(w,'Previous',15,-520,100,function()w.page=w.page-1;Reports.Update(w)end)
        button(w,'Next',125,-520,100,function()w.page=w.page+1;Reports.Update(w)end)
        w.pageText=text(w,'GameFontHighlightSmall',245,-525,520)
    end
    Reports.Update(w);w:Show()
end
function Reports.Refresh()
    for _,window in pairs(Reports.windows)do if window:IsShown()then Reports.Update(window)end end
end
