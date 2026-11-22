local _, ns = ...
-- Installing the module is the consent: recording starts by itself at the first login (a module that has to be switched
-- on is loaded and never used), and the notice is shown then. A pause (/tgfd stop) is kept. The notice version is stored
-- with the acceptance; after a changed notice it is shown again and the collection continues as it was.
local Consent = {}
ns.Consent = Consent

Consent.NOTICE_VERSION = 3

function Consent.Notice()
    local Text = ns.Text
    return {
        Text.Label('Titan Gathered Discovery records what this game client shows, so that new or different data can be compared with the Titan Gathered Forever catalogue. It is a data-collection tool for the owner and for contributors who choose to help, not a player feature.'),
        Text.Label('It records: everything you loot and where it came from, the NPCs and objects you talk to or target (IDs, names, services, vendor and trainer goods), quests, the zones and areas you enter, profession skills and the client build.'),
        Text.Label('It never records: chat, whispers, mail text, player GUIDs or names, guild names, or anything about the auction house.'),
        Text.Label('Nothing is sent anywhere. The game cannot send data, so you would hand it over yourself: ') .. Text.Value('/tgfd export') .. Text.Label(' checks and stamps the data, then you send the saved file.'),
        Text.Label('Scans (') .. Text.Value('/tgfd scan recipes') .. Text.Label(', ') .. Text.Value('/tgfd scan areas') .. Text.Label(') run only when you type them. They show their progress, can be cancelled with ') .. Text.Value('/tgfd cancel') .. Text.Label(' and only read what the game already lists; they open no window and ask the server for nothing.'),
        Text.Label('Recording starts by itself when the module is installed. To pause: ') .. Text.Value('/tgfd stop') .. Text.Label(', to resume: ') .. Text.Value('/tgfd start') .. Text.Label('.'),
    }
end

local function accepted(db)
    return type(db) == 'table' and type(db.consent) == 'table' and db.consent.accepted == true
        and db.consent.version == Consent.NOTICE_VERSION
end

-- 'blocked-schema', 'unaccepted', 'paused' or 'collecting'.
function Consent.State(db, runtime)
    runtime = runtime or {}
    if runtime.schemaBlocked then return 'blocked-schema' end
    if not accepted(db) then return 'unaccepted' end
    if db.consent.paused then return 'paused' end
    return 'collecting'
end

function Consent.Collecting(db, runtime)
    return Consent.State(db, runtime) == 'collecting'
end

-- Called at every login: starts the collection of a module that has not been decided yet ('started'), renews the
-- acceptance after a changed notice without touching a pause ('renewed'), or does nothing (nil). Data of a newer
-- schema are left alone.
function Consent.Auto(db, runtime, now)
    if runtime and runtime.schemaBlocked then return nil end
    local consent = db.consent
    if consent.accepted == true then
        if consent.version == Consent.NOTICE_VERSION then return nil end
        consent.version = Consent.NOTICE_VERSION
        return 'renewed'
    end
    consent.accepted, consent.version, consent.acceptedAt, consent.paused, consent.auto =
        true, Consent.NOTICE_VERSION, now, false, true
    return 'started'
end

-- true, or false with the reason 'schema'.
function Consent.Accept(db, runtime, now)
    if runtime and runtime.schemaBlocked then return false, 'schema' end
    if not accepted(db) then
        db.consent.accepted = true
        db.consent.version = Consent.NOTICE_VERSION
        db.consent.acceptedAt = now
        db.consent.paused = false
    end
    return true
end

function Consent.Stop(db, runtime)
    if not accepted(db) then return false end
    db.consent.paused = true
    return true
end

function Consent.Start(db, runtime)
    if not accepted(db) then return false end
    db.consent.paused = false
    return true
end
