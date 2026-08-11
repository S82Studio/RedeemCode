if Bridge.Base ~= 'qbx' then return end

local cc = Bridge._customCfg()
local qbx = (cc and cc.getCore and cc.getCore()) or exports.qbx_core
Bridge.Core = qbx

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

function Bridge.GetPlayer(src) return norm(qbx:GetPlayer(src)) end
function Bridge.GetPlayerByUid(uid) return norm(qbx:GetPlayerByCitizenId(uid)) end
function Bridge.GetUid(src)
    local p = qbx:GetPlayer(src); return p and p.PlayerData.citizenid or nil
end
function Bridge.GetName(src)
    local p = qbx:GetPlayer(src)
    if not p then return 'Unknown' end
    local c = p.PlayerData.charinfo
    return (c and (c.firstname .. ' ' .. c.lastname)) or 'Unknown'
end
function Bridge.GetPlayers()
    local out = {}
    for _, p in pairs(qbx:GetQBPlayers()) do
        if p and p.PlayerData then out[#out+1] = { src = p.PlayerData.source, uid = p.PlayerData.citizenid } end
    end
    return out
end

Bridge._getAccount    = function(p, key) return (p.PlayerData.money[key] or 0) end
Bridge._addAccount    = function(p, key, a, r) return qbx:AddMoney(p.PlayerData.source, key, a, r) end
Bridge._removeAccount = function(p, key, a, r) return qbx:RemoveMoney(p.PlayerData.source, key, a, r) end
Bridge._rawPlayer = function(src) return qbx:GetPlayer(src) end
Bridge._rawPlayerByUid = function(uid) return qbx:GetPlayerByCitizenId(uid) end

function Bridge.HasGroup(src, group)
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
