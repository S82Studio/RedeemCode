local GetCitizenId = Bridge.GetUid
local GetPlayerName = Bridge.GetName
local AddMoney = Bridge.AddMoney


local function isFiniteNum(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

local function SanitizeText(s, maxLen)
    s = tostring(s or ''):gsub('[<>]', '')
    if maxLen then s = s:sub(1, maxLen) end
    return s
end

local function NotifyClient(src, message, ntype)
    TriggerClientEvent('s82:client:notify', src, message, ntype or 'info')
end


local cooldowns = {}
local COOLDOWN_MS = (S82Cfg.Codes and S82Cfg.Codes.cooldownMs) or 2000

local function isOnCooldown(src)
    local now = GetGameTimer()
    if cooldowns[src] and (now - cooldowns[src]) < COOLDOWN_MS then
        return true
    end
    cooldowns[src] = now
    return false
end


local adminCooldowns = {}
local ADMIN_CD = (S82Cfg.Admin and S82Cfg.Admin.actionCooldownMs) or 800

local function isAdminOnCooldown(src)
    local now = GetGameTimer()
    if adminCooldowns[src] and (now - adminCooldowns[src]) < ADMIN_CD then
        return true
    end
    adminCooldowns[src] = now
    return false
end


local function IsAdmin(src)
    local ace = S82Cfg.Admin and S82Cfg.Admin.acePermission
    if ace and ace ~= '' then
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    local groups = S82Cfg.Admin and S82Cfg.Admin.frameworkGroups or {}
    for _, group in ipairs(groups) do
        if Bridge.HasGroup and Bridge.HasGroup(src, group) then return true end
    end
    return false
end


local function SendWebhook(event, data)
    if not Webhooks or not S82Cfg.Admin or not S82Cfg.Admin.auditWebhook then return end
    local evtCfg = Webhooks.events and Webhooks.events[event]
    if not evtCfg or not evtCfg.enabled then return end

    local url = (evtCfg.url and evtCfg.url ~= '') and evtCfg.url or Webhooks.defaultUrl
    if not url or url == '' then return end

    local pattern = Webhooks.urlValidationPattern
    if pattern and not url:match(pattern) then
        Debug.warn('WEBHOOK', 'url rejected by pattern: %s', url)
        return
    end

    local embed = {
        title       = data.title or event,
        description = data.description or '',
        color       = evtCfg.color or 0x7289DA,
        fields      = data.fields or {},
        footer      = { text = os.date('%Y-%m-%d %H:%M:%S') },
    }

    Debug.log('WEBHOOK', 'dispatch event=%s fields=%d', event, #(data.fields or {}))
    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            Debug.warn('WEBHOOK', 'dispatch failed event=%s status=%s', event, tostring(status))
        end
    end, 'POST', json.encode({
        username   = Webhooks.username or 's82',
        avatar_url = Webhooks.avatarUrl or '',
        embeds     = { embed },
    }), { ['Content-Type'] = 'application/json' })
end


CreateThread(function()
    MySQL.ready.await()
    DB.InitSchema()
    Debug.log('INIT', 's82 server ready (framework=%s inventory=%s)',
        tostring(Bridge.Framework), tostring(Bridge.Inventory))
end)


local function GetAllInventoryItems()
    if Bridge.GetAllItems then
        local ok, items = pcall(Bridge.GetAllItems)
        if not ok then
            Debug.warn('BRIDGE', 'GetAllItems failed: %s', tostring(items))
        end
        if ok and type(items) == 'table' then
            Debug.log('BRIDGE', 'inventory item list: %d items', #items)
            if Bridge.GetItemImage then
                for _, item in ipairs(items) do
                    if type(item) == 'table' and item.name then
                        local okImg, img = pcall(Bridge.GetItemImage, item.name)
                        if okImg and img and img ~= '' then
                            item.image = img
                        end
                    end
                end
            end
            return items
        end
    end
    return {}
end

local function GetSteamHex(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if string.sub(id, 1, 6) == 'steam:' then return id end
    end
    return nil
end

local function GetOnlinePlayersForNUI()
    local out = {}
    local players = (Bridge.GetPlayers and Bridge.GetPlayers()) or {}
    for _, entry in ipairs(players) do
        local psrc = entry.src
        if psrc then
            local np = Bridge.GetPlayer and Bridge.GetPlayer(psrc) or nil
            local firstname = (np and np.charinfo and np.charinfo.firstname) or ''
            local lastname  = (np and np.charinfo and np.charinfo.lastname) or ''
            local charName  = (np and np.name) or ((firstname .. ' ' .. lastname):gsub('^%s+', ''):gsub('%s+$', ''))
            out[#out+1] = {
                source    = psrc,
                citizenid = entry.uid,
                steamName = _G.GetPlayerName(psrc),
                steamHex  = GetSteamHex(psrc),
                firstname = firstname,
                lastname  = lastname,
                charName  = charName,
            }
        end
    end
    return out
end

local function ValidatePrivateTargets(isPrivate, rawTargets)
    if not isPrivate then return {}, nil end

    local seen, targets = {}, {}
    local maxT = (S82Cfg.Codes and S82Cfg.Codes.maxPrivateTargets) or 50
    if type(rawTargets) == 'table' then
        for _, t in ipairs(rawTargets) do
            if type(t) == 'string' then
                local id = SanitizeText(t, 64):gsub('%s', '')
                if id ~= '' and not seen[id] then
                    seen[id] = true
                    targets[#targets+1] = id
                    if #targets >= maxT then break end
                end
            end
        end
    end

    if #targets == 0 then return nil, 'admin_error_no_targets' end

    if not (S82Cfg.Codes and S82Cfg.Codes.validatePrivateTarget == false) then
        local online, toCheck = {}, {}
        for _, id in ipairs(targets) do
            if Bridge.GetPlayerByUid and Bridge.GetPlayerByUid(id) then
                online[id] = true
            else
                toCheck[#toCheck+1] = id
            end
        end
        if #toCheck > 0 then
            local src = Bridge.GetUidSource and Bridge.GetUidSource()
            if not src then return nil, 'admin_target_unverifiable' end
            local existing = DB.PlayersExist(src.table, src.col, toCheck)
            if existing == nil then return nil, 'admin_target_unverifiable' end
            local canon = {}
            for canonical in pairs(existing) do canon[canonical:lower()] = canonical end
            local resolved = {}
            for _, id in ipairs(targets) do
                if online[id] then
                    resolved[#resolved+1] = id
                else
                    local c = canon[id:lower()]
                    if not c then return nil, 'admin_targets_not_found' end
                    resolved[#resolved+1] = c
                end
            end
            return resolved, nil
        end
    end

    return targets, nil
end

local function SanitizeMoneys(rawList)
    local byId, order = {}, {}
    if type(rawList) == 'table' then
        for _, e in ipairs(rawList) do
            if type(e) == 'table' and type(e.type) == 'string'
               and Bridge.IsMoneyType and Bridge.IsMoneyType(e.type) then
                local amt = math.floor(tonumber(e.amount) or 0)
                if amt > 0 then
                    if not byId[e.type] then order[#order+1] = e.type; byId[e.type] = 0 end
                    byId[e.type] = byId[e.type] + amt
                end
            end
        end
    end
    local maxMoney = (S82Cfg.Rewards and S82Cfg.Rewards.maxMoney) or 1000000
    local list, sum = {}, 0
    for _, id in ipairs(order) do
        list[#list+1] = { type = id, amount = byId[id] }
        sum = sum + byId[id]
    end
    if sum > maxMoney then return nil, 0, 'admin_money_over_limit' end
    return list, sum, nil
end

local function MoneyLabel(typeId)
    if Bridge.GetMoneyType then
        local t = Bridge.GetMoneyType(typeId)
        if t and t.label then return t.label end
    end
    return typeId
end

local function FormatDateTime(val)
    if not val then return nil end
    if type(val) == 'string' then
        return val
    elseif type(val) == 'number' then
        if val > 1000000000000 then
            val = math.floor(val / 1000)
        end
        return os.date('%Y-%m-%d %H:%M:%S', val)
    elseif type(val) == 'table' then
        local ok, t = pcall(os.time, val)
        if ok then
            return os.date('%Y-%m-%d %H:%M:%S', t)
        end
    end
    return tostring(val)
end

local function FormatCodeForNUI(row)
    local items = {}
    if row.items then
        local ok, parsed = pcall(json.decode, row.items)
        if ok and type(parsed) == 'table' then
            for _, item in ipairs(parsed) do
                local label = item.name
                if Bridge.GetItemLabel then
                    local ok2, l = pcall(Bridge.GetItemLabel, item.name)
                    if ok2 and l then label = l end
                end
                items[#items+1] = { name = item.name, label = label, amount = item.amount or 1 }
            end
        end
    end
    local moneys = {}
    if row.moneys then
        local ok, parsed = pcall(json.decode, row.moneys)
        if ok and type(parsed) == 'table' then
            for _, m in ipairs(parsed) do
                if type(m) == 'table' and m.type then
                    moneys[#moneys+1] = { type = m.type, amount = tonumber(m.amount) or 0, label = MoneyLabel(m.type) }
                end
            end
        end
    end
    if #moneys == 0 and (row.money or 0) > 0 and Bridge.GetMoneyConfig then
        local mc = Bridge.GetMoneyConfig()
        if mc and mc.id then
            moneys[1] = { type = mc.id, amount = row.money, label = MoneyLabel(mc.id) }
        end
    end
    local targetCitizenIds = {}
    if row.target_citizenids then
        local ok, parsed = pcall(json.decode, row.target_citizenids)
        if ok and type(parsed) == 'table' then
            for _, t in ipairs(parsed) do
                if type(t) == 'string' then targetCitizenIds[#targetCitizenIds+1] = t end
            end
        end
    end
    if #targetCitizenIds == 0 and row.target_citizenid and row.target_citizenid ~= '' then
        targetCitizenIds[1] = row.target_citizenid
    end
    return {
        id             = row.id,
        code           = row.code,
        reward_type    = row.reward_type,
        money          = row.money or 0,
        moneys         = moneys,
        items          = items,
        max_uses       = row.max_uses or 0,
        uses           = row.uses or 0,
        expiry         = FormatDateTime(row.expiry),
        is_private     = (row.is_private or 0) == 1,
        target_citizenid = row.target_citizenid,
        target_citizenids = targetCitizenIds,
        created_by     = row.created_by,
        creator_name   = row.creator_name,
        creator_steam  = row.creator_steam,
        created_at     = FormatDateTime(row.created_at),
    }
end

local function FormatHistoryForNUI(row)
    local itemsText = ''
    if row.items then
        local ok, parsed = pcall(json.decode, row.items)
        if ok and type(parsed) == 'table' then
            local parts = {}
            for _, item in ipairs(parsed) do
                parts[#parts+1] = (item.label or item.name) .. ' x' .. (item.amount or 1)
            end
            itemsText = table.concat(parts, ', ')
        end
    end
    local moneysList, moneysParts = {}, {}
    if row.moneys then
        local ok, parsed = pcall(json.decode, row.moneys)
        if ok and type(parsed) == 'table' then
            for _, m in ipairs(parsed) do
                if type(m) == 'table' and m.type then
                    local label = m.label or MoneyLabel(m.type)
                    local amt = tonumber(m.amount) or 0
                    moneysList[#moneysList+1] = { type = m.type, amount = amt, label = label }
                    moneysParts[#moneysParts+1] = label .. ' $' .. tostring(amt)
                end
            end
        end
    end
    return {
        code            = row.code,
        redeemed_by     = row.citizenid,
        redeemed_by_name = row.player_name or row.citizenid,
        steam           = row.steam,
        redeemed_at     = FormatDateTime(row.redeemed_at),
        money           = row.money or 0,
        moneys          = moneysList,
        moneys_text     = table.concat(moneysParts, ', '),
        items_text      = itemsText,
        reward_type     = row.reward_type,
    }
end



RegisterNetEvent('s82:server:redeemCode', function(data)
    local src = source
    if not src or src <= 0 then return end

    if isOnCooldown(src) then
        Debug.warn('SECURITY', 'redeem reject src=%d reason=cooldown', src)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_cooldown'))
        return
    end

    local code = data and data.code
    if type(code) ~= 'string' or code:gsub('%s', '') == '' then
        Debug.warn('SECURITY', 'redeem reject src=%d reason=invalid_payload', src)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_empty'))
        return
    end
    code = SanitizeText(code:gsub('%s', ''), S82Cfg.Codes and S82Cfg.Codes.maxCodeLength or 32)

    local citizenid = GetCitizenId(src)
    if not citizenid then
        Debug.warn('SECURITY', 'redeem reject src=%d reason=no_identifier', src)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_error'))
        return
    end

    Debug.log('CODE', 'redeem attempt src=%d citizenid=%s code=%s', src, tostring(citizenid), code)

    local row
    if S82Cfg.Codes and S82Cfg.Codes.caseInsensitive then
        row = DB.GetCodeCaseInsensitive(code)
    else
        row = DB.GetCode(code)
    end

    if not row then
        Debug.log('CODE', 'redeem miss src=%d code=%s reason=not_found', src, code)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_invalid'))
        return
    end

    if (row.deleted or 0) == 1 then
        Debug.log('CODE', 'redeem miss src=%d code=%s reason=deleted', src, code)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_invalid'))
        return
    end

    if row.expiry then
        local expiryTs = row.expiry
        local now = os.time()
        local expiryTime = nil

        if type(expiryTs) == 'number' then
            if expiryTs > 1000000000000 then
                expiryTime = math.floor(expiryTs / 1000)
            else
                expiryTime = expiryTs
            end
        elseif type(expiryTs) == 'string' then
            local nowStr = os.date('%Y-%m-%d %H:%M:%S')
            if expiryTs < nowStr then
                Debug.log('CODE', 'redeem miss src=%d code=%s reason=expired', src, code)
                TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_expired'))
                return
            end
        elseif type(expiryTs) == 'table' then
            local ok, t = pcall(os.time, expiryTs)
            if ok then expiryTime = t end
        end

        if expiryTime and expiryTime < now then
            Debug.log('CODE', 'redeem miss src=%d code=%s reason=expired', src, code)
            TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_expired'))
            return
        end
    end

    if row.max_uses > 0 and row.uses >= row.max_uses then
        Debug.log('CODE', 'redeem miss src=%d code=%s reason=max_uses uses=%d/%d', src, code, row.uses, row.max_uses)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_max_uses'))
        return
    end

    if (row.is_private or 0) == 1 then
        local targets = {}
        if row.target_citizenids then
            local ok, parsed = pcall(json.decode, row.target_citizenids)
            if ok and type(parsed) == 'table' then
                for _, t in ipairs(parsed) do
                    if type(t) == 'string' then targets[#targets+1] = t end
                end
            end
        end
        if #targets == 0 and row.target_citizenid and row.target_citizenid ~= '' then
            targets = { row.target_citizenid }
        end

        local allowed = false
        for _, t in ipairs(targets) do
            if t == citizenid then allowed = true break end
        end
        if not allowed then
            Debug.warn('SECURITY', 'redeem reject src=%d code=%s reason=private_mismatch citizenid=%s',
                src, code, tostring(citizenid))
            TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_private'))
            return
        end
    end

    if DB.HasRedeemed(row.id, citizenid) then
        Debug.log('CODE', 'redeem miss src=%d code=%s reason=already_used', src, code)
        TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_already_used'))
        return
    end

    local rewardItems = {}
    if row.items then
        local ok, parsed = pcall(json.decode, row.items)
        if ok and type(parsed) == 'table' then
            rewardItems = parsed
        end
    end

    if #rewardItems > 0 and Bridge.CanCarry then
        for _, item in ipairs(rewardItems) do
            if not Bridge.CanCarry(src, item.name, item.amount or 1) then
                Debug.warn('REDEEM', 'inventory full src=%d code=%s item=%s x%d',
                    src, code, item.name, item.amount or 1)
                TriggerClientEvent('s82:client:redeemResult', src, false, Translate('redeem_inventory_full'))
                return
            end
        end
    end


    local rewardMoneys = {}
    if row.moneys then
        local ok, parsed = pcall(json.decode, row.moneys)
        if ok and type(parsed) == 'table' then rewardMoneys = parsed end
    end

    local moneyGiven = 0
    local moneysGiven = {}
    if #rewardMoneys > 0 then
        for _, m in ipairs(rewardMoneys) do
            local amt = math.floor(tonumber(m.amount) or 0)
            if type(m.type) == 'string' and amt > 0 then
                local ok = AddMoney(src, amt, 'redeem-code-' .. row.code, m.type)
                if ok then
                    moneyGiven = moneyGiven + amt
                    moneysGiven[#moneysGiven+1] = { type = m.type, amount = amt, label = MoneyLabel(m.type) }
                else
                    Debug.warn('REDEEM', 'failed to add money %d (%s) to player %s (code=%s)',
                        amt, tostring(m.type), tostring(citizenid), row.code)
                end
            end
        end
    elseif row.money and row.money > 0 then
        local ok = AddMoney(src, row.money, 'redeem-code-' .. row.code)
        if ok then
            moneyGiven = row.money
        else
            Debug.warn('REDEEM', 'failed to add money %d to player %s (code=%s)',
                row.money, tostring(citizenid), row.code)
        end
    end

    local itemsGiven = {}
    for _, item in ipairs(rewardItems) do
        local ok = Bridge.AddItem(src, item.name, item.amount or 1, item.metadata)
        if ok then
            local label = item.name
            if Bridge.GetItemLabel then
                local ok2, l = pcall(Bridge.GetItemLabel, item.name)
                if ok2 and l then label = l end
            end
            local img = nil
            if Bridge.GetItemImage then
                local ok3, imgPath = pcall(Bridge.GetItemImage, item.name)
                if ok3 and imgPath and imgPath ~= '' then img = imgPath end
            end
            itemsGiven[#itemsGiven+1] = { name = item.name, label = label, amount = item.amount or 1, image = img }
        else
            Debug.warn('REDEEM', 'failed to add item %s x%d to player %s',
                item.name, item.amount or 1, tostring(citizenid))
        end
    end

    local steamHex = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 6) == 'steam:' then
            steamHex = id
            break
        end
    end

    DB.IncrementUses(row.id)
    DB.RecordRedemption({
        code_id     = row.id,
        code        = row.code,
        citizenid   = citizenid,
        steam       = steamHex,
        player_name = GetPlayerName(src),
        money       = moneyGiven,
        moneys      = #moneysGiven > 0 and moneysGiven or nil,
        items       = itemsGiven,
    })

    Debug.log('REDEEM', 'player %s (%s) redeemed code %s → money=%d items=%d',
        tostring(citizenid), GetPlayerName(src), row.code, moneyGiven, #itemsGiven)

    local fields = {
        { name = 'Code', value = row.code, inline = true },
        { name = 'Player', value = ('%s (%s)'):format(GetPlayerName(src), citizenid), inline = true },
    }
    if #moneysGiven > 0 then
        local parts = {}
        for _, m in ipairs(moneysGiven) do parts[#parts+1] = (m.label or m.type) .. ' $' .. tostring(m.amount) end
        fields[#fields+1] = { name = 'Money', value = table.concat(parts, ', '), inline = false }
    elseif moneyGiven > 0 then
        fields[#fields+1] = { name = 'Money', value = '$' .. tostring(moneyGiven), inline = true }
    end
    if #itemsGiven > 0 then
        local parts = {}
        for _, it in ipairs(itemsGiven) do parts[#parts+1] = it.label .. ' x' .. it.amount end
        fields[#fields+1] = { name = 'Items', value = table.concat(parts, ', '), inline = false }
    end
    SendWebhook('code_redeem', {
        title = '🎁 Code Redeemed',
        description = ('%s redeemed code **%s**'):format(GetPlayerName(src), row.code),
        fields = fields,
    })

    TriggerClientEvent('s82:client:redeemResult', src, true, Translate('redeem_success'), {
        money = moneyGiven,
        moneys = moneysGiven,
        items = itemsGiven,
    })
end)


RegisterNetEvent('s82:server:createCode', function(data)
    local src = source
    if not src or src <= 0 then return end

    if not IsAdmin(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=create reason=no_permission', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_no_permission'), 'error')
        return
    end

    if isAdminOnCooldown(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=create reason=cooldown', src)
        return
    end

    local code = data and data.code
    if type(code) ~= 'string' or code:gsub('%s', '') == '' then
        Debug.warn('ADMIN', 'create reject src=%d reason=empty_code', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_code_required'), 'error')
        return
    end

    local minLen = (S82Cfg.Codes and S82Cfg.Codes.minCodeLength) or 3
    local maxLen = (S82Cfg.Codes and S82Cfg.Codes.maxCodeLength) or 32
    code = SanitizeText(code, maxLen)
    if #code < minLen then
        Debug.warn('ADMIN', 'create reject src=%d reason=too_short code=%s', src, code)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_invalid_data'), 'error')
        return
    end

    if DB.CodeExists(code) then
        Debug.warn('ADMIN', 'create reject src=%d reason=duplicate code=%s', src, code)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_code_exists'), 'error')
        return
    end

    local rewardType = data.rewardType or 'money'
    if rewardType ~= 'money' and rewardType ~= 'item' and rewardType ~= 'both' then
        rewardType = 'money'
    end

    local moneys, money = {}, 0
    if rewardType ~= 'item' then
        local list, sum, err = SanitizeMoneys(data.moneys)
        if err then
            Debug.warn('ADMIN', 'reject src=%d reason=%s', src, err)
            TriggerClientEvent('s82:client:toast', src, Translate(err), 'error')
            return
        end
        moneys, money = list, sum
        if #moneys == 0 then
            Debug.warn('ADMIN', 'reject src=%d reason=no_money', src)
            TriggerClientEvent('s82:client:toast', src, Translate('admin_error_no_money'), 'error')
            return
        end
    end

    local items = {}
    if rewardType ~= 'money' and type(data.items) == 'table' then
        local maxItems = (S82Cfg.Rewards and S82Cfg.Rewards.maxItems) or 10
        local maxItemAmt = (S82Cfg.Rewards and S82Cfg.Rewards.maxItemAmount) or 100
        for i, item in ipairs(data.items) do
            if i > maxItems then break end
            if type(item) == 'table' and type(item.name) == 'string' and item.name ~= '' then
                local amt = math.max(1, math.min(tonumber(item.amount) or 1, maxItemAmt))
                items[#items+1] = { name = SanitizeText(item.name, 64), amount = amt }
            end
        end
    end

    local maxUses = math.max(0, tonumber(data.maxUses) or 0)
    local expiry = nil
    if type(data.expiry) == 'string' and data.expiry ~= '' then
        expiry = data.expiry:gsub('T', ' '):sub(1, 19)
    end

    local isPrivate = data.isPrivate == true
    local targetCitizenIds = {}
    if isPrivate then
        local targets, terr = ValidatePrivateTargets(isPrivate, data.targetCitizenids)
        if terr then
            Debug.warn('ADMIN', 'create reject src=%d reason=%s', src, terr)
            TriggerClientEvent('s82:client:toast', src, Translate(terr), 'error')
            return
        end
        targetCitizenIds = targets
    end
    local targetCitizenId = targetCitizenIds[1]

    local citizenid = GetCitizenId(src)
    local creatorName = _G.GetPlayerName(src)
    local creatorSteam = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 6) == 'steam:' then
            creatorSteam = id
            break
        end
    end

    local newId = DB.CreateCode({
        code             = code,
        reward_type      = rewardType,
        money            = money,
        moneys           = #moneys > 0 and moneys or nil,
        items            = #items > 0 and items or nil,
        max_uses         = maxUses,
        expiry           = expiry,
        is_private       = isPrivate,
        target_citizenid = targetCitizenId,
        target_citizenids = #targetCitizenIds > 0 and targetCitizenIds or nil,
        created_by       = citizenid,
        creator_name     = creatorName,
        creator_steam    = creatorSteam,
    })

    if not newId then
        Debug.err('[ADMIN] code insert failed src=%d code=%s', src, code)
        TriggerClientEvent('s82:client:toast', src, Translate('redeem_error'), 'error')
        return
    end

    Debug.log('ADMIN', 'code %s created by %s (type=%s money=%d items=%d maxUses=%d private=%s)',
        code, tostring(citizenid), rewardType, money, #items, maxUses, tostring(isPrivate))

    SendWebhook('code_create', {
        title = '✅ Code Created',
        description = ('Admin **%s** created code **%s**'):format(_G.GetPlayerName(src), code),
        fields = {
            { name = 'Type', value = rewardType, inline = true },
            { name = 'Money', value = '$' .. tostring(money), inline = true },
            { name = 'Items', value = #items > 0 and tostring(#items) .. ' items' or 'None', inline = true },
            { name = 'Max Uses', value = maxUses > 0 and tostring(maxUses) or 'Unlimited', inline = true },
            { name = 'Private', value = isPrivate and 'Yes' or 'No', inline = true },
        },
    })

    local codes = DB.GetActiveCodes()
    local formatted = {}
    for _, row in ipairs(codes) do
        formatted[#formatted+1] = FormatCodeForNUI(row)
    end

    TriggerClientEvent('s82:client:codeCreated', src, Translate('admin_code_created'), formatted)
end)


RegisterNetEvent('s82:server:updateCode', function(data)
    local src = source
    if not src or src <= 0 then return end

    if not IsAdmin(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=update reason=no_permission', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_no_permission'), 'error')
        return
    end

    if isAdminOnCooldown(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=update reason=cooldown', src)
        return
    end

    local code = data and data.code
    if type(code) ~= 'string' or code == '' then
        Debug.warn('ADMIN', 'update reject src=%d reason=invalid_payload', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_invalid_data'), 'error')
        return
    end

    local row = DB.GetCode(code)
    if not row then
        Debug.warn('ADMIN', 'update reject src=%d reason=not_found code=%s', src, code)
        TriggerClientEvent('s82:client:toast', src, Translate('redeem_invalid'), 'error')
        return
    end

    local rewardType = data.rewardType or 'money'
    if rewardType ~= 'money' and rewardType ~= 'item' and rewardType ~= 'both' then
        rewardType = 'money'
    end

    local moneys, money = {}, 0
    if rewardType ~= 'item' then
        local list, sum, err = SanitizeMoneys(data.moneys)
        if err then
            Debug.warn('ADMIN', 'reject src=%d reason=%s', src, err)
            TriggerClientEvent('s82:client:toast', src, Translate(err), 'error')
            return
        end
        moneys, money = list, sum
        if #moneys == 0 then
            Debug.warn('ADMIN', 'reject src=%d reason=no_money', src)
            TriggerClientEvent('s82:client:toast', src, Translate('admin_error_no_money'), 'error')
            return
        end
    end

    local items = {}
    if rewardType ~= 'money' and type(data.items) == 'table' then
        local maxItems = (S82Cfg.Rewards and S82Cfg.Rewards.maxItems) or 10
        local maxItemAmt = (S82Cfg.Rewards and S82Cfg.Rewards.maxItemAmount) or 100
        for i, item in ipairs(data.items) do
            if i > maxItems then break end
            if type(item) == 'table' and type(item.name) == 'string' and item.name ~= '' then
                local amt = math.max(1, math.min(tonumber(item.amount) or 1, maxItemAmt))
                items[#items+1] = { name = SanitizeText(item.name, 64), amount = amt }
            end
        end
    end

    local maxUses = math.max(0, tonumber(data.maxUses) or 0)
    local expiry = nil
    if type(data.expiry) == 'string' and data.expiry ~= '' then
        expiry = data.expiry:gsub('T', ' '):sub(1, 19)
    end

    local isPrivate = data.isPrivate == true
    local targetCitizenIds = {}
    if isPrivate then
        local targets, terr = ValidatePrivateTargets(isPrivate, data.targetCitizenids)
        if terr then
            Debug.warn('ADMIN', 'update reject src=%d reason=%s', src, terr)
            TriggerClientEvent('s82:client:toast', src, Translate(terr), 'error')
            return
        end
        targetCitizenIds = targets
    end
    local targetCitizenId = targetCitizenIds[1]

    local affected = DB.UpdateCode({
        code             = code,
        reward_type      = rewardType,
        money            = money,
        moneys           = #moneys > 0 and moneys or nil,
        items            = #items > 0 and items or nil,
        max_uses         = maxUses,
        expiry           = expiry,
        is_private       = isPrivate,
        target_citizenid = targetCitizenId,
        target_citizenids = #targetCitizenIds > 0 and targetCitizenIds or nil,
    })

    if not affected or affected == 0 then
        Debug.err('[ADMIN] code update failed src=%d code=%s', src, code)
        TriggerClientEvent('s82:client:toast', src, Translate('redeem_error'), 'error')
        return
    end

    Debug.log('ADMIN', 'code %s updated by %s (type=%s money=%d items=%d maxUses=%d private=%s)',
        code, tostring(GetCitizenId(src)), rewardType, money, #items, maxUses, tostring(isPrivate))

    SendWebhook('code_update_admin', {
        title = '✏️ Code Edited',
        description = ('Admin **%s** edited code **%s**'):format(_G.GetPlayerName(src), code),
        fields = {
            { name = 'Type', value = rewardType, inline = true },
            { name = 'Money', value = '$' .. tostring(money), inline = true },
            { name = 'Items', value = #items > 0 and tostring(#items) .. ' items' or 'None', inline = true },
            { name = 'Max Uses', value = maxUses > 0 and tostring(maxUses) or 'Unlimited', inline = true },
            { name = 'Private', value = isPrivate and 'Yes' or 'No', inline = true },
        },
    })

    local codes = DB.GetActiveCodes()
    local formatted = {}
    for _, r in ipairs(codes) do
        formatted[#formatted+1] = FormatCodeForNUI(r)
    end

    TriggerClientEvent('s82:client:codeCreated', src, Translate('admin_code_updated'), formatted)
end)


RegisterNetEvent('s82:server:deleteCode', function(data)
    local src = source
    if not src or src <= 0 then return end

    if not IsAdmin(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=delete reason=no_permission', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_no_permission'), 'error')
        return
    end

    if isAdminOnCooldown(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=delete reason=cooldown', src)
        return
    end

    local code = data and data.code
    if type(code) ~= 'string' or code == '' then
        Debug.warn('ADMIN', 'delete reject src=%d reason=invalid_payload', src)
        return
    end

    local affected = DB.DeleteCode(code)
    if not affected or affected == 0 then
        Debug.warn('ADMIN', 'delete reject src=%d reason=not_found code=%s', src, code)
        TriggerClientEvent('s82:client:toast', src, Translate('redeem_invalid'), 'error')
        return
    end

    Debug.log('ADMIN', 'code %s deleted by %s', code, tostring(GetCitizenId(src)))

    SendWebhook('code_delete', {
        title = '🗑️ Code Deleted',
        description = ('Admin **%s** deleted code **%s**'):format(_G.GetPlayerName(src), code),
    })

    local codes = DB.GetActiveCodes()
    local formatted = {}
    for _, row in ipairs(codes) do
        formatted[#formatted+1] = FormatCodeForNUI(row)
    end

    TriggerClientEvent('s82:client:codeDeleted', src, Translate('admin_code_deleted'), formatted)
end)


RegisterNetEvent('s82:server:clearHistory', function()
    local src = source
    if not src or src <= 0 then return end

    if not IsAdmin(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=clear_history reason=no_permission', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_no_permission'), 'error')
        return
    end

    if isAdminOnCooldown(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=clear_history reason=cooldown', src)
        return
    end

    DB.ClearRedemptionHistory()

    Debug.log('ADMIN', 'redemption history cleared by %s', tostring(GetCitizenId(src)))

    SendWebhook('history_clear', {
        title = '🗑️ History Cleared',
        description = ('Admin **%s** cleared the redemption history'):format(_G.GetPlayerName(src)),
    })

    TriggerClientEvent('s82:client:historyCleared', src, Translate('admin_history_cleared') or 'Redemption history cleared.')
end)



RegisterNetEvent('s82:server:openAdmin', function()
    local src = source
    if not IsAdmin(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=open_panel reason=no_permission', src)
        NotifyClient(src, Translate('admin_no_permission'), 'error')
        return
    end

    local codes = DB.GetActiveCodes()
    local formattedCodes = {}
    for _, row in ipairs(codes) do
        formattedCodes[#formattedCodes+1] = FormatCodeForNUI(row)
    end

    local history = DB.GetRedemptionHistory(S82Cfg.Admin and S82Cfg.Admin.pageSize or 25)
    local formattedHistory = {}
    for _, row in ipairs(history) do
        formattedHistory[#formattedHistory+1] = FormatHistoryForNUI(row)
    end

    local items = GetAllInventoryItems()

    Debug.log('ADMIN', 'panel opened src=%d codes=%d history=%d items=%d',
        src, #formattedCodes, #formattedHistory, #items)

    TriggerClientEvent('s82:client:openAdmin', src, {
        codes      = formattedCodes,
        history    = formattedHistory,
        items      = items,
        moneyTypes = Bridge.GetMoneyTypes and Bridge.GetMoneyTypes() or {},
        locale     = BuildLocaleBundle(),
    })
end)


RegisterNetEvent('s82:server:getOnlinePlayers', function()
    local src = source
    if not src or src <= 0 then return end

    if not IsAdmin(src) then
        Debug.warn('SECURITY', 'admin reject src=%d action=get_players reason=no_permission', src)
        TriggerClientEvent('s82:client:toast', src, Translate('admin_no_permission'), 'error')
        return
    end

    local players = GetOnlinePlayersForNUI()
    Debug.log('ADMIN', 'online players requested src=%d count=%d', src, #players)

    TriggerClientEvent('s82:client:onlinePlayers', src, players)
end)


RegisterNetEvent('s82:server:openRedeem', function()
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then
        Debug.warn('SECURITY', 'open redeem reject src=%d reason=no_identifier', src)
        return
    end

    Debug.log('UI', 'redeem panel requested src=%d citizenid=%s', src, tostring(citizenid))

    TriggerClientEvent('s82:client:openRedeem', src, {
        locale = BuildLocaleBundle(),
    })
end)


AddEventHandler('playerDropped', function()
    local src = source
    cooldowns[src] = nil
    adminCooldowns[src] = nil
end)
