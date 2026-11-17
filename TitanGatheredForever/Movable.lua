local _, ns = ...
-- Lets the player move windows of the client that cannot be moved by themselves (the profession window and the
-- auction house window, where this addon adds its own buttons) and keeps their position, like the windows of this
-- addon. The window is dragged by any empty place of it; the client lays its windows out again on every show, so the
-- saved place is put back right after. The switch is Titan menu > Display.
local Movable = {}
ns.Movable = Movable

Movable.frames = {
    { name = 'ProfessionsFrame', key = 'professions' },
    { name = 'AuctionHouseFrame', key = 'auctionHouse' },
}
local attached = {}

local function enabled() return ns.settings and ns.settings.moveBlizzard ~= false end

local function restore(frame, key)
    if enabled() then ns.Nav.RestorePosition(key, frame) end
end

-- Makes one window movable once it exists. Returns whether it is attached.
function Movable.Attach(entry)
    if attached[entry.name] then return true end
    local frame = _G[entry.name]
    if not frame or not frame.RegisterForDrag or not frame.HookScript then return false end
    attached[entry.name] = entry
    entry.frame = frame
    frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
    frame:RegisterForDrag('LeftButton')
    frame:HookScript('OnDragStart', function(self) if enabled() then self:StartMoving() end end)
    frame:HookScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        if enabled() then ns.Nav.SavePosition(entry.key, self) end
    end)
    frame:HookScript('OnShow', function(self) C_Timer.After(0, function() restore(self, entry.key) end) end)
    if frame.IsShown and frame:IsShown() then restore(frame, entry.key) end
    return true
end

function Movable.AttachAll()
    for _, entry in ipairs(Movable.frames) do Movable.Attach(entry) end
end

-- The client lays its windows out again whenever one opens or closes: the saved places are put back afterwards.
local function layoutAgain()
    for _, entry in pairs(attached) do
        if entry.frame.IsShown and entry.frame:IsShown() then restore(entry.frame, entry.key) end
    end
end

function Movable.Initialize()
    if Movable.frame then return end
    Movable.AttachAll()
    if hooksecurefunc and _G.UpdateUIPanelPositions then pcall(hooksecurefunc, 'UpdateUIPanelPositions', layoutAgain) end
    local frame = CreateFrame('Frame')
    Movable.frame = frame
    frame:SetScript('OnEvent', function() C_Timer.After(0, Movable.AttachAll) end)
    for _, event in ipairs({ 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'TRADE_SKILL_SHOW', 'TRADE_SKILL_DATA_SOURCE_CHANGED' }) do
        frame:RegisterEvent(event)
    end
end
