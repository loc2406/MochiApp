# Glass design system

Hệ thiết kế theo các ảnh tham chiếu: nền trung tính/cá nhân hóa, nội dung dễ đọc,
điều khiển nổi bằng kính, danh sách chia nhóm, nút tròn hoặc dạng viên.
Đây là triển khai Flutter bằng blur/compositing, không mô phỏng khúc xạ native.

## Vị trí

| File | Trách nhiệm |
| --- | --- |
| `lib/core/theme/app_theme.dart` | Tạo ThemeData từ màu người dùng; cấu hình Material components |
| `lib/core/theme/color_constant.dart` | Sinh ColorScheme và chọn màu chữ tương phản |
| `lib/core/theme/spacing_constant.dart` | Nhịp khoảng cách, padding, vùng chạm, chiều rộng |
| `lib/core/theme/typography_constant.dart` | Vai trò chữ, family mặc định `Inter` (nhúng trong `assets/fonts/`), text scaling |
| `lib/core/theme/app_radius.dart` | Bo góc theo loại thành phần |
| `lib/core/theme/app_background.dart` | Cấu hình nền độc lập và ThemeExtension |
| `lib/core/theme/app_elevation.dart` | `AppBlur`, `AppOpacity`, `AppShadow`, `AppIconSize` |
| `lib/core/theme/app_breakpoints.dart` | `AppWindowSize` (compact/medium/expanded/large), rail 96, sidebar 260 |
| `lib/core/theme/app_semantic_colors.dart` | success/warning/info/streak/xp dạng ThemeExtension |
| `lib/core/theme/app_motion.dart` | `AppMotion.quick/page/slow`, curve và tôn trọng giảm chuyển động |
| `lib/shared/widgets/glass/glass_components.dart` | Điểm import chung cho Glass Components |

## Cấu hình theo người dùng

```dart
import 'package:mochi_app/core/theme/app_theme.dart';
import 'package:mochi_app/core/theme/apple_glass_theme.dart';
import 'package:mochi_app/shared/widgets/glass/glass_components.dart';

final accent = AppleOS27Colors.accentFor(store.profile.themePreset);
final visuals = AppVisualTheme(
  background: AppBackground(
    color: userBackgroundColor, // Color?, null dùng surface của theme
    image: userWallpaper,       // ImageProvider?, null khi chưa chọn ảnh
    scrimOpacity: .12,
  ),
  glassAppearance: GlassAppearance.tinted,
  reduceTransparency: false,
);

final lightTheme = AppTheme.build(accent: accent, visuals: visuals);
final darkTheme = AppTheme.build(
  accent: accent, brightness: Brightness.dark, visuals: visuals,
);
```

Màu nhấn là tham số bắt buộc; nhận bất kỳ `Color` nào, không giới hạn preset.
Màu nền, gradient và ảnh là các tham số độc lập với màu nhấn. Mặc định dùng
`ColorScheme.surface`; không có đường dẫn ảnh hay màu thương hiệu cố định.
Thứ tự nền: màu → gradient nếu có → ảnh nếu có → scrim → giao diện.
Ảnh lỗi hiển thị nền dự phòng. Nền là trang trí, không được đọc bởi screen reader.

`ImageProvider` hỗ trợ `AssetImage`, `MemoryImage`, `NetworkImage`... Lớp này không
lưu bytes/URL vào hồ sơ. Khi bổ sung picker cần xử lý lưu trữ, đồng bộ và quyền
truy cập ở tầng dữ liệu. Với web, ảnh URL cần đáp ứng CORS của trình duyệt.

## Token

Dùng token thay vì số/màu viết tay:

| Nhóm | Giá trị |
| --- | --- |
| `AppBlur` | `none 0`, `light 12`, `medium 16`, `heavy 24` |
| `AppOpacity` | `scrim .12`, `glassClear .62`, `glassTinted .88`, `hairline .65`, `disabled .38` |
| `AppShadow` | `flat 0`, `low 1`, `medium 2`, `high 3`; `resolve(colorScheme, level:)` đổi theo dark/light |
| `AppIconSize` | `xs 14`, `sm 18`, `md 22`, `lg 28`, `xl 36`, `hero 48` |
| `AppWindowSize` | `<600 compact`, `600–899 medium`, `900–1279 expanded`, `≥1280 large` |
| `AppBreakpoints` | `railWidth 96`, `sidebarWidth 260`, `maxContentWidth 1120`, `legacySidebar 768` |
| `AppSemanticColors` | `success`, `warning`, `info`, `streak`, `xp` + container/on màu tương phản |
| `AppMotion` | `quick 180ms`, `page 300ms`, `slow 420ms`; `duration()` trả `0` khi giảm chuyển động |

`AppSemanticColors` tự lấy từ `ColorScheme` nếu theme chưa cấu hình, nên dùng được
ngay cả trong widget test. Container được blend với `surface` để đọc tốt ở dark mode.

## Components

| Component | Sử dụng |
| --- | --- |
| `GlassSurface` | Vùng điều khiển nổi, clear/tinted/opaque, blur được clip |
| `GlassCard` | Bề mặt nội dung đặc, dành cho câu hỏi/giải thích dài |
| `GlassButton` | Primary/secondary/text, icon tùy chọn, loading/disabled |
| `GlassIconButton` | Nút icon có tooltip, vùng chạm 48 |
| `GlassSearchField` | Ô tìm kiếm có controller/onChanged |
| `GlassFilterChip` | Bộ lọc có trạng thái chọn |
| `GlassHeader` | Tiêu đề, mô tả, actions; tự xuống hàng trên màn nhỏ/chữ lớn |
| `GlassSection`, `GlassListTile` | Danh sách nhóm với divider thụt vào |
| `GlassBottomBar` | NavigationBar trên lớp kính |
| `GlassDialog` | Dialog cuộn, actions tự bố trí theo không gian |
| `GlassScaffold` | Nền runtime, header và bottom bar có safe area |

```dart
GlassScaffold(
  header: GlassHeader(
    title: 'Ôn tập',
    subtitle: 'Ôn vừa sức, nhớ lâu hơn.',
    actions: [GlassIconButton(
      icon: Icons.library_books_outlined,
      tooltip: 'Mở thư viện',
      onPressed: openLibrary,
    )],
  ),
  body: ListView(
    padding: SpacingConstant.page,
    children: [GlassCard(child: Text('Nội dung cần nhớ'))],
  ),
)
```

Dùng `Theme.of(context).colorScheme` cho màu, không đặt mã màu vào component.
Dùng `Theme.of(context).textTheme` để giữ text scaling. Kính clear không phù hợp
cho đoạn văn dài trên ảnh nền nhiều chi tiết; dùng card đặc hoặc tinted.
`reduceTransparency` hoặc `MediaQuery.highContrast` chuyển surface sang đặc và
tắt blur. Tránh lồng nhiều BackdropFilter trong danh sách dài.

## Tích hợp hiện tại

- `ReviewGlass` là adapter đọc `profile.themePreset` và dùng `AppTheme.build`.
- Ôn tập/thư viện đã sử dụng scaffold/card/surface chung.
- `MochiApp(visuals: ...)` truyền cấu hình nền xuống qua ThemeExtension; thay đổi
  cấu hình rồi rebuild sẽ cập nhật các màn đã dùng `GlassScaffold`.
- Các tab cũ vẫn dùng style hiện có; chưa chuyển toàn bộ app sang bộ mới.
- Theme mới hỗ trợ light/dark; ứng dụng hiện vẫn giữ lựa chọn theme mode đang
  có. Việc chuyển toàn bộ màn cũ sang dark mode chưa thuộc thay đổi này.
- Chưa thêm UI chọn ảnh nền hoặc lưu ảnh vào hồ sơ người dùng.

## Kiểm tra

`test/glass_design_system_test.dart`: tương phản chữ nút với màu tùy ý,
light/dark, đổi nền độc lập với màu nhấn, ảnh lỗi, giảm trong suốt và layout
320 px với text scale 200%. Các test Ôn tập kiểm tra hồi quy luồng đang dùng.

## Component tương tác bổ sung

Import duy nhất: `package:mochi_app/shared/widgets/glass/glass_components.dart`.

| API | Hành vi |
| --- | --- |
| `GlassNavigationBar` | Danh sách `NavigationDestination`, selected/disabled; cuộn ngang khi không đủ chỗ cho chữ lớn; `GlassBottomBar` chuyển tiếp sang API này |
| `GlassFloatingActionButton` | Nút nổi chính theo primary/onPrimary; dạng viên trên màn rộng, dạng icon có tooltip trên màn nhỏ/chữ lớn; loading chặn bấm lặp; heroTag mặc định null tránh trùng Hero |
| `showNativeBottomSheet<T>` | iOS dùng CupertinoSheetRoute; nền tảng khác dùng modal bottom sheet; đóng/kéo/Back, bàn phím, safe area và trả kết quả T |
| `AnimatedSwitch` | Giá trị do caller quản lý; có focus, Space/Enter, semantics toggled/disabled; hoạt ảnh tuân theo giảm chuyển động |
| `GlassSwitchTile` | Nhãn/mô tả và AnimatedSwitch |
| `GlassContainer` | Margin, padding, constraints và chất liệu kính tùy chọn |
| `CustomPageTransition.route<T>` | Adaptive/fade/slideUp; iOS adaptive giữ route Cupertino và back gesture; trả kết quả khi pop |
| `GlassCheckboxTile`, `GlassSlider` | Form controls theo theme, có nhãn và trạng thái disabled |
| `GlassTabBar` | TabBar cuộn theo TabController hoặc DefaultTabController |
| `GlassMenuButton<T>` | Menu bàn phím/chuột với các PopupMenuEntry và callback kết quả |
| `showGlassSnackBar` | Thông báo nổi, đóng và action tùy chọn; error dùng màu ngữ nghĩa |
| `GlassLoadingState`, `GlassEmptyState`, `GlassStatusBadge` | Trạng thái tải xác định/không xác định, rỗng có action và nhãn trạng thái |

FAB và nội dung cần đọc dùng bề mặt đặc; thanh điều hướng/container dùng kính.
Các input và date picker tiêu chuẩn vẫn lấy style từ `AppTheme`, không cần tạo
wrapper chỉ để đổi tên. Những component dùng state (switch/tab/navigation) nhận
giá trị và callback từ caller, không tự ghi vào store.

```dart
final result = await showNativeBottomSheet<bool>(
  context: context,
  title: 'Sửa kiến thức',
  builder: (sheetContext) => GlassButton(
    label: 'Lưu',
    onPressed: () => Navigator.pop(sheetContext, true),
  ),
);

await Navigator.push(context, CustomPageTransition.route<void>(
  context: context,
  builder: (_) => const DetailScreen(),
));
```

Sheet là route thích ứng nền tảng do Flutter render, không phải embedded OS view.
Builder sheet nhận nội dung **không tự cuộn**: helper quản lý scroll controller
và keyboard inset. Dùng StatefulBuilder hoặc StatefulWidget khi cần thay đổi
state bên trong sheet. Các Theme được capture qua route; Provider thuộc tầng
ứng dụng cần đặt phía trên Navigator hoặc truyền dữ liệu vào builder.

`AppVisualTheme(reduceMotion: true)` hoặc `MediaQuery.disableAnimations` tắt
hoạt ảnh switch/navigation/custom route. Với reduced motion, sheet dùng modal
không animation cả trên iOS. Ôn tập đọc `reducedMotion` và `highContrast` từ hồ sơ.
Các route đã mở dùng theme capture lúc mở; màn chi tiết có nhu cầu nhận màu đổi
trực tiếp tiếp tục dùng scope lắng nghe hồ sơ như `ReviewGlass`.

## Pattern components

15 pattern còn thiếu của hệ Mochi, cộng `GlassAdaptiveShell` cho điều hướng thích ứng.
Tất cả nằm trong barrel `glass_components.dart`, đọc màu/chữ từ theme, có semantics
và tôn trọng `reduceMotion`/`reduceTransparency`.

| Component | Dùng cho | Điểm chính |
| --- | --- | --- |
| `GlassAppBar` | AppBar cấp màn hình | `PreferredSizeWidget`; title + subtitle căn giữa, nền `primary` + chữ `onPrimary` ở cả light/dark, title 18, chevron iOS tự hiện khi route có thể pop, action cùng màu chữ; chỉ bo 2 góc dưới 16; title co bằng `FittedBox` thay vì tràn |
| `GlassBackButton` | Nút quay lại ngoài AppBar | Tooltip, RTL, vùng chạm 48 |
| `GlassNoticeBanner` | Lỗi đồng bộ, offline, gợi ý | `info/success/warning/error`, action, dismiss, `liveRegion` cho lỗi |
| `GlassStatTile`, `GlassStatRow` | XP, phút học, chuỗi ngày | Value/unit/caption/trend, icon + accent, row cao bằng nhau |
| `GlassSegmentedControl<T>` | Pomodoro/tự do, filter | Generic, selected pill, disabled segment, keyboard/semantics |
| `GlassProgressRing` | Phiên tập trung, mục tiêu | Xác định/không xác định, nhãn %, reduced motion đứng yên |
| `GlassMonthCalendar` | Tab lịch/thống kê | Dot theo `GlassDayStatus`, hôm nay, first/lastDate, legend |
| `GlassChatBubble`, `GlassTypingIndicator` | AI Tutor | user/assistant/system, footnote, time, typing, avatar |
| `GlassQuizCard` | Ôn tập, quiz AI | Option A–Z, selected/revealed, giải thích, note, prev/next |
| `GlassFormField` | Mọi form | Label/required/helper/error, đếm ký tự, ẩn–hiện mật khẩu |
| `GlassDialogActions` | Dialog 2 nút | Tự xếp dọc dưới 320 px |
| `GlassAsyncBuilder<T>` | Future/list | skeleton → data, lỗi có retry, empty state |
| `GlassAvatar` | Hồ sơ, chat | Initials, ảnh lỗi fallback, trạng thái online |
| `GlassSkeleton`, `GlassSkeletonList` | Chờ tải | Shimmer tắt khi reduced motion, gộp semantics |
| `GlassStepper`, `GlassStep` | Onboarding, wizard | Ngang có nhãn; dọc dạng timeline |
| `GlassImageCard`, `GlassImageBadge`, `GlassImageGrid` | Shop, bộ sưu tập | Scrim, badge, khoá, placeholder, grid theo bề rộng |
| `GlassSwipeActionTile` | Nhiệm vụ/thẻ | Vuốt 2 chiều, action cũng nằm trong custom semantics actions |
| `GlassAdaptiveShell` | Khung app | `<600` bottom bar, `600–899` rail, `≥900` sidebar 260; safe area + max content width |
| `GlassShellHeader` | Sidebar/rail | Logo + tên + avatar người dùng |

### AppBar

`GlassAppBar` dùng bố cục điều hướng iOS: title và subtitle căn giữa tuyệt đối
trên thanh, chevron quay lại nằm sát trái, các action nằm sát phải. Chevron tự
hiện khi route hiện tại có thể pop; tắt bằng `automaticallyImplyLeading: false`
hoặc truyền `leading` riêng. Nền thanh là `colorScheme.primary` ở cả light lẫn
dark mode; chữ và icon dùng `colorScheme.onPrimary` nên tương phản luôn đạt với
mọi preset accent. Title cỡ 18 (`w600`), subtitle `bodySmall`; icon status bar
tính theo luminance của nền primary (nền sáng → icon tối). Thanh chỉ bo hai góc
dưới 16 (`AppRadius.appBarBorder`); `showDivider` vẽ hairline inset 16 với
`onPrimary` alpha .18.

```dart
GlassAdaptiveShell(
  destinations: destinations,
  selectedIndex: index,
  onSelected: (i) => setState(() => index = i),
  header: const GlassShellHeader(title: 'MOCHI', userName: 'Minh Anh'),
  appBar: GlassAppBar(title: 'Hôm nay', subtitle: '3 việc cần làm'),
  floatingActionButton: GlassFloatingActionButton(
    label: 'Thêm',
    onPressed: addTask,
  ),
  body: ListView(
    padding: SpacingConstant.page,
    children: [
      const GlassNoticeBanner(
        message: 'Đang dùng dữ liệu offline.',
        severity: GlassNoticeSeverity.warning,
      ),
      GlassStatRow(children: const [
        GlassStatTile(label: 'XP tuần', value: '1 240'),
        GlassStatTile(label: 'Chuỗi', value: '12', unit: 'ngày'),
      ]),
      GlassAsyncBuilder<List<Task>>(
        future: loadTasks(),
        onRetry: loadTasks,
        isEmpty: (tasks) => tasks.isEmpty,
        builder: (context, tasks) => GlassSection(
          title: 'Nhiệm vụ',
          children: [for (final task in tasks) GlassListTile(title: task.title)],
        ),
      ),
    ],
  ),
)
```

`GlassStatRow` dùng `IntrinsicHeight` nên không đặt tile trong `ListView` có
`shrinkWrap` lồng nhau quá sâu. `GlassStatTile.dense` dành cho grid hẹp thay vì
tự đo bằng `LayoutBuilder` (không hỗ trợ intrinsic). `GlassSwipeActionTile` không
bao giờ là cách duy nhất để làm một việc: mỗi action được expose thành
`CustomSemanticsAction`.

## Xem thử độc lập

Từ `02-source/flutter-app`:

```powershell
flutter run -d chrome -t examples/glass_components.dart
```

Trang ví dụ có đổi màu, sáng/tối, giảm chuyển động, `GlassAdaptiveShell` (bottom bar/rail/sidebar),
15 pattern mới (app bar, banner, stat, segmented, ring, calendar, chat, quiz, form, async,
avatar, skeleton, stepper, image card, swipe action), navigation, FAB, sheet, menu, switch,
checkbox, slider và chuyển trang. Không đọc/ghi tài khoản, không cần AI. Không thay thế
entry point `lib/main.dart` của app.

Test bổ sung: `test/glass_patterns_test.dart` phủ từng pattern (kể cả error/retry, empty,
vuốt để xoá, breakpoint của shell và composition 320 px + 200% chữ ở dark mode).
`test/glass_interaction_test.dart` kiểm tra keyboard/disabled,
navigation 320px + 200% text, sheet ở cả iOS/Android có keyboard và pop result,
chuyển trang reduced motion, route Cupertino và FAB loading.
