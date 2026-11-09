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
    if row.kind~='Fishing' and row.sourceName and row.sourceName~='' then source=source..' - '..row.sourceName end
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
    if mode=='reagentUsage'then return ns.production:ReagentUsage(character)end
    if mode=='actions' then
        for _,row in ipairs(ns.actions:Rows(character)) do
            if not filter or row.kind==filter then result[#result+1]=row end
        end
        return result
    end
    if mode=='production' then
        for _,row in ipairs(ns.production:Rows(character))do
            if not filter or row.kind==filter then result[#result+1]=row end
        end
        return result
    end
    local rows=mode=='chances'and ns.history:Rates(character)or ns.history:Totals(character)
    local craftedKinds={}
    if mode=='history' and ns.production then
        local byID={};for _,row in ipairs(rows)do byID[row.itemID]=row end
        for _,output in ipairs(ns.production:Totals(character))do
            local row=byID[output.itemID]
            if not row then row={itemID=output.itemID,quantity=0};rows[#rows+1]=row;byID[output.itemID]=row end
            row.crafted=output.quantity
        end
        if filter then for _,recipe in ipairs(ns.production:Rows(character))do
            if recipe.kind==filter then for itemID in pairs(recipe.outputs)do craftedKinds[itemID]=true end end
        end end
        table.sort(rows,function(a,b)return a.itemID<b.itemID end)
    end
    if mode=='history' then
        local rates={}
        for _,rate in ipairs(ns.history:Rates(character))do
            rates[rate.itemID]=rates[rate.itemID]or{}
            local item=rates[rate.itemID]
            if #item<3 then item[#item+1]=string.format('%s: %.1f%% (%d/%d)',Reports.Source(rate),rate.percent,rate.hits,rate.trials)end
        end
        for _,row in ipairs(rows)do row.chances=rates[row.itemID]and table.concat(rates[row.itemID],'; ')or'Unknown'end
    end
    local obtained=filter and ns.history:ItemsFor(filter,character)or{}
    for _,row in ipairs(rows)do if Reports.Matches(row.itemID,filter,row.kind)or obtained[row.itemID]or craftedKinds[row.itemID]then result[#result+1]=row end end
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
local layouts={
    pvp={{'Statistic',0,330},{'Value',345,565}},
    history={{'Material',0,225},{'Lifetime obtained',235,115},{'Observed drop chance',360,570}},
    chances={{'Material',0,195},{'Observed',205,70},{'Hits / samples',285,105},{'Items',400,75},{'Source and zone',485,445}},
    actions={{'Profession',0,140},{'Attempts',150,65},{'Completed',225,75},{'Failed',310,55},
        {'Interrupted',375,85},{'Stopped',470,70},{'Unresolved',550,85},{'Recording began',645,285}},
    production={{'Recipe',0,190},{'Attempts',200,65},{'Completed',275,75},{'Completed %',360,85},
        {'Matched',455,65},{'Items',530,55},{'Bonus',595,155},{'Multicraft',760,170}},
    reagentUsage={{'Reagent',0,250},{'Estimated used',260,150},{'Leading profession',420,220},{'Share of tracked use',650,280}},
}
local contentTop,contentBottom=132,510
local function cells(frame,mode,font,y)
    local result={}
    for i,column in ipairs(layouts[mode])do result[i]=text(frame,font,column[2],y,column[3])end
    return result
end
local function values(mode,row)
    if mode=='pvp' then return {row.label,row.value} end
    if mode=='production'then
        local function percent(hits,total)
            return total>0 and string.format('%.1f%% (%d/%d)',hits/total*100,hits,total)or'Unknown'
        end
        return {row.name,row.attempts,row.completed,
            row.attempts>0 and string.format('%.1f%%',row.completed/row.attempts*100)or'Unknown',
            row.matched,row.quantity,percent(row.bonusHits,row.bonusKnown),percent(row.multicraftHits,row.multicraftKnown)}
    elseif mode=='actions'then
        local began=date and date('%Y-%m-%d %H:%M',row.began)or tostring(row.began)
        return {labels[row.kind],row.attempts,row.completed,row.failed,row.interrupted,row.stopped,row.unresolved,began}
    elseif mode=='chances'then
        return {ns.Style.ItemName(row.itemID),string.format('%.1f%%',row.percent),
            string.format('%d / %d',row.hits,row.trials),row.quantity,Reports.Source(row)}
    elseif mode=='reagentUsage'then
        return {ns.Style.ItemName(row.itemID),row.quantity,ns.Production.labels[row.leading],string.format('%.1f%%',row.share)}
    end
    return {ns.Style.ItemName(row.itemID),row.quantity+(row.crafted or 0),row.chances or'Unknown'}
end
function Reports.ReagentDetails(owner,row)
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(ns.Style.ItemName(row.itemID)..': '..row.quantity..' estimated items used')
        ns.Style.MenuNote(root,'Profession use, as a share of this reagent total')
        local kinds={};for kind in pairs(row.professions)do kinds[#kinds+1]=kind end
        table.sort(kinds,function(a,b)
            local left,right=row.professions[a],row.professions[b]
            if left~=right then return left>right end
            return a<b
        end)
        for _,kind in ipairs(kinds)do
            local quantity=row.professions[kind]
            root:CreateTitle(string.format('%s: %d (%.1f%%)',ns.Production.labels[kind],quantity,quantity/row.quantity*100))
        end
        ns.Style.MenuNote(root,'Estimate uses fixed required recipe reagents per completed tracked craft.')
        ns.Style.MenuNote(root,'Optional modifiers and unsupported required slots are excluded.')
        root:SetScrollMode(350)
    end)
end
local function pagesFor(window,rows)
    local pages={{}}
    local page,used=pages[1],0
    for _,row in ipairs(rows)do
        local columns=values(window.mode,row)
        local height=16
        for i,value in ipairs(columns)do
            local measure=window.measure.cells[i];measure:SetText(value)
            height=math.max(height,measure:GetStringHeight())
        end
        height=math.min(contentBottom-contentTop,height+6)
        if #page>0 and (#page==#window.rows or used+height>contentBottom-contentTop)then
            page={};pages[#pages+1]=page;used=0
        end
        page[#page+1]={data=row,values=columns,height=height};used=used+height
    end
    return pages
end
function Reports.ItemSources(owner,itemID,character)
    local rates=ns.history:Rates(character,itemID)
    local evidence=ns.Crafting and ns.Crafting.Evidence(itemID,character)or{spots={}}
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(ns.Style.ItemName(itemID));ns.Style.MenuNote(root,'Observed sources; complete loot samples only')
        ns.Style.MenuNote(root,'Grouped by source and zone; not a probability at a coordinate.')
        if #rates==0 then ns.Style.MenuNote(root,'No complete source samples recorded yet.')end
        for _,r in ipairs(rates)do
            local mapID=r.mapID
            local label=string.format('%s: %.1f%% (%d / %d)',Reports.Source(r),r.percent,r.hits,r.trials)
            if mapID and mapID>0 then
                root:CreateButton(label,function()if WorldMapFrame then WorldMapFrame:Show();WorldMapFrame:SetMapID(mapID)end end)
            else root:CreateTitle(label)end
        end
        for index=1,math.min(3,#evidence.spots)do
            local spot=evidence.spots[index];local mapID=spot.mapID
            root:CreateButton(string.format('%s: %d saved positions (separate from rate samples)',Reports.Zone(mapID),spot.positions),function()
                if WorldMapFrame then WorldMapFrame:Show();WorldMapFrame:SetMapID(mapID)end
            end)
        end
        local record=ns.Catalog.Get and ns.Catalog.Get(itemID)
        if ns.CraftingView and record then for index=1,math.min(2,#record.recipes)do
            local recipeID=record.recipes[index]
            root:CreateButton('Plan recipe #'..recipeID..' reagents',function()ns.CraftingView.Show(recipeID,1)end)
        end end
        root:SetScrollMode(350)
    end)
end
function Reports.ProductionDetails(owner,row)
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(row.name..' (#'..row.recipeID..')')
        if ns.CraftingView then root:CreateButton('Plan recipe reagents',function()ns.CraftingView.Show(row.recipeID,1)end)end
        root:CreateTitle(string.format('%d failed, %d interrupted, %d unresolved attempts',row.failed,row.interrupted,
            row.attempts-row.completed-row.failed-row.interrupted))
        root:CreateTitle('First recorded: '..(date and date('%Y-%m-%d',row.began)or tostring(row.began)))
        ns.Style.MenuNote(root,'Observed output quantities; unmatched operations are excluded')
        local ids={};for id in pairs(row.outputs)do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids)do
            local output=row.outputs[id]
            root:CreateTitle(ns.ItemName(id)..': '..output.quantity..' items in '..output.hits..' matched operations')
            local quantities={};for quantity,count in pairs(output.distribution)do if count>0 then quantities[#quantities+1]=quantity end end;table.sort(quantities)
            for _,quantity in ipairs(quantities)do
                root:CreateTitle(string.format('%d items in %d operations',quantity,output.distribution[quantity]))
            end
        end
        if #ids==0 then ns.Style.MenuNote(root,'No matched output results yet.')end
        root:SetScrollMode(350)
    end)
end
function Reports.Update(window)
    if not ns.history then return end
    local character=not window.combined and (ns.characterID or UnitGUID('player'))or nil
    local rows,metadata
    if window.mode=='pvp' then
        local stats=ns.pvp and ns.pvp:Snapshot(character)or{}
        local rank=stats.currentRankName or(stats.currentRankID==0 and'No rank')
            or(stats.currentRankID and('Rank '..stats.currentRankID))or'Not available'
        local highest=stats.highestRankName or(stats.highestRankID==0 and'No rank')
            or(stats.highestRankID and('Rank '..stats.highestRankID))or'Not available'
        local coverage=stats.coverageBegan and(date and date('%Y-%m-%d',stats.coverageBegan)or tostring(stats.coverageBegan))or'No tracked data'
        rows={{label='Client lifetime honorable kills (current character)',value=stats.lifetimeHonorableKills or'Not available'},
            {label='Current PvP rank',value=rank},{label='Highest recorded rank',value=highest},
            {label='Addon tracked outdoor honorable kills',value=stats.worldKills or 0},
            {label='Outdoor estimated honor from honorable kills',value=stats.worldHonorEstimate or 0},
            {label='Addon tracked Battleground honorable kills',value=stats.battlegroundKills or 0},
            {label='Battleground estimated honor from honorable kills',value=stats.battlegroundHonorEstimate or 0},
            {label='Addon tracked arena honorable kills',value=stats.arenaKills or 0},
            {label='Arena estimated honor from honorable kills',value=stats.arenaHonorEstimate or 0},
            {label='Addon tracked deaths, outdoor',value=stats.deaths and stats.deaths.world or 0},
            {label='Addon tracked deaths, battlegrounds',value=stats.deaths and stats.deaths.battleground or 0},
            {label='Addon tracked deaths, arenas',value=stats.deaths and stats.deaths.arena or 0},
            {label='Addon tracked deaths, total',value=stats.deaths and stats.deaths.total or 0},
            {label='Addon tracking coverage begins',value=coverage}}
    else rows,metadata=Reports.Rows(window.mode,character,window.filter)end
    if window.mode=='reagentUsage'then
        local coverage=metadata.coverageBegan and(date and date('%Y-%m-%d',metadata.coverageBegan)or tostring(metadata.coverageBegan))or'unknown'
        window.note:SetText(string.format('Estimated from fixed required reagents per completed craft. Coverage since %s. Percent is share of this reagent\'s tracked use. Unsupported recipes are excluded%s',
            coverage,metadata.unsupportedCasts>0 and string.format('; %d completed recipes had unsupported required reagents',metadata.unsupportedCasts)or''))
        window.empty:SetText(#rows==0 and'No supported reagent use is recorded in this coverage period.'or'')
    end
    local pages=pagesFor(window,rows)
    window.page=math.min(#pages,math.max(1,window.page))
    window.scope:SetText(window.combined and 'All characters' or 'This character')
    local module=window.filter and ns.Catalog.modules[window.filter]
    window.filterButton:SetText(module and module.label or (window.mode=='actions' and labels[window.filter])
        or (window.mode=='production'and ns.Production.labels[window.filter]) or 'All professions')
    window.pageText:SetText(string.format('Page %d / %d - %d entries',window.page,#pages,#rows))
    local y=contentTop
    for i,view in ipairs(window.rows)do
        local entry=pages[window.page][i];view.data=entry and entry.data;view.character=character
        if entry then
            view:ClearAllPoints();view:SetPoint('TOPLEFT',window,'TOPLEFT',15,-y);view:SetHeight(entry.height)
            for column,value in ipairs(entry.values)do
                view.cells[column]:SetHeight(entry.height-6);view.cells[column]:SetText(value)
            end
            view:Show();y=y+entry.height
        else view:Hide()end
    end
    window.empty:SetText(#rows==0 and (window.mode=='production'and'No recipe operations recorded for this view. Earlier inventory cannot reconstruct production.'
        or window.mode=='actions' and 'No actions recorded for this view. Earlier loot history cannot reconstruct actions.'
        or 'No recorded observations for this view yet. History starts with this version.')or'')
end
function Reports.Show(mode)
    mode=(mode=='pvp' or mode=='chances' or mode=='actions' or mode=='production' or mode=='reagentUsage') and mode or 'history'
    local w=Reports.windows[mode]
    if not w then
        local name='TitanGatheredForeverV3'..(mode=='pvp'and'PvPBoard'or mode=='chances'and'Chances'or mode=='actions'and'Actions'or mode=='production'and'Production'
            or mode=='reagentUsage'and'ReagentUsage'or'History')..'Window'
        w=CreateFrame('Frame',name,UIParent,'BasicFrameTemplateWithInset');Reports.windows[mode]=w
        if UISpecialFrames then table.insert(UISpecialFrames,name)end
        w.mode,w.page,w.rows=mode,1,{}
        w:SetSize(960,560);w:SetPoint('CENTER',UIParent,'CENTER',0,0)
        w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true);w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart',function(self)self:StartMoving()end)
        w:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
        w:SetScript('OnHide',function()GameTooltip:Hide()end)
        w.TitleText:SetText(mode=='pvp'and'TGF v3 PvP Board'
            or mode=='production'and'TGF v3 Crafting and cooking'
            or mode=='reagentUsage'and'TGF v3 Reagent usage estimates'
            or mode=='chances'and'TGF v3 Observed acquisition chances'
            or mode=='actions'and'TGF v3 Profession actions'or'TGF v3 Lifetime material history')
        local note=text(w,'GameFontHighlightSmall',15,-33,930);w.note=note
        note:SetText(mode=='pvp'and'Client lifetime honorable kills and rank are current-character totals across PvP modes. Per-kill honor estimates come only from named honorable-kill events; other honor awards are excluded. Death tracking begins with this version; earlier deaths cannot be reconstructed.'
            or mode=='reagentUsage'and'Estimated reagent consumption by item and profession. Click a row for the profession breakdown.'
            or mode=='production'and'Completed % = completed casts / observed attempts, including unresolved attempts. Bonus/multicraft use readable-field counts. Click for output details.'
            or mode=='actions'and'Fishing completion means a catch window; other completion means spell success. Stopped means no confirmed result; gaps are not reconstructed.'
            or mode=='chances'and'Observed outcomes / complete looted sources, grouped by source and zone. Not a probability at a map coordinate. Click for sources.'
            or'Lifetime obtained combines acquired and crafted quantities. Chances use complete source samples; Unknown means insufficient evidence. Click for all sources.')
        w.scope=button(w,'This character',15,-65,150,function()w.combined=not w.combined;w.page=1;Reports.Update(w)end)
        w.filterButton=button(w,'All professions',175,-65,190,function(owner)
            MenuUtil.CreateContextMenu(owner,function(_,root)
                root:CreateButton('All professions',function()w.filter=nil;w.page=1;Reports.Update(w)end)
                if mode=='actions' then
                    for _,id in ipairs({'Mining','Herbs','Skinning','Fishing','Enchanting'}) do
                        local kind=id
                        root:CreateButton(labels[kind],function()w.filter=kind;w.page=1;Reports.Update(w)end)
                    end
                elseif mode=='production'then
                    local kinds={};for kind in pairs(ns.Production.labels)do kinds[#kinds+1]=kind end;table.sort(kinds)
                    for _,id in ipairs(kinds)do
                        local kind=id
                        root:CreateButton(ns.Production.labels[kind],function()w.filter=kind;w.page=1;Reports.Update(w)end)
                    end
                else
                    for _,module in ipairs(ns.Catalog.Modules())do
                        local id=module.id
                        root:CreateButton(module.label,function()w.filter=id;w.page=1;Reports.Update(w)end)
                    end
                end
            end)
        end)
        if mode=='reagentUsage'or mode=='pvp'then w.filterButton:Hide()end
        local header=CreateFrame('Frame',nil,w);header:SetSize(930,30);header:SetPoint('TOPLEFT',w,'TOPLEFT',15,-100)
        w.headers=cells(header,mode,'GameFontNormalSmall',0)
        for i,column in ipairs(layouts[mode])do w.headers[i]:SetText(column[1])end
        w.measure=CreateFrame('Frame',nil,w);w.measure.cells=cells(w.measure,mode,'GameFontHighlightSmall',0);w.measure:Hide()
        for i=1,16 do
            local row=CreateFrame('Button',nil,w);row:SetSize(930,22)
            row.cells=cells(row,mode,'GameFontHighlightSmall',0)
            row.name=row.cells[1];row.detail=mode=='production'and row.cells[2]or nil
            row:SetScript('OnClick',function(self)
                if mode=='reagentUsage'and self.data then Reports.ReagentDetails(self,self.data)
                elseif mode=='production'and self.data then Reports.ProductionDetails(self,self.data)
                elseif self.data and self.data.itemID then Reports.ItemSources(self,self.data.itemID,self.character)end
            end)
            row:SetScript('OnEnter',function(self)
                if self.data and self.data.itemID then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.data.itemID)end;GameTooltip:Show()end
            end)
            row:SetScript('OnLeave',function()GameTooltip:Hide()end);w.rows[i]=row
        end
        w.empty=text(w,'GameFontHighlight',15,-contentTop,930)
        button(w,'Previous',15,-520,100,function()w.page=w.page-1;Reports.Update(w)end)
        button(w,'Next',125,-520,100,function()w.page=w.page+1;Reports.Update(w)end)
        w.pageText=text(w,'GameFontHighlightSmall',245,-525,690)
    end
    for _,window in pairs(Reports.windows)do if window~=w then window:Hide()end end
    Reports.Update(w);w:Show()
end
function Reports.Refresh()
    for _,window in pairs(Reports.windows)do if window:IsShown()then Reports.Update(window)end end
    if ns.CraftingView then ns.CraftingView.Refresh()end
end
