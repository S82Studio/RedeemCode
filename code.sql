-- ─────────────────────────────────────────────────────────────────────────────
-- Nhập tệp này vào cơ sở dữ liệu của bạn nếu autoCreateTables bị tắt.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `s82_codes` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code`             VARCHAR(64) NOT NULL,
    `reward_type`      ENUM('money','item','both') NOT NULL DEFAULT 'money',
    `money`            INT UNSIGNED NOT NULL DEFAULT 0,
    `items`            JSON DEFAULT NULL,
    `max_uses`         INT UNSIGNED NOT NULL DEFAULT 0,
    `uses`             INT UNSIGNED NOT NULL DEFAULT 0,
    `expiry`           DATETIME DEFAULT NULL,
    `is_private`       TINYINT(1) NOT NULL DEFAULT 0,
    `target_citizenid` VARCHAR(64) DEFAULT NULL,
    `created_by`       VARCHAR(64) DEFAULT NULL,
    `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `deleted`          TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `s82_redemptions` (
    `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code_id`        INT UNSIGNED NOT NULL,
    `code`           VARCHAR(64) NOT NULL,
    `citizenid`      VARCHAR(64) NOT NULL,
    `player_name`    VARCHAR(128) DEFAULT NULL,
    `money`          INT UNSIGNED NOT NULL DEFAULT 0,
    `items`          JSON DEFAULT NULL,
    `redeemed_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_code_id` (`code_id`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
