# Mochii: thông báo Android

## Đã tích hợp

Đã bổ sung bộ nhắc thông minh cục bộ; xem `SMART_REMINDERS.md`. Đây không phải backend AI/cron gửi FCM.

- Firebase project `mochii-aab7d`, Android package `com.mochi.study.mochi_app`.
- `google-services.json`, Gradle Google Services, `firebase_core`, `firebase_messaging`.
- Android notification payload: Android FCM SDK hiển thị khi app ở nền/đã đóng thông thường; khi app mở, listener dùng thông báo hệ thống cục bộ để hiển thị.
- Kênh push ưu tiên cao, icon trạng thái vector đơn sắc, âm thanh theo cài đặt Android.
- Giải thích và xin quyền thông báo sau khi UI đã mở; có nút mở cài đặt khi bị từ chối.
- Có FCM token để sao chép và tự cập nhật khi token thay đổi. Không ghi token vào log.
- Khởi tạo Firebase chạy bất đồng bộ: lỗi mạng không chặn mở ứng dụng.
- Báo thức có khai báo `SCHEDULE_EXACT_ALARM`, kiểm tra quyền trước khi chọn chế độ chính xác; dự phòng chế độ không chính xác nếu chưa cấp quyền.

## Kiểm tra trên điện thoại

1. Cài đè APK, mở ứng dụng, cho phép thông báo.
2. Vào **Tôi > Cài đặt > Thông báo**. Nếu quyền đang tắt, bấm **Bật thông báo** hoặc **Cài đặt Android**.
3. **Thử trên máy**: kéo thanh thông báo xuống. Đây là thông báo thật của Android nhưng là thông báo cục bộ, KHÔNG chứng minh Firebase đã gửi tới máy.
4. Nếu muốn thử hẹn giờ: cho phép báo thức chính xác, quay lại, chọn **Thử chạy nền**, về Home và chờ khoảng 10 giây. Nếu không cấp quyền chính xác, Android có thể trì hoãn.
5. Với push: chờ trạng thái có FCM token rồi chọn **Sao chép FCM token**.
6. Trong Firebase Console đúng project, mở **Messaging**, tạo notification message với tiêu đề/nội dung, chọn **Send test message**, dán token và bấm **Test**.
7. Thử khi app mở, ở nền và đã đóng thông thường; chạm thông báo để mở lại app.

## Ranh giới nghiệm thu

- Token tồn tại không chứng minh đã nhận push. Chỉ xác nhận đầu-cuối sau khi tin từ Firebase xuất hiện trên điện thoại.
- Firebase Console / backend tin cậy là bên gửi push từ xa. File cấu hình không tự tạo lịch gửi, không cung cấp quyền gửi bằng Admin SDK.
- Bản này chưa thêm backend lưu token theo tài khoản hay cron gửi FCM tự động. Lịch học/hẹn giờ cục bộ vẫn do thiết bị thực thi.
- Data-only payload không được tự chuyển thành thông báo; kiểm tra bằng notification payload có tiêu đề/nội dung.
- Android force-stop làm ngừng nhận; phải mở lại ứng dụng. Quyền bị tắt, Google Play Services không khả dụng, chế độ Không làm phiền, hạn chế pin của hãng máy hoặc mạng có thể ảnh hưởng việc nhận/hiển thị.
- Android/APK là nền tảng đã cấu hình ở đợt này; chưa cấu hình Firebase iOS/Web.

## Nguồn chính thức đã tra cứu

- https://firebase.google.com/docs/cloud-messaging/flutter/client
- https://firebase.google.com/docs/cloud-messaging/flutter/receive
- https://developer.android.com/develop/ui/views/notifications/notification-permission
- README và API đi kèm `flutter_local_notifications` 22.3.3.
- API FlutterFire cài tại workspace: messaging 17.0.1 bổ sung API FID mới. Luồng test của Firebase Console vẫn dùng registration token, do đó giữ `getToken` và `onTokenRefresh` theo tài liệu Firebase; không đánh đồng FID với token.

## Chữ ký

Theo lựa chọn của chủ ứng dụng, giữ keystore hiện tại để cài đè không mất dữ liệu. APK build chế độ release nhưng vẫn dùng chứng chỉ debug hiện hữu. Đây không phải chuyển đổi sang khóa phát hành Play Store. Không gỡ ứng dụng/xóa dữ liệu để cập nhật bản này.
