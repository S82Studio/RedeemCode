Bridge = Bridge or {}

local IS_SERVER = IsDuplicityVersion()

local function dbg(msg, ...)
    if Debug then Debug.log('BRIDGE', msg, ...) end
end

local function started(res) return GetResourceState(res) == 'started' end

local function detectFramework()
    local mode = (S82Cfg.Framework and S82Cfg.Framework.mode) or 'auto'
    if mode ~= 'auto' then return mode end
    if started('qbx_core') then return 'qbx' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return nil
end

local function detectInventory(fw)
    local mode = (S82Cfg.Framework and S82Cfg.Framework.inventory) or 'auto'
    if mode ~= 'auto' then return mode end
    if started('ox_inventory') then return 'ox' end
    if started('qs-inventory') then return 'qs' end
    if started('ps-inventory') then return 'ps' end
    if started('codem-inventory') then return 'codem' end
    if started('tgiann-inventory') then return 'tgiann' end
    if started('qb-inventory') then return 'qb' end
    if fw == 'esx' then return 'esx_native' end
    return nil
end

Bridge.Framework = detectFramework()
if Bridge.Framework == 'custom' then
    local base = (S82Cfg.Framework and S82Cfg.Framework.custom and S82Cfg.Framework.custom.base) or nil
    if base == 'qb' or base == 'qbx' or base == 'esx' then
        Bridge.Base = base
    else
        if Debug then Debug.err('[BRIDGE] custom framework: invalid base %q (expected qb|qbx|esx) — resource inert', tostring(base)) end
        Bridge.Framework = nil
    end
else
    Bridge.Base = Bridge.Framework
end
Bridge.Inventory = Bridge.Base and detectInventory(Bridge.Base) or nil

function Bridge._customCfg()
    if Bridge.Framework ~= 'custom' then return nil end
    return (S82Cfg.Framework and S82Cfg.Framework.custom) or {}
end

if not Bridge.Framework then
    if Debug then Debug.err('[BRIDGE] no supported framework detected (esx/qb/qbx) — resource inert') end
elseif not Bridge.Inventory then
    if Debug then Debug.err('[BRIDGE] no supported inventory detected for framework %s', tostring(Bridge.Framework)) end
else
    dbg('detected framework=%s inventory=%s', tostring(Bridge.Framework), tostring(Bridge.Inventory))
end

Bridge._ready = false
local readyCbs, loadedCbs, unloadCbs = {}, {}, {}

function Bridge.IsReady() return Bridge._ready end

function Bridge.OnReady(cb)
    if Bridge._ready then cb() else readyCbs[#readyCbs+1] = cb end
end

function Bridge._setReady()
    if Bridge._ready then return end
    Bridge._ready = true
    for _, cb in ipairs(readyCbs) do pcall(cb) end
end

function Bridge.OnPlayerLoaded(cb) loadedCbs[#loadedCbs+1] = cb end
function Bridge.OnPlayerUnload(cb) unloadCbs[#unloadCbs+1] = cb end
function Bridge._emitPlayerLoaded(src, uid)
    for _, cb in ipairs(loadedCbs) do pcall(cb, src, uid) end
end
function Bridge._emitPlayerUnload(src, uid)
    for _, cb in ipairs(unloadCbs) do pcall(cb, src, uid) end
end

local KIND_OX = { success='success', error='error', info='inform', warning='warning' }
local KIND_QB = { success='success', error='error', info='primary', warning='warning' }
function Bridge.MapKind(kind)
    kind = kind or 'info'
    if Bridge.Base == 'esx' then return kind end
    return kind
end
Bridge._KIND_OX = KIND_OX
Bridge._KIND_QB = KIND_QB

local IMAGE_TEMPLATES = {
    ox          = 'nui://ox_inventory/web/images/%s.png',
    qb          = 'nui://qb-inventory/html/images/%s.png',
    qs          = 'nui://qs-inventory/html/images/%s.png',
    ps          = 'nui://ps-inventory/html/images/%s.png',
    codem       = 'nui://codem-inventory/html/itemimages/%s.png',
    tgiann      = 'nui://inventory_images/images/%s.webp',
    esx_native  = '',
}
function Bridge.ImageTemplate()
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return override end
    return IMAGE_TEMPLATES[Bridge.Inventory] or ''
end

local CB_REQ = 's82:bridge:cbReq'
local CB_RES = 's82:bridge:cbRes'

if IS_SERVER then
    local handlers = {}
    function Bridge.RegisterCallback(name, fn)
        handlers[name] = fn
    end
    RegisterNetEvent(CB_REQ, function(reqId, name, ...)
        local src = source
        local fn = handlers[name]
        if not fn then
            if Debug then Debug.warn('BRIDGE', 'no server callback registered: %s', tostring(name)) end
            TriggerClientEvent(CB_RES, src, reqId)
            return
        end
        local args = table.pack(...)
        fn(src, function(...)
            TriggerClientEvent(CB_RES, src, reqId, ...)
        end, table.unpack(args, 1, args.n))
    end)

    local fw = Bridge.Base
    local moneyCfg = S82Cfg.Money or {}

    local activeTypes = {}
    local typeById = {}
    for _, t in ipairs(moneyCfg.types or {}) do
        local key = t.accounts and t.accounts[fw]
        local idOk = t.id and tostring(t.id):match('^[%w_%-]+$')
        if key and idOk and tostring(key):match('^%w+$') then
            local entry = { id = t.id, label = t.label or t.id, icon = t.icon or '', key = key }
            activeTypes[#activeTypes+1] = entry
            typeById[t.id] = entry
        elseif key and not idOk then
            dbg('money type dropped: invalid id %q (allowed: alphanumeric, _ and -)', tostring(t.id))
        elseif key then
            dbg('money type %s dropped: invalid account key %q', tostring(t.id), tostring(key))
        end
    end

    local payoutEntry = typeById[moneyCfg.payoutType] or typeById['bank'] or activeTypes[1]
    if moneyCfg.payoutType and not typeById[moneyCfg.payoutType] and Debug then
        Debug.warn('BRIDGE', 'payoutType %q not active, falling back to %s',
            tostring(moneyCfg.payoutType), payoutEntry and payoutEntry.id or 'none')
    end
    if #activeTypes == 0 and Debug then
        Debug.err('[BRIDGE] no active money types resolved for framework %s', tostring(fw))
    end

    function Bridge.GetBalance(src)
        local p = Bridge._rawPlayer(src)
        if not p or not payoutEntry then return 0 end
        return Bridge._getAccount(p, payoutEntry.key) or 0
    end

    function Bridge.GetMoneyConfig()
        if not payoutEntry then return {} end
        return { id = payoutEntry.id, label = payoutEntry.label, icon = payoutEntry.icon }
    end

    function Bridge.RemoveMoney(src, amount, reason)
        local p = Bridge._rawPlayer(src)
        if not p or not payoutEntry then return false end
        reason = reason or 'redeem-code'
        if (Bridge._getAccount(p, payoutEntry.key) or 0) < amount then return false end
        local ok = Bridge._removeAccount(p, payoutEntry.key, amount, reason) ~= false
        return ok
    end

    function Bridge.AddMoney(src, amount, reason, typeId)
        local p = Bridge._rawPlayer(src)
        if not p then return false end
        local entry
        if typeId == nil then
            entry = payoutEntry
        else
            entry = typeById[typeId]
        end
        if not entry then return false end
        reason = reason or 'redeem-code'
        return Bridge._addAccount(p, entry.key, amount, reason) ~= false
    end

    function Bridge.GetMoneyTypes()
        local out = {}
        for _, t in ipairs(activeTypes) do
            out[#out+1] = { id = t.id, label = t.label, icon = t.icon }
        end
        return out
    end

    function Bridge.IsMoneyType(id)
        return typeById[id] ~= nil
    end

    function Bridge.GetMoneyType(id)
        local t = typeById[id]
        if not t then return nil end
        return { id = t.id, label = t.label, icon = t.icon }
    end

    function Bridge._parseIdentifiers(src)
        local out = {}
        for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            local kind, val = tostring(id):match('^(%w+):(.+)$')
            if kind and not out[kind] then out[kind] = val end
        end
        return out
    end

    local UID_SOURCE = {
        qb  = { table = 'players', col = 'citizenid' },
        qbx = { table = 'players', col = 'citizenid' },
        esx = { table = 'users',   col = 'identifier' },
    }

    function Bridge.GetUidSource()
        local cc = Bridge._customCfg()
        local base = UID_SOURCE[Bridge.Base]
        local tbl = (cc and cc.playersTable) or (base and base.table)
        local col = (cc and cc.uidColumn) or (base and base.col)
        if not tbl or not col then return nil end
        return { table = tbl, col = col }
    end

    function Bridge.GetIdentity(uid)
        if not uid then return nil end
        local info = { citizenid = uid, online = false }
        local p = Bridge.GetPlayerByUid(uid)
        if p and p.src then
            info.online    = true
            info.firstname = p.charinfo and p.charinfo.firstname or ''
            info.lastname  = p.charinfo and p.charinfo.lastname or ''
            info.name      = p.name
            local ids = Bridge._parseIdentifiers(p.src)
            info.steam     = ids.steam
            info.license   = ids.license
            info.discord   = ids.discord
            info.fivem     = ids.fivem
        end
        return info
    end
else
    local pending = {}
    local seq = 0
    RegisterNetEvent(CB_RES, function(reqId, ...)
        local cb = pending[reqId]
        if not cb then return end
        pending[reqId] = nil
        cb(...)
    end)
    function Bridge.TriggerCallback(name, cb, ...)
        seq = seq + 1
        local reqId = seq
        pending[reqId] = cb or function() end
        TriggerServerEvent(CB_REQ, reqId, name, ...)
        SetTimeout(60000, function()
            if pending[reqId] then
                pending[reqId] = nil
                if Debug then Debug.warn('BRIDGE', 'callback timed out: %s', tostring(name)) end
            end
        end)
    end
end
