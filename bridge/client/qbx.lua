if Bridge.Base ~= 'qbx' then return end

local cc = Bridge._customCfg()
local qbx = (cc and cc.getCore and cc.getCore()) or exports.qbx_core

local function notifyBackend()
    local m = (S82Cfg.Framework and S82Cfg.Framework.notify) or 'auto'
    if m == 'framework' then return 'fw' end
    if (m == 'oxlib' or m == 'auto') and GetResourceState('ox_lib') == 'started' then return 'ox' end
    return 'fw'
end

local function fwNotify(msg, kind, duration)
    local t = Bridge._KIND_OX[kind] or 'inform'
    local ok = pcall(function() qbx:Notify(msg, t, duration or 5000) end)
    if not ok and GetResourceState('qb-core') == 'started' then
        exports['qb-core']:GetCoreObject().Functions.Notify(msg, Bridge._KIND_QB[kind] or 'primary', duration or 5000)
    end
end

function Bridge.Notify(msg, kind, duration)
    kind = kind or 'info'
    if notifyBackend() == 'ox' then
        TriggerEvent('ox_lib:notify', { description = msg, type = Bridge._KIND_OX[kind] or 'inform', duration = duration or 5000 })
    else
        fwNotify(msg, kind, duration)
    end
end

local function rawPlayerData()
    local ok, d = pcall(function() return qbx:GetPlayerData() end)
    if ok and d then return d end
    if GetResourceState('qb-core') == 'started' then
        return exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
    end
    return nil
end

function Bridge.GetPlayerData()
    local d = rawPlayerData()
    if not d or not d.citizenid then return nil end
    return {
        uid = d.citizenid,
        name = (d.charinfo and (d.charinfo.firstname .. ' ' .. d.charinfo.lastname)) or 'Unknown',
        charinfo = { firstname = d.charinfo and d.charinfo.firstname or '', lastname = d.charinfo and d.charinfo.lastname or '' },
        job = { name = d.job and d.job.name or '', label = d.job and d.job.label or '', grade = d.job and d.job.grade and d.job.grade.level or 0 },
        raw = d,
    }
end

Bridge._setReady()
