if Bridge.Base ~= 'esx' then return end
local cc = Bridge._customCfg()
local ESX = (cc and cc.getCore and cc.getCore()) or exports['es_extended']:getSharedObject()

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
        ESX.ShowNotification(msg)
    end
end

function Bridge.GetPlayerData()
    local d = ESX.GetPlayerData()
    if not d or not d.identifier then return nil end
    local first = d.firstName or ''
    local last = d.lastName or ''
    local name = d.name or ((first ~= '' or last ~= '') and (first .. ' ' .. last) or '')
    return {
        uid = d.identifier,
        name = name,
        charinfo = { firstname = first, lastname = last },
        job = { name = d.job and d.job.name or '', label = d.job and d.job.label or '', grade = d.job and tonumber(d.job.grade) or 0 },
        raw = d,
    }
end

Bridge._setReady()
