S82Cfg = {}
S82Cfg.Locale = 'vi'                       -- ngôn ngữ: locales/<mã>.lua (vi, en, ...)

S82Cfg.Command = {
    redeem     = 'redeem',                -- lệnh chat để người chơi mở bảng đổi mã
    admin      = 'redeemadmin',           -- lệnh chat để admin mở bảng quản lý mã
    suggestion = true,                    -- hiển thị gợi ý lệnh trong danh sách chat
}

S82Cfg.Admin = {
    acePermission    = 's82.admin',       
    frameworkGroups  = { 'admin', 'god' }, 
    auditWebhook     = true,              
    actionCooldownMs = 800,               
    pageSize         = 25,                
}

S82Cfg.Rewards = {
    allowMoney    = true,                 -- cho phép tiền làm phần thưởng
    allowItems    = true,                 -- cho phép vật phẩm làm phần thưởng
    maxMoney      = 1000000,              -- số tiền tối đa cho mỗi mã
    maxItems      = 10,                   -- số loại vật phẩm tối đa cho mỗi mã
    maxItemAmount = 100,                  -- số lượng tối đa cho mỗi loại vật phẩm
}

S82Cfg.Codes = {
    maxCodeLength          = 32,          -- độ dài tối đa của mã
    minCodeLength          = 3,           -- độ dài tối thiểu của mã
    caseInsensitive        = true,        -- không phân biệt hoa/thường khi so khớp mã
    cooldownMs             = 2000,        -- thời gian chờ giữa các lần đổi mã của mỗi người chơi
    validatePrivateTarget  = true,        -- từ chối mã riêng tư nếu ID công dân mục tiêu không tồn tại trong DB
    maxPrivateTargets      = 50,          -- số ID công dân mục tiêu tối đa cho mỗi mã riêng tư
}

S82Cfg.Framework = {
    mode        = 'auto', -- 'auto'|'esx' | 'qb' | 'qbx' | 'custom'
    inventory   = 'auto', -- 'auto'|'ox'|'qb'|'qs'|'ps'|'codem'|'tgiann'|'esx_native'|'custom'
    notify      = 'auto', -- 'auto' ưu tiên ox_lib nếu có, không thì dùng framework; hoặc ép buộc 'framework' | 'oxlib'
    notifyStyle = 'custom', -- 'custom' = dùng toast đẹp riêng của resource này; 'native' = giao cho backend `notify` xử lý

    custom = {
        base    = 'qbx',   -- BẮT BUỘC: 'qb' | 'qbx' | 'esx'
        getCore = nil,    

        playerLoadedEvent = nil,  
        playerUnloadEvent = nil,  
    },
}

S82Cfg.Inventory = {
    imageUrl = 'auto',   -- 'auto' hoặc tự đặt 'nui://<resource>/.../%s.png'
    -- Túi đồ tuỳ chỉnh (chỉ áp dụng khi Framework.inventory = 'custom').
    custom = nil,
}

S82Cfg.Money = {
    payoutType = 'bank',                  -- loại tài khoản mặc định khi trả thưởng tiền

    types = {
        { id = 'cash',       label = 'Tiền mặt',    icon = 'fa-solid fa-money-bill-wave',  accounts = { qb = 'cash',   qbx = 'cash',   esx = 'money' } },
        { id = 'bank',       label = 'Ngân hàng',    icon = 'fa-solid fa-building-columns', accounts = { qb = 'bank',   qbx = 'bank',   esx = 'bank' } },
        { id = 'crypto',     label = 'Tiền điện tử', icon = 'fa-solid fa-coins',            accounts = { qb = 'crypto', qbx = 'crypto' } },
        { id = 'blackmoney', label = 'Tiền bẩn',     icon = 'fa-solid fa-sack-dollar',      accounts = { esx = 'black_money' } },
    },
}

S82Cfg.Database = {
    autoCreateTables = true,              -- tự tạo/nâng cấp cấu trúc bảng khi resource khởi động
}

S82Cfg.Debug = {
    enabled = false,                      

    -- Nhóm log — đặt false để tắt riêng từng nhóm
    categories = {
        INIT     = true,                  -- resource khởi động, load config/schema
        BRIDGE   = true,                  -- nhận diện framework/túi đồ và các adapter
        UI       = true,                  -- mở/đóng NUI, các yêu cầu từ giao diện
        CODE     = true,                  -- tra cứu và kiểm tra mã khi đổi thưởng
        REDEEM   = true,                  -- quy trình trao phần thưởng
        ADMIN    = true,                  -- hành động trong bảng admin (tạo/sửa/xoá)
        IO       = true,                  -- truy vấn cơ sở dữ liệu
        WEBHOOK  = true,                  -- gửi webhook Discord
        SECURITY = true,                  -- hành động bị từ chối, cooldown, thiếu quyền
        PERF     = false,                 -- đo hiệu năng
        ERROR    = true,                  -- lỗi
    },

    -- Mã màu ANSI cho từng nhóm log trên console server (^1..^8 — mã màu FiveM)
    colors = {
        INIT     = '^3',
        BRIDGE   = '^3',
        UI       = '^4',
        CODE     = '^2',
        REDEEM   = '^5',
        ADMIN    = '^6',
        IO       = '^6',
        WEBHOOK  = '^5',
        SECURITY = '^8',
        PERF     = '^8',
        ERROR    = '^1',
    },

    -- Tiền tố thêm vào đầu dòng log theo mức độ nghiêm trọng.
    severityPrefix = {
        info = '',
        warn = '[CẢNH BÁO] ',
        err  = '[LỖI]  ',
    },

    perfThresholdMs = 50,                 -- truy vấn DB chậm hơn mốc này (ms) sẽ được log vào nhóm PERF
}