local _, ns = ...
-- The profit of every recipe of the recipe books of the installed profession addons (a mirror of client tables that is
-- not complete, completed from the profession windows): what the materials cost at the cheapest known price, what the
-- product sells for (vendor against the auction house after its fee), and the difference. The number a craft makes is
-- one until the profession was read or the recipe opened in the reagent window. An unknown price never gives a profit.
-- A profession whose addon is not installed has no recipes here.
local Profit = {}
ns.Profit = Profit


-- The name of a recipe: the spell name of the client when it has it, else the product, else the number.
function Profit.Name(recipeID, productID)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(recipeID)
    if type(info) == 'table' and ns.IsPublic(info.name) and type(info.name) == 'string' and info.name ~= '' then
        return info.name
    end
    if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, recipeID) end
    local product = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(productID)
    if type(product) == 'string' and ns.IsPublic(product) then return product end
    return 'Recipe ' .. recipeID
end

-- true: the character has learned the recipe; false: the profession was read and it is not learned; nil: the
-- profession was never read. The recipe ID is the sure test, the name is the fallback for older records.
function Profit.Learned(character, kind, recipeID, name)
    local K = ns.KnownRecipes
    if not K or not character then return nil end
    local byID = K.IsKnownID(character, kind, recipeID)
    if byID == true then return true end
    local byName = K.IsKnown(character, kind, name)
    if byName == true then return true end
    if byID == false then return false end
    return byName
end

-- How many one craft makes: the number seen in the reagent window, otherwise one (and flagged as assumed).
function Profit.Makes(recipeID)
    local makes = ns.db and ns.db.recipeMakes and ns.db.recipeMakes[recipeID]
    if type(makes) == 'table' and type(makes[1]) == 'number' and type(makes[2]) == 'number' then
        return makes[1], makes[2], false
    end
    return 1, 1, true
end

-- The professions that have recipes here, that is those of the installed profession addons (module ids, sorted).
function Profit.Kinds()
    local set, result = {}, {}
    if not ns.Catalog then return result end
    for _, recipe in pairs(ns.Catalog.Book()) do set[recipe[2]] = true end
    for _, recipe in pairs(ns.Catalog.ExtraRecipes()) do set[recipe[2]] = true end
    for kind in pairs(set) do result[#result + 1] = kind end
    table.sort(result)
    return result
end

-- A product whose price comes from the auction house and rests on fewer than minAuctions auctions is a thin market: one
-- odd offer sets the lowest buyout. Where the vendor pays more than the auction leaves, the auction does not matter.
function Profit.Thin(product, minAuctions)
    if not product or not minAuctions or minAuctions <= 1 then return false end
    return product.best == 'auction' and product.auction ~= nil and (product.auction.n or 0) < minAuctions
end

-- Rows for the profit list. options: mine (only recipes the character has learned), kind (one profession),
-- search (text in the name or the profession), minAuctions (hide the thin markets). Returns the rows, best first, and
-- a table with the professions that were never read for the character (their recipes cannot be told apart), the number
-- of recipes looked at and the number of rows hidden as thin markets.
function Profit.Rows(character, options)
    options = options or {}
    local rows, unread, unreadSet, looked, thinHidden = {}, {}, {}, 0, 0
    if not ns.Catalog then return rows, { unread = unread, looked = 0, thinHidden = 0 } end
    local needle = options.search and options.search ~= '' and options.search:lower() or nil
    -- recipe: { product, kind, { { item, quantity }, ... }, label }; the kind is the module id of the profession.
    local function consider(recipeID, recipe, fromWindow)
        local productID, kind, pairsList, profession = recipe[1], recipe[2], recipe[3], recipe[4]
        if options.kind and options.kind ~= kind then return end
        looked = looked + 1
        local name = Profit.Name(recipeID, productID)
        local learned
        if options.mine then
            learned = Profit.Learned(character, kind, recipeID, name)
            if learned == nil then unreadSet[kind] = true end
            if learned ~= true then return end
        end
        if needle and not (name:lower():find(needle, 1, true) or profession:lower():find(needle, 1, true)) then return end
        local reagents = {}
        for index, reagent in ipairs(pairsList) do reagents[index] = { itemID = reagent[1], perOperation = reagent[2] } end
        local low, high, assumed = Profit.Makes(recipeID)
        local product = ns.Economy.Product({ outputItemID = productID, quantityMin = low, quantityMax = high,
            rows = reagents, issues = {}, operations = 1 })
        if Profit.Thin(product, options.minAuctions) then
            thinHidden = thinHidden + 1
        else
            rows[#rows + 1] = { recipeID = recipeID, name = name, profession = profession, kind = kind, productID = productID,
                product = product, profit = product and product.profit, assumed = assumed, learned = learned,
                fromWindow = fromWindow or nil }
        end
    end
    for recipeID, recipe in pairs(ns.Catalog.Book()) do consider(recipeID, recipe, false) end
    for recipeID, recipe in pairs(ns.Catalog.ExtraRecipes()) do consider(recipeID, recipe, true) end
    -- Rows with a profit come first, the best at the top; the rest follow by name.
    table.sort(rows, function(a, b)
        if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
        if a.profit ~= b.profit then return a.profit > b.profit end
        if a.name ~= b.name then return a.name < b.name end
        return a.recipeID < b.recipeID
    end)
    for kind in pairs(unreadSet) do unread[#unread + 1] = kind end
    table.sort(unread)
    return rows, { unread = unread, looked = looked, thinHidden = thinHidden }
end
