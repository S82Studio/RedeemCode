DB = {}

local function timedQuery(label, fn, ...)
    local t0 = GetGameTimer()
    local result = fn(...)
    local dt = GetGameTimer() - t0
    local rowsLabel
    if type(result) == 'table' then
        local n = #result
        if n == 0 and next(result) ~= nil then n = 1 end
        rowsLabel = tostring(n)
    elseif type(result) == 'number' then
        rowsLabel = tostring(result)
    elseif result == nil then
        rowsLabel = 'nil'
    else
        rowsLabel = '?'
    end
    Debug.log('IO', 'db %s rows=%s ms=%d', label, rowsLabel, dt)
    if dt > (S82Cfg.Debug.perfThresholdMs or 50) then
        Debug.log('PERF', 'db %s slow: %d ms (threshold=%d)',
            label, dt, S82Cfg.Debug.perfThresholdMs or 50)
    end
    return result
end


local SCHEMA = [[
    CREATE TABLE IF NOT EXISTS `s82_codes` (
        `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `code`             VARCHAR(64) NOT NULL,
        `reward_type`      ENUM('money','item','both') NOT NULL DEFAULT 'money',
        `money`            INT UNSIGNED NOT NULL DEFAULT 0,
        `moneys`           JSON DEFAULT NULL,
        `items`            JSON DEFAULT NULL,
        `max_uses`         INT UNSIGNED NOT NULL DEFAULT 0,
        `uses`             INT UNSIGNED NOT NULL DEFAULT 0,
        `expiry`           DATETIME DEFAULT NULL,
        `is_private`       TINYINT(1) NOT NULL DEFAULT 0,
        `target_citizenid` VARCHAR(64) DEFAULT NULL,
        `target_citizenids` JSON DEFAULT NULL,
        `created_by`       VARCHAR(64) DEFAULT NULL,
        `creator_name`     VARCHAR(128) DEFAULT NULL,
        `creator_steam`    VARCHAR(64) DEFAULT NULL,
        `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `deleted`          TINYINT(1) NOT NULL DEFAULT 0,
        `code_active`      VARCHAR(64) GENERATED ALWAYS AS (IF(`deleted` = 0, `code`, NULL)) STORED,
        PRIMARY KEY (`id`),
        KEY `idx_code` (`code`),
        UNIQUE KEY `uk_code_active` (`code_active`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

    CREATE TABLE IF NOT EXISTS `s82_redemptions` (
        `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `code_id`        INT UNSIGNED NOT NULL,
        `code`           VARCHAR(64) NOT NULL,
        `citizenid`      VARCHAR(64) NOT NULL,
        `steam`          VARCHAR(64) DEFAULT NULL,
        `player_name`    VARCHAR(128) DEFAULT NULL,
        `money`          INT UNSIGNED NOT NULL DEFAULT 0,
        `moneys`         JSON DEFAULT NULL,
        `items`          JSON DEFAULT NULL,
        `redeemed_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_code_id` (`code_id`),
        KEY `idx_citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

function DB.InitSchema()
    if not S82Cfg.Database or not S82Cfg.Database.autoCreateTables then return end
    Debug.log('IO', '[DB] auto-creating schema...')
    for stmt in SCHEMA:gmatch('[^;]+') do
        local trimmed = stmt:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then
            local ok, err = pcall(MySQL.update.await, trimmed)
            if not ok then
                Debug.err('[DB] schema error: %s', tostring(err))
            end
        end
    end

    local ok_col, cols = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_redemptions` LIKE 'steam'")
    if ok_col and (not cols or #cols == 0) then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_redemptions` ADD COLUMN `steam` VARCHAR(64) DEFAULT NULL AFTER `citizenid`")
        if not ok then
            Debug.err('[DB] failed to add steam column: %s', tostring(err))
        else
            Debug.log('IO', '[DB] dynamically added steam column to s82_redemptions')
        end
    end

    local ok_c1, col_c1 = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_codes` LIKE 'creator_name'")
    if ok_c1 and (not col_c1 or #col_c1 == 0) then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` ADD COLUMN `creator_name` VARCHAR(128) DEFAULT NULL AFTER `created_by`")
        if not ok then Debug.err('[DB] failed to add creator_name column: %s', tostring(err)) end
    end
    local ok_c2, col_c2 = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_codes` LIKE 'creator_steam'")
    if ok_c2 and (not col_c2 or #col_c2 == 0) then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` ADD COLUMN `creator_steam` VARCHAR(64) DEFAULT NULL AFTER `creator_name`")
        if not ok then Debug.err('[DB] failed to add creator_steam column: %s', tostring(err)) end
    end

    local ok_m1, col_m1 = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_codes` LIKE 'moneys'")
    if ok_m1 and (not col_m1 or #col_m1 == 0) then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` ADD COLUMN `moneys` JSON DEFAULT NULL AFTER `money`")
        if not ok then Debug.err('[DB] failed to add moneys column to s82_codes: %s', tostring(err)) end
    end
    local ok_m2, col_m2 = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_redemptions` LIKE 'moneys'")
    if ok_m2 and (not col_m2 or #col_m2 == 0) then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_redemptions` ADD COLUMN `moneys` JSON DEFAULT NULL AFTER `money`")
        if not ok then Debug.err('[DB] failed to add moneys column to s82_redemptions: %s', tostring(err)) end
    end

    local ok_t1, col_t1 = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_codes` LIKE 'target_citizenids'")
    if ok_t1 and (not col_t1 or #col_t1 == 0) then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` ADD COLUMN `target_citizenids` JSON DEFAULT NULL AFTER `target_citizenid`")
        if not ok then Debug.err('[DB] failed to add target_citizenids column to s82_codes: %s', tostring(err)) end
    end

    local function indexExists(name)
        local ok, cnt = pcall(MySQL.scalar.await,
            "SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 's82_codes' AND index_name = ?",
            { name })
        return ok and (tonumber(cnt) or 0) > 0
    end

    local ok_ca, col_ca = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_codes` LIKE 'code_active'")
    if ok_ca and (not col_ca or #col_ca == 0) then
        local ok, err = pcall(MySQL.update.await,
            "ALTER TABLE `s82_codes` ADD COLUMN `code_active` VARCHAR(64) GENERATED ALWAYS AS (IF(`deleted` = 0, `code`, NULL)) STORED AFTER `deleted`")
        if not ok then
            Debug.err('[DB] failed to add code_active column (needs MySQL 5.7+/MariaDB 10.2+, keeping legacy uk_code): %s', tostring(err))
        else
            Debug.log('IO', '[DB] added generated column code_active to s82_codes')
        end
    end

    local hasCodeActive = false
    local ok_ca2, col_ca2 = pcall(MySQL.query.await, "SHOW COLUMNS FROM `s82_codes` LIKE 'code_active'")
    if ok_ca2 and col_ca2 and #col_ca2 > 0 then hasCodeActive = true end

    if hasCodeActive and not indexExists('uk_code_active') then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` ADD UNIQUE KEY `uk_code_active` (`code_active`)")
        if not ok then Debug.err('[DB] failed to add uk_code_active index: %s', tostring(err)) end
    end

    if not indexExists('idx_code') then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` ADD KEY `idx_code` (`code`)")
        if not ok then Debug.err('[DB] failed to add idx_code index: %s', tostring(err)) end
    end

    if hasCodeActive and indexExists('uk_code_active') and indexExists('uk_code') then
        local ok, err = pcall(MySQL.update.await, "ALTER TABLE `s82_codes` DROP INDEX `uk_code`")
        if not ok then
            Debug.err('[DB] failed to drop legacy uk_code index: %s', tostring(err))
        else
            Debug.log('IO', '[DB] dropped legacy uk_code (soft-deleted codes can now be recreated)')
        end
    end

    Debug.log('IO', '[DB] schema ready')
end


function DB.CreateCode(data)
    return timedQuery('CreateCode', MySQL.insert.await, [[
        INSERT INTO s82_codes (code, reward_type, money, moneys, items, max_uses, expiry, is_private, target_citizenid, target_citizenids, created_by, creator_name, creator_steam)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.code,
        data.reward_type,
        data.money or 0,
        data.moneys and json.encode(data.moneys) or nil,
        data.items and json.encode(data.items) or nil,
        data.max_uses or 0,
        data.expiry,
        data.is_private and 1 or 0,
        data.target_citizenid,
        data.target_citizenids and json.encode(data.target_citizenids) or nil,
        data.created_by,
        data.creator_name,
        data.creator_steam,
    })
end

function DB.GetCode(code)
    return timedQuery('GetCode', MySQL.single.await,
        'SELECT * FROM s82_codes WHERE code = ? AND deleted = 0', { code })
end

function DB.GetCodeCaseInsensitive(code)
    return timedQuery('GetCodeCaseInsensitive', MySQL.single.await,
        'SELECT * FROM s82_codes WHERE LOWER(code) = LOWER(?) AND deleted = 0', { code })
end

function DB.GetActiveCodes()
    return timedQuery('GetActiveCodes', MySQL.query.await,
        'SELECT * FROM s82_codes WHERE deleted = 0 ORDER BY created_at DESC')
end

function DB.DeleteCode(code)
    return timedQuery('DeleteCode', MySQL.update.await,
        'UPDATE s82_codes SET deleted = 1 WHERE code = ? AND deleted = 0', { code })
end

function DB.IncrementUses(codeId)
    return timedQuery('IncrementUses', MySQL.update.await,
        'UPDATE s82_codes SET uses = uses + 1 WHERE id = ?', { codeId })
end

function DB.CodeExists(code)
    local row
    if S82Cfg.Codes and S82Cfg.Codes.caseInsensitive then
        row = timedQuery('CodeExists', MySQL.scalar.await,
            'SELECT COUNT(*) FROM s82_codes WHERE LOWER(code) = LOWER(?) AND deleted = 0', { code })
    else
        row = timedQuery('CodeExists', MySQL.scalar.await,
            'SELECT COUNT(*) FROM s82_codes WHERE code = ? AND deleted = 0', { code })
    end
    return (tonumber(row) or 0) > 0
end

function DB.PlayerExists(tbl, col, uid)
    if type(tbl) ~= 'string' or not tbl:match('^%w+$') then return nil end
    if type(col) ~= 'string' or not col:match('^%w+$') then return nil end
    if type(uid) ~= 'string' or uid == '' then return false end
    local ok, res = pcall(MySQL.scalar.await,
        ('SELECT 1 FROM `%s` WHERE `%s` = ? LIMIT 1'):format(tbl, col), { uid })
    if not ok then
        Debug.warn('IO', 'PlayerExists query failed table=%s col=%s: %s', tbl, col, tostring(res))
        return nil
    end
    return res ~= nil
end

function DB.PlayersExist(tbl, col, ids)
    if type(tbl) ~= 'string' or not tbl:match('^%w+$') then return nil end
    if type(col) ~= 'string' or not col:match('^%w+$') then return nil end
    if type(ids) ~= 'table' or #ids == 0 then return {} end
    local placeholders = {}
    for i = 1, #ids do placeholders[i] = '?' end
    local sql = ('SELECT `%s` AS uid FROM `%s` WHERE `%s` IN (%s)'):format(col, tbl, col, table.concat(placeholders, ','))
    local ok, rows = pcall(MySQL.query.await, sql, ids)
    if not ok then
        Debug.warn('IO', 'PlayersExist query failed table=%s col=%s: %s', tbl, col, tostring(rows))
        return nil
    end
    local set = {}
    if type(rows) == 'table' then
        for _, r in ipairs(rows) do
            if r.uid ~= nil then set[tostring(r.uid)] = true end
        end
    end
    return set
end


function DB.HasRedeemed(codeId, citizenid)
    local count = timedQuery('HasRedeemed', MySQL.scalar.await,
        'SELECT COUNT(*) FROM s82_redemptions WHERE code_id = ? AND citizenid = ?',
        { codeId, citizenid }
    )
    return (tonumber(count) or 0) > 0
end

function DB.RecordRedemption(data)
    return timedQuery('RecordRedemption', MySQL.insert.await, [[
        INSERT INTO s82_redemptions (code_id, code, citizenid, steam, player_name, money, moneys, items)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.code_id,
        data.code,
        data.citizenid,
        data.steam,
        data.player_name,
        data.money or 0,
        data.moneys and json.encode(data.moneys) or nil,
        data.items and json.encode(data.items) or nil,
    })
end

function DB.GetRedemptionHistory(limit)
    limit = limit or 100
    return timedQuery('GetRedemptionHistory', MySQL.query.await, [[
        SELECT r.*, c.reward_type
        FROM s82_redemptions r
        LEFT JOIN s82_codes c ON c.id = r.code_id
        ORDER BY r.redeemed_at DESC
        LIMIT ?
    ]], { limit })
end

function DB.ClearRedemptionHistory()
    return timedQuery('ClearRedemptionHistory', MySQL.update.await,
        'DELETE FROM s82_redemptions')
end

function DB.GetRedemptionsByCode(code)
    return timedQuery('GetRedemptionsByCode', MySQL.query.await, [[
        SELECT * FROM s82_redemptions WHERE code = ? ORDER BY redeemed_at DESC
    ]], { code })
end

function DB.UpdateCode(data)
    return timedQuery('UpdateCode', MySQL.update.await, [[
        UPDATE s82_codes
        SET reward_type = ?, money = ?, moneys = ?, items = ?, max_uses = ?, expiry = ?, is_private = ?, target_citizenid = ?, target_citizenids = ?
        WHERE code = ? AND deleted = 0
    ]], {
        data.reward_type,
        data.money or 0,
        data.moneys and json.encode(data.moneys) or nil,
        data.items and json.encode(data.items) or nil,
        data.max_uses or 0,
        data.expiry,
        data.is_private and 1 or 0,
        data.target_citizenid,
        data.target_citizenids and json.encode(data.target_citizenids) or nil,
        data.code,
    })
end
