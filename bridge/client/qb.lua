if Bridge.Base ~= 'qb' then return end
local cc = Bridge._customCfg()
local QBCore = (cc and cc.getCore and cc.getCore()) or exports['qb-core']:GetCoreObject()

local function notifyBackend()
    local m = (S82Cfg.Framework and S82Cfg.Framework.notify) or 'auto'
    if m == 'framework' then return 'fw' end
    if (m == 'oxlib' or m == 'auto') and GetResourceState('ox_lib') == 'started' then return 'ox' end
    return 'fw'
end

function Bridge.Notify(msg, kind, duration)
    kind = kind or 'info'
    if notifyBackend() == 'ox' then
        TriggerEvent('ox_lib:notify', { description = msg, type = Bridge._KIND_OX[kind] or 'inform', duration = duration or 5000 })
    else
        QBCore.Functions.Notify(msg, Bridge._KIND_QB[kind] or 'primary', duration or 5000)
    end
end

function Bridge.GetPlayerData()
    local d = QBCore.Functions.GetPlayerData()
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
