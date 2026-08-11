if Bridge.Inventory ~= 'qb' then return end

local inv = exports['qb-inventory']
local QBShared = exports['qb-core']:GetCoreObject().Shared

function Bridge.GetItemLabel(name)
    local s = QBShared.Items[name]; return (s and s.label) or name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    local s = QBShared.Items[name]
    local file = (s and s.image) or (name .. '.png')
    return ('nui://qb-inventory/html/images/%s'):format(file)
end

function Bridge.GetAllItems()
    local out = {}
    for name, data in pairs(QBShared.Items or {}) do
        out[#out+1] = { name = name, label = data.label or name }
    end
    return out
end

function Bridge.AddItem(src, name, amount, metadata)
    local ok, res = pcall(function()
        return inv:AddItem(src, name, amount, nil, metadata, 'redeem-code')
    end)
    if ok and res then
        return true
    end
    local Player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
    if Player then
        return Player.Functions.AddItem(name, amount, nil, metadata) == true
    end
    return false
end

function Bridge.RemoveItem(src, name, amount, slot)
    local ok, res = pcall(function()
        return inv:RemoveItem(src, name, amount, slot, 'redeem-code')
    end)
    if ok and res then
        return true
    end
    local Player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
    if Player then
        return Player.Functions.RemoveItem(name, amount, slot) == true
    end
    return false
end

function Bridge.HasItem(src, name, amount)
    local ok, res = pcall(function()
        return inv:HasItem(src, name, amount or 1)
    end)
    if ok then
        return res and true or false
    end
    local Player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
    if Player then
        local item = Player.Functions.GetItemByName(name)
        return item ~= nil and item.amount >= (amount or 1)
    end
    return false
end

function Bridge.CanCarry(src, name, amount)
    local ok, res = pcall(function()
        return inv:CanAddItem(src, name, amount or 1)
    end)
    if ok then
        return res ~= false
    end
    return true
end
