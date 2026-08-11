
Locales = Locales or {}

function _L(key, ...)
    local lang = (S82Cfg and S82Cfg.Locale) or 'en'
    local s    = (Locales[lang] and Locales[lang][key])
              or (Locales['en'] and Locales['en'][key])
              or key
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, s, ...)
        if ok then return res end
    end
    return s
end

function Translate(key, ...)
    return _L(key, ...)
end

function BuildLocaleBundle()
    local lang = (S82Cfg and S82Cfg.Locale) or 'en'
    local out  = {}
    local enFB = Locales['en'] or {}
    for k, v in pairs(enFB) do out[k] = v end
    local active = Locales[lang]
    if active and active ~= enFB then
        for k, v in pairs(active) do out[k] = v end
    end
    return out
end


Debug = {}

local LAYER = IsDuplicityVersion() and 'SERVER' or 'CLIENT'
local _unknownCatWarned = {}

local function shouldLog(category)
    if not S82Cfg or not S82Cfg.Debug then return false end
    if not S82Cfg.Debug.enabled then return false end
    local state = S82Cfg.Debug.categories[category]
    if state == nil then
        if not _unknownCatWarned[category] then
            _unknownCatWarned[category] = true
            print(('^1[%s][DEBUG]^0 unknown category: %s (call site bug)')
                :format(LAYER, tostring(category)))
        end
        return false
    end
    if not state then return false end
    return true
end

local function emit(category, severity, msg, ...)
    if not shouldLog(category) then return end
    local color = (S82Cfg.Debug.colors and S82Cfg.Debug.colors[category]) or '^7'
    local sev   = (S82Cfg.Debug.severityPrefix and S82Cfg.Debug.severityPrefix[severity]) or ''
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, msg, ...)
        if ok then msg = formatted end
    end
    print(('%s[%s][%s]^0 %s%s'):format(color, LAYER, category, sev, tostring(msg)))
end

function Debug.log(category, msg, ...) emit(category, 'info', msg, ...) end

function Debug.warn(category, msg, ...) emit(category, 'warn', msg, ...) end

function Debug.err(msg, ...) emit('ERROR', 'err', msg, ...) end

function Debug.buildNuiPayload()
    if not S82Cfg or not S82Cfg.Debug then
        return { enabled = false, categories = {} }
    end
    return {
        enabled    = S82Cfg.Debug.enabled,
        categories = S82Cfg.Debug.categories,
    }
end
