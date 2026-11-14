local _, ns = ...
ns.Settings = {}

function ns.Settings.Initialize(saved)
    if type(saved) ~= 'table' or saved.schema ~= 1 then saved = { schema = 1 } end
    if type(saved.settings) ~= 'table' then saved.settings = {} end
    local settings = saved.settings
    if type(settings.showZero) ~= 'boolean' then settings.showZero = false end
    if type(settings.showBank) ~= 'boolean' then settings.showBank = true end
    if type(settings.debugMode) ~= 'boolean' then settings.debugMode = false end
    if type(settings.debugChat) ~= 'boolean' then settings.debugChat = false end
    if type(settings.showMinimapButton) ~= 'boolean' then settings.showMinimapButton = true end
    if type(settings.minimapButtonAngle) ~= 'number' or settings.minimapButtonAngle ~= settings.minimapButtonAngle
        or settings.minimapButtonAngle == math.huge or settings.minimapButtonAngle == -math.huge then
        settings.minimapButtonAngle = 205
    end
    if type(settings.flightPoints) ~= 'boolean' then settings.flightPoints = true end
    settings.showTotal = nil
    if type(settings.itemTooltips) ~= 'boolean' then settings.itemTooltips = true end
    if type(settings.categories) ~= 'table' then settings.categories = {} end
    for _, key in ipairs({ 'gatheringMap', 'mapMining', 'mapHerbs', 'mapSkinning', 'mapFishing', 'mapRare', 'mapPvP', 'mapWorld', 'mapMinimap' }) do
        if type(settings[key]) ~= 'boolean' then settings[key] = true end
    end
    if type(settings.recordPvP) ~= 'boolean' then settings.recordPvP = true end
    if type(settings.mapTrainers) ~= 'boolean' then settings.mapTrainers = true end
    if type(settings.mapRecipeVendors) ~= 'boolean' then settings.mapRecipeVendors = true end
    if type(settings.recordNpcs) ~= 'boolean' then settings.recordNpcs = true end
    if type(settings.auctionAutoScan) ~= 'boolean' then settings.auctionAutoScan = false end
    if type(settings.npcAxisSwap) ~= 'boolean' then settings.npcAxisSwap = false end
    if type(settings.mapNpcProfessions) ~= 'table' then settings.mapNpcProfessions = {} end
    if type(settings.recordHistory) ~= 'boolean' then settings.recordHistory = true end
    if type(settings.recordActions) ~= 'boolean' then settings.recordActions = true end
    if type(settings.recordProduction) ~= 'boolean' then settings.recordProduction = true end
    if type(settings.productionProfessions) ~= 'table' then settings.productionProfessions = {} end
    if type(settings.actionProfessions) ~= 'table' then settings.actionProfessions = {} end
    if type(settings.recordRare) ~= 'boolean' then settings.recordRare = true end
    if type(settings.historyTooltips) ~= 'boolean' then settings.historyTooltips = true end
    if type(settings.mapProfessions) ~= 'table' then settings.mapProfessions = {} end
    if type(settings.historyProfessions) ~= 'table' then settings.historyProfessions = {} end
    if type(settings.mapItems) ~= 'table' then settings.mapItems = {} end
    for _, kind in ipairs({ 'Mining', 'Herbs', 'Skinning', 'Fishing', 'Cooking', 'Alchemy', 'Blacksmithing', 'Engineering', 'FirstAid', 'Leatherworking', 'Tailoring', 'Rare' }) do
        if type(settings.mapItems[kind]) ~= 'table' then settings.mapItems[kind] = {} end
    end
    if type(settings.mapItemVisibility) ~= 'table' then settings.mapItemVisibility = {} end
    -- Migrate hidden materials once per item. Explicit shared choices take
    -- precedence on later reloads, including showing an old hidden material.
    for _, items in pairs(settings.mapItems) do
        if type(items) == 'table' then
            for itemID, visible in pairs(items) do
                if type(itemID) == 'number' and visible == false and settings.mapItemVisibility[itemID] == nil then
                    settings.mapItemVisibility[itemID] = false
                end
            end
        end
    end
    for old, current in pairs({ ['First Aid'] = 'FirstAid', Herbalism = 'Herbs', Other = 'Auction' }) do
        if settings.categories[current] == nil and type(settings.categories[old]) == 'boolean' then
            settings.categories[current] = settings.categories[old]
        end
    end
    if type(settings.rowsPerPage) ~= 'number' or settings.rowsPerPage < 5
        or settings.rowsPerPage > 40 or settings.rowsPerPage ~= math.floor(settings.rowsPerPage) then
        settings.rowsPerPage = 20
    end
    if type(saved.characters) ~= 'table' then saved.characters = {} end
    if type(saved.gathering) ~= 'table' then saved.gathering = {} end
    if type(saved.history) ~= 'table' then saved.history = {} end
    if type(saved.actions) ~= 'table' then saved.actions = {} end
    if type(saved.production) ~= 'table' then saved.production = {} end
    if type(saved.flightVisits) ~= 'table' then saved.flightVisits = {} end
    if type(saved.pvp) ~= 'table' then saved.pvp = {} end
    if type(saved.npcs) ~= 'table' then saved.npcs = {} end
    if type(saved.npcLog) ~= 'table' then saved.npcLog = {} end
    if type(saved.auctionLog) ~= 'table' then saved.auctionLog = {} end
    if type(saved.debugLog) ~= 'table' then saved.debugLog = {} end
    if type(saved.knownRecipes) ~= 'table' then saved.knownRecipes = {} end
    return saved, settings
end
