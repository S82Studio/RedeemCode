if Bridge.Inventory ~= 'codem' then return end

local inv = exports['codem-inventory']

function Bridge.GetItemLabel(name)
    local ok, label = pcall(function() return inv:GetItemLabel(name) end)
    return (ok and label and label ~= '' and label) or name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    return ('nui://codem-inventory/html/itemimages/%s.png'):format(name)
end

function Bridge.GetAllItems()
    local out = {}
    local ok, items = pcall(function() return inv:GetItemList() end)
    if ok and type(items) == 'table' then
        for name, data in pairs(items) do
            out[#out+1] = { name = name, label = (type(data) == 'table' and data.label) or name }
        end
    end
    return out
end

function Bridge.AddItem(src, name, amount, metadata)
    return inv:AddItem(src, name, amount, nil, metadata) and true or false
end

function Bridge.RemoveItem(src, name, amount, slot)
    return inv:RemoveItem(src, name, amount, slot) and true or false
end

function Bridge.HasItem(src, name, amount)
    return (inv:GetItemsTotalAmount(src, name) or 0) >= (amount or 1)
end

function Bridge.CanCarry(_, _, _) return true end
