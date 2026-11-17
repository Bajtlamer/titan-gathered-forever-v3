local _, ns = ...
local Production={};Production.__index=Production;ns.Production=Production
Production.labels={Alchemy='Alchemy',Blacksmithing='Blacksmithing',Cooking='Cooking',Enchanting='Enchanting',
    Engineering='Engineering',FirstAid='First Aid',Leatherworking='Leatherworking',Mining='Smelting',Tailoring='Tailoring'}
local counters={'attempts','completed','failed','interrupted','matched','quantity','bonusKnown','bonusHits','multicraftKnown','multicraftHits'}
local outcomes={UNIT_SPELLCAST_SUCCEEDED='completed',UNIT_SPELLCAST_FAILED='failed',UNIT_SPELLCAST_INTERRUPTED='interrupted'}
local function integer(n)return type(n)=='number' and n>0 and n<math.huge and n==math.floor(n)end
local skillKinds={[171]='Alchemy',[164]='Blacksmithing',[185]='Cooking',[333]='Enchanting',[202]='Engineering',
    [129]='FirstAid',[165]='Leatherworking',[186]='Mining',[197]='Tailoring'}
local function metadata(method,...)
    if type(method)~='function' then return end
    local ok,value=pcall(method,...)
    if ok and ns.IsPublic(value)and type(value)=='table'then return value end
end
local function readable(record,keys)
    if not record then return false end
    for _,key in ipairs(keys)do if not ns.IsPublic(record[key])then return false end end
    return true
end
function Production.Recipe(recipeID)
    if not integer(recipeID)or not C_TradeSkillUI then return end
    local info=metadata(C_TradeSkillUI.GetRecipeInfo,recipeID)
    local profession=metadata(C_TradeSkillUI.GetProfessionInfoByRecipeID,recipeID)
    local schematic=metadata(C_TradeSkillUI.GetRecipeSchematic,recipeID,false)
    if not readable(info,{'recipeID','name','learned','qualityItemIDs','isRecraft','isDummyRecipe',
        'isGatheringRecipe','isEnchantingRecipe','isSalvageRecipe'})
        or not readable(profession,{'professionID','parentProfessionID'})
        or not readable(schematic,{'recipeID','recipeType','isRecraft','outputItemID'})then return end
    if info.recipeID~=recipeID or schematic.recipeID~=recipeID or info.learned~=true
        or type(info.name)~='string' or schematic.isRecraft~=false or schematic.recipeType~=1
        or not integer(schematic.outputItemID)then return end
    for _,flag in ipairs({'isRecraft','isDummyRecipe','isGatheringRecipe','isEnchantingRecipe','isSalvageRecipe'})do
        if info[flag]~=false then return end
    end
    local kind=skillKinds[profession.parentProfessionID]or skillKinds[profession.professionID]
    if not kind then return end
    local ids={[schematic.outputItemID]=true}
    if type(info.qualityItemIDs)=='table'then
        for _,id in ipairs(info.qualityItemIDs)do
            if not ns.IsPublic(id)then return end
            if integer(id)then ids[id]=true end
        end
    end
    local reagents,reagentsSupported
    local craftingRecipe=ns.Crafting and ns.Crafting.Read(recipeID)
    if craftingRecipe then reagents,reagentsSupported=ns.Crafting.FixedReagents(craftingRecipe)end
    return {recipeID=recipeID,kind=kind,name=info.name,outputItemID=schematic.outputItemID,
        outputIDs=ids,reagents=reagents,reagentsSupported=reagentsSupported==true}
end
function Production.Enabled(kind)
    local s=ns.settings
    return s and s.recordProduction and Production.labels[kind]~=nil and ns.Catalog.modules[kind]~=nil
        and s.categories[kind]~=false and s.productionProfessions[kind]~=false
end
function Production.SettingsChanged()
    local keys={};for kind in pairs(Production.labels)do keys[#keys+1]=kind end;table.sort(keys)
    local parts={tostring(ns.settings.recordProduction)}
    for _,kind in ipairs(keys)do parts[#parts+1]=tostring(Production.Enabled(kind))end
    local signature=table.concat(parts,':')
    if Production.signature and signature~=Production.signature and ns.production then ns.production:Pause()end
    Production.signature=signature
end
function Production.New(saved,api)
    if not saved.schema then saved.schema=1 end
    if saved.schema==1 and type(saved.characters)~='table' then saved.characters={} end
    if saved.schema==1 and not saved.reagentCoverageBegan then saved.reagentCoverageBegan=api.Timestamp()end
    local self=setmetatable({saved=saved,api=api,operations={},operationOrder={}},Production)
    self:Pause();return self
end
function Production:Pause()
    if self.saved.schema~=1 then return end
    for _,c in pairs(self.saved.characters)do for _,r in pairs(c.recent)do
        r.sealed=true;r.pending={};r.timestamp=r.timestamp or self.api.Timestamp()
    end end
end
function Production:Changed()if self.api.Changed then self.api.Changed()end end
function Production:Cast(event,unit,guid,recipeID)
    if self.saved.schema~=1 or unit~='player' or type(guid)~='string' or guid=='' then return end
    if event~='UNIT_SPELLCAST_START' and not outcomes[event] then return end
    local character=self.api.Character();if not character then return end
    local c=self.saved.characters[character];local receipt=c and c.recent[guid]
    if receipt and (receipt.sealed or receipt.recipeID~=recipeID)then return end
    if not receipt then
        if event~='UNIT_SPELLCAST_START' then return end
        local ok,recipe=pcall(self.api.Recipe,recipeID)
        if not ok or not recipe or not self.api.Enabled(recipe.kind) then return end
        if not c then c={name=self.api.Name(),recipes={},items={},recent={},order={}};self.saved.characters[character]=c end
        local row=c.recipes[recipeID]
        if not row then
            row={recipeID=recipeID,kind=recipe.kind,name=recipe.name,itemID=recipe.outputItemID,began=self.api.Timestamp(),
                outputs={},reagentUse={},reagentUnsupportedCasts=0,reagentCoverageBegan=self.saved.reagentCoverageBegan}
            for _,key in ipairs(counters)do row[key]=0 end
            c.recipes[recipeID]=row
        end
        local reagentMap,reagentsSupported
        if recipe.reagentsSupported==true and type(recipe.reagents)=='table' then
            reagentMap={};reagentsSupported=true
            for itemID,quantity in pairs(recipe.reagents)do
                if not integer(itemID)or not integer(quantity)then reagentMap=nil;reagentsSupported=false;break end
                reagentMap[itemID]=quantity
            end
            if not next(reagentMap or {})then reagentMap=nil;reagentsSupported=false end
        end
        receipt={recipeID=recipeID,kind=recipe.kind,outputIDs=recipe.outputIDs,reagents=reagentMap,
            reagentsSupported=reagentsSupported==true,at=self.api.Now(),timestamp=self.api.Timestamp(),pending={},seen={},outputs={}}
        c.recent[guid]=receipt;c.order[#c.order+1]=guid;row.attempts=row.attempts+1
        if #c.order>1024 then c.recent[table.remove(c.order,1)]=nil end
    end
    if not self.api.Enabled(receipt.kind) then return end
    local row=c.recipes[recipeID];row.lastSeen=self.api.Timestamp()
    local outcome=outcomes[event]
    if outcome and not receipt.outcome then
        receipt.outcome=outcome;row[outcome]=row[outcome]+1
        if outcome=='completed'then
            if receipt.reagentsSupported then
                for itemID,quantity in pairs(receipt.reagents)do
                    row.reagentUse=row.reagentUse or{}
                    row.reagentUse[itemID]=(row.reagentUse[itemID]or 0)+quantity
                end
            else row.reagentUnsupportedCasts=(row.reagentUnsupportedCasts or 0)+1 end
        end
    end
    if receipt.outcome=='completed' then self:Flush(c,receipt)
    elseif receipt.outcome then receipt.pending={} end
    self:Changed()
end
function Production:Flag(row,receipt,key,value)
    if value==nil then return end
    local prior=receipt[key]
    if prior==nil then row[key..'Known']=row[key..'Known']+1 end
    if value and not prior then row[key..'Hits']=row[key..'Hits']+1 end
    receipt[key]=prior or value
end
function Production:Flush(c,receipt)
    if receipt.sealed or receipt.outcome~='completed' then return end
    local row=c.recipes[receipt.recipeID]
    for _,data in ipairs(receipt.pending)do
        if not receipt.matched then row.matched=row.matched+1;receipt.matched=true end
        local output=row.outputs[data.itemID]
        if not output then output={quantity=0,hits=0,distribution={}};row.outputs[data.itemID]=output end
        local prior=receipt.outputs[data.itemID]or 0
        if prior>0 then output.distribution[prior]=output.distribution[prior]-1
        else output.hits=output.hits+1 end
        local total=prior+data.quantity;receipt.outputs[data.itemID]=total
        output.distribution[total]=(output.distribution[total]or 0)+1
        output.quantity=output.quantity+data.quantity;row.quantity=row.quantity+data.quantity
        local item=c.items[data.itemID]or{quantity=0};c.items[data.itemID]=item
        item.quantity=item.quantity+data.quantity;item.lastSeen=self.api.Timestamp()
        self:Flag(row,receipt,'bonus',data.bonus)
        self:Flag(row,receipt,'multicraft',data.multicraft)
    end
    receipt.pending={}
end
function Production:Result(data)
    if self.saved.schema~=1 or not self.api.Public(data) or type(data)~='table' then return end
    for _,key in ipairs({'operationID','itemID','quantity','itemGUID','firstCraftReward','isEnchant'})do
        if not self.api.Public(data[key]) then return end
    end
    if not integer(data.operationID)or not integer(data.itemID)or not integer(data.quantity)
        or type(data.itemGUID)~='string'or data.itemGUID==''
        or data.firstCraftReward~=false or data.isEnchant~=false then return end
    local character=self.api.Character();local c=self.saved.characters[character];if not c then return end
    local operation=character..':'..tostring(data.operationID)
    local guid=self.operations[operation];local receipt=guid and c.recent[guid]
    if guid and not receipt then return end
    if not receipt then
        local recipeID
        -- Results contain no cast or recipe identity. Recent sealed contexts can
        -- explain a delayed result, so they must block attribution to a new cast.
        for _,candidate in pairs(c.recent)do
            if candidate.sealed and candidate.outputIDs[data.itemID]
                and self.api.Timestamp()-candidate.timestamp<=60 then return end
        end
        for _,candidateGUID in ipairs(c.order)do
            local candidate=c.recent[candidateGUID]
            if not candidate.sealed and not candidate.operation and (not candidate.outcome or candidate.outcome=='completed')
                and self.api.Now()-candidate.at<=60 and candidate.outputIDs[data.itemID] and self.api.Enabled(candidate.kind) then
                if recipeID and recipeID~=candidate.recipeID then return end
                recipeID=candidate.recipeID
                if not receipt then receipt=candidate;guid=candidateGUID end
            end
        end
        if not receipt then return end
        receipt.operation=operation;self.operations[operation]=guid;self.operationOrder[#self.operationOrder+1]=operation
        if #self.operationOrder>1024 then self.operations[table.remove(self.operationOrder,1)]=nil end
    end
    if receipt.sealed or not self.api.Enabled(receipt.kind) or self.api.Now()-receipt.at>60
        or (receipt.outcome and receipt.outcome~='completed') then return end
    local key=tostring(data.itemID)..':'..data.itemGUID
    if receipt.seen[key]then return end
    receipt.seen[key]=true
    local bonus,multicraft
    if self.api.Public(data.bonusCraft)and type(data.bonusCraft)=='boolean'then bonus=data.bonusCraft end
    if self.api.Public(data.multicraft)and type(data.multicraft)=='number'and data.multicraft>=0
        and data.multicraft<math.huge then multicraft=data.multicraft>0 end
    receipt.pending[#receipt.pending+1]={itemID=data.itemID,quantity=data.quantity,bonus=bonus,multicraft=multicraft}
    self:Flush(c,receipt);self:Changed()
end
function Production:Rows(character)
    if self.saved.schema~=1 then return {} end
    local combined={}
    for id,c in pairs(self.saved.characters)do if not character or id==character then
        for recipeID,source in pairs(c.recipes)do
            local key=source.kind..':'..recipeID;local row=combined[key]
            if not row then
                row={recipeID=recipeID,kind=source.kind,name=source.name,itemID=source.itemID,began=source.began,
                    outputs={},reagentUse={},reagentUnsupportedCasts=0,reagentCoverageBegan=source.reagentCoverageBegan}
                for _,counter in ipairs(counters)do row[counter]=0 end;combined[key]=row
            end
            row.began=math.min(row.began,source.began)
            for _,counter in ipairs(counters)do row[counter]=row[counter]+source[counter]end
            row.reagentUnsupportedCasts=row.reagentUnsupportedCasts+(source.reagentUnsupportedCasts or 0)
            if source.reagentCoverageBegan then
                row.reagentCoverageBegan=math.min(row.reagentCoverageBegan or source.reagentCoverageBegan,source.reagentCoverageBegan)
            end
            for itemID,quantity in pairs(source.reagentUse or{})do
                row.reagentUse[itemID]=(row.reagentUse[itemID]or 0)+quantity
            end
            for itemID,output in pairs(source.outputs)do
                local t=row.outputs[itemID]or{quantity=0,hits=0,distribution={}};row.outputs[itemID]=t
                t.quantity=t.quantity+output.quantity;t.hits=t.hits+output.hits
                for quantity,count in pairs(output.distribution)do t.distribution[quantity]=(t.distribution[quantity]or 0)+count end
            end
        end
    end end
    local rows={};for _,row in pairs(combined)do rows[#rows+1]=row end
    table.sort(rows,function(a,b)if a.kind~=b.kind then return a.kind<b.kind end;return a.recipeID<b.recipeID end)
    return rows
end
function Production:Totals(character)
    if self.saved.schema~=1 then return {} end
    local totals={}
    for id,c in pairs(self.saved.characters)do if not character or id==character then
        for itemID,source in pairs(c.items)do
            local row=totals[itemID]or{itemID=itemID,quantity=0,lastSeen=0};totals[itemID]=row
            row.quantity=row.quantity+source.quantity;row.lastSeen=math.max(row.lastSeen,source.lastSeen or 0)
        end
    end end
    local rows={};for _,row in pairs(totals)do rows[#rows+1]=row end
    table.sort(rows,function(a,b)return a.itemID<b.itemID end);return rows
end
function Production:Total(character,itemID)
    if self.saved.schema~=1 then return 0 end
    local quantity=0
    for id,c in pairs(self.saved.characters)do
        if (not character or id==character)and c.items[itemID]then quantity=quantity+c.items[itemID].quantity end
    end
    return quantity
end
function Production:ReagentUsage(character)
    local usage,unsupported={},0
    for _,recipe in ipairs(self:Rows(character))do
        unsupported=unsupported+(recipe.reagentUnsupportedCasts or 0)
        for itemID,quantity in pairs(recipe.reagentUse or{})do
            local row=usage[itemID]or{itemID=itemID,quantity=0,professions={},coverageBegan=self.saved.reagentCoverageBegan,incomplete=false}
            usage[itemID]=row;row.quantity=row.quantity+quantity
            row.professions[recipe.kind]=(row.professions[recipe.kind]or 0)+quantity
        end
    end
    local rows={}
    for _,row in pairs(usage)do
        local leading,maximum
        for kind,quantity in pairs(row.professions)do
            if not maximum or quantity>maximum or(quantity==maximum and kind<leading)then leading,maximum=kind,quantity end
        end
        row.leading, row.share=leading,maximum/row.quantity*100
        rows[#rows+1]=row
    end
    table.sort(rows,function(a,b)return a.itemID<b.itemID end)
    return rows,{coverageBegan=self.saved.reagentCoverageBegan,unsupportedCasts=unsupported}
end
