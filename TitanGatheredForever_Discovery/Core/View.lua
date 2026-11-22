local _, ns = ...
-- The view model of the overview window: which rows to show, how a row looks and what its detail says. No frames here.
local View = { show = 'changes', category = false, search = '', offset = 0 }
ns.View = View

View.ROWS = 16
View.SHOWS = {
    { value = 'changes', label = 'New and different' },
    { value = 'toreview', label = 'To review (new or different, not marked)' },
    { value = 'new', label = 'New' },
    { value = 'different', label = 'Different' },
    { value = 'notseen', label = 'Not yet seen' },
    { value = 'unbaselined', label = 'No baseline' },
    { value = 'unchanged', label = 'Unchanged' },
    { value = 'all', label = 'Everything observed' },
}

local STATE_LABEL = { new = 'New', different = 'Different', unchanged = 'Unchanged', unbaselined = 'No baseline', notseen = 'Not yet seen',
    observed = 'Observed' }
local STATE_COLOR = { new = 'cyan', different = 'orange', unchanged = 'gray', unbaselined = 'gray', notseen = 'violet',
    observed = 'gray' }

local notSeenCache

local function reviewKey(row) return row.category .. ':' .. tostring(row.key) end

-- Review marks are local notes in the saved data; they never change the comparison or the catalogue.
function View.IsReviewed(row) return ns.db.reviewed[reviewKey(row)] ~= nil end

-- Marks or unmarks the row. Returns true when it is marked afterwards.
function View.ToggleReviewed(row)
    local key = reviewKey(row)
    if ns.db.reviewed[key] then ns.db.reviewed[key] = nil; return false end
    ns.db.reviewed[key] = ns.env.now()
    return true
end

-- Baseline entries that no observation touched, as rows (catalogue items first, then seed NPCs).
local function notSeenRows()
    if notSeenCache and notSeenCache.results == ns.results then return notSeenCache.rows end
    local rows = {}
    local baseline = ns.Baseline.FromCore()
    if baseline then
        for _, category in ipairs({ 'loot', 'npcs' }) do
            for _, key in ipairs(ns.Compare.NotSeen(ns.db, baseline, category)) do
                local name
                if category == 'loot' then name = ns.Text.Item(key) else name = baseline.npc(key).n end
                rows[#rows + 1] = { category = category, key = key, name = name, state = 'notseen',
                    why = 'In the baseline, never observed on this client.', details = {}, differences = 0 }
            end
        end
    end
    notSeenCache = { results = ns.results, rows = rows }
    return rows
end

local function wanted(row)
    local show = View.show
    if View.category and row.category ~= View.category then return false end
    if show == 'all' then return true end
    if show == 'changes' then return row.state == 'new' or row.state == 'different' end
    if show == 'toreview' then return (row.state == 'new' or row.state == 'different') and not View.IsReviewed(row) end
    return row.state == show
end

local function matches(row, needle)
    if needle == '' then return true end
    local haystack = (ns.Compare.LABELS[row.category] or '') .. ' ' .. tostring(row.key) .. ' ' .. (row.name or '')
    return haystack:lower():find(needle, 1, true) ~= nil
end

-- What was observed, as rows, before any comparison has run in this session (the comparison is started by /tgfd compare):
-- they have no state of a comparison, only the record itself.
local observedCache
local function observedRows()
    -- Built again only when the number of records changed or a moment has passed: scrolling asks for the rows all the time.
    local count = 0
    for _, category in ipairs(ns.Database.CATEGORIES) do
        for _ in pairs(ns.db.data[category] or {}) do count = count + 1 end
    end
    local now = ns.env.now()
    if observedCache and observedCache.db == ns.db and observedCache.count == count and now - observedCache.at < 2 then
        return observedCache.rows
    end
    local rows = {}
    for _, category in ipairs(ns.Database.CATEGORIES) do
        local records = ns.db.data[category] or {}
        for _, key in ipairs(ns.Util.SortedKeys(records)) do
            local record = records[key]
            local name = record.name or record.title or (type(key) == 'string' and key) or nil
            if category == 'vendors' and ns.db.data.npcs[key] then name = ns.db.data.npcs[key].name or name end
            rows[#rows + 1] = { category = category, key = key, name = name, state = 'observed', details = {}, differences = 0,
                why = 'Observed, not compared yet. Type /tgfd compare to see what is new or different.',
                seen = record.seen, first = record.first, last = record.last }
        end
    end
    observedCache = { db = ns.db, count = count, at = now, rows = rows }
    return rows
end

-- The rows for the current filters. Without a comparison in this session only Everything observed has rows (the
-- records themselves); the other lists need the comparison and give nil.
function View.Rows()
    if not ns.results and View.show ~= 'all' then return nil end
    local needle = tostring(View.search or ''):lower()
    local source = {}
    if not ns.results then
        source = observedRows()
    elseif View.show == 'notseen' then
        source = notSeenRows()
    else
        for _, category in ipairs(ns.Database.CATEGORIES) do
            for _, row in ipairs(ns.results.rows[category]) do source[#source + 1] = row end
        end
    end
    local rows = {}
    for _, row in ipairs(source) do
        if wanted(row) and matches(row, needle) then rows[#rows + 1] = row end
    end
    return rows
end

function View.Clamp(offset, total)
    local last = math.max(0, total - View.ROWS)
    return math.max(0, math.min(math.floor(offset + 0.5), last))
end

function View.RangeText(offset, total)
    if total == 0 then return ns.Text.Label('No records') end
    return ns.Text.Range(offset + 1, math.min(total, offset + View.ROWS), total)
end

function View.Cells(row)
    local Text = ns.Text
    local notes = {}
    if row.otherBuild then notes[#notes + 1] = 'other build' end
    if row.severalBuilds then notes[#notes + 1] = 'several builds' end
    if View.IsReviewed(row) then notes[#notes + 1] = 'reviewed' end
    if (row.differences or 0) > 0 then
        notes[#notes + 1] = row.differences .. (row.differences == 1 and ' difference' or ' differences')
    end
    return {
        Text.Value(ns.Compare.LABELS[row.category] or row.category),
        Text.Value(tostring(row.key)),
        Text.Value(row.name or ''),
        Text.Color(STATE_COLOR[row.state] or 'gray', STATE_LABEL[row.state] or tostring(row.state)),
        Text.Value(row.seen and tostring(row.seen) or ''),
        row.last and Text.Date(ns.env.date('%Y-%m-%d', row.last)) or '',
        Text.Label(table.concat(notes, ', ')),
    }
end

local function detailLine(detail)
    local Text = ns.Text
    local name = detail.name and ('"' .. detail.name .. '"') or ''
    if detail.field == 'price' then
        return Text.Label('Price of ') .. Text.Value(Text.Item(detail.itemID)) .. Text.Label(': seed ') .. Text.Coin(detail.baseline)
            .. Text.Label(', observed ') .. Text.Coin(detail.observed)
    elseif detail.field == 'cost' then
        return Text.Label('Cost of ') .. Text.Value(name) .. Text.Label(': seed ') .. Text.Coin(detail.baseline)
            .. Text.Label(', observed ') .. Text.Coin(detail.observed)
    elseif detail.field == 'skill' then
        return Text.Label('Skill requirement of ') .. Text.Value(name) .. Text.Label(': seed ') .. Text.Value(detail.baseline)
            .. Text.Label(', observed ') .. Text.Value(detail.observed)
    elseif detail.field == 'profession' then
        return Text.Label('Profession: seed ') .. Text.Value(detail.baseline) .. Text.Label(', observed ') .. Text.Value(detail.observed)
    elseif detail.field == 'name' then
        return Text.Label('Name: seed ') .. Text.Value(detail.baseline) .. Text.Label(', observed ') .. Text.Value(detail.observed)
    elseif detail.field == 'notOffered' then
        return Text.Value(Text.Item(detail.itemID)) .. Text.Label(' is in the seed but was not offered.')
    elseif detail.field == 'notInSeed' then
        return Text.Value(name) .. Text.Label(' is taught but not in the seed.')
    elseif detail.field == 'notTaught' then
        return Text.Value(name) .. Text.Label(' is in the seed but was not taught.')
    end
    return Text.Label(tostring(detail.field))
end

function View.DetailText(row)
    local lines = { ns.Text.Label(row.why or '') }
    for _, detail in ipairs(row.details or {}) do lines[#lines + 1] = detailLine(detail) end
    return lines
end

function View.Header()
    local Text = ns.Text
    if not ns.results then
        return Text.Label('No comparison in this session: only Everything observed has rows. Type ') .. Text.Value('/tgfd compare')
            .. Text.Label(' to compare the observations with the Titan Gathered Forever data.')
    end
    local saved = ns.db.compare or {}
    return Text.Label('Baseline: Titan Gathered Forever ') .. Text.Value(saved.baselineVersion or 'unknown')
        .. Text.Label(' (target build ') .. Text.Value(saved.targetBuild or 'unknown') .. Text.Label('), client build ')
        .. Text.Value(saved.clientBuild or ns.state.build or 'unknown') .. Text.Label('. Compared ')
        .. (saved.ranAt and Text.Date(ns.env.date('%Y-%m-%d %H:%M', saved.ranAt)) or Text.Value('this session'))
        .. Text.Label('. These are unverified observations, not catalogue facts.')
end
