local _, ns = ...
local View={};ns.CraftingView=View
local function text(frame,font,x,y,width)
    local t=frame:CreateFontString(nil,'OVERLAY',font);t:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y)
    t:SetWidth(width);t:SetJustifyH('LEFT');return t
end
local function button(frame,label,x,y,width,callback)
    local b=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate');b:SetSize(width,22)
    b:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',callback);return b
end
function View.Refresh()
    local w=View.window;if not w or not w:IsShown()then return end
    local plan=ns.Crafting.Plan(w.recipeID,w.operations);w.plan=plan
    local last=math.max(0,#plan.rows-6);w.offset=math.min(last,math.max(0,math.floor(w.offset+0.5)))
    w.TitleText:SetText('TGF v3 Recipe reagents'..(plan.name and': '..plan.name or''))
    w.target:SetText(w.operations..' planned operations')
    w.pageText:SetText(#plan.rows==0 and'Click a reagent for observed sources'
        or string.format('Showing %d-%d of %d reagents; click a reagent for observed sources',w.offset+1,math.min(#plan.rows,w.offset+6),#plan.rows))
    ns.Nav.SyncScrollbar(w.slider,w.offset,last)
    if plan.error then w.summary:SetText(plan.error);w.note:SetText('Use /tgf recipe <recipeID> [operations], or select a supported profession recipe.')
    else
        local limit=plan.craftable and string.format('Material limit: %d operations%s',plan.craftable,plan.cached and' (cached estimate)'or'')
            or'Material limit unavailable: required slots or inventory are unresolved.'
        w.summary:SetText(limit..(plan.learned==false and'; recipe not learned'or''))
        local freshness=plan.unknown and'; unknown inventory counts display zero'or''
        if plan.bankObservedAt then
            freshness=freshness..'; bank observed '..(date and date('%Y-%m-%d %H:%M',plan.bankObservedAt)or tostring(plan.bankObservedAt))
        end
        w.note:SetText('Scope: '..plan.scope..' (Display > Show bank counts)'..freshness
            ..'\nMaterials only: skill, tools and cooldowns are not checked; optional reagents are excluded.'
            ..(#plan.issues>0 and' Fixed rows below are partial.'or''))
    end
    local character=ns.characterID or UnitGUID('player')
    for i,row in ipairs(w.rows)do
        local data=plan.rows[w.offset+i];row.data=data
        if data then
            row:Show();row.name:SetText(ns.Style.ItemName(data.itemID))
            local evidence=ns.Crafting.Evidence(data.itemID,character)
            local source=evidence.rates[1];local hint='No recorded acquisition evidence.'
            if source then hint=string.format('%s: %d / %d observed source/zone samples',ns.Reports.Source(source),source.hits,source.trials)
            elseif evidence.spots[1]then hint='Recorded positions: '..ns.Reports.Zone(evidence.spots[1].mapID)..'; no complete source samples.'end
            row.detail:SetText(string.format('%d per op; need %d, have %d, missing %d\n%s',
                data.perOperation,data.required,data.available,data.missing,hint))
        else row:Hide()end
    end
end
function View.Show(recipeID,operations)
    local w=View.window
    if not w then
        local name='TitanGatheredForeverV3RecipeWindow'
        w=CreateFrame('Frame',name,UIParent,'BasicFrameTemplateWithInset');View.window=w
        if UISpecialFrames then table.insert(UISpecialFrames,name)end
        w.rows={};w:SetSize(845,600);w:SetPoint('CENTER',UIParent,'CENTER',0,0)
        w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true);w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart',function(self)self:StartMoving()end)
        w:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
        w.summary=text(w,'GameFontHighlight',15,-35,785)
        w.target=text(w,'GameFontNormal',15,-70,400)
        w.note=text(w,'GameFontHighlightSmall',15,-100,785)
        button(w,'Fewer',440,-65,80,function()w.operations=math.max(1,w.operations-1);View.Refresh()end)
        button(w,'More',530,-65,80,function()w.operations=math.min(1000000,w.operations+1);View.Refresh()end)
        button(w,'Refresh',620,-65,100,function()if ns.ScheduleRefresh then ns.ScheduleRefresh()end;View.Refresh()end)
        for i=1,6 do
            local row=CreateFrame('Button',nil,w);w.rows[i]=row
            row:SetSize(785,54);row:SetPoint('TOPLEFT',w,'TOPLEFT',15,-155-(i-1)*62)
            row.name=text(row,'GameFontNormal',0,0,220);row.detail=text(row,'GameFontHighlightSmall',230,0,550)
            row:SetScript('OnClick',function(self)
                if self.data then ns.Reports.ItemSources(self,self.data.itemID,ns.characterID or UnitGUID('player'))end
            end)
            row:SetScript('OnEnter',function(self)
                if self.data then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetItemByID(self.data.itemID);GameTooltip:Show()end
            end)
            row:SetScript('OnLeave',function()GameTooltip:Hide()end)
        end
        local function scrollTo(offset)w.offset=offset;View.Refresh()end
        w.slider=ns.Nav.Scrollbar(w,15+785+8,-155,6*62-8,scrollTo,function(delta)scrollTo(w.offset-delta*2)end)
        w:EnableMouseWheel(true)
        w:SetScript('OnMouseWheel',function(_,delta)scrollTo(w.offset-delta*2)end)
        w.pageText=text(w,'GameFontHighlightSmall',15,-565,785)
    end
    w.recipeID,w.operations,w.offset=recipeID,operations or 1,0
    ns.Crafting.Select({recipeID=recipeID});w:Show();View.Refresh()
end
