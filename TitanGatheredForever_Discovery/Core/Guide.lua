local _, ns = ...
-- The text of the second tab of the window: what the module is, what it records, how it works, what the data are for and
-- how to hand them over. Contact details are set in CONTACTS; without them the text points to the project page.
local Guide = {}
ns.Guide = Guide

-- Where to send the data. A nil value is left out of the text.
Guide.CONTACTS = { discord = nil, email = nil }

local function contactLines()
    local Text = ns.Text
    local lines = {}
    if Guide.CONTACTS.discord then
        lines[#lines + 1] = Text.Label('   Discord: ') .. Text.Value(Guide.CONTACTS.discord)
    end
    if Guide.CONTACTS.email then
        lines[#lines + 1] = Text.Label('   E-mail: ') .. Text.Value(Guide.CONTACTS.email)
    end
    if #lines == 0 then
        lines[1] = Text.Label('   The contact of the author is on the project page of Titan Gathered Forever on CurseForge.')
    end
    return lines
end

-- The lines of the text, in order: a heading (white) and its gold paragraphs, with an empty line between the sections.
function Guide.Lines()
    local Text = ns.Text
    local label, value = Text.Label, Text.Value
    local lines = {}
    local function add(line) lines[#lines + 1] = line end
    local function section(title)
        if #lines > 0 then add('') end
        add(value(title))
    end

    section('What it is')
    add(label('Titan Gathered Discovery is a data-collection tool for the owner of Titan Gathered Forever and for players who choose to help. It records what the WoW Forever client shows and compares it with the data Titan Gathered Forever ships, so that new and different facts can be found, checked and added. It is not a player feature: nothing changes in your game because of it.'))

    section('What it records')
    add(label('Everything you loot and where it came from, the NPCs and objects you talk to or target (IDs, names, services, vendor and trainer goods), quests (not their text), the zones and areas you enter, your profession skills, and the client build and module versions.'))

    section('What it never records')
    add(label('Chat, whispers, mail text, player or pet names and GUIDs, guild names, or anything about the auction house. Before the data are handed over, ') .. value('/tgfd audit') .. label(' and ') .. value('/tgfd export') .. label(' check them for private values and refuse to go on if they find one.'))

    section('How it works')
    add(label('Recording starts by itself when the module is installed and runs quietly while you play: it listens to a few game events and keeps small records in the saved variables file, which the game writes when you ') .. value('/reload') .. label(' or log out. Scans (') .. value('/tgfd scan recipes') .. label(', ') .. value('/tgfd scan areas') .. label(') and the comparison (') .. value('/tgfd compare') .. label(') run only when you type them, show their progress and can be cancelled with ') .. value('/tgfd cancel') .. label('.'))
    add(label('The first tab shows the result: what is new, what differs from the catalogue and what has not been seen, with filters, search and the details of every row. ') .. value('/tgfd stop') .. label(' pauses recording and ') .. value('/tgfd start') .. label(' resumes it; the pause is kept after a reload.'))

    section('What the data is used for')
    add(label('The owner reads the files that players hand over, merges them by ID and build, and reviews every candidate by hand before anything is added to the catalogue of Titan Gathered Forever (recipes, trainers, vendors, sources, map areas). The observations are unverified: they are never published with your name and they never change the catalogue by themselves.'))

    section('How to send the data')
    add(label('Nothing is sent by the game itself: you decide when and whether to hand the data over.'))
    add(label('1. Type ') .. value('/tgfd export') .. label('. The data are checked for private values and stamped with versions and checksums (') .. value('/tgfd audit') .. label(' does the check alone).'))
    add(label('2. Type ') .. value('/reload') .. label(' or log out, so that the game writes the file.'))
    add(label('3. Send the file ') .. value('TitanGatheredForever_Discovery.lua') .. label(' from the folder ') .. value('WTF/Account/<your account>/SavedVariables') .. label(' to the owner:'))
    for _, line in ipairs(contactLines()) do add(line) end
    add(label('4. Afterwards you can clear the exported data from the game: ') .. value('/tgfd stop') .. label(', ') .. value('/tgfd export') .. label(', ') .. value('/reload') .. label(', copy the file, then ') .. value('/tgfd archive confirm') .. label('. It clears nothing if the data changed since the export.'))
    return lines
end

function Guide.Text()
    return table.concat(Guide.Lines(), '\n')
end
