if Bridge.Base ~= 'qb' then return end

local cc = Bridge._customCfg()
local QBCore = (cc and cc.getCore and cc.getCore()) or exports['qb-core']:GetCoreObject()
Bridge.Core = QBCore

local function norm(p)
    if not p then return nil end
    local d = p.PlayerData
    return {
        src = d.source, uid = d.citizenid, raw = p,
        name = (d.charinfo and (d.charinfo.firstname .. ' ' .. d.charinfo.lastname)) or 'Unknown',
        charinfo = { firstname = d.charinfo and d.charinfo.firstname or '', lastname = d.charinfo and d.charinfo.lastname or '' },
        job = { name = d.job and d.job.name or '', label = d.job and d.job.label or '', grade = d.job and d.job.grade and d.job.grade.level or 0 },
    }
end
Bridge._norm = norm

function Bridge.GetPlayer(src) return norm(QBCore.Functions.GetPlayer(src)) end
function Bridge.GetPlayerByUid(uid) return norm(QBCore.Functions.GetPlayerByCitizenId(uid)) end
function Bridge.GetUid(src)
    local p = QBCore.Functions.GetPlayer(src); return p and p.PlayerData.citizenid or nil
end
function Bridge.GetName(src)
    local p = QBCore.Functions.GetPlayer(src)
    if not p then return 'Unknown' end
    local c = p.PlayerData.charinfo
    return (c and (c.firstname .. ' ' .. c.lastname)) or 'Unknown'
end
function Bridge.GetPlayers()
    local out = {}
    for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
        if p and p.PlayerData then out[#out+1] = { src = p.PlayerData.source, uid = p.PlayerData.citizenid } end
    end
    return out
end

Bridge._getAccount    = function(p, key) return (p.PlayerData.money[key] or 0) end
Bridge._addAccount    = function(p, key, a, r) return p.Functions.AddMoney(key, a, r) end
Bridge._removeAccount = function(p, key, a, r) return p.Functions.RemoveMoney(key, a, r) end
Bridge._rawPlayer = function(src) return QBCore.Functions.GetPlayer(src) end
Bridge._rawPlayerByUid = function(uid) return QBCore.Functions.GetPlayerByCitizenId(uid) end

function Bridge.HasGroup(src, group)
    if QBCore.Functions.HasPermission then
        return QBCore.Functions.HasPermission(src, group) == true
    end
    return IsPlayerAceAllowed(src, 'group.' .. group)
end

if not (cc and cc.onPlayerLoaded) then
    AddEventHandler((cc and cc.playerLoadedEvent) or 'QBCore:Server:PlayerLoaded', function(Player)
        if Player and Player.PlayerData then
            Bridge._emitPlayerLoaded(Player.PlayerData.source, Player.PlayerData.citizenid)
        end
    end)
end
if not (cc and cc.onPlayerUnload) then
    AddEventHandler((cc and cc.playerUnloadEvent) or 'QBCore:Server:OnPlayerUnload', function(src)
        Bridge._emitPlayerUnload(src, nil)
    end)
end

Bridge._setReady()
