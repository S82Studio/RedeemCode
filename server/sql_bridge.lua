
local function hasMethod(name)
    return type(MySQL) == 'table'
        and type(MySQL[name]) == 'table'
        and type(MySQL[name].await) == 'function'
end
if hasMethod('scalar') and hasMethod('single')
   and hasMethod('query') and hasMethod('insert') and hasMethod('update') then
    Debug.log('IO', '[sql_bridge] MySQL already defined (oxmysql lib?). Bridge skipping init.')
    return
end

local DRIVERS              = { 'oxmysql', 'mysql-async', 'ghmattimysql' }
local DETECT_TIMEOUT_MS    = 30000
local CALLBACK_TIMEOUT_MS  = 30000
local READY_POLL_MS        = 50

local detected     = nil
local bridgeReady  = false
local readyQueue   = {}

local function logOk  (msg, ...) Debug.log('IO',  '[sql_bridge] ' .. msg, ...) end
local function logWarn(msg, ...) Debug.warn('IO', '[sql_bridge] ' .. msg, ...) end
local function logErr (msg, ...) Debug.err('[sql_bridge] ' .. msg, ...) end

local function detectOnce()
    for _, name in ipairs(DRIVERS) do
        if GetResourceState(name) == 'started' then
            return name
        end
    end
    return nil
end

local startBootstrap

local function doBootstrap()
    local deadline = GetGameTimer() + DETECT_TIMEOUT_MS
    while not detected do
        detected = detectOnce()
        if detected then break end
        if GetGameTimer() >= deadline then
            logErr('no MySQL driver started within %dms (checked: %s). s82 DB calls will throw.',
                DETECT_TIMEOUT_MS, table.concat(DRIVERS, ' / '))
            return
        end
        Wait(100)
    end

    if detected == 'mysql-async' and exports['mysql-async'].is_ready ~= nil then
        local tries = 0
        while tries < 100 do
            local ok, ready = pcall(exports['mysql-async'].is_ready, exports['mysql-async'])
            if ok and ready then break end
            Wait(100)
            tries = tries + 1
        end
        if tries >= 100 then
            logWarn('mysql-async is_ready() timeout (10s) — proceeding anyway, first query may fail')
        end
    end

    bridgeReady = true
    logOk('driver detected: %s', detected)

    if readyQueue then
        local q = readyQueue
        readyQueue = nil
        for _, cb in ipairs(q) do
            local ok, err = pcall(cb)
            if not ok then logErr('ready callback failed: %s', tostring(err)) end
        end
    end
end

startBootstrap = function()
    CreateThread(doBootstrap)
end

startBootstrap()

local function ensureReady()
    if bridgeReady then return true end
    local deadline = GetGameTimer() + DETECT_TIMEOUT_MS
    while not bridgeReady do
        if GetGameTimer() >= deadline then
            logErr('ensureReady timeout (%dms) — no driver detected', DETECT_TIMEOUT_MS)
            return false
        end
        Wait(READY_POLL_MS)
    end
    return true
end

local function awaitCallback(dispatch)
    local result, done = nil, false
    dispatch(function(r)
        result = r
        done = true
    end)
    local deadline = GetGameTimer() + CALLBACK_TIMEOUT_MS
    while not done do
        if GetGameTimer() >= deadline then
            logErr('callback timeout after %dms (driver=%s)', CALLBACK_TIMEOUT_MS, detected)
            return nil
        end
        Wait(0)
    end
    return result
end

local function splitPlaceholders(sql)
    local parts, count = {}, 0
    local buf = {}
    local i, len = 1, #sql
    local inStr = false
    while i <= len do
        local c = sql:sub(i, i)
        if inStr then
            buf[#buf + 1] = c
            if c == "'" then
                if sql:sub(i + 1, i + 1) == "'" then
                    buf[#buf + 1] = "'"
                    i = i + 1
                else
                    inStr = false
                end
            end
        elseif c == "'" then
            inStr = true
            buf[#buf + 1] = c
        elseif c == '?' then
            count = count + 1
            parts[count] = table.concat(buf)
            buf = {}
        else
            buf[#buf + 1] = c
        end
        i = i + 1
    end
    parts[count + 1] = table.concat(buf)
    return parts, count
end

local function normalize(sql, params, style)
    params = params or {}

    local isMap = false
    for k in pairs(params) do
        if type(k) ~= 'number' then
            isMap = true
            break
        end
    end
    if isMap then
        if style == 'named' then
            local out = {}
            for k, v in pairs(params) do
                local key = tostring(k)
                if key:sub(1, 1) ~= '@' then key = '@' .. key end
                out[key] = v
            end
            return sql, out
        end
        return sql, params
    end

    local parts, n = splitPlaceholders(sql)
    if n == 0 then
        return sql, (style == 'named') and {} or params
    end

    local outSql, outParams = {}, {}
    local idx = 0
    for i = 1, n do
        outSql[#outSql + 1] = parts[i]
        local v = params[i]
        if v == nil then
            outSql[#outSql + 1] = 'NULL'
        elseif style == 'named' then
            idx = idx + 1
            local key = ('@fp%02d'):format(idx)
            outSql[#outSql + 1] = key
            outParams[key] = v
        else
            idx = idx + 1
            outSql[#outSql + 1] = '?'
            outParams[idx] = v
        end
    end
    outSql[#outSql + 1] = parts[n + 1]
    return table.concat(outSql), outParams
end

local promise_new = promise.new
local Citizen_Await = Citizen.Await
local oxmysql_exports = nil

local function oxAwait(method, sql, params)
    if not oxmysql_exports then oxmysql_exports = exports.oxmysql end
    local p = promise_new()
    oxmysql_exports[method](nil, sql, params, function(result, err)
        if err then return p:reject(err) end
        p:resolve(result)
    end, 's82')
    local ok, result = pcall(Citizen_Await, p)
    if not ok then
        logErr('oxmysql %s error: %s', method, tostring(result))
        return nil
    end
    return result
end

local function prep(sql, params)
    if detected == 'oxmysql' then
        return normalize(sql, params, 'positional')
    end
    return normalize(sql, params, 'named')
end

local Impl = {}

function Impl.scalar(sql, params)
    local q, p = prep(sql, params)
    if detected == 'oxmysql' then
        return oxAwait('scalar', q, p)
    elseif detected == 'mysql-async' then
        local rows = awaitCallback(function(cb)
            exports['mysql-async']:mysql_fetch_all(q, p, cb)
        end)
        if type(rows) == 'table' and rows[1] then
            for _, v in pairs(rows[1]) do return v end
        end
        return nil
    elseif detected == 'ghmattimysql' then
        local rows = awaitCallback(function(cb)
            exports.ghmattimysql:execute(q, p, cb)
        end)
        if type(rows) == 'table' and rows[1] then
            for _, v in pairs(rows[1]) do return v end
        end
        return nil
    end
    return nil
end

function Impl.single(sql, params)
    local q, p = prep(sql, params)
    if detected == 'oxmysql' then
        return oxAwait('single', q, p)
    elseif detected == 'mysql-async' then
        local rows = awaitCallback(function(cb)
            exports['mysql-async']:mysql_fetch_all(q, p, cb)
        end)
        return rows and rows[1] or nil
    elseif detected == 'ghmattimysql' then
        local rows = awaitCallback(function(cb)
            exports.ghmattimysql:execute(q, p, cb)
        end)
        return rows and rows[1] or nil
    end
    return nil
end

function Impl.query(sql, params)
    local q, p = prep(sql, params)
    if detected == 'oxmysql' then
        return oxAwait('query', q, p) or {}
    elseif detected == 'mysql-async' then
        return awaitCallback(function(cb)
            exports['mysql-async']:mysql_fetch_all(q, p, cb)
        end) or {}
    elseif detected == 'ghmattimysql' then
        local res = awaitCallback(function(cb)
            exports.ghmattimysql:execute(q, p, cb)
        end)
        if type(res) ~= 'table' then return {} end
        if res.affectedRows ~= nil and res[1] == nil then return {} end
        return res
    end
    return {}
end

function Impl.insert(sql, params)
    local q, p = prep(sql, params)
    if detected == 'oxmysql' then
        return oxAwait('insert', q, p)
    elseif detected == 'mysql-async' then
        return awaitCallback(function(cb)
            exports['mysql-async']:mysql_insert(q, p, cb)
        end)
    elseif detected == 'ghmattimysql' then
        local res = awaitCallback(function(cb)
            exports.ghmattimysql:execute(q, p, cb)
        end)
        if type(res) == 'table' then return res.insertId end
        return nil
    end
    return nil
end

function Impl.update(sql, params)
    local q, p = prep(sql, params)
    if detected == 'oxmysql' then
        return oxAwait('update', q, p) or 0
    elseif detected == 'mysql-async' then
        return awaitCallback(function(cb)
            exports['mysql-async']:mysql_execute(q, p, cb)
        end) or 0
    elseif detected == 'ghmattimysql' then
        local res = awaitCallback(function(cb)
            exports.ghmattimysql:execute(q, p, cb)
        end)
        if type(res) == 'table' then return res.affectedRows or 0 end
        return tonumber(res) or 0
    end
    return 0
end

local function runAwait(method, sql, params)
    if not ensureReady() then
        error(('s82 sql_bridge: no MySQL driver — cannot execute %s'):format(method), 2)
    end
    return Impl[method](sql, params or {})
end

MySQL = MySQL or {}
for _, m in ipairs({ 'scalar', 'single', 'query', 'insert', 'update' }) do
    local method = m
    MySQL[method] = setmetatable({
        await = function(sql, params)
            return runAwait(method, sql, params)
        end,
    }, {
        __call = function(_, sql, params, cb)
            CreateThread(function()
                if not ensureReady() then return end
                local ok, res = pcall(Impl[method], sql, params or {})
                if not ok then
                    logErr('async %s failed: %s', method, tostring(res))
                    return
                end
                if cb then
                    local cbOk, cbErr = pcall(cb, res)
                    if not cbOk then logErr('async %s callback error: %s', method, tostring(cbErr)) end
                end
            end)
        end,
    })
end

MySQL.ready = setmetatable({
    await = function()
        if not ensureReady() then
            error('s82 sql_bridge: ready timeout — no MySQL driver', 2)
        end
    end,
}, {
    __call = function(_, cb)
        if not cb then return end
        if bridgeReady then
            CreateThread(function() cb() end)
            return
        end
        readyQueue[#readyQueue + 1] = cb
    end,
})

MySQL.__bridge = {
    isReady     = function() return bridgeReady end,
    getDriver   = function() return detected end,
    getDrivers  = function() return { DRIVERS[1], DRIVERS[2], DRIVERS[3] } end,
}

AddEventHandler('onResourceStop', function(res)
    if res ~= detected then return end
    logWarn('driver %s stopped — invalidating bridge, waiting for rediscovery', res)
    bridgeReady     = false
    detected        = nil
    oxmysql_exports = nil
    readyQueue      = {}
    startBootstrap()
end)
