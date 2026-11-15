# Mochii — Flutter source

Snapshot mã nguồn bàn giao phiên bản 1.4.10+2047, bao gồm các chỉnh sửa chưa commit.
Đọc README ở thư mục gốc bộ bàn giao và `03-documentation` trước khi triển khai.

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /mochi/ --no-pub
flutter build apk --release --no-pub
```

Flutter 3.47.4 / Dart 3.13.3; Android SDK 36 / JDK 17.
Không có local.properties, cache, build output hay private keystore trong source này.
Android release đang dùng debug signer; cần thiết lập release signing cho phát hành chính thức.
`docs/` giữ nguyên nghiên cứu và nghiệm thu các đợt trước; không dùng các tuyên bố lịch sử để chứng nhận build mới.
