# Mochii — Bộ bàn giao kỹ thuật

**Ngày đóng gói:** 04/11/2026 (Việt Nam)  
**Phiên bản trong bộ bàn giao:** 1.4.10, build 2047  
**Phạm vi:** bản Web đã biên dịch, APK Android, mã nguồn, dịch vụ AI gateway, tài liệu, slide và bằng chứng kiểm tra.

## Bắt đầu tại đây

1. Đọc `03-documentation/01-HUONG-DAN-BAN-GIAO.md`.
2. Android: cài `01-release/android/Mochii-1.4.10-2047.apk`.
3. Web: cài Python 3 rồi chạy `python3 05-operations/preview.py`; mở `http://127.0.0.1:8500/mochi/`.
4. Xem `03-documentation/03-CAU-HINH-DICH-VU.md` để tiếp nhận Supabase, Firebase và AI.
5. Đối chiếu `06-verification/verification-report.md`, `release-manifest.json` và `SHA256SUMS.txt`.

## Cấu trúc

```text
Mochii-Handover-2026-11-04/
├── README.md
├── release-manifest.json
├── SHA256SUMS.txt
├── 01-release/
│   ├── android/             APK duy nhất, phiên bản 1.4.10 (2047)
│   └── web/                 Web release, base URL /mochi/
├── 02-source/
│   ├── flutter-app/         Source Flutter, assets, tests, SQL và tài liệu gốc
│   └── ai-gateway/          Gateway Node.js, test và .env.example
├── 03-documentation/        Hướng dẫn tiếp nhận, build, triển khai và giới hạn
├── 04-presentation/         Slide HTML, PDF, nội dung và kịch bản gốc
├── 05-operations/           Preview, build, kiểm tra checksum, mẫu Nginx/systemd
└── 06-verification/         Log build/test, nguồn gốc snapshot và kiểm tra bản giao
```

## Những điều cần biết

- Web và APK được build từ cùng snapshot mã nguồn trong lần đóng gói này. Source bao gồm cả thay đổi chưa commit của thư mục làm việc, không chỉ Git HEAD.
- Không thay thế ứng dụng đang chạy, không tắt dịch vụ, không xóa thư mục gốc. Bộ này là bản bàn giao riêng.
- APK là release build nhưng **ký bằng Android Debug certificate**, chưa phải bản đủ điều kiện phát hành chính thức lên cửa hàng.
- Không kèm private key, tài khoản/mật khẩu, token người dùng, database người dùng, SDK, cache hay toàn bộ các bản phát hành cũ.
- Có giữ cấu hình Firebase client và Supabase publishable key đang có trong ứng dụng; đây không phải thông tin quản trị và không thay cho việc chuyển quyền dự án.
- Nghiên cứu, ảnh và slide gốc là tài liệu tham khảo lịch sử, không phải chứng nhận nghiệm thu cho build mới. Tài liệu hiện tại trong `03-documentation` và báo cáo lần đóng gói này được ưu tiên.
