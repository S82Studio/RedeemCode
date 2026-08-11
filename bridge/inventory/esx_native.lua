if Bridge.Inventory ~= 'esx_native' then return end

local ESX = Bridge.Core

function Bridge.GetItemLabel(name)
    if ESX.Items and ESX.Items[name] and ESX.Items[name].label then
        return ESX.Items[name].label
    end
    return name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    return ''
end

function Bridge.GetAllItems()
    local out = {}
    local items = (type(ESX.GetItems) == 'function' and ESX.GetItems()) or ESX.Items or {}
    for key, data in pairs(items) do
        local nm = (type(data) == 'table' and data.name) or (type(key) == 'string' and key) or nil
        if nm then
            out[#out+1] = { name = nm, label = (type(data) == 'table' and data.label) or nm }
        end
    end
    return out
end

function Bridge.AddItem(src, name, amount, metadata)
    local xp = Bridge._rawPlayer(src)
    if not xp then return false end
    xp.addInventoryItem(name, amount)
    return true
end

function Bridge.RemoveItem(src, name, amount, _)
    local xp = Bridge._rawPlayer(src)
    if not xp then return false end
    xp.removeInventoryItem(name, amount)
    return true
end

function Bridge.HasItem(src, name, amount)
    local xp = Bridge._rawPlayer(src)
    if not xp then return false end
    local it = xp.getInventoryItem(name)
    return ((it and it.count) or 0) >= (amount or 1)
end

function Bridge.CanCarry(src, name, amount)
    local xp = Bridge._rawPlayer(src)
    if not xp then return false end
    return xp.canCarryItem(name, amount or 1) == true
end
