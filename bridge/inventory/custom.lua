if Bridge.Inventory ~= 'custom' then return end

local cb = (S82Cfg.Inventory and S82Cfg.Inventory.custom) or {}

do
    local required = {
        'addItem', 'removeItem', 'hasItem', 'canCarryItem',
        'getItemLabel', 'getItemImage', 'getAllItems',
    }
    for _, fn in ipairs(required) do
        if type(cb[fn]) ~= 'function' then
            Debug.err('[BRIDGE] custom inventory: missing callback %s', fn)
        end
    end
end

function Bridge.GetItemLabel(name)
    if cb.getItemLabel then
        local label = cb.getItemLabel(name)
        if label and label ~= '' then return label end
    end
    return name
end

function Bridge.GetItemImage(name)
    local override = S82Cfg.Inventory and S82Cfg.Inventory.imageUrl
    if override and override ~= 'auto' then return string.format(override, name) end
    if cb.getItemImage then return cb.getItemImage(name) or '' end
    return ''
end

function Bridge.GetAllItems()
    local out = {}
    if not cb.getAllItems then return out end
    for key, item in pairs(cb.getAllItems() or {}) do
        local nm = (type(item) == 'table' and item.name) or (type(key) == 'string' and key) or nil
        if nm then
            out[#out+1] = {
                name = nm,
                label = (type(item) == 'table' and item.label) or Bridge.GetItemLabel(nm),
            }
        end
    end
    return out
end

function Bridge.AddItem(src, name, amount, metadata)
    if not cb.addItem then return false end
    return cb.addItem(src, name, amount, metadata) and true or false
end

function Bridge.RemoveItem(src, name, amount, slot)
    if not cb.removeItem then return false end
    return cb.removeItem(src, name, amount, slot) and true or false
end

function Bridge.HasItem(src, name, amount)
    if not cb.hasItem then return false end
    return cb.hasItem(src, name, amount or 1) and true or false
end

function Bridge.CanCarry(src, name, amount)
    if not cb.canCarryItem then return true end
    return cb.canCarryItem(src, name, amount or 1) ~= false
end
