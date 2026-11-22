local _, ns = ...
-- The progress window of a running operation: name, phase, bar, counts, elapsed time and a Cancel button. The window
-- only shows; the operation is driven by its own ticker frame, so a failure to build the window never stops it.
local Progress = {}
ns.Progress = Progress

function Progress.Format(state)
    local Text = ns.Text
    local percent = state.total > 0 and math.floor(state.done / state.total * 100) or 0
    return {
        title = Text.Value(state.name),
        phase = Text.Label(string.format('Phase %d of %d: %s', state.phaseIndex, state.phaseCount, state.phaseLabel)),
        count = Text.Value(string.format('%d of %d (%d%%)', state.done, state.total, percent)),
        elapsed = Text.Label(string.format('Elapsed %.1f s', state.elapsed)),
    }
end

local function build()
    local frame = CreateFrame('Frame', 'TitanGatheredForeverDiscoveryProgress', UIParent, 'BackdropTemplate')
    frame:SetSize(360, 130)
    frame:SetPoint('TOP', UIParent, 'TOP', 0, -170)
    frame:SetFrameStrata('DIALOG')
    frame:SetClampedToScreen(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
            edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border', tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    end
    frame.header = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    frame.header:SetPoint('TOP', frame, 'TOP', 0, -16)
    frame.phase = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    frame.phase:SetPoint('TOP', frame.header, 'BOTTOM', 0, -6)
    frame.bar = CreateFrame('StatusBar', nil, frame)
    frame.bar:SetSize(300, 14)
    frame.bar:SetPoint('TOP', frame.phase, 'BOTTOM', 0, -8)
    frame.bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')
    frame.bar:SetMinMaxValues(0, 1)
    frame.count = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    frame.count:SetPoint('TOP', frame.bar, 'BOTTOM', 0, -6)
    frame.elapsed = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    frame.elapsed:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 20, 16)
    frame.cancel = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
    frame.cancel:SetSize(80, 22)
    frame.cancel:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -18, 12)
    frame.cancel:SetText('Cancel')
    frame.cancel:SetScript('OnClick', function() ns.Runner.Cancel('cancelled by button') end)
    frame:Hide()
    return frame
end

function Progress.Refresh()
    local frame, state = Progress.frame, ns.Runner.Progress()
    if not frame or not state then return end
    local lines = Progress.Format(state)
    frame.header:SetText(lines.title)
    frame.phase:SetText(lines.phase)
    frame.count:SetText(lines.count)
    frame.elapsed:SetText(lines.elapsed)
    frame.bar:SetValue(state.fraction)
end

function Progress.Attach()
    ns.Runner.Listen(function(event)
        if event == 'start' then
            if not Progress.frame and not Progress.failed then
                local ok, frame = pcall(build)
                if ok then
                    Progress.frame = frame
                    frame:SetScript('OnUpdate', Progress.Refresh)
                else
                    Progress.failed = true
                    ns.Print(ns.Text.Label('The progress window is unavailable (' .. tostring(frame) .. '). Progress is shown in chat.'))
                end
            end
            if Progress.frame then Progress.frame:Show(); Progress.Refresh() end
        elseif event == 'finish' or event == 'abort' then
            if Progress.frame then Progress.frame:Hide() end
        end
    end)
end
