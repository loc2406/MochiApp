# 04 — Phạm vi và giới hạn nghiệm thu

## Có trong bộ bàn giao

- Source Flutter hiện tại, gồm cả các thay đổi chưa commit tại thời điểm snapshot.
- Web/APK release build từ snapshot đó, cùng phiên bản 1.4.10+2047.
- Assets, tests, dependency lockfile, cấu hình native, migration SQL.
- Gateway AI cùng bộ test, cấu hình mẫu, hướng dẫn triển khai và kiểm tra integrity.
- Slide/PDF/kịch bản và nghiên cứu gốc, được đánh dấu là tài liệu lịch sử.

## Không tự động được chuyển giao

- Quyền quản trị dịch vụ cloud, domain/Tailscale, tài khoản đăng nhập hoặc billing.
- Keystore ký Android, private key, provider secret, token, dữ liệu người dùng.
- Bản backup cloud, lịch sử Git đầy đủ, SDK, cache, emulator hoặc toàn bộ APK cũ.
- Backend cron FCM, dịch vụ Gemini Live chính thức, build iOS/desktop.

## Chưa phải chứng nhận production

Build thành công và kiểm thử tự động không thay cho QA thiết bị thực, tải cao, bảo mật đầy đủ,
nghiệm thu dữ liệu/sao lưu, quyền sử dụng tài sản và phê duyệt cửa hàng.
APK ký debug; chuyển sang release signing là việc bắt buộc trước phát hành chính thức.
Chi phí/hạn mức AI và cloud phụ thuộc tài khoản, không cam kết miễn phí hay hoạt động vĩnh viễn.
Kết quả kiểm tra thực tế, kể cả lỗi chưa xử lý, được ghi trong `06-verification/verification-report.md`.

## Thay đổi chỉ áp dụng cho bản sao bàn giao

- Chuẩn hóa version source thành 1.4.10+2047 để khớp bản APK mới nhất.
- Sửa script build helper dùng đường dẫn tương đối, mặc định build APK đa kiến trúc.
- Thay README khởi tạo bằng hướng dẫn rõ ràng cho bên nhận.
- Slide HTML bàn giao dùng đường dẫn preview cục bộ; PDF, ảnh và QR gốc là tư liệu lịch sử.
- Không sửa logic nghiệp vụ, không hợp nhất/commit thay đổi vào repository gốc.
