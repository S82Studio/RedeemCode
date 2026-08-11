Webhooks = {}

Webhooks.defaultUrl = ''                  -- URL webhook mặc định, dùng khi 1 sự kiện không có url riêng

Webhooks.username  = 's82 logger'         -- tên hiển thị của bot khi gửi tin nhắn
Webhooks.avatarUrl = ''                   -- ảnh đại diện của bot (để trống dùng mặc định của Discord)

Webhooks.events = {
    code_create        = { enabled = true, color = 0x2ecc71, url = '' }, -- tạo mã mới
    code_delete        = { enabled = true, color = 0xe74c3c, url = '' }, -- xoá mã
    code_redeem        = { enabled = true, color = 0x3498db, url = '' }, -- người chơi đổi mã
    history_clear      = { enabled = true, color = 0x9b59b6, url = '' }, -- xoá lịch sử đổi mã
    code_update_admin  = { enabled = true, color = 0xf1c40f, url = '' }, -- admin sửa mã
}

-- Hàng đợi gửi webhook — tránh spam Discord API khi có nhiều sự kiện cùng lúc.
Webhooks.queue = {
    tickMs           = 250,               
    maxSize          = 200,               
    retryAfterMaxSec = 30,                
    requestTimeoutMs = 10000,             
    retry5xxOnce     = true,              
}

Webhooks.urlValidationPattern = '^https://[%w%.%-]*discord[%w]*%.com/api/webhooks/' -- kiểm tra URL webhook hợp lệ