local _, ns = ...
local Crafting={};ns.Crafting=Crafting
local function integer(n,max)return type(n)=='number'and n>=1 and n<math.huge and n==math.floor(n)and n<=(max or 1000000)end
local function array(value)
    if not ns.IsPublic(value)or type(value)~='table'or #value>128 then return false end
    local count=0
    for key in pairs(value)do
        if not ns.IsPublic(key)or not integer(key,128)or key>#value then return false end
        count=count+1
    end
    return count==#value
end
local function readable(value,keys)
    if not ns.IsPublic(value)or type(value)~='table'then return false end
    for _,key in ipairs(keys)do if not ns.IsPublic(value[key])then return false end end
    return true
end
local skillKinds={[171]='Alchemy',[164]='Blacksmithing',[185]='Cooking',[333]='Enchanting',[202]='Engineering',
    [129]='FirstAid',[165]='Leatherworking',[186]='Mining',[197]='Tailoring'}
local function metadata(method,...)
    if type(method)~='function'then return end
    local ok,value=pcall(method,...)
    if ok and ns.IsPublic(value)and type(value)=='table'then return value end
end
function Crafting.Read(recipeID)
    if not integer(recipeID,2147483647)or not C_TradeSkillUI or not ns.settings then return end
    local info=metadata(C_TradeSkillUI.GetRecipeInfo,recipeID)
    if not readable(info,{'recipeID','name','learned','isRecraft','isDummyRecipe','isGatheringRecipe','isSalvageRecipe'})
        or info.recipeID~=recipeID or type(info.name)~='string'or type(info.learned)~='boolean'then return end
    for _,flag in ipairs({'isRecraft','isDummyRecipe','isGatheringRecipe','isSalvageRecipe'})do if info[flag]~=false then return end end
    local profession=metadata(C_TradeSkillUI.GetProfessionInfoByRecipeID,recipeID)
    if not readable(profession,{'professionID','parentProfessionID'})then return end
    local kind=skillKinds[profession.parentProfessionID]or skillKinds[profession.professionID]
    if not kind or not ns.Catalog.modules[kind]or ns.settings.categories[kind]==false then return end
    local schematic=metadata(C_TradeSkillUI.GetRecipeSchematic,recipeID,false)
    if not readable(schematic,{'recipeID','isRecraft','recipeType','reagentSlotSchematics'})or schematic.recipeID~=recipeID
        or schematic.isRecraft~=false or (schematic.recipeType~=1 and schematic.recipeType~=3)
        or not array(schematic.reagentSlotSchematics)then return end
    return {recipeID=recipeID,name=info.name,learned=info.learned,kind=kind,slots=schematic.reagentSlotSchematics}
end
function Crafting.Plan(recipeID,operations)
    local recipe=Crafting.Read(recipeID)
    if not recipe then return {rows={},issues={},error='Recipe unavailable, unsupported, or profession addon/category disabled.'}end
    return Crafting.Compute(recipe,ns.inventory,ns.settings.showBank,operations or 1)
end
function Crafting.Select(info,native)
    Crafting.selectedID=nil
    if native and readable(info,{'recipeID','nextRecipeID'})then
        if Professions and type(Professions.GetHighestLearnedRecipe)=='function'then
            local ok,highest=pcall(Professions.GetHighestLearnedRecipe,info)
            if not ok or not ns.IsPublic(highest)then return end
            if highest then info=highest end
        elseif info.nextRecipeID~=nil then return end
    elseif native then return end
    if readable(info,{'recipeID'})and integer(info.recipeID,2147483647)then Crafting.selectedID=info.recipeID end
end
function Crafting.Initialize()
    if Crafting.registered or not EventRegistry or not EventRegistry.RegisterCallback then return end
    EventRegistry:RegisterCallback('ProfessionsRecipeListMixin.Event.OnRecipeSelected',function(_,info)Crafting.Select(info,true)end,Crafting)
    Crafting.registered=true
end
function Crafting.Context(itemID)
    if not Crafting.selectedID or not ns.inventory then return end
    local plan=Crafting.Plan(Crafting.selectedID,1)
    for _,row in ipairs(plan.rows)do if row.itemID==itemID then return row,plan end end
end
function Crafting.Compute(recipe,inventory,showBank,operations)
    local p={rows={},issues={},operations=operations,scope=showBank and'Bags + Bank'or'Bags',cached=false,unknown=false}
    if not integer(operations)then p.error='Operations must be a whole number from 1 to 1000000.';return p end
    if not recipe or not array(recipe.slots)then p.error='Recipe reagent data is unavailable.';return p end
    p.recipeID,p.name,p.kind,p.learned=recipe.recipeID,recipe.name,recipe.kind,recipe.learned
    local quantities,indices={},{}
    for _,slot in ipairs(recipe.slots)do
        local valid=readable(slot,{'required','reagentType','slotIndex'})
            and type(slot.required)=='boolean'and integer(slot.slotIndex,128)and not indices[slot.slotIndex]
        if valid then indices[slot.slotIndex]=true end
        if valid and slot.required==false and (slot.reagentType==0 or slot.reagentType==2)then
            p.optionalExcluded=true
        else
            valid=valid and slot.reagentType==1 and readable(slot,{'quantityRequired','reagents','variableQuantities','dataSlotType'})
                and integer(slot.quantityRequired)and slot.dataSlotType==(Enum and Enum.TradeskillSlotDataType and Enum.TradeskillSlotDataType.Reagent or 1)
                and array(slot.reagents)and #slot.reagents==1
                and array(slot.variableQuantities)and #slot.variableQuantities==0
            local reagent=valid and slot.reagents[1]
            valid=valid and readable(reagent,{'itemID','currencyID'})and integer(reagent.itemID,2147483647)and reagent.currencyID==nil
            if valid then quantities[reagent.itemID]=(quantities[reagent.itemID]or 0)+slot.quantityRequired
            else p.issues[#p.issues+1]='A required or unreadable slot needs an unsupported reagent choice or quantity.'end
        end
    end
    local limit=math.huge
    for id,perOperation in pairs(quantities)do
        local ok,count=pcall(inventory.Get,inventory,id)
        if not ok or type(count)~='table'then count={}end
        local function amount(value,state)
            if (state~='current'and state~='cached')or type(value)~='number'or value<0 or value~=math.floor(value)or value==math.huge then
                p.unknown=true;return 0
            end
            if state=='cached'then p.cached=true end
            return value
        end
        local available=amount(count.bags,count.bagsState)
        if showBank then
            available=available+amount(count.bank,count.bankState)
            if count.bankState=='cached'and type(count.bankObservedAt)=='number'then
                p.bankObservedAt=math.min(p.bankObservedAt or count.bankObservedAt,count.bankObservedAt)
            end
        end
        local required=perOperation*operations
        p.rows[#p.rows+1]={itemID=id,perOperation=perOperation,required=required,available=available,missing=math.max(0,required-available)}
        limit=math.min(limit,math.floor(available/perOperation))
    end
    if #p.rows==0 then p.issues[#p.issues+1]='No complete fixed item-reagent requirements are available.'end
    if #p.issues==0 and not p.unknown and limit<math.huge then p.craftable=limit end
    table.sort(p.rows,function(a,b)return a.itemID<b.itemID end)
    return p
end
function Crafting.Evidence(itemID,character)
    local result={rates={},spots={}}
    if ns.history then for _,row in ipairs(ns.history:Rates(character,itemID))do result.rates[#result.rates+1]=row end end
    table.sort(result.rates,function(a,b)
        if a.trials~=b.trials then return a.trials>b.trials end
        if (a.mapID or 0)~=(b.mapID or 0)then return (a.mapID or 0)<(b.mapID or 0)end
        return tostring(a.source)<tostring(b.source)
    end)
    if ns.gathering then for mapID,nodes in pairs(ns.gathering.saved.maps)do
        if type(mapID)=='number'and mapID>0 and type(nodes)=='table'then
            local positions=0
            for _,node in ipairs(nodes)do if node.itemID==itemID and node.kind~='Enchanting'then positions=positions+1 end end
            if positions>0 then result.spots[#result.spots+1]={mapID=mapID,positions=positions}end
        end
    end end
    table.sort(result.spots,function(a,b)return a.mapID<b.mapID end)
    return result
end
