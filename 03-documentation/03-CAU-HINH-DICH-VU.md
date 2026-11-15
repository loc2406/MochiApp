# 03 — Cấu hình dịch vụ và tài khoản

## Sơ đồ vận hành

```text
Web / Android ── Supabase Auth + đồng bộ dữ liệu học
      │
      └── AI gateway /mochi-ai ── kiểm tra JWT qua Supabase ── Groq
Android ── Firebase FCM + thông báo cục bộ trên thiết bị
```

## AI gateway

Mã: `02-source/ai-gateway/server.mjs`. Dùng Node.js 22, không cần npm dependency.
Sao chép `.env.example` sang file riêng, ví dụ `/etc/mochii/gateway.env`, điền giá trị thật và giới hạn quyền đọc.
Khởi động bằng `node --env-file=/etc/mochii/gateway.env server.mjs` trong thư mục gateway.
Health: `http://127.0.0.1:8897/health`; endpoint chat là `/chat/completions` hoặc `/mochi-ai/chat/completions`.
Mẫu systemd nằm trong `05-operations`. Chưa tự động cài dịch vụ hay tạo user `mochii`.

**CORS:** danh sách origin được cấu hình bằng biến môi trường `ALLOWED_ORIGINS`
(danh sách phân tách bằng dấu phẩy) trong `server.mjs`; mặc định chỉ
`https://bendocs.tailc1f51b.ts.net`. Khi chuyển domain, thêm origin mới vào
`ALLOWED_ORIGINS` và build ứng dụng với `MOCHI_AI_GATEWAY` mới. Khi cần thử trên
máy local, có hai cách: thêm origin preview (ví dụ `http://127.0.0.1:8600`) một cách
tường minh; hoặc dùng `05-operations/preview.py --web-root ...` để nó chuyển tiếp
`/mochi-ai/*` phía server, khi đó app gọi cùng origin và không cần mở CORS.
Không nên để `*`. Mỗi origin được echo lại đúng giá trị trong
`Access-Control-Allow-Origin` để trình duyệt chấp nhận.
Hạn mức và model allowlist cũng đang đặt trong source. Bộ đếm ở RAM, reset khi restart;
chưa phải quota phân tán nhiều instance. `/health` chỉ xác nhận process sống, không xác nhận upstream đã hoạt động.

## Supabase

Cấu hình mặc định nằm trong `lib/core/services/cloud_sync_service.dart`.
Có URL dự án và publishable key, không có service-role secret.
Nếu chuyển dự án, đổi cấu hình mặc định trong source hoặc cấu hình phù hợp trong ứng dụng,
đồng thời cấu hình `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` trên gateway và build lại.
Migration SQL nằm trong `supabase/migrations/20261102_account_state.sql`.
Đọc và chạy trên môi trường test trước; policy creation trong file không thiết kế để chạy lặp vô điều kiện.
Chuyển quyền dự án, auth settings, redirect URLs, SMTP và dữ liệu cần bàn giao riêng.

## Firebase

Có giữ `android/app/google-services.json` của dự án hiện hữu để build Android tương thích.
Đây là cấu hình client; không phải service-account JSON và không cấp quyền quản trị/gửi push.
Đơn vị nhận cần được cấp quyền Firebase hoặc thay file bằng dự án riêng đúng applicationId.
Xem tài liệu gốc `02-source/flutter-app/docs/FIREBASE_NOTIFICATIONS.md` và `SMART_REMINDERS.md`.
Chưa cấu hình Firebase cho iOS/Web. Backend cron/push gửi nhắc học tự động không nằm trong bộ này.

## Live bridge thử nghiệm

`02-source/flutter-app/tool/gemini_live_bridge.py` là công cụ ADB/uiautomator2 phụ thuộc thiết bị,
không phải API transcript chính thức và không phải server bắt buộc để mở app.
Cần Python/uiautomator2, Android platform-tools, thiết bị được cho phép và Gemini phù hợp.
Script gốc còn đường dẫn ADB/output theo máy phát triển; phải đổi trước khi dùng trên máy mới.
Không có session, transcript cá nhân hoặc thiết bị đã ghép nối trong gói giao.

## Secret và dữ liệu

Không đặt Groq key, service role, private signing key vào client hoặc thư mục web.
Không gửi nguyên `.env` hoặc database cá nhân cùng ZIP này. Bàn giao riêng qua kênh kiểm soát quyền truy cập.
ZIP không phải bản backup toàn bộ hạ tầng cloud; xuất dữ liệu/backup và chuyển quyền là việc riêng.
