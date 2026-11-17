# Mochii Pastel — Design System toàn ứng dụng

Bộ Pastel đã được áp dụng vào toàn bộ màn hình hiện có: Hôm nay, Kế hoạch,
AI Tutor (cả bottom sheet), Ôn tập, Quản lý kiến thức, Hồ sơ/Lịch học,
Cài đặt, Lịch sinh hoạt, Cửa hàng, Tập trung, Learning Hub, Đăng nhập,
Onboarding và màn tải ứng dụng. Điều hướng vẫn giữ 5 tab.

`lib/design/pastel/` là nguồn theme/mặt thẻ/nút đã được duyệt;
`lib/design/mochi_design.dart` là API dùng chung cho toàn dự án.
Các component Mochi mở rộng cùng bộ Pastel cho input, bộ lọc, điều hướng,
thống kê, thông báo, hộp thoại và sheet. Hai theme cũ trong `lib/core/theme/`
và scope/panel tùy chỉnh riêng của Ôn tập đã bị xóa.

## Ngôn ngữ giao diện

- Inter đóng gói trong ứng dụng, giữ nguyên các tệp font hiện có.
- Nền pastel với vùng sáng mềm, độc lập với màu nhấn; không dùng blur nền.
- Thẻ gradient nhẹ, góc 26 px, viền sáng 1 px, bóng khuếch tán.
- Nút chính dạng viên thuốc, cao tối thiểu 54 px; nút nhỏ tối thiểu 48 px.
- Lề trang 24 px; khoảng cách 4 / 8 / 12 / 16 / 24 / 32 / 40 px.
- Nội dung đọc tối đa 680 px, tự co trên điện thoại; thống kê xếp dọc khi thiếu chỗ hoặc chữ lớn.
- Chữ chính màu mực, chữ phụ dịu hơn; màu chữ thao tác được tính từ màu nhấn để đạt tương phản tối thiểu 4.5:1 trên mặt thẻ và nền chip.
- Giữ tài nguyên robot và minh họa đang có. Không tạo hay tải hình mới.

## Màu sắc và cá nhân hóa

Mở **Tôi → Cài đặt & Tùy chọn → Cá nhân hóa không gian học → Màu nền & gradient**.
Nút tùy chỉnh giao diện Ôn tập đã được gỡ. Phần chọn nền nằm cùng màu chủ đạo
và chế độ hiển thị trong Cài đặt.

| Thiết lập | Lựa chọn | Lưu trữ |
| --- | --- | --- |
| Màu chủ đạo | 6 màu đang có trong hồ sơ | `ProfileModel.themePreset` |
| Nền gradient | Mây tím, Trời xanh, Đào sữa, Bạc hà | `ProfileModel.backgroundPreset` |
| Nền đơn sắc | Trắng dịu, Xám ấm | `ProfileModel.backgroundPreset` |
| Chế độ | Sáng, Tối, Hệ thống | `ProfileModel.themeMode` |

Mọi lựa chọn được lưu qua `MochiStore.save()` như các thiết lập hiện có.
Hồ sơ cũ thiếu trường nền nhận giá trị mặc định `lavender`. Khóa nền không hợp lệ
cũng hiển thị Mây tím. Nền đổi theo chế độ sáng/tối nhưng không đổi khi chọn màu nhấn.
Màu chủ đạo, nền và chế độ sáng/tối áp dụng xuyên suốt các tab, trang được mở
thêm và hộp thoại/sheet qua `MaterialApp`. Robot và màu trang phục vẫn dùng
tài nguyên/màu minh họa riêng, không bị thay bằng token giao diện.

## API

- `PastelTheme.build`: ThemeData riêng, Inter, ColorScheme và ThemeExtension.
- `PastelPalette`: màu nhấn gốc, màu thao tác có tương phản, mực, mặt thẻ,
  nền nhạt, viền, gradient nút/thẻ và bóng.
- `PastelBackgrounds`: danh mục và cặp màu nền sáng/tối.
- `MochiTheme`: tích hợp PastelTheme, MochiPalette và MochiVisuals tại gốc ứng dụng;
  đọc hồ sơ và phản ứng trực tiếp khi đổi thiết lập.
- `MochiBackground`: đọc preset nền độc lập qua MochiVisuals trên mọi route.
- `MochiCard` / `MochiButton`: dùng chung triển khai Pastel đã được duyệt.
- `MochiPrimaryButton`: nút gradient cho nội dung widget tùy ý, giữ trạng thái
  disabled và API onPressed cho các luồng nhập liệu hiện có.
- Component: `PastelScaffold`, `PastelAppBar`, `PastelCard`, `PastelSection`,
  `PastelListTile`, `PastelButton`, `PastelIconButton`, `PastelChip`,
  `PastelNoticeBanner`, `PastelProgressRing`, `PastelStatTile`, `PastelStatRow`,
  `PastelIllustration`, `PastelLoadingState`.
- `ReviewQuizCard` dùng component mới và giữ API xác thực/lưu câu trả lời hiện có.

```dart
import 'package:mochi_app/design/pastel/pastel_components.dart';

PastelCard(
  child: PastelButton(
    label: 'Bắt đầu',
    icon: Icons.play_arrow_rounded,
    expand: true,
    onPressed: start,
  ),
)
```

Các component cần đặt dưới `MochiTheme` (hoặc `PastelTheme` khi render độc lập).
High contrast bỏ bóng và vùng sáng trang trí; reduced motion được truyền qua
MediaQuery. Không khóa cỡ chữ của người dùng.

## Kiểm tra và ảnh xem trước

`review_theme_test.dart` kiểm tra tương phản của 6 màu × 2 chế độ, các màu nền,
khả năng lưu/đọc thiết lập và hồ sơ cũ. `pastel_preview_test.dart` kiểm tra layout
320 / 390 / 1366 px, chữ lớn 170%, đổi nền trực tiếp và giữ màu chủ đạo.
Các bài kiểm tra hành trình và khả năng phục hồi vẫn kiểm tra ôn thẻ, tự chấm,
quiz, kết quả và lỗi gateway.

`global_pastel_test.dart` kiểm tra 15 màn hình ở cả sáng/tối; 13 màn hình có
thêm kiểm tra 320 px/chữ 170% và 1366 px, kiểm tra đổi nền từ Cài đặt
và chuyển route vẫn giữ nền. Ảnh `docs/previews/global-*.png` được render từ
widget thực với dữ liệu kiểm thử, không bao gồm thanh điều hướng của khung ứng dụng.

Kết quả migration: toàn suite 226 pass, 2 skip; analyzer không có error
(117 cảnh báo/lint gồm 1 unused import ngoài phạm vi thiết kế). Build Web đạt.
Các nhóm responsive được sửa khi migration: chip nhắc học/filter xuống dòng,
thống kê và chú thích lịch tự xuống dòng, tiêu đề tháng co giãn, cửa hàng tăng
chiều cao theo cỡ chữ/số cột và dòng chuyển đăng nhập/đăng ký dùng Wrap.
Chưa QA thiết bị Android thật trong đợt này.

```powershell
flutter test test/review_theme_test.dart test/pastel_preview_test.dart test/review_journey_test.dart test/review_resilience_test.dart
# Xuất lại ảnh với font Inter và Material Icons:
flutter test test/pastel_preview_test.dart --dart-define=PASTEL_CAPTURE=true --update-goldens
flutter test test/global_pastel_test.dart --dart-define=PASTEL_CAPTURE=true --update-goldens
flutter build web --base-href / --no-pub
```
