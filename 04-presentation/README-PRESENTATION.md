# Mochii — Thuyết trình dự án

Đối tượng: giảng viên / hội đồng. Bài trình bày 12 trang, khoảng **12 phút 30 giây**, chưa tính hỏi đáp.

## Cách dùng

- Mở trang slide, nhấn **F** hoặc nút Toàn màn hình.
- Phím **← / →**, **Space**, **Page Up / Page Down** để chuyển; **Home / End** tới trang đầu/cuối.
- Nhấn **P** hoặc **Lời dẫn** để mở cửa sổ người thuyết trình riêng: lời nói, câu chuyển ý, trang kế tiếp và đồng hồ. Đặt cửa sổ đó trên màn hình cá nhân khi dùng chế độ mở rộng màn hình.
- Trong cửa sổ người nói, nhấn **T** để bắt đầu/tạm dừng giờ.
- Dùng nút **Mở demo** để mở ứng dụng thật. Nếu không có mạng, nói rõ khi dùng ảnh chụp thay cho demo trực tiếp.
- Kịch bản và gợi ý hỏi đáp: kich-ban-thuyet-trinh.md. PDF là phương án dự phòng khi không dùng trang web.

## Thay đổi nội dung

Chuyển từ quảng cáo tính năng sang: vấn đề → vòng lặp giải pháp → tình huống → demo → nhắc thông minh → học & ôn → trải nghiệm → kiến trúc → kiểm chứng → hướng phát triển → mời trải nghiệm.

Đã bỏ các khẳng định chưa đo: AI 0,7 giây, 100% tránh trùng lịch, 0đ trọn đời, 100% bảo mật, giảm 80% thời gian quên, 120Hz/60 FPS không có benchmark. Sửa mô tả lưu trữ thành SharedPreferences thay vì SQLite; không nói mọi tính năng đều offline hay đã có backend AI tự gửi FCM.

## Cập nhật APK và QR

Mã QR APK giữ nguyên đường dẫn `/slide/mochi-app.apk`. Khi phát hành: thay file APK bằng rename nguyên tử, rồi cập nhật release.json với version/build/size/SHA-256. Trang tự đọc metadata đó; không cần sửa số phiên bản ở nhiều nơi và không làm mã QR cũ mất hiệu lực.

Ảnh thông báo minh họa được cắt chỉ còn thông báo Mochii, không đưa các thông báo ứng dụng khác vào slide.
