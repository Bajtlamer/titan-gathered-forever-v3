local _, ns = ...
local View = {}
ns.EconomyView = View

local Style = ns.Style
local columns = {
    { x = 30, width = 185, label = 'Source' },
    { x = 220, width = 130, label = 'Sales' },
    { x = 365, width = 195, label = 'Income' },
    { x = 575, width = 360, label = 'Coverage' },
}
local sources = { 'Merchant sales', 'Auction sales', 'Quest rewards', 'Mob loot', 'Total income' }

local function text(window, x, y, width, value)
    local field = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    field:SetPoint('TOPLEFT', window, 'TOPLEFT', x, y)
    field:SetWidth(width)
    field:SetJustifyH('LEFT')
    field:SetText(value or '')
    return field
end

local function band(window, y, height, shade)
    local fill = window:CreateTexture(nil, 'ARTWORK')
    fill:SetPoint('TOPLEFT', window, 'TOPLEFT', 22, y)
    fill:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -22, y)
    fill:SetHeight(height)
    fill:SetColorTexture(shade, shade * 0.81, shade * 0.58, 0.75)
end

local function detail(window, y, label)
    text(window, 30, y, 185, Style.Label(label))
    return text(window, 220, y, 350)
end

local function money(value)
    return Style.Value(ns.Economy.Coin(value))
end

local function observed(value, known, invoices, format)
    if known == 0 then return Style.Label('Unavailable') end
    return (known < invoices and Style.Label('At least ') or '') .. format(value)
end

local function characterName(db, id)
    local inventory = db.characters and db.characters[id]
    if inventory and inventory.economyName then return inventory.economyName end
    for _, key in ipairs({ 'history', 'actions', 'production', 'pvp' }) do
        local store = db[key]
        local record = store and store.characters and store.characters[id]
        if record and type(record.name) == 'string' then
            local name = record.name:match('^(%S+) %- ') or record.name:match('^(%S+)$')
            if name and name ~= id then return name end
        end
    end
end

local function characterChoices(db, realm)
    local choices = { { value = false, label = 'All characters' } }
    local scopes, ids, names = {}, {}, {}
    for _, key in ipairs({ 'vendorSales', 'questIncome', 'lootIncome' }) do
        local store = db[key]
        for id in pairs(store and store[realm] or {}) do ids[id] = true end
    end
    if ns.characterID then ids[ns.characterID] = true end
    local others = {}
    for id in pairs(ids) do
        local name = characterName(db, id)
        if name then names[name] = names[name] == nil and id or false end
        scopes[id] = { id = id, name = name or false }
        local choice = { value = id, label = name or id }
        if id == ns.characterID then
            choice.label = 'This character'
            choices[#choices + 1] = choice
        else
            others[#others + 1] = choice
        end
    end
    for _, scope in pairs(scopes) do
        if scope.name and names[scope.name] == false then scope.name = false end
    end
    for _, entry in ipairs(db.sales and db.sales.entries or {}) do
        local name = type(entry) == 'table' and entry.character
        if type(name) == 'string' and name ~= '' and entry.source == 'invoice' and entry.realm == realm and not names[name] then
            local key = 'auction:' .. name
            if not scopes[key] then
                scopes[key] = { id = false, name = name }
                others[#others + 1] = { value = key, label = name .. ' (auction history)' }
            end
        end
    end
    table.sort(others, function(a, b) return a.label < b.label end)
    for _, choice in ipairs(others) do choices[#choices + 1] = choice end
    return choices, scopes
end

function View.Refresh()
    local window = View.window
    if not window or not window:IsShown() then return end
    local realm = GetRealmName and GetRealmName()
    local db = ns.db or {}
    local ledger = db.sales
    window.choices, window.scopes = characterChoices(db, realm)
    local scope = window.scopes[window.character]
    if not scope then window.character = false end
    local id, seller
    if scope then id, seller = scope.id, scope.name end
    window.scopeNote:SetText(Style.Label(scope and 'Recorded history for the selected character'
        or 'Recorded history for all characters on this realm'))
    -- Without the Auction house module the sales are not read: the auction row says so and counts nothing.
    local total = ns.Sales and ns.Sales.Totals(ledger and ledger.entries, realm, seller)
        or { invoices = 0, units = 0, unitCount = 0, gross = 0, grossCount = 0, net = 0, netCount = 0, fees = 0,
             deposits = 0, credit = 0, creditCount = 0 }
    local vendors, auctions, quests, loot, combined = unpack(window.rows)
    local merchant = ns.VendorSales.Totals(db.vendorSales, realm, id)
    -- A sale is what the player put up and sold, one stack or a hundred: the number of sales, not of items.
    vendors.count:SetText(merchant.sales > 0 and Style.Value(merchant.sales) or Style.Label('Unavailable'))
    vendors.income:SetText(merchant.sales > 0 and money(merchant.soldCopper) or Style.Label('Unavailable'))
    vendors.coverage:SetText(Style.Label(merchant.sales > 0 and 'Verified merchant sales' or 'No verified merchant sales recorded'))
    window.vendorBuybacks:SetText(merchant.buybacks > 0 and (Style.Value(merchant.buybackUnits)
        .. Style.Label(merchant.buybackUnits == 1 and ' unit for ' or ' units for ') .. money(merchant.buybackCopper))
        or Style.Label('None recorded'))
    window.vendorRepairs:SetText(merchant.repairs > 0 and (Style.Value(merchant.repairs)
        .. Style.Label(merchant.repairs == 1 and ' repair for ' or ' repairs for ') .. money(merchant.repairCopper))
        or Style.Label('None recorded'))
    local coverage
    if not ns.Sales then
        coverage = 'Needs the Auction house module'
    elseif total.invoices == 0 then
        coverage = 'No confirmed seller invoices recorded'
    elseif total.netCount < total.invoices then
        coverage = 'Some invoices lack verified net amounts'
    else
        coverage = 'Confirmed seller invoices'
    end
    auctions.count:SetText(total.invoices > 0 and Style.Value(total.invoices) or Style.Label('Unavailable'))
    auctions.income:SetText(observed(total.net, total.netCount, total.invoices, money))
    auctions.coverage:SetText(Style.Label(coverage))
    local reward, turnIns = ns.QuestIncome.Total(db.questIncome, realm, id)
    quests.income:SetText(reward and money(reward) or Style.Label('Unavailable'))
    quests.coverage:SetText(turnIns and (Style.Value(turnIns)
        .. Style.Label(turnIns == 1 and ' verified turn-in' or ' verified turn-ins'))
        or Style.Label('No verified quest rewards recorded'))
    local looted, pickups = ns.LootIncome.Total(db.lootIncome, realm, id)
    loot.income:SetText(looted and money(looted) or Style.Label('Unavailable'))
    loot.coverage:SetText(pickups and (Style.Value(pickups)
        .. Style.Label(pickups == 1 and ' verified coin pickup' or ' verified coin pickups'))
        or Style.Label('No verified coin pickups recorded'))
    local known = merchant.sales > 0 or total.netCount > 0 or looted ~= nil or reward ~= nil
    local combinedIncome = merchant.soldCopper + total.net + (looted or 0) + (reward or 0)
    combined.income:SetText(known and (Style.Label('At least ') .. money(combinedIncome)) or Style.Label('Unavailable'))
    window.invoiceCount:SetText(Style.Value(total.invoices))
    window.gross:SetText(observed(total.gross, total.grossCount, total.invoices, money))
    window.fees:SetText(observed(total.fees, total.netCount, total.invoices, money))
    window.returned:SetText(observed(total.deposits, total.netCount, total.invoices, money))
    window.credit:SetText(observed(total.credit, total.creditCount, total.invoices, money))
end

function View.Show()
    local window = View.window
    if not window then
        local name = 'TitanGatheredForeverEconomyWindow'
        window = CreateFrame('Frame', name, UIParent, 'BasicFrameTemplateWithInset')
        View.window = window
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
        window:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag('LeftButton')
        ns.Nav.Frame(window, 'economy')
        window.TitleText:SetText('Titan Gathered Forever Economy')
        window.character = false
        window.choices = {}
        window.characterPicker = ns.Nav.Dropdown(window, 30, -42, 228, function() return window.choices end,
            function() return window.character end, function(value)
                window.character = value
                View.Refresh()
            end)
        window.scopeNote = text(window, 274, -49, 636)

        band(window, -84, 28, 0.28)
        window.columnLabels = {}
        for index, column in ipairs(columns) do
            window.columnLabels[index] = text(window, column.x, -93, column.width, Style.Label(column.label))
        end
        window.rows = {}
        for i, label in ipairs(sources) do
            local y = -112 - (i - 1) * 36
            band(window, y, 34, i == #sources and 0.23 or (i % 2 == 1 and 0.12 or 0.16))
            text(window, columns[1].x, y - 13, columns[1].width, Style.Label(label))
            window.rows[i] = {
                count = text(window, columns[2].x, y - 13, columns[2].width),
                income = text(window, columns[3].x, y - 13, columns[3].width, Style.Label('Unavailable')),
                coverage = text(window, columns[4].x, y - 13, columns[4].width),
            }
        end
        window.rows[5].coverage:SetText(Style.Label('Partial coverage'))
        band(window, -306, 28, 0.28)
        text(window, 30, -315, 360, Style.Label('Auction settlement'))
        window.invoiceCount = detail(window, -350, 'Confirmed seller invoices')
        window.gross = detail(window, -376, 'Gross sale amount')
        window.fees = detail(window, -402, 'Auction fees')
        window.returned = detail(window, -428, 'Returned deposits')
        window.credit = detail(window, -454, 'Mail credit')
        window.vendorBuybacks = detail(window, -493, 'Merchant buybacks')
        window.vendorRepairs = detail(window, -515, 'Equipment repairs')
        text(window, 30, -540, 910, Style.Label('Auction income excludes returned deposits. Merchant buybacks and equipment repairs are shown as spending.'))
    end
    ns.Nav.Activate('economy', window)
    window:Show()
    View.Refresh()
    window.characterPicker.Sync()
end
