local _, ns = ...
local History = {}
ns.AuctionHistory = History

local DAY, PRICE_DAYS, SALES_DAYS = 86400, 7, 30
local WIDTH, HEIGHT = 300, 342
local Style = ns.Style

local function positive(value)
    return type(value) == 'number' and value > 0 and value < math.huge and value == math.floor(value)
end

-- The current scan also serves as today's observation. Archive it only when another scan replaces it.
function History.Archive(db, now, currentRealm)
    local realms = type(db.auctionHistory) == 'table' and db.auctionHistory or {}
    db.auctionHistory = realms
    local today = math.floor(now / DAY)
    local first = today - PRICE_DAYS + 1
    for realm, days in pairs(realms) do
        for day in pairs(days) do
            if day < first or day > today or (day == today and realm == currentRealm) then days[day] = nil end
        end
        if not next(days) then realms[realm] = nil end
    end
    local scan = db.auction
    if type(scan) ~= 'table' or type(scan.realm) ~= 'string' or not positive(scan.at) or scan.at > now then return end
    local day = math.floor(scan.at / DAY)
    if day < first or (day == today and scan.realm == currentRealm) then return end
    local days = realms[scan.realm] or {}
    realms[scan.realm] = days
    if days[day] and days[day].at >= scan.at then return end
    local prices = {}
    for itemID, packed in pairs(scan.others or {}) do
        if positive(packed) then prices[itemID] = ns.AuctionScan.Unpack(packed) end
    end
    for itemID, entry in pairs(scan.items or {}) do
        if type(entry) == 'table' and positive(entry.min) then prices[itemID] = entry.min end
    end
    days[day] = { at = scan.at, prices = prices }
end

function History.Prices(db, realm, itemID, now)
    local days = db.auctionHistory and db.auctionHistory[realm] or {}
    local scan, currentPrice = db.auction
    if type(scan) ~= 'table' or scan.realm ~= realm or not positive(scan.at) or scan.at > now then
        scan = nil
    else
        local entry = scan.items and scan.items[itemID]
        local packed = scan.others and scan.others[itemID]
        currentPrice = type(entry) == 'table' and entry.min or (positive(packed) and ns.AuctionScan.Unpack(packed))
    end
    local today = math.floor(now / DAY)
    local scanDay = scan and math.floor(scan.at / DAY)
    local points, latest = {}
    for day = today - PRICE_DAYS + 1, today do
        local snapshot = days[day]
        local at, price
        if scanDay == day and (not snapshot or scan.at >= snapshot.at) then
            at, price = scan.at, currentPrice
        elseif snapshot and snapshot.at <= now then
            at, price = snapshot.at, snapshot.prices[itemID]
        end
        if positive(price) then
            latest = { at = at, price = price }
            points[#points + 1] = latest
        end
    end
    if not latest and positive(currentPrice) then latest = { at = scan.at, price = currentPrice } end
    return points, latest
end

-- Use invoice prices before fees. A mail payout can include a returned deposit.
function History.Sales(entries, realm, itemID, now)
    local result = { sales = 0, knownUnits = 0, completeQuantity = true, pricedSales = 0 }
    local totalPrice, pricedUnits = 0, 0
    local first = now - SALES_DAYS * DAY
    for _, entry in ipairs(entries or {}) do
        if type(entry) == 'table' and entry.realm == realm and entry.itemID == itemID
            and type(entry.soldAt) == 'number' and entry.soldAt >= first and entry.soldAt <= now then
            result.sales = result.sales + 1
            local unitPrice
            if positive(entry.count) then
                result.knownUnits = result.knownUnits + entry.count
                if entry.source == 'invoice' and positive(entry.buyout) then
                    totalPrice = totalPrice + entry.buyout
                    pricedUnits = pricedUnits + entry.count
                    result.pricedSales = result.pricedSales + 1
                    unitPrice = entry.buyout / entry.count
                end
            else
                result.completeQuantity = false
            end
            if not result.last or entry.soldAt >= result.last.at then
                result.last = { at = entry.soldAt, price = unitPrice }
            end
        end
    end
    if pricedUnits > 0 then result.average = totalPrice / pricedUnits end
    return result
end

local function money(price)
    return price and ns.Economy.Coin(price) or Style.Label('Unavailable')
end

local function text(parent, point, x, y, value, font)
    local line = parent:CreateFontString(nil, 'OVERLAY', font or 'GameFontNormalSmall')
    line:SetPoint(point, parent, point, x, y)
    line:SetJustifyH(point == 'TOPRIGHT' and 'RIGHT' or 'LEFT')
    line:SetText(value)
    return line
end

local function box(parent, x, y, width, height, r, g, b, alpha)
    local fill = parent:CreateTexture(nil, 'ARTWORK')
    fill:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
    fill:SetSize(width, height)
    fill:SetColorTexture(r, g, b, alpha)
    return fill
end

local function section(panel, y, title, days)
    box(panel, 12, y, WIDTH - 24, 22, 0.16, 0.09, 0.045, 0.7)
    box(panel, 12, y - 22, WIDTH - 24, 1, 0.55, 0.36, 0.17, 0.7)
    text(panel, 'TOPLEFT', 16, y - 5, Style.Label(title), 'GameFontNormal')
    text(panel, 'TOPRIGHT', -16, y - 6, Style.Value(days) .. Style.Label(' days'))
end

local function row(panel, y, label)
    text(panel, 'TOPLEFT', 16, y, Style.Label(label))
    return text(panel, 'TOPRIGHT', -16, y)
end

local function createChart(panel)
    local chart = CreateFrame('Frame', nil, panel)
    chart:SetPoint('TOPLEFT', panel, 'TOPLEFT', 14, -132)
    chart:SetSize(WIDTH - 28, 74)
    box(chart, 0, 0, WIDTH - 28, 74, 0.035, 0.025, 0.018, 0.9)
    chart.high = text(chart, 'TOPLEFT', 5, -3)
    chart.low = text(chart, 'TOPLEFT', 5, -59)
    chart.note = chart:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    chart.note:SetPoint('CENTER')
    chart.start = text(panel, 'TOPLEFT', 14, -211)
    chart.finish = text(panel, 'TOPRIGHT', -14, -211)
    chart.lines, chart.dots = {}, {}
    for i = 1, PRICE_DAYS do
        chart.dots[i] = box(chart, 0, 0, 4, 4, 1, 0.8, 0.3, 1)
        if i < PRICE_DAYS then
            local line = chart:CreateLine(nil, 'ARTWORK')
            line:SetThickness(2)
            line:SetColorTexture(0.95, 0.68, 0.25, 1)
            chart.lines[i] = line
        end
    end
    return chart
end

local function drawChart(chart, points)
    local trend = #points > 1
    for i, dot in ipairs(chart.dots) do dot:SetShown(trend and i <= #points) end
    for i, line in ipairs(chart.lines) do line:SetShown(i < #points) end
    chart.note:SetShown(not trend)
    if not trend then
        chart.high:SetText(''); chart.low:SetText('')
        chart.start:SetText(''); chart.finish:SetText('')
        chart.note:SetText(Style.Label(#points == 1 and 'One scan day recorded' or 'No scan prices in this period'))
        return
    end
    local first, last = points[1], points[#points]
    local high, low = first.price, first.price
    for _, point in ipairs(points) do
        high, low = math.max(high, point.price), math.min(low, point.price)
    end
    local previousX, previousY
    for i, point in ipairs(points) do
        local x = 90 + (WIDTH - 128) * (point.at - first.at) / (last.at - first.at)
        local y = high == low and -37 or -65 + 56 * (point.price - low) / (high - low)
        local dot = chart.dots[i]
        dot:ClearAllPoints()
        dot:SetPoint('CENTER', chart, 'TOPLEFT', x, y)
        if previousX then
            local line = chart.lines[i - 1]
            line:SetStartPoint('TOPLEFT', chart, previousX, previousY)
            line:SetEndPoint('TOPLEFT', chart, x, y)
        end
        previousX, previousY = x, y
    end
    chart.high:SetText(money(high))
    chart.low:SetText(high ~= low and money(low) or '')
    chart.start:SetText(Style.Date(date('%d %b', first.at)))
    chart.finish:SetText(Style.Date(date('%d %b', last.at)))
end

local function render(view, itemID)
    local now, realm = time(), GetRealmName()
    local points, latest = History.Prices(ns.db, realm, itemID, now)
    local sales = History.Sales(ns.db.sales and ns.db.sales.entries, realm, itemID, now)
    view.item:SetText(Style.Value(ns.ItemName(itemID)))
    view.price:SetText(money(latest and latest.price))
    view.scanDate:SetText(latest and (Style.Label('Scanned ') .. Style.Date(date('%d %b %H:%M', latest.at))) or '')
    local trend = ''
    if #points > 1 then
        local change = (points[#points].price / points[1].price - 1) * 100
        trend = Style.Label('Trend ') .. Style.Text(change > 0 and Style.green or change < 0 and Style.red or Style.white,
            string.format('%+.1f%%', change))
    end
    view.trend:SetText(trend)
    drawChart(view.chart, points)
    local units = money(nil)
    if sales.sales == 0 then
        units = Style.Label('None recorded')
    elseif sales.completeQuantity then
        units = Style.Value(sales.knownUnits)
    elseif sales.knownUnits > 0 then
        units = Style.Label('At least ') .. Style.Value(sales.knownUnits)
    end
    view.units:SetText(units)
    view.average:SetText(money(sales.average))
    view.last:SetText(sales.last and
        (Style.Date(date('%d %b', sales.last.at)) .. '   ' .. money(sales.last.price)) or money(nil))
    view.salesNote:SetText(sales.pricedSales > 0 and sales.pricedSales < sales.sales
        and Style.Label('Average uses sales with known prices and quantities.') or '')
end

local function selectedItem(sell)
    local location = sell:GetItem()
    if location and location:IsValid() then
        local itemID = C_Item.GetItemID(location)
        if ns.IsPublic(itemID) and positive(itemID) then return itemID end
    end
end

local function canDock(frame)
    local left, screenLeft = frame:GetLeft(), UIParent:GetLeft()
    if not left or not screenLeft then return false end
    return left * frame:GetEffectiveScale() - screenLeft * UIParent:GetEffectiveScale()
        >= (WIDTH + 8) * frame:GetEffectiveScale()
end

function History.Refresh()
    local view = History.view
    if not view then return end
    local itemID
    for _, sell in ipairs(view.forms) do
        if sell:IsVisible() then
            local ok, id = pcall(selectedItem, sell)
            if ok and id then itemID = id; break end
        end
    end
    view.itemID = itemID
    if not itemID then
        view.panel:Hide(); view.toggle:Hide()
        return
    end
    local docked = canDock(view.frame)
    local expanded = ns.settings.auctionHistoryCollapsed ~= true and (docked or view.overlayRequested == true)
    if expanded and (view.docked ~= docked or not view.panel:IsVisible()) then
        view.panel:ClearAllPoints()
        if docked then
            view.panel:SetPoint('TOPRIGHT', view.frame, 'TOPLEFT', -3, -42)
        else
            view.panel:SetPoint('TOPLEFT', view.frame, 'TOPLEFT', 8, -52)
        end
    end
    view.docked = docked
    if expanded then render(view, itemID) end
    view.panel:SetShown(expanded)
    view.toggle:SetShown(not expanded)
end

function History.Attach(frame)
    if History.view then return History.view end
    if not frame or not frame.ItemSellFrame or not frame.CommoditiesSellFrame then return end
    local forms = { frame.CommoditiesSellFrame, frame.ItemSellFrame }
    for _, sell in ipairs(forms) do
        if type(sell.GetItem) ~= 'function' or type(sell.SetItem) ~= 'function' then return end
    end
    local panel = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    panel:Hide()
    panel:SetClampedToScreen(true)
    panel:SetFrameLevel(frame:GetFrameLevel() + 30)
    panel:EnableMouse(true)
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetBackdrop({
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background-Dark',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Gold-Border',
        edgeSize = 18, insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    panel:SetBackdropColor(0.57, 0.48, 0.38, 1)
    panel:SetBackdropBorderColor(0.91, 0.76, 0.56, 1)
    box(panel, 8, -8, WIDTH - 16, 27, 0.15, 0.08, 0.035, 0.96)
    text(panel, 'TOPLEFT', 16, -15, Style.Label('Market history'), 'GameFontNormal')
    local item = text(panel, 'TOPLEFT', 16, -44, '', 'GameFontHighlight')
    item:SetWidth(WIDTH - 32)
    item:SetWordWrap(false)
    local hide = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    hide:SetSize(94, 19)
    hide:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -12, -12)
    hide:SetText('Hide history')
    hide:SetScript('OnClick', function()
        ns.settings.auctionHistoryCollapsed = true
        History.view.overlayRequested = nil
        History.Refresh()
    end)
    local toggle = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
    toggle:Hide()
    toggle:SetFrameLevel(frame:GetFrameLevel() + 30)
    toggle:SetSize(106, 20)
    toggle:SetPoint('TOPLEFT', frame, 'TOPLEFT', 73, -11)
    toggle:SetText('Show history')
    toggle:SetScript('OnClick', function()
        ns.settings.auctionHistoryCollapsed = false
        History.view.overlayRequested = not canDock(frame)
        History.Refresh()
    end)
    section(panel, -66, 'Auction prices', PRICE_DAYS)
    section(panel, -228, 'Your sales', SALES_DAYS)
    local view = {
        frame = frame, forms = forms, panel = panel, toggle = toggle, hide = hide, item = item,
        price = row(panel, -96, 'Last scanned buyout / unit'),
        scanDate = text(panel, 'TOPLEFT', 16, -114),
        trend = text(panel, 'TOPRIGHT', -16, -114),
        chart = createChart(panel),
        units = row(panel, -259, 'Units sold'),
        average = row(panel, -278, 'Average / unit'),
        last = row(panel, -297, 'Last sale (est. date)'),
        salesNote = text(panel, 'TOPLEFT', 16, -317),
    }
    History.view = view
    local elapsed = 0
    local function follow(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.15 then return end
        elapsed = 0
        if view.docked ~= canDock(frame) then History.Refresh() end
    end
    panel:SetScript('OnUpdate', follow)
    toggle:SetScript('OnUpdate', follow)
    frame:HookScript('OnHide', function()
        view.overlayRequested = nil
        History.Refresh()
    end)
    frame:HookScript('OnShow', History.Refresh)
    for _, sell in ipairs(forms) do
        sell:HookScript('OnShow', History.Refresh)
        sell:HookScript('OnHide', History.Refresh)
        hooksecurefunc(sell, 'SetItem', History.Refresh)
    end
    History.Refresh()
    return view
end

function History.Initialize()
    local listener = CreateFrame('Frame')
    listener:SetScript('OnEvent', function(_, event, itemID)
        if event == 'AUCTION_HOUSE_SHOW' then
            History.Attach(_G.AuctionHouseFrame)
        elseif History.view and History.view.itemID
            and (event == 'BAG_UPDATE_DELAYED' or itemID == History.view.itemID) then
            History.Refresh()
        end
    end)
    listener:RegisterEvent('AUCTION_HOUSE_SHOW')
    listener:RegisterEvent('ITEM_DATA_LOAD_RESULT')
    listener:RegisterEvent('BAG_UPDATE_DELAYED')
end
