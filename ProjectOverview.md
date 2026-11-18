# Mochii — Mô tả tổng quan dự án

> **Phiên bản:** 1.4.10, build 2047  
> **Ngày đóng gói bàn giao:** 04/11/2026  
> **Nền tảng:** Android (APK) + Web (Flutter)  
> **Tài liệu này được lập từ:** đọc toàn bộ source, tài liệu, slide, log build/analyze/test và báo cáo kiểm định trong gói bàn giao. Không phải biên bản QA thiết bị thật cho đúng build 2047.

> **Cập nhật kiểm tra source:** 17/11/2026. Mục 4.1–4.2 là bản tóm tắt màn hình và lỗi hiện tại, thay thế mô tả dài trước đây. Đây là rà soát tĩnh mã nguồn; không khẳng định backend Supabase, gateway, quyền Android hoặc giao diện trên thiết bị thật đang hoạt động nếu chưa kiểm tra trên môi trường tương ứng. Các log test/build cũ bên dưới không đại diện cho source mới ngày 17/11.

---

## Mục lục

1. [Dự án là gì](#1-dự-án-là-gì)
2. [Bộ bàn giao gồm gì](#2-bộ-bàn-giao-gồm-gì)
3. [Kiến trúc & công nghệ](#3-kiến-trúc--công-nghệ)
4. [Tính năng](#4-tính-năng)
   - [Hoạt động](#41-hoạt-động)
   - [Lỗi, hạn chế và hướng xử lý](#42-lỗi-hạn-chế-và-hướng-xử-lý)
5. [Tổng hợp lỗi & rủi ro](#5-tổng-hợp-lỗi--rủi-ro)
6. [Bằng chứng kiểm định](#6-bằng-chứng-kiểm-định)
7. [Cách chạy thử nhanh](#7-cách-chạy-thử-nhanh)
8. [Kết luận & ưu tiên xử lý](#8-kết-luận--ưu-tiên-xử-lý)

---

## Chú thích trạng thái

| Ký hiệu | Ý nghĩa |
|---|---|
| ✅ | Có trong mã, build được, test tự động liên quan đạt |
| ⚠️ | Hoạt động nhưng có điều kiện (đăng nhập, mạng, quyền, dịch vụ ngoài) |
| 🔴 | Lỗi chặn sử dụng / chặn phát hành |
| 🟠 | Lỗi hoặc hạn chế đã biết, có thể vượt qua |
| 🟡 | Rủi ro / chưa được kiểm chứng đầy đủ |

---

## 1. Dự án là gì

**Mochii** là ứng dụng đồng hành tự học cho học sinh/sinh viên Việt Nam, chạy trên **Android** và **Web**, viết bằng **Flutter**. Trọng tâm không phải "chatbot" mà là một vòng lặp khép kín:

> **Đặt mục tiêu → chia nhỏ & xếp lịch → học có đồng hồ/nhắc nhở → ôn tập & điều chỉnh**

Thông tin bản phát hành:

| Hạng mục | Giá trị |
|---|---|
| Phiên bản | 1.4.10+2047 |
| Package Android | `com.mochi.study.mochi_app` |
| Min / Target / Compile SDK | 24 / 36 / 36 |
| Kiến trúc APK | arm64-v8a, armeabi-v7a, x86_64 |
| Dung lượng APK | 67.851.699 byte (~67,9 MB) |
| Web base href | `/mochi/` |
| Ngôn ngữ giao diện | Tiếng Việt |
| Chữ ký APK | Android Debug certificate (⚠️ chưa phải bản phát hành) |

---

## 2. Bộ bàn giao gồm gì

| Thư mục | Nội dung |
|---|---|
| `01-release/` | APK Android + bản Web đã build |
| `02-source/flutter-app/` | Toàn bộ source Flutter, assets, bộ test Flutter, migration Supabase, tài liệu gốc |
| `02-source/ai-gateway/` | Gateway Node.js 22 (không cần npm dependency) + 6 test |
| `03-documentation/` | Hướng dẫn tiếp nhận, build/triển khai, cấu hình dịch vụ, phạm vi & giới hạn |
| `04-presentation/` | Slide HTML/PDF, kịch bản thuyết trình, ảnh chụp màn hình |
| `05-operations/` | `preview.py`, `build-release.sh`, mẫu Nginx/systemd, script kiểm checksum |
| `06-verification/` | Log build, log test, log analyze, báo cáo kiểm định, ảnh smoke test |

**Không có trong gói:** keystore ký release, private key, Gemini API key, service-role key, database người dùng, backup cloud, lịch sử Git đầy đủ, SDK/cache, IPA/desktop build.

---

## 3. Kiến trúc & công nghệ

```text
Flutter (Android + Web)
 ├── Dữ liệu học tập: SharedPreferences (JSON, offline-first)
 ├── Supabase Auth + bảng mochi_account_state (đồng bộ JSONB, CAS revision)
 ├── AI Gateway (Node.js) ── kiểm JWT Supabase ── Gemini API
 └── Android: local notifications + Firebase Cloud Messaging (chỉ nhận)
```

- **State management:** Provider + `ChangeNotifier` (`MochiStore`, ~1.400 dòng, chứa phần lớn nghiệp vụ).
- **AI:** app gửi tên model nội bộ theo định dạng OpenAI-compatible; gateway ánh xạ sang `gemini-3.8-flash` / `gemini-3.5-flash-lite`; app **không** giữ Gemini API key.
- **Đồng bộ:** outbox bền, ghi tuần tự, retry CAS, merge 3 chiều; xung đột được giữ lại và báo, không ghi đè âm thầm.
- **Thông báo:** local notification Android + FCM client; **không** có backend cron gửi push.
- **Không có trong mã:** STT/TTS, server Gemini Live chính thức, dashboard phụ huynh/giáo viên, thanh toán, đa ngôn ngữ.

---

## 4. Tính năng

### 4.1. Hoạt động

| Nhóm màn hình | Chức năng chính | Tình trạng |
|---|---|---|
| **Onboarding, Hôm nay, điều hướng** (`onboarding_screen.dart`, `today_screen.dart`, `main.dart`) | Tạo hồ sơ ban đầu; xem nhiệm vụ và tiến độ ngày; đánh dấu hoàn thành; mở kế hoạch, AI, ôn tập, hồ sơ và đồng hồ. | ⚠️ Luồng có trong source; chưa QA lại thiết bị cho source hiện tại. |
| **Kế hoạch học tập** (`planner_screen.dart`, `learning_hub_screen.dart`, `routine_screen.dart`) | Quản lý mục tiêu/bài học; khai báo môn, chủ đề, thời khóa biểu và thời gian rảnh; xem trước rồi áp dụng lịch. | ⚠️ Xếp lịch chạy theo ràng buộc local; chia mục tiêu và bóc thời khóa biểu cần AI/gateway. |
| **AI Tutor** (`ai_tutor_screen.dart`, `ai_tutor_sheet.dart`) | Hỏi đáp, gửi ảnh, xem Markdown/công thức, quiz, đề xuất đổi lịch và lưu lịch sử chat. | ⚠️ Cần đăng nhập Supabase, gateway và mạng; AI có thể sai, chưa streaming. |
| **Ôn tập & kiến thức** (`review_screen.dart`, `flashcards_screen.dart`) | Quản lý bộ thẻ, tìm/lọc, ôn offline, tự chấm theo lịch lặp lại, quiz và giải thích bằng AI. | ⚠️ Phần thẻ đã lưu dùng offline; nội dung AI cần gateway. |
| **Đồng hồ tập trung** (`focus_timer_screen.dart`) | Pomodoro/đếm tự do; lưu phiên, đánh giá, cộng XP/sao và tùy chọn tổng kết AI. | ⚠️ Timer foreground có logic; báo nền phụ thuộc quyền và chính sách pin Android. |
| **Hồ sơ, lịch & cửa hàng** (`profile_calendar_screen.dart`, `robot_shop_screen.dart`) | Xem lịch học, streak, 5 phiên học gần nhất; đặt nhắc; mua/mặc vật phẩm bằng sao. | ⚠️ Dữ liệu phần thưởng do client quản lý; nhắc phụ thuộc nền tảng. Đã bỏ nút “Xem tất cả” chưa có chức năng. |
| **Cài đặt** (`settings_screen.dart`, `personalization_card.dart`) | Chọn theme/màu/nền gradient hoặc ảnh `assets/bg/bg-01.jpg`; điều chỉnh trợ lý; quản lý thông báo; sao lưu/khôi phục. | ⚠️ Nền ảnh được áp dụng qua `backgroundPreset`; không còn chức năng đặt lại dữ liệu. |
| **Tài khoản & đồng bộ** (`auth_screen.dart`, `cloud_sync_service.dart`) | Đăng ký/đăng nhập email-password; đồng bộ state tài khoản qua Supabase; có thể dùng guest. | ⚠️ Phụ thuộc Supabase, cấu hình email và mạng. |
| **Chia sẻ tiến độ học sinh** (`student_sharing_card.dart`, `student_sharing_permissions_screen.dart`, `student_overview_screen.dart`) | Học sinh tạo mã một lần gắn email/role; mã hoạt động 5 phút; người xem nhập email+mã để xem dashboard học tập, không có chat AI. Danh sách gộp theo email, hiển thị lần xem gần nhất và cho phép chọn 8 mục thông tin được chia sẻ (hồ sơ, XP, chuỗi ngày, phút học, mục tiêu, môn học, tiến độ, hoạt động gần đây); thu hồi sẽ khóa mọi phiên của email đó. | ⚠️ Backend mời đã được người dùng xác nhận hoạt động; áp dụng lần lượt `20261117193000_student_viewer_last_access.sql` và `20261118_student_viewer_sections.sql` để bật gộp email, lưu thời điểm xem và phân quyền theo mục. |
| **Thông báo & nhắc thông minh** (`notification_settings_card.dart`, `smart_reminder_settings.dart`) | Quản lý quyền, exact alarm và lịch nhắc theo bài/lịch; có thể dùng AI soạn nội dung rồi lưu local. | ⚠️ Chỉ hỗ trợ notification trên Android; FCM hiện không có backend gửi nhắc. |

> **Lưu ý build:** APK/Web trong `01-release/` là bản đóng gói cũ; cần build lại từ source hiện tại trước khi phân phối.

### 4.2. Lỗi, hạn chế và hướng xử lý

1. **Phân quyền người xem cần migration mới trên Supabase.** Chạy `20261117193000_student_viewer_last_access.sql` sau migration viewer và migration hạn 5 phút, rồi chạy `20261118_student_viewer_sections.sql`. Migration cuối thêm cột `shared_sections`, cập nhật RPC đọc/ghi quyền và giữ nguyên lựa chọn khi email nhận mã mới. Màn hình ghi lần xem khi tải/làm mới dashboard; danh sách chỉ hiện một dòng cho mỗi email đang có quyền.
2. **Guest chưa luôn sáng nếu thiết bị/hồ sơ cũ đặt dark.** `main.dart` đọc `profile.themeMode`; đổi default model không thay giá trị đã lưu. Nếu muốn ép sáng khi đăng xuất, dùng `ThemeMode.light` khi `!store.cloudService.hasActiveUser`.
3. **AI và đồng bộ phụ thuộc dịch vụ ngoài.** AI cần Supabase session, gateway, quota và mạng; gateway mặc định dùng host Tailscale. Cấu hình `MOCHI_AI_GATEWAY` và `ALLOWED_ORIGINS` theo môi trường deploy.
4. **Notification có thể trễ hoặc dừng trên Android.** Doze, force-stop và chính sách pin của hãng ảnh hưởng alarm; cần QA trên thiết bị thật. Web không có local notification.
5. **Chưa xác minh source mới bằng analyzer/test/build.** SDK cài trong workspace là Flutter 3.29.2/Dart 3.7, còn `pubspec.yaml` yêu cầu Dart `^3.13.3`; log test/build ở phần dưới là kết quả lịch sử, không phải xác nhận source hiện tại.
## 5. Tổng hợp lỗi & rủi ro

### 5.1. Kết quả test lịch sử

| # | Test | Kết quả |
|---|---|---|
| — | Toàn bộ suite Flutter tại lần kiểm định trước | ✅ **152 pass / 0 fail / 2 skip** |

> **Đã sửa trong các đợt này:** FAB Planner chồng thanh điều hướng; fallback ngoại tuyến cho AI Planner; layout bàn phím AI Tutor; 4 test cũ tìm "AI trực tuyến"; CORS gateway cấu hình được. Test mới: `planner_screen_test`, `planner_offline_fallback_test`, `planner_goal_test`, `ai_tutor_ux_test`; gateway **7/7** pass.

### 5.2. Lỗi/hạn chế theo mức độ

**🔴 Chặn phát hành hoặc chặn tính năng chính**

1. APK ký **Android Debug** — không thể phát hành chính thức.
2. AI phụ thuộc **Supabase login + gateway riêng**; host mặc định là Tailscale nội bộ (CORS cấu hình được qua `ALLOWED_ORIGINS`; preview local dùng proxy `/mochi-ai` của `preview.py`).
3. Không có **backend push/cron**; nhắc học khi app đóng không đảm bảo.
4. Chưa có **QA thiết bị thật cho build 2047**.

**🟠 Lỗi/hạn chế đã biết**

5. Giao thông báo nền/đồng hồ không ổn định theo hãng máy; force-stop dừng alarm; chưa khôi phục sau reboot.
6. Đồng bộ hai thiết bị sửa cùng lúc: giữ xung đột, không tự giải quyết; chưa nghiệm thu đầy đủ.
7. Kinh tế sao/XP không có xác thực server.
8. Không có quên/đổi mật khẩu; phụ thuộc SMTP/redirect URL của Supabase.
9. Không streaming câu trả lời AI; mỗi lượt chờ tới 30 giây/model (có nút Huỷ).

**🟡 Rủi ro / cần kiểm chứng**

11. AI có thể trả lời sai, đặc biệt công thức/bài giải; quiz/đáp án chưa xác minh độc lập (UI đã có ghi chú kiểm chứng).
12. Kế hoạch AI không phải lúc nào cũng khớp mọi xung đột lịch; người dùng phải xem trước.
13. Hạn mức AI trong RAM, reset khi restart, không phù hợp nhiều instance.
14. `/health` chỉ báo gateway đang sống, không xác nhận Gemini API key hoặc quota còn dùng được.
15. Chat AI Tutor chỉ gửi 12 tin gần nhất và cắt tin > 6.000 ký tự để kiểm soát chi phí.
16. SharedPreferences JSON có thể phình to khi dữ liệu học nhiều.
17. Migration Supabase không chạy lặp an toàn.
18. 120 issue analyze (lint/deprecated), dễ che lỗi mới.
19. Breakpoint 768px cứng; tablet dọc có thể chật (riêng Planner đã nâng lên 900px).
20. Đã bổ sung tìm kiếm/lọc flashcard trong bản mã nguồn cập nhật 15/11/2026.
21. Onboarding tự điền dữ liệu mẫu, không có nút bỏ qua.

---

## 6. Bằng chứng kiểm định

| Hạng mục | Kết quả | Ghi chú |
|---|---|---|
| Build Web | ✅ | Flutter 3.47.4 / Dart 3.13.3, `--base-href /mochi/` |
| Build APK | ✅ | 67.851.699 byte, đa kiến trúc |
| Chữ ký APK | ⚠️ | Hợp lệ v1/v2/v3 nhưng là **Android Debug** |
| Flutter test | **152 pass / 0 fail / 2 skip** | Không còn test trượt |
| Flutter analyze | 120 issue, 0 error | Chủ yếu `curly_braces...`, deprecated, `use_build_context_synchronously` |
| Gateway test | **7/7 pass** | Rate limit, JWT, proxy chat, CORS cấu hình được, chặn ảnh URL lạ, không lộ lỗi provider |
| Web smoke (Playwright) | ✅ | Desktop 1440×1000, mobile 390×844; HTTP 200; first frame; 0 lỗi console/tài nguyên |
| QA thiết bị thật bản 2047 | ❌ | Không có trong gói; các kết quả Honor là build cũ (2016–2022) |

---

## 7. Cách chạy thử nhanh

### 7.1. Web

```powershell
# Bản đóng gói (chỉ xem giao diện; AI có thể bị CORS trên origin local)
python 05-operations/preview.py
# mở http://127.0.0.1:8500/mochi/
# slide: http://127.0.0.1:8500/presentation/
```

```powershell
# Bản dev mới nhất, AI chạy được trên local qua proxy /mochi-ai
cd 02-source/flutter-app
flutter build web --base-href /
cd ../..
python 05-operations/preview.py --port 8600 --web-root 02-source/flutter-app/build/web
# mở http://127.0.0.1:8600/ rồi Ctrl+F5
```

> `preview.py` chuyển tiếp `/mochi-ai/*` sang gateway server-side (không gửi `Origin`),
> nên trình duyệt không gặp CORS. App tự dùng đường dẫn cùng origin khi chạy trên
> `127.0.0.1`/`localhost`; bản deploy vẫn dùng gateway tuyệt đối.
> Trên bản đóng gói tại `/mochi/`, AI chỉ hoạt động nếu origin local được thêm vào
> `ALLOWED_ORIGINS` của gateway (xem `03-documentation/03-CAU-HINH-DICH-VU.md`).

### 7.2. Android

```powershell
adb install -r 01-release/android/Mochii-1.4.10-2047.apk
```

- Cấp quyền thông báo khi được hỏi.
- Vào **Tôi → Cài đặt → Cho phép báo thức chính xác** để nhắc sát giờ.
- Nếu cài đè bản cũ bị xung đột chữ ký: **không gỡ app trước khi sao lưu dữ liệu**.

### 7.3. Gateway AI (nếu muốn AI hoạt động)

```sh
cd 02-source/ai-gateway
cp .env.example /etc/mochii/gateway.env   # điền Supabase và GEMINI_API_KEY
node --env-file=/etc/mochii/gateway.env server.mjs
```

Để test APK nội bộ trên Windows mà không cần domain riêng, làm theo [`05-operations/HUONG-DAN-TEST-AI-APK.md`](05-operations/HUONG-DAN-TEST-AI-APK.md): chạy gateway local, mở HTTPS tạm bằng Cloudflare Quick Tunnel và truyền URL tunnel vào `MOCHI_AI_GATEWAY` khi chạy/build Flutter.

Để chạy lâu dài hoặc chia sẻ ra ngoài mạng nội bộ:
1. Deploy gateway sau Nginx/TLS (mẫu trong `05-operations`).
2. Build lại **cả Web và APK** với:
   ```sh
   --dart-define=MOCHI_AI_GATEWAY=https://domain-cua-ban/mochi-ai
   ```

---

## 8. Kết luận & ưu tiên xử lý

**Đây là một prototype/bản demo chạy được, khá đầy đủ về nghiệp vụ, nhưng chưa phải bản production.**

**Điểm mạnh**
- Vòng lặp học khép kín: mục tiêu → lịch → phiên học → ôn tập.
- Nghiệp vụ lịch/ôn tập được test khá kỹ: ngân sách, không chồng lấn, chia nhiều ngày, SM-2, nhắc học 2/ngày.
- Offline-first; dữ liệu học vẫn dùng được khi mất mạng.
- AI đặt sau gateway có kiểm JWT; app không giữ Gemini API key.
- Giao diện responsive, có tùy chọn tương phản cao/giảm chuyển động.

**Điểm yếu chặn phát hành**
1. APK ký debug.
2. AI phụ thuộc Supabase login + gateway Tailscale (CORS nay cấu hình được qua `ALLOWED_ORIGINS`).
3. Không có backend push; chưa QA thiết bị cho build 2047.
4. Đồng bộ đa thiết bị chưa nghiệm thu xung đột.
5. Chưa có keystore/tài khoản cloud — phải chuyển giao ngoài gói.

**Thứ tự ưu tiên nếu tiếp nhận**

| Ưu tiên | Việc cần làm | Tệp/hạng mục |
|---|---|---|
| 1 | Cấu hình `ALLOWED_ORIGINS` + `MOCHI_AI_GATEWAY` theo môi trường; deploy gateway mới | `ai-gateway/server.mjs`, `.env.example`, `05-operations` |
| 2 | Build lại Web + APK với gateway mới | `05-operations/build-release.sh` |
| 3 | Tạo release keystore, ký lại APK | `android/app/build.gradle.kts` |
| 4 | QA ít nhất 3 hãng máy: thông báo, báo thức, bàn phím AI Tutor, force-stop, đổi múi giờ | Thiết bị thật |
| 5 | Kiểm thử đồng bộ 2 thiết bị + chạy migration Supabase trên môi trường test | `supabase/migrations` |
| 6 | Quyết định có làm backend push/cron hay không | Ngoài gói |
| 7 | Cân nhắc streaming AI (SSE) nếu cần trải nghiệm chờ ngắn hơn | `ai_service.dart`, gateway |
| 8 | Dọn 120 issue analyze và các trường dữ liệu di sản | Toàn source |

---

*Tài liệu này chỉ mô tả hiện trạng gói bàn giao. Các tuyên bố trong slide/nghiên cứu gốc là tài liệu lịch sử, không phải chứng nhận nghiệm thu cho build 2047.*

### Bộ theme và Glass Components dùng chung (15/11/2026)

- Token trong `02-source/flutter-app/lib/core/theme/`: `app_theme.dart`, `color_constant.dart`, `spacing_constant.dart`, `typography_constant.dart`, `app_radius.dart`.
- `app_background.dart`: màu nền, gradient hoặc ImageProvider độc lập với màu chủ đạo; có nền dự phòng khi ảnh lỗi. Chưa có UI chọn/lưu ảnh nền.
- Components trong `lib/shared/widgets/glass/`, import qua `glass_components.dart`: surface/card, button/icon button, header, tìm kiếm, filter, section/list tile, bottom bar, dialog, scaffold.
- Ôn tập đã dùng bộ chung qua adapter `ReviewGlass`; các tab cũ chưa được chuyển toàn bộ. Màu chủ đạo vẫn lấy từ lựa chọn trong tab Tôi.
- Tài liệu API và ví dụ tích hợp: [Glass design system](02-source/flutter-app/docs/glass-design-system.md).

- **Bổ sung shared components:** GlassNavigationBar, GlassFloatingActionButton, showNativeBottomSheet, AnimatedSwitch/GlassSwitchTile, GlassContainer, CustomPageTransition; thêm checkbox, slider, tab bar, menu, snackbar và trạng thái loading/empty/badge. Ví dụ tương tác độc lập: `02-source/flutter-app/examples/glass_components.dart`.
- Ôn tập dùng transition/loading/search/filter chung và đọc reducedMotion/highContrast từ hồ sơ. Chưa thay đồng loạt navigation/FAB/sheet cũ ở các tab khác.

### Design System Pastel — bản đánh giá trong tab Ôn tập (15/11/2026)

- Bộ thay thế độc lập trong `lib/design/pastel/`, giữ Inter và tài nguyên minh họa hiện có; áp dụng trước vào trang Ôn tập, phiên ôn, quiz và kết quả. Các tab khác, thanh 5 tab và màn Quản lý kiến thức chưa chuyển đổi.
- Thẻ gradient bo tròn, viền sáng, bóng nhẹ, nút viên thuốc, nền pastel và chế độ sáng/tối/hệ thống.
- Nút bảng màu ở đầu tab Ôn tập cho chọn 6 màu chủ đạo và 6 nền có sẵn (4 gradient, 2 đơn sắc). Nền được lưu vào `ProfileModel.backgroundPreset`, độc lập với màu chủ đạo.
- Kiểm tra: 23 test theme/layout/hành trình/khả năng phục hồi và 4 test khung ứng dụng/điều hướng đạt; build Web thành công. Chưa kiểm thử trên thiết bị Android thật cho thay đổi này.
- Chi tiết API, phạm vi và ảnh render: [Pastel Design System](02-source/flutter-app/docs/pastel-design-system.md).

### Pastel đã áp dụng toàn bộ màn hình (15/11/2026)

- Đã chuyển toàn bộ màn hình hiện có, kể cả đăng nhập/onboarding, đồng hồ tập trung, cửa hàng, lịch sinh hoạt, Learning Hub, thư viện, sheet AI và màn tải. Giữ tính năng, 5 tab, Inter và tài nguyên robot/minh họa.
- **Tôi → Cài đặt & Tùy chọn → Cá nhân hóa không gian học → Màu nền & gradient** là nơi chọn nền; nút tùy chỉnh giao diện Ôn tập đã bị gỡ. Màu chủ đạo/nền/chế độ sáng tối áp dụng toàn ứng dụng và các route được mở thêm.
- Đã xóa hai theme cũ trong `lib/core/theme/` và panel/scope tùy chỉnh riêng của Ôn tập. Các API component dùng chung lấy màu từ Pastel.
- Kiểm tra: **226 pass / 2 skip**, 15 màn hình ở sáng/tối, thêm responsive 320 px với chữ 170% và desktop 1366 px. Analyzer: 0 error, 117 cảnh báo/lint; Web build thành công. Chưa QA thiết bị Android thật.
