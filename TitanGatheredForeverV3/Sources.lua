local _, ns = ...
local Sources={};ns.Sources=Sources
local switches={Mining='mapMining',Herbs='mapHerbs',Skinning='mapSkinning',Fishing='mapFishing',Rare='mapRare'}
function Sources.Categories(includeSaved)
    local result={}
    for _,m in ipairs(ns.Catalog.Modules())do
        if m.id~='Enchanting' and m.kind=='profession'then result[#result+1]={id=m.id,label=m.label}end
    end
    if includeSaved and ns.gathering then
        local present={Rare=true};for _,c in ipairs(result)do present[c.id]=true end
        for _,nodes in pairs(ns.gathering.saved.maps)do if type(nodes)=='table'then for _,node in ipairs(nodes)do
            if not present[node.kind]then result[#result+1]={id=node.kind,label=node.kind=='Herbs'and'Herbalism'or node.kind};present[node.kind]=true end
        end end end
    end
    result[#result+1]={id='Rare',label='Rare loot'}
    return result
end
function Sources.MaterialVisible(itemID)
    return ns.settings.mapItemVisibility[itemID] ~= false
end
function Sources.SetMaterialVisible(itemID,visible)
    ns.settings.mapItemVisibility[itemID] = visible == true
end
function Sources.Enabled(kind,itemID)
    local s=ns.settings;if not s or not s.gatheringMap or kind=='Enchanting'then return false end
    if kind~='Rare'then
        if not ns.Catalog.modules[kind]or s.categories[kind]==false then return false end
    end
    if switches[kind]then if not s[switches[kind]]then return false end
    elseif s.mapProfessions[kind]==false then return false end
    return not itemID or Sources.MaterialVisible(itemID)
end
function Sources.ToggleKey(kind)return switches[kind]end
function Sources.Items(kind)
    local result={};local m=ns.Catalog.modules[kind]
    for id in pairs(m and (m.gatheringResources or m.items)or{})do result[id]=true end
    if ns.history then for id in pairs(ns.history:ItemsFor(kind))do result[id]=true end end
    if ns.gathering then for _,nodes in pairs(ns.gathering.saved.maps)do
        if type(nodes)=='table'then for _,node in ipairs(nodes)do if node.kind==kind then result[node.itemID]=true end end end
    end end
    return result
end
function Sources.Track(kind)
    local s=ns.settings
    return s and s.recordHistory and s.historyProfessions[kind]~=false
        and (kind=='Loot' or (ns.Catalog.modules[kind]~=nil and s.categories[kind]~=false))
end
function Sources.Active(kind)
    if Sources.Track(kind)then return true end
    if kind=='Loot'then
        for _,m in ipairs(Sources.Categories())do if Sources.Enabled(m.id)then return true end end
        return false
    end
    return Sources.Enabled(kind)
end
function Sources.Eligible(itemID,quality)
    return ns.Catalog.Get(itemID)~=nil or (ns.settings.recordRare and type(quality)=='number'and quality>=3)
end
-- Preserve the eligible-item set for each recording configuration so a newly
-- enabled profession does not inherit samples collected while it was disabled.
function Sources.Policy()
    local selected, loaded, modules = {}, {}, ns.Catalog.Modules()
    for _,m in ipairs(modules)do
        loaded[#loaded+1]=m.id
        if ns.settings.categories[m.id]~=false and ns.settings.historyProfessions[m.id]~=false then selected[#selected+1]=m.id end
    end
    local key=table.concat(loaded,',')..'/'..table.concat(selected,',')..':'..tostring(ns.settings.recordRare)..':'..tostring(ns.DataMetadata.sourceSHA256)
    if not Sources.policy or Sources.policy.key~=key then
        local ids,known={},{}
        for _,m in ipairs(modules)do
            for id in pairs(m.items)do
                known[id]=true
                if ns.settings.categories[m.id]~=false and ns.settings.historyProfessions[m.id]~=false then ids[id]=true end
            end
        end
        Sources.policy={key=key,items=ids,knownItems=known,rare=ns.settings.recordRare}
    end
    return Sources.policy
end
function Sources.SettingsChanged()
    if not ns.history then return end
    local signature=Sources.Policy().key..':'..tostring(ns.settings.recordHistory)..':'..tostring(ns.settings.historyProfessions.Loot)
    if Sources.recordingSignature and Sources.recordingSignature~=signature then
        ns.history:InvalidatePending(ns.characterID or UnitGUID('player'))
        if ns.observations then ns.observations:Cancel()end
    end
    Sources.recordingSignature=signature
end

local function miningMarker(items)
    local module = ns.Catalog.modules.Mining
    local resources = module and module.gatheringResources or {}
    local chosen, priority
    for id, quantity in pairs(items) do
        local rank = resources[id]
        if type(rank) == 'number' and rank >= 0 and rank < math.huge and type(quantity) == 'number' and quantity > 0
            and (not chosen or rank < priority or (rank == priority and id < chosen)) then
            chosen, priority = id, rank
        end
    end
    return chosen
end

function Sources.Record(e)
    local character=ns.characterID or UnitGUID('player')
    if Sources.Track(e.kind)then
        local items={}
        for id,qty in pairs(e.items)do
            local include=e.kind~='Loot'
            if not include then
                local matched=false
                for _,m in ipairs(ns.Catalog.Modules())do
                    if m.items[id]then
                        matched=true
                        if ns.settings.categories[m.id]~=false and ns.settings.historyProfessions[m.id]~=false then include=true end
                    end
                end
                if not matched and ns.settings.recordRare then include=true end
            end
            if include then items[id]=qty end
        end
        local receipt={};for key,value in pairs(e)do receipt[key]=value end;receipt.items=items
        if e.kind=='Loot'then receipt.policy=Sources.Policy()end
        local name=UnitName and UnitName('player')or character
        local realm=GetRealmName and GetRealmName()or''
        ns.history:Observe(character,name..(realm~=''and' - '..realm or''),receipt)
    end
    local inside, context = IsInInstance()
    local outdoor = ns.IsPublic(inside) and ns.IsPublic(context) and inside == false and context == 'none'
    if outdoor and e.kind~='Enchanting'and e.mapID and e.mapID>0 and e.x and e.y then
        -- Keep every output in history, but give a mining source one resource
        -- marker. Otherwise stones/gems can cover the ore at the same point.
        local miningItem = e.kind == 'Mining' and miningMarker(e.items)
        for id in pairs(e.items)do
            if e.kind=='Loot'then
                local matched=false
                for _,m in ipairs(Sources.Categories())do
                    local module=ns.Catalog.modules[m.id]
                    if module and module.items[id]and Sources.Enabled(m.id)and not(e.suppressMaps and e.suppressMaps[m.id])then ns.gathering:Record(m.id,id,e);matched=true end
                end
                if not matched and not ns.Catalog.Get(id)and Sources.Enabled('Rare')and not(e.suppressMaps and e.suppressMaps.Rare)then ns.gathering:Record('Rare',id,e)end
            elseif Sources.Enabled(e.kind)and (e.kind~='Mining'or id==miningItem)
                and not(e.suppressMaps and e.suppressMaps[e.kind])then ns.gathering:Record(e.kind,id,e)end
        end
    end
    ns.Map.Update();ns.Minimap.Update()
    if ns.Reports then ns.Reports.Refresh()end
end
