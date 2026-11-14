local _, ns = ...
-- The profit of every recipe of the recipe book (Data/RecipeBook.lua, a mirror of client tables that is not complete):
-- what the materials cost at the cheapest known price, what the product sells for (vendor against the auction house
-- after its fee), and the difference. The number a craft makes is one until the recipe was opened in the reagent
-- window, which keeps the real number. An unknown price never gives a profit.
local Profit = {}
ns.Profit = Profit

-- The kinds the learned recipes are stored under (the recipe book names the profession in words).
local kinds = { ['First Aid'] = 'FirstAid' }
function Profit.Kind(profession) return kinds[profession] or profession end

local function book() return ns.RecipeBook end

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

-- Rows for the profit list. options: mine (only recipes the character has learned), kind (one profession),
-- search (text in the name or the profession). Returns the rows, best first, and a table with the professions that
-- were never read for the character (their recipes cannot be told apart) and the number of recipes looked at.
function Profit.Rows(character, options)
    options = options or {}
    local data = book()
    local rows, unread, unreadSet, looked = {}, {}, {}, 0
    if not data then return rows, { unread = unread, looked = 0 } end
    local needle = options.search and options.search ~= '' and options.search:lower() or nil
    for recipeID, recipe in pairs(data.recipes) do
        local profession = data.professions[recipe[2]]
        local kind = Profit.Kind(profession)
        if not options.kind or options.kind == kind then
            looked = looked + 1
            local name = Profit.Name(recipeID, recipe[1])
            local include = true
            local learned
            if options.mine then
                learned = Profit.Learned(character, kind, recipeID, name)
                if learned == nil then unreadSet[kind] = true end
                include = learned == true
            end
            if include and needle and not (name:lower():find(needle, 1, true) or profession:lower():find(needle, 1, true)) then
                include = false
            end
            if include then
                local reagents = {}
                for index, reagent in ipairs(recipe[3]) do reagents[index] = { itemID = reagent[1], perOperation = reagent[2] } end
                local low, high, assumed = Profit.Makes(recipeID)
                local product = ns.Economy.Product({ outputItemID = recipe[1], quantityMin = low, quantityMax = high,
                    rows = reagents, issues = {}, operations = 1 })
                rows[#rows + 1] = { recipeID = recipeID, name = name, profession = profession, kind = kind, productID = recipe[1],
                    product = product, profit = product and product.profit, assumed = assumed, learned = learned }
            end
        end
    end
    -- Rows with a profit come first, the best at the top; the rest follow by name.
    table.sort(rows, function(a, b)
        if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
        if a.profit ~= b.profit then return a.profit > b.profit end
        if a.name ~= b.name then return a.name < b.name end
        return a.recipeID < b.recipeID
    end)
    for kind in pairs(unreadSet) do unread[#unread + 1] = kind end
    table.sort(unread)
    return rows, { unread = unread, looked = looked }
end
