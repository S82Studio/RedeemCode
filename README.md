# S82RedeemCode — Hệ Thống Đổi Mã Quà Tặng

Framework (ESX / QB / QBX) cho phép người chơi đổi **mã quà tặng**
lấy tiền và / hoặc vật phẩm, đi kèm bảng quản lý (admin panel) đầy đủ chức năng
ngay trong game.

## Tính năng chính

- **Bảng quản lý (Admin Panel)** — 3 tab: Tạo mã, Mã đang hoạt động, Lịch sử đổi mã. Tạo mã tự động, chọn người chơi online, tìm kiếm trực tiếp.
- **Phần thưởng linh hoạt** — Tiền (tiền mặt / ngân hàng / crypto / tiền bẩn) và/hoặc vật phẩm, giới hạn số lần dùng, ngày hết hạn, cooldown theo người chơi.
- **Mã công khai & riêng tư** — Mã riêng tư chỉ định theo ID công dân cụ thể (tối đa 50 ID/mã), có kiểm tra hợp lệ với database.
- **Đa framework** — Tự nhận diện ESX, QB, QBX (và các bản fork) cùng hệ thống túi đồ đang dùng, không cần cấu hình thủ công.
- **Log Discord (tuỳ chọn)** — Ghi lại các hành động admin và lượt đổi mã qua webhook Discord.
- **Đa ngôn ngữ** — Có sẵn 2 ngôn ngữ, bao gồm **Tiếng Việt** (mặc định).
- **Giao diện** — Phông chữ Roboto cục bộ.

## Yêu cầu

- Framework: ESX, QB hoặc QBX (hoặc bản fork tương thích)
- MySQL: `oxmysql`, `mysql-async` hoặc `ghmattimysql` (tự nhận diện)

## Cài đặt nhanh

1. Copy thư mục resource vào `resources/`.
2. Thêm vào `server.cfg`:

```cfg
ensure oxmysql      # hoặc mysql-async / ghmattimysql
ensure redeemcode
```

4. Khởi động lại server — bảng dữ liệu sẽ tự động được tạo.
5. Gõ `/redeem` trong game để mở bảng đổi mã, `/redeemadmin` để quản lý mã (cần quyền admin — | add_ace group.admin s82.admin allow |).

