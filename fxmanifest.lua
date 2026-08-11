fx_version 'cerulean'
game 'gta5'

name 's82_redeemcode'
author 'S82Studio'
description 'Hệ thống mã đổi quà nâng cao - Đa khung'
version '1.0.0'

shared_scripts {
    'config/config.lua',
    'locales/*.lua',
    'shared.lua',
    'bridge/init.lua',
}

client_scripts {
    'bridge/client/esx.lua',
    'bridge/client/qb.lua',
    'bridge/client/qbx.lua',
    'bridge/client/custom.lua',
    'client/main.lua',
}

server_scripts {
    'config/config_webhooks.lua',
    'server/sql_bridge.lua',
    'bridge/server/esx.lua',
    'bridge/server/qb.lua',
    'bridge/server/qbx.lua',
    'bridge/server/custom.lua',
    'bridge/inventory/ox.lua',
    'bridge/inventory/qb.lua',
    'bridge/inventory/qs.lua',
    'bridge/inventory/ps.lua',
    'bridge/inventory/codem.lua',
    'bridge/inventory/tgiann.lua',
    'bridge/inventory/esx_native.lua',
    'bridge/inventory/custom.lua',
    'server/database.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/admin.css',
    'html/debug.js',
    'html/script.js',
    'html/fonts/*.ttf',
}

lua54 'yes'