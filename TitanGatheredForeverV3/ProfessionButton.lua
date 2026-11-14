local _, ns = ...
-- Two ways into the reagent window from the native profession window, so /tgf recipe is not needed:
--  * a "Reagents" button in the header of the window, left of the maximize button (or of the close button), which
--    opens the selected recipe with the number of crafts typed beside the Create button;
--  * an entry "Reagents" in the right click menu of a learned recipe in the recipe list.
-- The chat command and the Titan menu entry still work.
local Button = {}
ns.ProfessionButton = Button

-- The menu the client opens on a right click in the recipe list (client source, branch forever).
Button.MENU_TAG = 'MENU_PROFESSIONS_RECIPE_LIST_FAVORITE'

-- The number typed beside the Create button of the profession window (1 when unreadable).
function Button.Operations(page)
    local box = page and page.CreateMultipleInputBox
    if box and box.GetNumber then
        local ok, value = pcall(box.GetNumber, box)
        if ok and ns.IsPublic(value) and type(value) == 'number' and value >= 1 then return math.floor(value) end
    end
    return 1
end

function Button.Open(page)
    local recipeID = ns.Crafting and ns.Crafting.selectedID
    if not recipeID then
        ns.Print('Select a recipe in the profession window first.')
        return
    end
    ns.CraftingView.Show(recipeID, Button.Operations(page))
end

-- The recipe of a recipe list button: its element is a tree node whose data holds the recipe info.
function Button.RecipeOf(owner)
    if type(owner) ~= 'table' or not owner.GetElementData then return nil end
    local ok, node = pcall(owner.GetElementData, owner)
    if not ok or type(node) ~= 'table' then return nil end
    local data = node.GetData and node:GetData() or node.data
    local info = type(data) == 'table' and data.recipeInfo or nil
    if not info then return nil end
    return ns.Crafting.Resolve(info, true)
end

-- Adds the entry to the right click menu of a recipe. The ID is resolved when the menu opens.
function Button.ModifyMenu(owner, rootDescription)
    local recipeID = Button.RecipeOf(owner)
    if not recipeID then return end
    rootDescription:CreateButton('Reagents', function() ns.CraftingView.Show(recipeID, 1) end)
end

function Button.HookMenu()
    if Button.menuHooked or not Menu or not Menu.ModifyMenu then return false end
    Button.menuHooked = pcall(Menu.ModifyMenu, Button.MENU_TAG, Button.ModifyMenu)
    return Button.menuHooked
end

-- A bounded log of what was found when the button was attached, for the case that it does not show.
local function log(stage, details)
    local entries = ns.db and ns.db.professionLog
    if type(entries) ~= 'table' then return end
    local entry = { at = time and time() or 0, stage = stage }
    for key, value in pairs(details or {}) do entry[key] = value end
    entries[#entries + 1] = entry
    while #entries > 12 do table.remove(entries, 1) end
end

-- The header button goes left of the maximize button when that one is on screen, otherwise left of the close button.
-- It is a child of the recipes page, so it is shown exactly on that page and never hidden by a button it is not part of.
function Button.Place()
    local frame, button = _G.ProfessionsFrame, Button.button
    if not frame or not button then return end
    local maximize = frame.MaximizeMinimize
    local neighbour = (maximize and maximize.IsShown and maximize:IsShown()) and maximize or frame.CloseButton
    if not neighbour then return end
    button:ClearAllPoints()
    button:SetPoint('RIGHT', neighbour, 'LEFT', -6, 0)
end

-- Adds the header button once the profession window exists. Returns whether the button is there.
function Button.Attach()
    if Button.button then return true end
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    if not frame or not (frame.MaximizeMinimize or frame.CloseButton) then
        if not Button.missingLogged then
            Button.missingLogged = true
            log('no-frame', { frame = frame ~= nil, close = frame and frame.CloseButton ~= nil or false })
        end
        return false
    end
    local button = CreateFrame('Button', nil, page or frame, 'UIPanelButtonTemplate')
    Button.button = button
    button:SetSize(80, 20)
    button:SetText('Reagents')
    if button.SetFrameLevel and (page or frame).GetFrameLevel then button:SetFrameLevel(((page or frame):GetFrameLevel() or 0) + 20) end
    button:SetScript('OnClick', function() Button.Open(frame.CraftingPage) end)
    button:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine('Reagents of the selected recipe')
        GameTooltip:AddLine('What you have in the bags and the bank, what is missing and where to get it, for the number of crafts entered beside Create. Right click a recipe for another one.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function() GameTooltip:Hide() end)
    Button.Place()
    local host = page or frame
    if host.HookScript then host:HookScript('OnShow', Button.Place) end
    log('attached', { page = page ~= nil, maximize = frame.MaximizeMinimize ~= nil,
        maximizeShown = frame.MaximizeMinimize and frame.MaximizeMinimize.IsShown and frame.MaximizeMinimize:IsShown() or false,
        close = frame.CloseButton ~= nil })
    return true
end

-- The profession addon of the client loads on demand, so the button is tried again on the events around opening it.
function Button.Initialize()
    if Button.frame then return end
    Button.HookMenu()
    Button.Attach()
    local frame = CreateFrame('Frame')
    Button.frame = frame
    frame:SetScript('OnEvent', function(_, event, name)
        Button.HookMenu()
        if Button.button then return end
        if event == 'ADDON_LOADED' and name ~= 'Blizzard_Professions' then return end
        C_Timer.After(0, Button.Attach)
    end)
    for _, event in ipairs({ 'ADDON_LOADED', 'TRADE_SKILL_SHOW', 'TRADE_SKILL_DATA_SOURCE_CHANGED' }) do
        frame:RegisterEvent(event)
    end
end
