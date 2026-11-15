# 02 — Build và triển khai

## Môi trường ghi nhận tại thời điểm đóng gói

- Flutter 3.47.4 stable; Dart 3.13.3.
- JDK 17; Android compile/target SDK 36, min SDK 24.
- Node.js 22.23.2 cho AI gateway; Python 3 cho preview/checksum.
- Cần Android SDK và NDK theo cấu hình Flutter; chạy `flutter doctor -v` trước.
- SDK không nằm trong ZIP. Lần build đầu cần mạng để tải dependencies.

## Build lại

Từ thư mục gốc bộ bàn giao trên Bash:

```sh
bash 05-operations/build-release.sh
```

Script sử dụng pubspec.lock, chạy pub get và build web/APK, rồi cập nhật bản giao.
Nếu source đã thay đổi phiên bản, cập nhật script, manifest và tài liệu trước khi phát hành.
Script không tự tạo release keystore, không tự triển khai và không tự tạo lại checksum.

Hoặc chạy thủ công trong `02-source/flutter-app`:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /mochi/ --no-pub
flutter build apk --release --no-pub
```

Sau build, web ở `build/web`, APK ở `build/app/outputs/flutter-apk/app-release.apk`.
Dùng `--dart-define=MOCHI_AI_GATEWAY=https://YOUR-HOST/mochi-ai` khi đổi gateway.
Phải truyền cùng tham số cho cả hai lệnh build.

## Web

Bản giao có `<base href="/mochi/">`. Toàn bộ file và assets phải được phục vụ dưới `/mochi/`.
Không dùng build mặc định base `/`: việc này gây lỗi 404 cho bootstrap và ảnh.
Nếu deploy ở domain root, build lại bằng `--base-href /` thay vì sửa mỗi URL riêng lẻ.
Bản preview chỉ phục vụ loopback trên máy người nhận. Có hai cách để AI chạy trên origin local:
thêm origin preview vào `ALLOWED_ORIGINS` của gateway (xem `03-CAU-HINH-DICH-VU.md`), hoặc build bản dev
với `--base-href /` rồi chạy `python 05-operations/preview.py --port 8600 --web-root 02-source/flutter-app/build/web`.
Preview sẽ chuyển tiếp `/mochi-ai/*` phía server, còn app tự chọn gateway cùng origin khi host là loopback.

Mẫu `05-operations/nginx.conf.example` giả định giải nén bộ giao tại `/opt/mochii`.
Đổi hostname và cấu hình TLS riêng trước khi đưa lên Internet. Mẫu không bật HTTPS tự động.
Không public thư mục source, tài liệu kiểm tra hoặc file môi trường của server.

## Android

Build release hiện vẫn dùng `signingConfigs.getByName("debug")` trong `android/app/build.gradle.kts`.
Cần thiết lập release signing riêng trước khi phát hành chính thức. Lưu keystore ngoài source và có backup.
Không đổi signer khi muốn cập nhật đè bản cài hiện hữu. Min SDK 24, target SDK 36.
Source có thư mục iOS/macOS/Linux/Windows, nhưng bộ giao chỉ build/kiểm tra Web và APK;
không có IPA hoặc bộ cài desktop, không xác nhận các nền tảng đó hoạt động.

## Rollback

Giữ nguyên bộ deploy cũ ngoài thư mục public trước khi thay web. Deploy theo thư mục version rồi đổi symlink/đích proxy.
Không ghi đè từng file web khi đang có người dùng. Giữ backup database trước migration.
APK rollback phải xét versionCode, signer và dữ liệu; không gỡ ứng dụng để xử lý tùy tiện.
