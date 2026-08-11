if Bridge.Base ~= 'esx' then return end

local cc = Bridge._customCfg()
local ESX = (cc and cc.getCore and cc.getCore()) or exports['es_extended']:getSharedObject()
Bridge.Core = ESX

local function splitName(xPlayer)
    local full = (xPlayer.getName and xPlayer.getName()) or ''
    local a, b = full:match('^(%S+)%s+(.+)$')
    if a then return a, b end
    return full, ''
end

local function norm(xp)
    if not xp then return nil end
    local fn, ln = splitName(xp)
    local job = (xp.getJob and xp.getJob()) or xp.job or {}
    return {
        src = xp.source, uid = xp.identifier, raw = xp,
        name = (xp.getName and xp.getName()) or (fn .. ' ' .. ln),
        charinfo = { firstname = fn, lastname = ln },
        job = { name = job.name or '', label = job.label or '', grade = tonumber(job.grade) or 0 },
    }
end
Bridge._norm = norm

function Bridge.GetPlayer(src) return norm(ESX.GetPlayerFromId(src)) end
function Bridge.GetPlayerByUid(uid) return norm(ESX.GetPlayerFromIdentifier(uid)) end
function Bridge.GetUid(src) local xp = ESX.GetPlayerFromId(src); return xp and xp.identifier or nil end
function Bridge.GetName(src) local n = norm(ESX.GetPlayerFromId(src)); return n and n.name or 'Unknown' end
function Bridge.GetPlayers()
    local out = {}
    for _, xp in pairs(ESX.GetExtendedPlayers()) do
        if xp then out[#out+1] = { src = xp.source, uid = xp.identifier } end
    end
    return out
end

Bridge._getAccount    = function(xp, key) local a = xp.getAccount(key); return (a and a.money) or 0 end
Bridge._addAccount    = function(xp, key, a, r) xp.addAccountMoney(key, a, r); return true end
Bridge._removeAccount = function(xp, key, a, r) xp.removeAccountMoney(key, a, r); return true end
Bridge._rawPlayer = function(src) return ESX.GetPlayerFromId(src) end
Bridge._rawPlayerByUid = function(uid) return ESX.GetPlayerFromIdentifier(uid) end

function Bridge.HasGroup(src, group)
    local xp = ESX.GetPlayerFromId(src)
    return xp ~= nil and xp.getGroup() == group
end

if not (cc and cc.onPlayerLoaded) then
    AddEventHandler((cc and cc.playerLoadedEvent) or 'esx:playerLoaded', function(playerId, xPlayer)
        Bridge._emitPlayerLoaded(playerId, xPlayer and xPlayer.identifier or nil)
    end)
end
if not (cc and cc.onPlayerUnload) then
    AddEventHandler((cc and cc.playerUnloadEvent) or 'esx:playerDropped', function(playerId)
        Bridge._emitPlayerUnload(playerId, nil)
    end)
end

Bridge._setReady()
