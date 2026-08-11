if Bridge.Framework ~= 'custom' then return end

local c = Bridge._customCfg() or {}

if type(c.normalize) == 'function' then Bridge._norm = c.normalize end
local norm = Bridge._norm

if type(c.getPlayer) == 'function' then Bridge._rawPlayer = c.getPlayer end
if type(c.getPlayerByUid) == 'function' then Bridge._rawPlayerByUid = c.getPlayerByUid end

local dataOverride = type(c.getPlayer) == 'function' or type(c.getPlayerByUid) == 'function'
    or type(c.normalize) == 'function' or type(c.identifierOf) == 'function'

if dataOverride then
    Bridge.GetPlayer = function(src) return norm(Bridge._rawPlayer(src)) end
    Bridge.GetPlayerByUid = function(uid) return norm(Bridge._rawPlayerByUid(uid)) end
    Bridge.GetName = function(src)
        local n = norm(Bridge._rawPlayer(src))
        return n and n.name or 'Unknown'
    end
    Bridge.GetUid = function(src)
        if type(c.identifierOf) == 'function' then return c.identifierOf(Bridge._rawPlayer(src)) end
        local n = norm(Bridge._rawPlayer(src))
        return n and n.uid or nil
    end
end

if type(c.getPlayers) == 'function' then
    Bridge.GetPlayers = function()
        local out = {}
        for _, raw in pairs(c.getPlayers() or {}) do
            local n = norm(raw)
            if n then out[#out+1] = { src = n.src, uid = n.uid } end
        end
        return out
    end
end

if type(c.getAccount) == 'function' then Bridge._getAccount = c.getAccount end
if type(c.addAccount) == 'function' then
    Bridge._addAccount = function(p, key, a, r) c.addAccount(p, key, a, r); return true end
end
if type(c.removeAccount) == 'function' then Bridge._removeAccount = c.removeAccount end

if type(c.hasGroup) == 'function' then Bridge.HasGroup = c.hasGroup end

if type(c.onPlayerLoaded) == 'function' then
    if c.playerLoadedEvent and Debug then Debug.warn('BRIDGE', 'custom: both onPlayerLoaded and playerLoadedEvent set; playerLoadedEvent ignored') end
    c.onPlayerLoaded(Bridge._emitPlayerLoaded)
end
if type(c.onPlayerUnload) == 'function' then
    if c.playerUnloadEvent and Debug then Debug.warn('BRIDGE', 'custom: both onPlayerUnload and playerUnloadEvent set; playerUnloadEvent ignored') end
    c.onPlayerUnload(Bridge._emitPlayerUnload)
end

if Debug then Debug.log('BRIDGE', 'custom framework active (base=%s)', tostring(Bridge.Base)) end
