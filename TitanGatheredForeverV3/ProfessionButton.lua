local _, ns = ...
-- A "Reagents" button in the native profession window, next to the Create buttons: it opens the reagent window for
-- the selected recipe with the number of crafts typed in the profession window. The chat command and the Titan menu
-- entry still work.
local Button = {}
ns.ProfessionButton = Button

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

-- Adds the button once the profession window exists. Returns whether the button is there.
function Button.Attach()
    if Button.button then return true end
    local frame = _G.ProfessionsFrame
    local page = frame and frame.CraftingPage
    local anchor = page and page.CreateAllButton
    if not anchor then return false end
    local button = CreateFrame('Button', nil, page, 'UIPanelButtonTemplate')
    Button.button = button
    button:SetSize(90, 22)
    button:SetText('Reagents')
    button:SetPoint('RIGHT', anchor, 'LEFT', -8, 0)
    button:SetScript('OnClick', function() Button.Open(page) end)
    button:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:AddLine('Reagents of the selected recipe')
        GameTooltip:AddLine('What you have in the bags and the bank, what is missing and where to get it, for the number of crafts entered here.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function() GameTooltip:Hide() end)
    return true
end

-- The profession addon of the client loads on demand, so the button is tried again on the events around opening it.
function Button.Initialize()
    if Button.frame then return end
    Button.Attach()
    local frame = CreateFrame('Frame')
    Button.frame = frame
    frame:SetScript('OnEvent', function(_, event, name)
        if Button.button then return end
        if event == 'ADDON_LOADED' and name ~= 'Blizzard_Professions' then return end
        C_Timer.After(0, Button.Attach)
    end)
    for _, event in ipairs({ 'ADDON_LOADED', 'TRADE_SKILL_SHOW', 'TRADE_SKILL_DATA_SOURCE_CHANGED' }) do
        frame:RegisterEvent(event)
    end
end
