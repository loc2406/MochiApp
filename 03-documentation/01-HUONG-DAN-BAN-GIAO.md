# 01 — Hướng dẫn tiếp nhận

## Thành phần bàn giao

| Thành phần | Vị trí | Cách sử dụng |
|---|---|---|
| APK đa kiến trúc | `01-release/android` | Android 7.0/API 24 trở lên; ARMv7, ARM64, x86_64 |
| Web đã build | `01-release/web` | Phục vụ bằng HTTP(S) tại `/mochi/`, không mở bằng file:// |
| Source Flutter | `02-source/flutter-app` | Có pubspec.lock, tests, assets và native project |
| Backend AI proxy | `02-source/ai-gateway` | Node.js 22; cần cấu hình Supabase và Groq |
| Database schema | `02-source/flutter-app/supabase/migrations` | SQL tạo dữ liệu đồng bộ và RLS; không phải database dump |
| Bộ thuyết trình | `04-presentation` | HTML/PDF và kịch bản lịch sử; xem ghi chú trong thư mục |
| Bằng chứng kiểm tra | `06-verification` | Phân biệt kiểm tra thực thi và phần chưa kiểm chứng |

## Cài Android

Chép APK sang điện thoại, mở và cho phép cài từ nguồn tải xuống nếu Android yêu cầu.
Có thể dùng `adb install -r 01-release/android/Mochii-1.4.10-2047.apk`.
Nếu Android báo xung đột chữ ký, không gỡ app cũ trước khi sao lưu dữ liệu cần giữ.
Bản giao không chứa keystore; các bản build trên máy mới có thể có signer khác.

## Danh mục phải chuyển giao ngoài ZIP

- Chủ sở hữu/quyền quản trị Firebase, Supabase, Groq, domain và máy chủ/Tailscale.
- Khóa ký Android hiện hữu nếu cần cập nhật đè bản đang cài; trao qua kênh riêng được kiểm soát.
- API key của nhà cung cấp AI vào biến môi trường server, không đưa vào ứng dụng hoặc Git.
- Dữ liệu người dùng: lập kế hoạch export/import và quyền xử lý dữ liệu riêng nếu cần.
- Quyền sử dụng tài sản hình ảnh/font và điều khoản thư viện: source có asset và lockfile nhưng chưa thực hiện kiểm toán pháp lý.

## Checklist người nhận

- [ ] Chạy kiểm tra checksum; lưu lại manifest.
- [ ] Cài APK và thử trên thiết bị mục tiêu, cả quyền camera/thông báo.
- [ ] Chạy preview web trên desktop và mobile.
- [ ] Build lại với đúng SDK và cấu hình dự án của đơn vị nhận.
- [ ] Tiếp nhận cloud project và thử đăng nhập/đồng bộ bằng tài khoản test.
- [ ] Thử AI end-to-end với gateway và quota thật.
- [ ] Thử Firebase push thật, không chỉ thông báo cục bộ.
- [ ] Chốt signer phát hành, backup và kế hoạch triển khai/rollback.
