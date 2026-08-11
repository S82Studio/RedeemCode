if Bridge.Inventory ~= 'ps' then return end

if Bridge.Base ~= 'qb' and Bridge.Base ~= 'qbx' then
    Debug.warn('IO', 'ps-inventory requires qb/qbx framework; adapter disabled')
    return
end

local inv = exports['ps-inventory']
local QBShared
if Bridge.Base == 'qb' then
    QBShared = Bridge.Core and Bridge.Core.Shared
else
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    QBShared = ok and core and core.Shared or nil
end
if not QBShared then
    Debug.warn('IO', 'ps-inventory: qb-core Shared unavailable; item labels/images fall back to defaults')
    QBShared = { Items = {} }
end

function Bridge.GetItemLabel(name)
    local s = QBShared.Items[name]; return (s and s.label) or name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    local s = QBShared.Items[name]
    local file = (s and s.image) or (name .. '.png')
    return ('nui://ps-inventory/html/images/%s'):format(file)
end

function Bridge.GetAllItems()
    local out = {}
    for name, data in pairs(QBShared.Items or {}) do
        out[#out+1] = { name = name, label = data.label or name }
    end
    return out
end

function Bridge.AddItem(src, name, amount, metadata)
    return inv:AddItem(src, name, amount, nil, metadata, 'redeem-code') and true or false
end

function Bridge.RemoveItem(src, name, amount, slot)
    return inv:RemoveItem(src, name, amount, slot, 'redeem-code') and true or false
end

function Bridge.HasItem(src, name, amount)
    return inv:HasItem(src, name, amount or 1) and true or false
end

function Bridge.CanCarry(src, name, amount)
    local ok, res = pcall(function() return inv:CanAddItem(src, name, amount or 1) end)
    if ok then return res ~= false end
    return true
end
