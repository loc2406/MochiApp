# Báo cáo kiểm định kỹ thuật đợt bàn giao (04/11/2026)

## 1. Kết quả kiểm tra tự động

- **Web release build:** Hoàn thành thành công bằng Flutter 3.47.4 (Dart 3.13.3), cờ `--base-href /mochi/`.
- **Android release build:** Hoàn thành thành công, tạo APK đa kiến trúc `Mochii-1.4.10-2047.apk` dung lượng 67,851,699 bytes.
- **Kiểm định chữ ký APK:** Signer: Android Debug DN (`CN=Android Debug, O=Android, C=US`). Đạt tính toàn vẹn chữ ký APK v1/v2/v3, nhưng phải thay thế bằng release keystore chính thức trước khi phân phối lên Google Play.
- **Web smoke test qua Playwright:** Đạt tại viewport desktop (1440x1000) và mobile (390x844). `_mochiiFirstFrame == true`, HTTP 200, 0 lỗi tài nguyên/console.
- **AI Gateway unit tests:** 6/6 tests PASS (`server.test.mjs`), bao gồm rate limit, kiểm tra JWT, proxy chat và CORS headers.

## 2. Các điểm kỹ thuật cần lưu ý cho bên tiếp nhận

1. **Flutter analyze:** Báo cáo 125 issues (chủ yếu là lint linter `curly_braces_in_flow_control_structures` và deprecation từ codebase gốc). Không chặn quá trình biên dịch release.
2. **Flutter tests:** Bộ test đơn vị đạt 134 bài kiểm thử. Có 6 bài kiểm thử UI widget trượt do phụ thuộc bố cục màn hình cũ trước khi nâng cấp giao diện Liquid Glass/tutor layout mới nhất (đã ghi nhận chi tiết tại `flutter-tests.log`).
3. **Cấu hình Gateway:** Biến `origin` trong `02-source/ai-gateway/server.mjs` đang trỏ domain hiện tại. Khi đổi domain máy chủ mới, cần cập nhật giá trị origin này.
4. **Quyền riêng tư & bảo mật:** Toàn bộ private key, personal environment files, ADB session traces và credential lưu trữ nhạy cảm đã được loại trừ khỏi gói ZIP bàn giao.
