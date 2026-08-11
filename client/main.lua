local isOpen = false
local adminOpen = false


CreateThread(function()
    local redeemCmd = S82Cfg.Command and S82Cfg.Command.redeem or 'redeem'
    if type(redeemCmd) ~= 'string' or redeemCmd == '' then redeemCmd = 'redeem' end

    RegisterCommand(redeemCmd, function()
        if isOpen or adminOpen then return end
        TriggerServerEvent('s82:server:openRedeem')
    end, false)
    Debug.log('INIT', 'redeem command registered: /%s', redeemCmd)

    if not (S82Cfg.Command and S82Cfg.Command.suggestion == false) then
        TriggerEvent('chat:addSuggestion', '/' .. redeemCmd, _L('command_suggestion'))
    end

    local adminCmd = S82Cfg.Command and S82Cfg.Command.admin or 'redeemadmin'
    if type(adminCmd) ~= 'string' or adminCmd == '' then adminCmd = 'redeemadmin' end

    RegisterCommand(adminCmd, function()
        if isOpen or adminOpen then return end
        TriggerServerEvent('s82:server:openAdmin')
    end, false)
    Debug.log('INIT', 'admin command registered: /%s', adminCmd)

    if not (S82Cfg.Command and S82Cfg.Command.suggestion == false) then
        TriggerEvent('chat:addSuggestion', '/' .. adminCmd, _L('admin_command_suggestion'))
    end
end)


local function pushDebugConfig()
    SendNUIMessage({
        action  = 'debug:config',
        payload = Debug.buildNuiPayload(),
    })
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pushDebugConfig()
    Debug.log('INIT', 'client ready: locale=%s',
        (S82Cfg and S82Cfg.Locale) or 'en')
end)


RegisterNetEvent('s82:client:openRedeem', function(data)
    if isOpen or adminOpen then return end
    isOpen = true
    data = data or {}

    Debug.log('UI', 'opening redeem panel')
    SetNuiFocus(true, true)
    pushDebugConfig()
    SendNUIMessage({
        action  = 'openRedeem',
        locale  = data.locale or {},
        imageTemplate = Bridge.ImageTemplate and Bridge.ImageTemplate() or '',
    })
end)


RegisterNetEvent('s82:client:openAdmin', function(data)
    if isOpen or adminOpen then return end
    adminOpen = true
    data = data or {}

    Debug.log('UI', 'opening admin panel: codes=%d history=%d items=%d',
        #(data.codes or {}), #(data.history or {}), #(data.items or {}))
    SetNuiFocus(true, true)
    pushDebugConfig()
    SendNUIMessage({
        action  = 'openAdmin',
        locale  = data.locale or {},
        codes   = data.codes or {},
        history = data.history or {},
        items   = data.items or {},
        moneyTypes = data.moneyTypes or {},
        imageTemplate = Bridge.ImageTemplate and Bridge.ImageTemplate() or '',
    })
end)


RegisterNUICallback('closeUI', function(_, cb)
    cb('ok')
    isOpen = false
    adminOpen = false
    SetNuiFocus(false, false)
    Debug.log('UI', 'UI closed')
end)

RegisterNUICallback('redeemCode', function(data, cb)
    cb('ok')
    Debug.log('UI', 'redeem submit')
    TriggerServerEvent('s82:server:redeemCode', data)
end)

RegisterNUICallback('createCode', function(data, cb)
    cb('ok')
    Debug.log('UI', 'admin create submit code=%s', tostring(data and data.code))
    TriggerServerEvent('s82:server:createCode', data)
end)

RegisterNUICallback('updateCode', function(data, cb)
    cb('ok')
    Debug.log('UI', 'admin update submit code=%s', tostring(data and data.code))
    TriggerServerEvent('s82:server:updateCode', data)
end)

RegisterNUICallback('deleteCode', function(data, cb)
    cb('ok')
    Debug.log('UI', 'admin delete submit code=%s', tostring(data and data.code))
    TriggerServerEvent('s82:server:deleteCode', data)
end)

RegisterNUICallback('clearHistory', function(_, cb)
    cb('ok')
    Debug.log('UI', 'admin clear history submit')
    TriggerServerEvent('s82:server:clearHistory')
end)

RegisterNUICallback('getOnlinePlayers', function(_, cb)
    cb('ok')
    Debug.log('UI', 'admin request online players')
    TriggerServerEvent('s82:server:getOnlinePlayers')
end)


RegisterNetEvent('s82:client:redeemResult', function(success, message, rewards)
    Debug.log('UI', 'redeem result: success=%s money=%s items=%d',
        tostring(success), tostring(rewards and rewards.money or 0), rewards and #(rewards.items or {}) or 0)
    SendNUIMessage({
        action  = 'redeemResult',
        success = success,
        message = message,
        rewards = rewards,
    })
    if success then
        local notifyStyle = (S82Cfg.Framework and S82Cfg.Framework.notifyStyle) or 'custom'
        if notifyStyle == 'native' and Bridge.Notify then
            Bridge.Notify(message, 'success', 5000)
        end
    end
end)


RegisterNetEvent('s82:client:codeCreated', function(message, codes)
    SendNUIMessage({
        action  = 'codeCreated',
        message = message,
        codes   = codes,
    })
end)


RegisterNetEvent('s82:client:codeDeleted', function(message, codes)
    SendNUIMessage({
        action  = 'codeDeleted',
        message = message,
        codes   = codes,
    })
end)


RegisterNetEvent('s82:client:historyCleared', function(message)
    SendNUIMessage({
        action  = 'historyCleared',
        message = message,
    })
end)


RegisterNetEvent('s82:client:onlinePlayers', function(players)
    SendNUIMessage({
        action  = 'onlinePlayers',
        players = players or {},
    })
end)


RegisterNetEvent('s82:client:toast', function(message, ntype)
    SendNUIMessage({
        action  = 'toast',
        message = message,
        type    = ntype or 'info',
    })
end)


RegisterNetEvent('s82:client:notify', function(message, ntype)
    local style = (S82Cfg.Framework and S82Cfg.Framework.notifyStyle) or 'custom'
    if style == 'custom' then
        SendNUIMessage({
            action  = 'toast',
            message = message,
            type    = ntype or 'info',
        })
    elseif Bridge.Notify then
        Bridge.Notify(message, ntype, 5000)
    end
end)
