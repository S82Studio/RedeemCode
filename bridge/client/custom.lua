if Bridge.Framework ~= 'custom' then return end

local c = Bridge._customCfg() or {}

if type(c.notify) == 'function' then
    Bridge.Notify = function(msg, kind, duration) c.notify(msg, kind or 'info', duration) end
end

if type(c.getPlayerData) == 'function' then
    Bridge.GetPlayerData = function()
        local d = c.getPlayerData()
        if not d or not d.uid then return nil end
        local ci = d.charinfo or {}
        local job = d.job or {}
        local full = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        return {
            uid = d.uid,
            name = d.name or (full ~= '' and full) or 'Unknown',
            charinfo = { firstname = ci.firstname or '', lastname = ci.lastname or '' },
            job = { name = job.name or '', label = job.label or '', grade = job.grade or 0 },
            raw = d.raw or d,
        }
    end
end
