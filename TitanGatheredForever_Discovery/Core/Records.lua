local _, ns = ...
-- Records of observations: how often, first and last time, first and last client build. An observation is not a verified
-- fact; the counts let a later review judge it.
local Records = {}
ns.Records = Records
ns.state = ns.state or {}

function Records.Context()
    return { now = ns.api.Now(), build = ns.state.build }
end

-- The record under key, created with nothing counted yet. Second result: true when it was created.
function Records.Ensure(bucket, key, ctx)
    local record = bucket[key]
    if record then return record, false end
    record = { seen = 0, first = ctx.now, last = ctx.now, firstBuild = ctx.build, lastBuild = ctx.build }
    bucket[key] = record
    return record, true
end

-- Ensure, then count one more observation and update the last time and build.
function Records.Touch(bucket, key, ctx)
    local record, isNew = Records.Ensure(bucket, key, ctx)
    record.seen = record.seen + 1
    record.last, record.lastBuild = ctx.now, ctx.build
    return record, isNew
end

function Records.Count(record, field, key, amount)
    record[field] = record[field] or {}
    record[field][key] = (record[field][key] or 0) + (amount or 1)
end
