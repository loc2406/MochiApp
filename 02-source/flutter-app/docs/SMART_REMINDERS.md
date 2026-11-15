# Nhắc học thông minh trên thiết bị

## Cơ chế thực tế

- **Bộ quy tắc trên máy quyết định lúc nhắc**; AI không tự chạy ngầm liên tục.
- Nhiệm vụ có ngày/giờ hợp lệ: nhắc đến lịch, một lần nhắc lại sau khoảng 3 giờ nếu vẫn chưa đánh dấu hoàn thành. Nhiệm vụ đã quá hạn khi mở app được lùi ít nhất 2 giờ để tránh nhắc dồn ngay lúc mở.
- Hoạt động học dựa trên phiên học đã ghi nhận, lúc bắt đầu tập trung và thời điểm hoàn thành nhiệm vụ. Chuẩn bị lời mời học sau 2/4/6 ngày không có hoạt động mới.
- Việc mở lại app được ghi nhận khi foreground/resume. Chuẩn bị lời mời quay lại sau 3/6 ngày không mở app.
- Lên lịch trước tối đa 7 ngày, làm mới khi mở app và khi nhiệm vụ/hoạt động học thay đổi. Không có daemon AI vô hạn hay lịch FCM tự động ở server.
- Tối đa 2 lời nhắc tự động/ngày; cách nhau ít nhất 3 giờ; không **hẹn** trong 22:00–08:00. Các lời nhắc có giờ nhiệm vụ được ưu tiên trước lời mời chung.
- Hạn mức ghi nhận cả các reservation đã tới giờ (kể cả OS có trì hoãn), không được reset chỉ bởi mở lại app. Chuông Pomodoro, thông báo thử và FCM từ xa là các luồng riêng, không nằm trong hạn mức 2/ngày.
- Hoàn thành/xóa nhiệm vụ, quay lại app hoặc ghi nhận học làm mới lịch; các alarm thông minh cũ được hủy theo ID riêng, không xóa timer hoặc lịch ôn tập.

## AI soạn nội dung, có fallback rõ ràng

- Khi có quyền thông báo và đã bật tính năng, app dùng kết nối AI hiện hữu để chuẩn bị 4 mẫu câu tiếng Việt.
- **Không gửi tên người học, tiêu đề nhiệm vụ hay lịch sử hoạt động cho AI**. Tên và nhiệm vụ chỉ được chèn vào placeholder trên máy.
- Kiểm tra JSON, độ dài, placeholder, nội dung xuống dòng/URL/emoji trước khi dùng. Phản hồi bị cắt hoặc lỗi không được nhận là nội dung AI hoàn chỉnh.
- Cache AI được lưu trong SharedPreferences. Làm mới tối đa một lần/ngày; lỗi mạng được giới hạn thử lại sau ít nhất một giờ. Có nút soạn lại khi người dùng muốn.
- Mất mạng hoặc phản hồi không hợp lệ: dùng mẫu theo quy tắc, hiển thị nguồn là **mẫu theo quy tắc**, không gắn nhãn AI giả.
- Có công tắc bật/tắt toàn bộ nhắc thông minh và công tắc riêng cho AI soạn câu.

## Điều kiện và giới hạn

- Cần quyền thông báo Android; quyền báo thức chính xác giúp hẹn sát giờ hơn. Nếu chưa cấp, dùng inexact thay vì làm lịch thất bại vì thiếu quyền.
- Doze/tiết kiệm pin của hãng máy có thể trì hoãn việc phát. Khung yên lặng ở đây là giờ hẹn; không phải cam kết Android không bao giờ giao muộn. Dùng Không làm phiền của Android nếu cần yên lặng tuyệt đối.
- Force-stop có thể làm ngừng alarm/FCM; cần mở lại app. Khi đổi múi giờ, mở lại app để tính lại theo giờ địa phương.
- Chỉ biết dữ liệu đã ghi nhận tại thiết bị. Hoàn thành ở thiết bị khác chỉ hủy nhắc ở đây sau khi có đồng bộ thực tế và app cập nhật dữ liệu; cơ chế này không thay thế kiểm thử đồng bộ hai thiết bị.
- Nhiệm vụ cũ không có ngày/giờ đã lưu sẽ không bị tự gán một giờ học tưởng tượng. Chúng không có nhắc đến lịch cho đến khi có lịch hợp lệ.
- Không có network AI vào lúc alarm phát: Android hiển thị nội dung đã lưu, nên offline vẫn nhận được nếu hệ điều hành cho phép.

## Kiểm thử

- Policy: hạn mức, khoảng cách, giờ yên lặng qua ranh giới tháng, nhiệm vụ hoàn thành/xóa/thiếu lịch, inactivity, ID ổn định và ledger chống reset quota.
- AI: schema, placeholder, lỗi mạng, phân biệt nguồn rules/AI, dữ liệu gửi ra không chứa thông tin người học.
- Coordinator: đăng ký alarm native qua platform channel, hủy nhiệm vụ hoàn thành, không hủy timer ID 9999.
- UI: chiều rộng 320px, tỷ lệ chữ 1x/2x.
- Các test mock chứng minh logic và lời gọi native, KHÔNG thay cho kiểm tra giao thông báo thực tế trên điện thoại hoặc push đầu-cuối.
