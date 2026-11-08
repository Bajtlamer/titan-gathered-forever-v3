local _, ns = ...
local Export={};ns.Export=Export
Export.FORMAT='TGFv3-statistics';Export.PART_FORMAT='TGFv3-statistics-part'
local ARRAY={}
function Export.Array(values)return setmetatable(values or {},ARRAY)end
local function sorted(t)
    local keys={};for key in pairs(t or {})do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end);return keys
end
local function integer(value,minimum)
    return type(value)=='number'and value>=(minimum or 0)and value<math.huge and value==math.floor(value)
end
local function itemSet(t)
    local ids=Export.Array()
    for key,value in pairs(t or {})do if value and integer(key,1)then ids[#ids+1]=key end end
    table.sort(ids);return ids
end
local kinds={Mining=true,Herbs=true,Skinning=true,Fishing=true,Loot=true,Enchanting=true,Alchemy=true,
    Blacksmithing=true,Cooking=true,Engineering=true,FirstAid=true,Leatherworking=true,Tailoring=true}
local contexts={none=true,party=true,raid=true,pvp=true,arena=true,scenario=true,unknown=true}
local function source(row)
    if row.kind=='Fishing'then return {type='catch'}end
    local id=tonumber(row.source)
    if integer(id,1)then return {type=row.kind=='Enchanting'and'input_item'or'entry',id=id}end
    return {type=row.source=='unattributed item loot'and'unattributed_item_loot'or'unknown'}
end
local function location(row)
    return integer(row.mapID)and row.mapID or 0,contexts[row.instanceType]and row.instanceType or'unknown'
end
local function items(model,character)
    local rows=Export.Array()
    if model then for _,row in ipairs(model:Totals(character))do
        rows[#rows+1]={itemID=row.itemID,quantity=row.quantity,lastSeen=row.lastSeen}
    end end
    return rows
end
local function rates(model,character)
    local rows=Export.Array()
    if model then for _,row in ipairs(model:Rates(character))do
        local mapID,context=location(row)
        rows[#rows+1]={itemID=row.itemID,kind=kinds[row.kind]and row.kind or'Unknown',source=source(row),
            mapID=mapID,instanceType=context,hits=row.hits,eligibleCompleteSources=row.trials,quantity=row.quantity}
    end end
    return rows
end
local function history(model,character,aggregate)
    local h={status=model and'available'or'unavailable',startTimestampRecorded=false,
        items=items(model,character),rates=rates(model,character)}
    if aggregate then return h end
    h.policies,h.sourceGroups=Export.Array(),Export.Array()
    local c=model and model.saved.characters[character];if not c then return h end
    local policyKeys,refs={},{}
    for key in pairs(c.scopes or {})do policyKeys[key]=true end
    for _,g in pairs(c.groups)do
        if g.trialScopes then for key in pairs(g.trialScopes)do policyKeys[key]=true end
        else policyKeys.all=true end
    end
    for i,key in ipairs(sorted(policyKeys))do
        local p=c.scopes and c.scopes[key];local unrestricted=key=='all'or(p and p.all==true)
        local ref='policy-'..i;refs[key]=ref
        h.policies[#h.policies+1]={ref=ref,status=(unrestricted or p)and'known'or'unknown_policy',
            all=unrestricted==true,rare=p and p.rare==true or false,items=itemSet(p and p.items),
            knownItems=itemSet(p and p.knownItems)}
    end
    for i,key in ipairs(sorted(c.groups))do
        local g=c.groups[key];local mapID,context=location(g)
        local group={ref='source-'..i,kind=kinds[g.kind]and g.kind or'Unknown',source=source(g),mapID=mapID,
            instanceType=context,completeSources=g.trials,lastSeen=g.lastSeen,trialPolicies=Export.Array(),outcomes=Export.Array()}
        local scopes=g.trialScopes or {all=g.trials}
        for _,policy in ipairs(sorted(scopes))do
            group.trialPolicies[#group.trialPolicies+1]={policyRef=refs[policy],completeSources=scopes[policy]}
        end
        local ids={};for id in pairs(g.items)do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids)do local output=g.items[id]
            group.outcomes[#group.outcomes+1]={itemID=id,hits=output.hits,quantity=output.quantity,quality=output.quality}
        end
        h.sourceGroups[#h.sourceGroups+1]=group
    end
    return h
end
local actionFields={'attempts','completed','failed','interrupted','stopped','unresolved','began','lastSeen'}
local productionFields={'recipeID','itemID','attempts','completed','failed','interrupted','matched','quantity',
    'bonusKnown','bonusHits','multicraftKnown','multicraftHits','began'}
local function feature(model,character,production)
    local schema=model and model.saved.schema
    local result={sourceSchema=integer(schema,1)and schema or nil,
        status=not model and'unavailable'or schema~=1 and'unsupported_schema'or'available'}
    local rows=Export.Array();result[production and'recipes'or'rows']=rows
    if production then result.items=Export.Array()end
    if result.status~='available'then return result end
    if production then result.items=items(model,character)end
    for _,row in ipairs(model:Rows(character))do
        local r={kind=kinds[row.kind]and row.kind or'Unknown'}
        for _,field in ipairs(production and productionFields or actionFields)do r[field]=row[field]end
        if production then
            r.unresolved=row.attempts-row.completed-row.failed-row.interrupted;r.outputs=Export.Array()
            local ids={};for id in pairs(row.outputs)do ids[#ids+1]=id end;table.sort(ids)
            for _,id in ipairs(ids)do local output=row.outputs[id];local distribution=Export.Array()
                local quantities={};for quantity,count in pairs(output.distribution)do if count>0 then quantities[#quantities+1]=quantity end end
                table.sort(quantities)
                for _,quantity in ipairs(quantities)do distribution[#distribution+1]={quantity=quantity,operations=output.distribution[quantity]}end
                r.outputs[#r.outputs+1]={itemID=id,quantity=output.quantity,hits=output.hits,distribution=distribution}
            end
        end
        rows[#rows+1]=r
    end
    return result
end
function Export.Build(sources,options)
    options=options or {};local scope=options.scope or'character'
    assert(scope=='character'or scope=='combined','Invalid export scope')
    assert(type(sources.character)=='string'and sources.character~='','Current character is unavailable')
    local identity=options.includeIdentity==true
    local selected={[sources.character]=true}
    if scope=='combined'then
        for _,model in pairs({history=sources.history,actions=sources.actions,production=sources.production})do
            if model and (model==sources.history or model.saved.schema==1)then
                for id in pairs(model.saved.characters)do selected[id]=true end
            end
        end
    end
    local d={format=Export.FORMAT,schemaVersion=1,exportedAt=sources.timestamp,
        addon={version=sources.version or'unknown',client='WoW Forever',clientVersion='1.60.1',interface=16001,
            catalogueSourceSHA256=sources.sourceSHA256},
        selection={scope=scope,includeIdentity=identity,characterCount=0},
        definitions={acquiredQuantities='Observed acquisitions, including partial loot; exclude crafted output and current inventory.',
            sourceSamples='Complete observed loot sources; item denominators depend on recording policy.',
            sourceGroupQuantities='Quantities from complete eligible source samples; partial quantities exist only in acquired totals.',
            rates='Hits / eligible complete source samples, grouped by source, zone and instance context; not server probabilities.',
            actions='Observed profession actions; fishing completion requires a catch window, other completion means spell success.',
            production='Observed enabled starts and cast results; matched output operations differ from completed casts.',
            procs='Explicit readable bonus/multicraft flags; use their known-field denominators.',
            coverageIntervalsRecorded=false,historyIntroducedIn='0.4.0',
            coordinatesIncluded=false,rawReceiptsIncluded=false,inventoryIncluded=false},
        characters=Export.Array()}
    for i,id in ipairs(sorted(selected))do
        local c={ref='character-'..i,history=history(sources.history,id),
            actions=feature(sources.actions,id),production=feature(sources.production,id,true)}
        if identity then
            local name
            for _,model in ipairs({sources.history or false,sources.actions or false,sources.production or false})do
                local saved=model and (model==sources.history or model.saved.schema==1)
                    and type(model.saved.characters)=='table'and model.saved.characters[id]
                if type(saved)=='table'and type(saved.name)=='string'then name=saved.name;break end
            end
            c.identity={guid=id,name=name}
        end
        d.characters[#d.characters+1]=c
    end
    d.selection.characterCount=#d.characters
    if scope=='combined'then d.combined={history=history(sources.history,nil,true),
        actions=feature(sources.actions),production=feature(sources.production,nil,true)}end
    return d
end
function Export.Current(options)
    return Export.Build({history=ns.history,actions=ns.actions,production=ns.production,
        character=ns.characterID or UnitGUID('player'),timestamp=time(),
        version=C_AddOns.GetAddOnMetadata('TitanGatheredForeverV3','Version'),
        sourceSHA256=ns.DataMetadata.sourceSHA256},options)
end
local escapes={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
local function quoted(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)return escapes[c]or string.format('\\u%04x',c:byte())end)..'"'
end
function Export.Encode(value)
    local active={}
    local function encode(v,depth)
        assert(depth<64,'Export nesting limit exceeded')
        local kind=type(v)
        if kind=='string'then return quoted(v)
        elseif kind=='boolean'then return v and'true'or'false'
        elseif kind=='number'then
            assert(v==v and v~=math.huge and v~=-math.huge,'Nonfinite export number')
            return string.format('%.17g',v):gsub(',','.')
        end
        assert(kind=='table','Unsupported export value: '..kind)
        assert(not active[v],'Cyclic export value');active[v]=true
        local parts={}
        if getmetatable(v)==ARRAY then
            local count=0
            for key in pairs(v)do assert(integer(key,1)and key<=#v,'Sparse export array');count=count+1 end
            assert(count==#v,'Sparse export array')
            for i=1,#v do parts[#parts+1]=encode(v[i],depth+1)end
            active[v]=nil;return '['..table.concat(parts,',')..']'
        end
        for key in pairs(v)do assert(type(key)=='string','Export object keys must be strings')end
        for _,key in ipairs(sorted(v))do parts[#parts+1]=quoted(key)..':'..encode(v[key],depth+1)end
        active[v]=nil;return '{'..table.concat(parts,',')..'}'
    end
    return encode(value,0)
end
function Export.Checksum(payload)
    local a,b=1,0
    for i=1,#payload do a=(a+payload:byte(i))%65521;b=(b+a)%65521 end
    return string.format('%08x',b*65536+a)
end
function Export.Parts(payload,maxBytes)
    maxBytes=maxBytes or 8192
    assert(integer(maxBytes,4)and maxBytes<=8192,'Part size must be between 4 and 8192 bytes')
    if #payload<=maxBytes then return {payload}end
    local raw={};local first=1
    while first<=#payload do
        local last=math.min(#payload,first+maxBytes-1)
        while last<#payload and payload:byte(last+1)>=128 and payload:byte(last+1)<192 do last=last-1 end
        assert(last>=first,'Invalid UTF-8 part boundary')
        raw[#raw+1]=payload:sub(first,last);first=last+1
    end
    local checksum=Export.Checksum(payload);local parts={}
    for i,chunk in ipairs(raw)do parts[i]=Export.Encode({format=Export.PART_FORMAT,schemaVersion=1,part=i,total=#raw,
        bytes=#payload,checksum=checksum,payload=chunk})end
    return parts
end
