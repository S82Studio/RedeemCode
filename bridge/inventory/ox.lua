if Bridge.Inventory ~= 'ox' then return end

local ox = exports.ox_inventory

function Bridge.GetItemLabel(name)
    local it = ox:Items(name)
    return (it and it.label) or name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    return ('nui://ox_inventory/web/images/%s.png'):format(name)
end

function Bridge.GetAllItems()
    local out = {}
    local items = ox:Items()
    if type(items) == 'table' then
        for name, data in pairs(items) do
            out[#out+1] = { name = name, label = data.label or name }
        end
    end
    return out
end

function Bridge.AddItem(src, name, amount, metadata)
    local ok = ox:AddItem(src, name, amount, metadata)
    return ok and true or false
end

function Bridge.RemoveItem(src, name, amount, slot)
    local ok = ox:RemoveItem(src, name, amount, nil, slot)
    return ok and true or false
end

function Bridge.HasItem(src, name, amount)
    return (ox:GetItemCount(src, name) or 0) >= (amount or 1)
end

function Bridge.CanCarry(src, name, amount)
    return ox:CanCarryItem(src, name, amount or 1) == true
end
