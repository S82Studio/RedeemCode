if Bridge.Inventory ~= 'tgiann' then return end

local inv = exports['tgiann-inventory']

function Bridge.GetItemLabel(name)
    local ok, label = pcall(function() return inv:GetItemLabel(name) end)
    return (ok and label and label ~= '' and label) or name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    return ('nui://inventory_images/images/%s.webp'):format(name)
end

function Bridge.GetAllItems()
    local out = {}
    local ok, items = pcall(function() return inv:GetItemList() end)
    if not ok or type(items) ~= 'table' then
        ok, items = pcall(function() return inv:GetItems() end)
    end
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
    return inv:HasItem(src, name, amount or 1) and true or false
end

function Bridge.CanCarry(src, name, amount)
    local ok, res = pcall(function() return inv:CanCarryItem(src, name, amount or 1) end)
    if ok then return res ~= false end
    return true
end
