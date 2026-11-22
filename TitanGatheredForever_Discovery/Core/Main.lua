local _, ns = ...
-- Loading, saved data, login checks, the slash command and the events that stop a running operation.
local Main = {}
ns.Main = Main

local FOLDER = 'TitanGatheredForever_Discovery'

local function metadata(addon, field)
    local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not read then return nil end
    local ok, value = pcall(read, addon, field)
    return ok and value or nil
end

local function realEnv()
    return {
        now = time, date = date, build = GetBuildInfo, clock = debugprofilestop, inCombat = InCombatLockdown,
        moduleVersion = metadata(FOLDER, 'Version') or 'unknown',
        coreVersion = function() return metadata('TitanGatheredForever', 'Version') end,
    }
end

local function onAddonLoaded()
    ns.Print = ns.Print or function(message) DEFAULT_CHAT_FRAME:AddMessage(message) end
    ns.env = ns.env or realEnv()
    ns.api = ns.api or ns.Api.Default()
    ns.runtime = {}
    ns.state.session = tostring(ns.env.now()) .. '-' .. tostring(math.floor(ns.env.clock()))
    local status
    _G.TitanGatheredForeverDiscoveryDB, status = ns.Database.Init(_G.TitanGatheredForeverDiscoveryDB, ns.env.moduleVersion, ns.env.now())
    ns.db = _G.TitanGatheredForeverDiscoveryDB
    ns.runtime.schemaBlocked = status == 'newer'
    _G.SLASH_TGFD1 = '/tgfd'
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList.TGFD = function(message) ns.Commands.Handle(message) end
    ns.frame:RegisterEvent('PLAYER_LOGIN')
end

local function onLogin()
    local Text = ns.Text
    pcall(ns.Stats.Initialize)           -- the Titan Panel plugin is optional; a failure must never stop the start
    if ns.runtime.schemaBlocked then
        ns.Print(Text.Label('Discovery is off: the saved data are from a newer version of this module and are left untouched. Update the module.'))
    end
    if ns.runtime.schemaBlocked then return end
    -- The window of the collected data is also in the menu of the core (minimap button and Titan Panel).
    local core = _G.TitanGatheredForeverV3
    if core and core.Titan and core.Titan.AddMenuExtension then
        pcall(core.Titan.AddMenuExtension, function(root)
            root:CreateButton('Titan Gathered Discovery', function() ns.Window.Toggle() end)
        end)
    end
    local began = ns.Consent.Auto(ns.db, ns.runtime, ns.env.now())
    ns.Manager.Begin()
    local state = ns.Consent.State(ns.db, ns.runtime)
    if began then
        for _, line in ipairs(ns.Consent.Notice()) do ns.Print(line) end
        ns.Print(Text.Label('Discovery ') .. Text.Value(state == 'paused' and 'is paused' or 'has started recording')
            .. Text.Label('. Type ') .. Text.Value('/tgfd status') .. Text.Label(', or open the window from the menu of the minimap button.'))
    elseif state == 'unaccepted' then
        ns.Print(Text.Label('Discovery records nothing until you accept its notice. Type ') .. Text.Value('/tgfd') .. Text.Label('.'))
    else
        ns.Print(Text.Label('Discovery: ') .. Text.Value(state == 'paused' and 'Paused' or 'Collecting') .. Text.Label('. Type ') .. Text.Value('/tgfd status') .. Text.Label('.'))
    end
end

-- While an operation runs: a visible ticker frame drives it, and combat or a loading screen stops it. Both are removed
-- again at the end, so an idle module costs no per-frame work and listens to no game events.
local ABORT_EVENTS = { PLAYER_REGEN_DISABLED = 'combat started', PLAYER_LEAVING_WORLD = 'loading screen or reload' }

local function onOperation(event)
    if event == 'start' then
        if not ns.ticker then
            ns.ticker = CreateFrame('Frame')
            ns.ticker:SetScript('OnUpdate', function() ns.Runner.Tick() end)
        end
        ns.ticker:Show()
        for abortEvent in pairs(ABORT_EVENTS) do ns.frame:RegisterEvent(abortEvent) end
    elseif event == 'finish' or event == 'abort' then
        if ns.ticker then ns.ticker:Hide() end
        for abortEvent in pairs(ABORT_EVENTS) do ns.frame:UnregisterEvent(abortEvent) end
    end
end

function Main.Start()
    ns.frame = CreateFrame('Frame')
    ns.frame:RegisterEvent('ADDON_LOADED')
    ns.frame:SetScript('OnEvent', function(_, event, ...)
        if event == 'ADDON_LOADED' then
            if (...) == FOLDER then onAddonLoaded() end
        elseif event == 'PLAYER_LOGIN' then
            onLogin()
        elseif ABORT_EVENTS[event] then
            ns.Runner.Cancel(ABORT_EVENTS[event])
        else
            ns.Manager.Handle(event, ...)
        end
    end)
    ns.Progress.Attach()
    ns.Runner.Listen(onOperation)
end
