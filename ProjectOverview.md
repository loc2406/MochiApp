# Mochii — Mô tả tổng quan dự án

> **Phiên bản:** 1.4.10, build 2047  
> **Ngày đóng gói bàn giao:** 04/11/2026  
> **Nền tảng:** Android (APK) + Web (Flutter)  
> **Tài liệu này được lập từ:** đọc toàn bộ source, tài liệu, slide, log build/analyze/test và báo cáo kiểm định trong gói bàn giao. Không phải biên bản QA thiết bị thật cho đúng build 2047.

---

## Mục lục

1. [Dự án là gì](#1-dự-án-là-gì)
2. [Bộ bàn giao gồm gì](#2-bộ-bàn-giao-gồm-gì)
3. [Kiến trúc & công nghệ](#3-kiến-trúc--công-nghệ)
4. [Bản đồ tính năng kèm giao diện và lỗi](#4-bản-đồ-tính-năng-kèm-giao-diện-và-lỗi)
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
| `02-source/flutter-app/` | Toàn bộ source Flutter, assets, 30 file test, migration Supabase, tài liệu gốc |
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

## 4. Bản đồ tính năng kèm giao diện và lỗi

### 4.0. Khung điều hướng & bố cục responsive

- **Tệp UI:** `lib/main.dart`
- **Giao diện:**
  - **Mobile (< 768px):** 5 tab trong "floating glass bar" nổi ở đáy: **Hôm nay · Kế hoạch · AI Tutor (nút tròn ở giữa) · Ôn tập · Tôi**. Thanh tự ẩn khi cuộn xuống và hiện lại sau ~900ms khi ngừng cuộn.
  - **Desktop/Web (≥ 768px):** sidebar trái cố định 260px, có logo MOCHI, thẻ người dùng, menu **Hôm nay / Kế hoạch học tập / AI Tutor trực tuyến / Ôn tập / Lịch học & Tôi**, thẻ chuỗi ngày học. Không có floating bar.
  - Nền `#F8FAFC`, chừa khoảng trống đáy bằng `FloatingBarInset` cho các trang cuộn.
- **Trạng thái:** ✅ (widget test "Bottom bar stays at bottom", "Floating bar returns after scrolling stops" đạt)
- **Lỗi đã sửa:**
  - ✅ **Nút "Thêm nhiệm vụ" của Planner từng chồng lên thanh điều hướng ~5,5px** (đáy nút 810,0 so với đỉnh thanh 804,5) do FAB không cộng `FloatingBarInset`. Nay FAB và padding danh sách đều cộng inset; test `navigation_hit_test` và `planner_screen_test` đạt.
- **Lỗi đang có:**
  - 🟡 Thanh điều hướng tự ẩn khi cuộn có thể gây khó chịu/nhầm nếu người dùng muốn đổi tab giữa lúc cuộn.
  - 🟡 Breakpoint cứng 768px; tablet dọc 768px chuyển sang sidebar desktop, có thể chật.

---

### 4.1. Onboarding (3 bước)

- **Tệp UI:** `lib/features/onboarding/onboarding_screen.dart`
- **Giao diện:**
  - Thanh tiến trình 3 đoạn màu tím ở trên cùng, không có nút thoát.
  - **Bước 1:** robot mascot, tiêu đề "Chào mừng bạn đến với Mochi!", ô nhập tên/biệt danh, chip chọn cấp học (Tiểu học, THCS, THPT, Đại học, Tự học).
  - **Bước 2:** tiêu đề "Mục tiêu học tập lớn của bạn", ô mục tiêu, chip chọn môn trọng tâm (Toán, Lý, Hóa, Anh, Văn, Tin, Sinh).
  - **Bước 3:** "Tùy chỉnh người bạn Robot" — ô tên robot, dãy chấm màu chủ đạo, preview mascot.
  - Nút **Quay lại** (bước 2–3) và **Tiếp tục / Bắt đầu hành trình cùng Mochi** ở đáy.
- **Trạng thái:** ✅ (test `mochi_unit_test` xác nhận onboarding tạo tên + mục tiêu)
- **Lỗi đang có:**
  - 🟡 Không có nút "Bỏ qua"; người dùng buộc đi hết 3 bước (chế độ khách chỉ có ở màn đăng nhập).
  - 🟡 Nếu để trống, app tự điền tên **"Bạn nhỏ"** và mục tiêu **"Chinh phục kỳ thi học kỳ"**; người dùng có thể không nhận ra dữ liệu mẫu.
  - 🟡 Onboarding **không gọi AI**; chỉ tạo 1 mục tiêu 30 ngày + 2 nhiệm vụ mẫu. Việc chia nhỏ mục tiêu bằng AI phải làm thủ công sau đó ở Planner.
  - 🟡 Chưa có test/QA cho trường hợp nhập ký tự đặc biệt, tên rỗng sau khi xóa, hoặc xoay ngang màn hình.

---

### 4.2. Tab "Hôm nay"

- **Tệp UI:** `lib/features/today/today_screen.dart`
- **Giao diện:**
  - **AppBar nền đậm, chữ trắng:** avatar robot, "Chào <tên>!", "Học cùng <robot>", pill chuỗi ngày (ngọn lửa + "N ngày").
  - **Thẻ hero:** robot mascot lớn, câu động viên theo trạng thái, các chỉ số **XP**, **phút học**, chip **Cửa hàng**.
  - **Thẻ "Tiến độ nhiệm vụ":** thanh tiến độ + số đã hoàn thành.
  - **Danh sách nhiệm vụ hôm nay:** card có checkbox, tên, môn, thời lượng, nút **Học ngay**.
  - **Mục "Đã hoàn thành"** và trạng thái rỗng "Chưa có bài tập nào hôm nay".
  - **FAB mở rộng "Thêm nhiệm vụ mới"**.
  - **Thẻ "Gặp bài tập khó?"** với nút **Hỏi AI** mở AI Tutor dạng sheet.
- **Trạng thái:** ✅ (test `navigation_hit_test`: checkbox nhận chạm; test `widget_test` app load)
- **Lỗi đang có:**
  - ⚪ Không có lỗi riêng được ghi nhận.
  - 🟡 Trên Web, chuông/thông báo không hoạt động, nên "Học ngay" chỉ mở đồng hồ trên tab, không có nhắc nền.
  - 🟡 Nếu dữ liệu đồng bộ về muộn, danh sách có thể nhảy thứ tự/đổi trạng thái ngay trước mắt người dùng (poll 15 giây).
  - 🟡 Chuỗi ngày (streak) và XP là phản hồi trong app, không phải thước đo năng lực; có thể sai nếu người dùng chỉnh JSON backup.

---

### 4.3. Tab "Kế hoạch" (Planner)

- **Tệp UI:** `lib/features/planner/planner_screen.dart`
- **Giao diện (sau khi sửa):**
  - **AppBar:** "Kế hoạch học tập", icon lịch chung (mở Learning Hub).
  - **TabBar 2 tab:** **Nhiệm vụ & Bài tập** / **Mục tiêu lớn** (nhãn tab tự co giãn, không tràn ở màn hẹp).
  - **Tab nhiệm vụ:** card từng nhiệm vụ (checkbox, tên, chip ngày · giờ, môn, thời lượng, nút xóa), trạng thái rỗng có icon + hướng dẫn.
  - **Tab mục tiêu:** card mục tiêu (hạn, chip môn, thanh tiến độ `x / y nhiệm vụ`), nút **AI chia nhỏ việc**.
  - **FAB mở rộng:** "Thêm nhiệm vụ" hoặc "Thêm mục tiêu" tùy tab; **cộng `FloatingBarInset`** nên luôn nằm trên thanh điều hướng.
  - **Dialog thêm nhiệm vụ:** tên, môn (dropdown dùng chung), thời lượng (phút), lỗi nhập liệu ngay trong dialog.
  - **Dialog thêm mục tiêu:** tên, **môn trọng tâm**, chọn ngày hạn; môn được lưu vào `GoalModel.subject` và dùng cho AI + nhiệm vụ con.
  - **Bottom sheet xem trước kế hoạch:** "Kế hoạch đề xuất", dải ngày, số nhiệm vụ, banner **kế hoạch mẫu ngoại tuyến** khi AI không phản hồi, nhắc "chưa được lưu, hãy kiểm tra", nút **Bỏ qua** và **Áp dụng & Nhắc nhở** (đổi thành **Áp dụng kế hoạch mẫu** ở chế độ ngoại tuyến).
  - **Dialog xóa:** nêu rõ hậu quả không thể hoàn tác và **số nhiệm vụ con** sẽ mất khi xóa mục tiêu.
  - **Layout rộng (≥ 900px):** hai cột mục tiêu/nhiệm vụ, không dùng FAB; **< 900px:** tab + FAB.
- **Trạng thái:** ✅ các lỗi trong danh sách bên dưới đã sửa và có test; ⚠️ chất lượng nội dung AI vẫn phụ thuộc đăng nhập + gateway.
- **Lỗi đã sửa:**
  - ✅ **FAB "Thêm nhiệm vụ" chồng thanh điều hướng** — FAB và padding danh sách cộng `FloatingBarInset`; test `navigation_hit_test` và `planner_screen_test` đạt.
  - ✅ **"AI chia nhỏ việc" không có fallback offline** — khi chưa đăng nhập/mất mạng/gateway lỗi, `AIService.breakDownGoalIntoTasks` trả **kế hoạch mẫu gắn nhãn `offline_template`** (không gọi là AI), vẫn qua bộ xếp lịch ràng buộc và giới hạn theo `dailyMinutes`; test `planner_offline_fallback_test` đạt.
  - ✅ **Dễ hiểu nhầm kế hoạch đã được xếp** — sheet xem trước ghi rõ "Đây là đề xuất chưa được lưu", hiển thị dải ngày và số nhiệm vụ trước khi áp dụng.
  - ✅ **Xóa mục tiêu không rõ hậu quả** — `deleteGoal()` vốn đã xóa nhiệm vụ con; dialog nay nêu số nhiệm vụ con sẽ bị xóa; test `planner_goal_test` đạt.
  - ✅ **"Áp dụng & Nhắc nhở" phụ thuộc quyền thông báo** — kế hoạch vẫn được lưu; snackbar báo rõ nhắc chưa đặt (kèm **Mở cài đặt** trên Android) hoặc bản Web không có nhắc thiết bị.
- **Còn lại (không chặn):**
  - 🟡 Chất lượng nội dung AI vẫn phụ thuộc model/gateway; kế hoạch mẫu ngoại tuyến chỉ là quy tắc cố định, không cá nhân hoá sâu.
  - 🟡 Chưa có kiểm thử thiết bị thật cho luồng xin quyền thông báo và mở cài đặt hệ thống.

---

### 4.4. Tab "AI Tutor"

- **Tệp UI:** `lib/features/ai_tutor/ai_tutor_screen.dart`, `ai_tutor_sheet.dart`, `widgets/tutor_quiz_card.dart`, `widgets/schedule_change_card.dart`
- **Giao diện (sau khi sửa):**
  - **AppBar gradient:** avatar robot, tiêu đề "Học cùng <robot>", phụ đề "Cùng hiểu bài, từng chút một".
  - **Dải chip gợi ý nhanh** ở đầu danh sách (4 câu hỏi mẫu), cùng bề rộng nội dung với ô soạn tin.
  - **Danh sách tin nhắn:** bubble người dùng (nền đậm, phải) / trợ lý (nền trắng, trái), render Markdown + công thức LaTeX; nội dung giới hạn 720px và canh giữa trên màn rộng.
  - **Composer nổi:** nút gửi ảnh đề bài (camera/thư viện), ô "Hỏi Mochi…", nút gửi; cùng giới hạn 720px.
  - **Trạng thái đang trả lời:** pill "Mình đang xem câu hỏi của bạn…" kèm nút **Huỷ**; phản hồi về muộn bị bỏ qua.
  - **Cuối câu trả lời AI:** ghi chú "AI có thể sai. Hãy kiểm chứng với SGK hoặc giáo viên…"; nếu câu trả lời bị cắt do giới hạn độ dài, hiện thông báo + nút **Viết tiếp**.
  - **Thẻ quiz trắc nghiệm** hiện inline (câu x/y, 4 lựa chọn, giải thích sau khi chọn, ghi chú đáp án do AI tạo chưa xác minh).
  - **Thẻ "Đề xuất dời lịch"** hiện inline (trước/sau, nút xác nhận).
  - **Lỗi:** khối "Chưa kết nối được AI" kèm lý do cụ thể (mất mạng, hết hạn đăng nhập, bị chặn origin, hạn mức, máy chủ lỗi…). Chỉ hiện **Thử lại** với lỗi tạm thời; lỗi phiên hiện **Đăng nhập lại**; lỗi cấu hình/origin chỉ giải thích cách xử lý.
  - **Chưa đăng nhập:** câu giải thích + nút **Đăng nhập ngay** chuyển thẳng sang mục Tôi.
  - **Dạng sheet:** mở từ phiên học/Hôm nay, không có thanh điều hướng; sheet tự nhường chỗ bàn phím một lần.
- **Trạng thái:** ✅ các lỗi UI trong danh sách đã sửa và có test; ⚠️ chất lượng câu trả lời vẫn phụ thuộc model/gateway.
- **Lỗi đã sửa:**
  - ✅ **Layout bàn phím** — `Scaffold` con co giãn body và xoá `viewInsets` khỏi context bên trong, nên code cũ tưởng bàn phím đóng và cộng thêm `barInset` (~88px). Nay inset được đọc ở context phía trên, `resizeToAvoidBottomInset: false`, và sheet xoá inset trùng; test `keyboard_layout_regression_test` đạt (tâm nút Gửi ~506 khi bàn phím mở).
  - ✅ **4 test cũ tìm "AI trực tuyến"** — đã cập nhật theo tiêu đề "Học cùng <robot>"; cả 4 test `ai_tutor_screen_test` đạt.
  - ✅ **Ngõ cụt khi chưa đăng nhập** — giữ yêu cầu đăng nhập (gateway xác thực JWT) nhưng thêm nút **Đăng nhập ngay** chuyển sang mục Tôi, thay vì chỉ một câu văn.
  - ✅ **CORS hardcode** — gateway đọc `ALLOWED_ORIGINS` (mặc định vẫn chỉ origin production, echo đúng origin được phép); preview local dùng được ngay nhờ `preview.py` chuyển tiếp `/mochi-ai/*` phía server và app tự chọn gateway cùng origin khi host là loopback. Có test gateway.
  - ✅ **Không rõ khi câu trả lời bị cắt** — hiện thông báo và nút **Viết tiếp**; cờ `truncated` đã được dùng thực sự.
  - ✅ **Chờ quá lâu** — timeout mỗi model 30 giây (trước 15), có nút **Huỷ** và bỏ qua phản hồi về muộn.
  - ✅ **AI có thể sai** — ghi chú kiểm chứng dưới mọi câu trả lời AI và trong thẻ quiz.
  - ✅ **Nút camera Gemini thử nghiệm** — đã bỏ khỏi AI Tutor; bridge vẫn còn trong mã cho mục 4.14.
  - ✅ **"Chưa kết nối được AI" chung chung sau khi đăng nhập** — service phân loại lỗi gateway (401 `session_expired`, 403 `origin_denied`, 429 `capacity`, 5xx `upstream`, timeout, mạng) và trả `reason`; UI hiện đúng nguyên nhân, chỉ cho **Thử lại** khi lỗi tạm thời, lỗi phiên hiện **Đăng nhập lại**. Lỗi không tự khỏi (origin/cấu hình) không thử model thứ hai để tránh chờ vô ích. Có test 403/401/429.
- **Còn lại (không chặn):**
  - 🟠 Không streaming: vẫn chờ toàn bộ câu trả lời (đã có Huỷ/30 giây mỗi model).
  - 🟡 Chat lịch sử gửi lên model giới hạn 12 tin gần nhất và 6.000 ký tự/tin (giữ để kiểm soát chi phí).
  - 🟡 Chất lượng nội dung AI (công thức, đáp án quiz) chưa được xác minh độc lập; cần QA nội dung.

---

### 4.5. Tab "Ôn tập" (Review + Flashcards)

- **Tệp UI:** `lib/features/flashcards/review_screen.dart`, `flashcards_screen.dart`, `knowledge_explanation.dart`
- **Giao diện:**
  - **AppBar "Ôn tập"**, icon mở **Quản lý kiến thức**.
  - **Màn phiên ôn:** tiêu đề "Lượt ôn hôm nay · khoảng N phút", nút "Vì sao có lượt ôn này?" mở dialog lý do; dòng "Giờ ôn đã xếp: …".
  - **Thẻ lật:** "Tự nhớ trước khi lật", chạm để xem đáp án; nút **Xem giải thích** (AI bổ sung phần nghĩa/công thức/ví dụ).
  - **4 nút tự chấm:** **Quên / Còn khó / Nhớ / Rất chắc**.
  - **Quiz kiểm tra vận dụng:** câu hỏi, 4 đáp án, khóa đáp án đến khi chọn, giải thích, câu trước/câu tiếp.
  - **Dialog kết quả:** "Đã hoàn thành lượt ôn", đáp án AI, nút "Đến Quản lý kiến thức".
  - **Màn Quản lý kiến thức:** tiêu đề "Quản lý kiến thức", danh sách bộ thẻ (môn · số thẻ · số đến hạn), chạm bộ thẻ để học; tìm kiếm câu hỏi/đáp án/tên bộ thẻ, lọc môn và thẻ đến hạn; nút **AI tạo bộ thẻ**, **Tạo bộ thẻ mới** và **Thêm thẻ mới** trong từng bộ.
  - **Dialog AI tạo thẻ:** ô chủ đề + chip môn + trạng thái "đang chuẩn bị câu hỏi".
  - **Dialog sửa kiến thức:** câu hỏi + giải thích/công thức/ví dụ, cảnh báo "Sửa nội dung sẽ đưa thẻ về lịch ôn gần nhất".
- **Trạng thái:** ✅ SM-2, ôn offline, quản lý thẻ, quiz có đối chiếu nguồn; ⚠️ chưa nghiệm thu đồng bộ trên hai thiết bị thật
- **Lỗi đang có:**
  - ✅ **Ôn offline từ thẻ đã lưu:** tự dùng khi chưa đăng nhập hoặc gateway lỗi/timeout; giữ lịch ôn và mức tự nhớ, hoàn tất không cần quiz AI. Vẫn cần thẻ đến hạn và quỹ giờ phù hợp.
  - ✅ **Quiz AI có nhãn chưa xác minh**, đối chiếu thẻ nguồn và nút bỏ qua quiz còn lại. Sai quiz vẫn đưa thẻ về gần hơn, không tự đánh dấu "đã vững"; độ đúng học thuật chưa được xác minh độc lập.
  - ✅ **Giải thích có nội dung dự phòng:** hiện đáp án đã lưu ngay khi lật thẻ; AI lỗi/timeout không chặn tiếp tục ôn. Phiên offline dùng nội dung đã lưu.
  - ✅ **Kiểm tra phiên khi đồng bộ:** lưu nội dung nguồn, vô hiệu hóa phiên khi thẻ bị sửa/xóa, cập nhật tiến độ từ thiết bị khác. Đã kiểm thử tự động với hai store dùng cloud giả lập; chưa nghiệm thu trên hai thiết bị thật.
  - ✅ **Thư viện có tìm kiếm và bộ lọc:** tìm câu hỏi/đáp án/tên bộ thẻ/môn học, lọc môn và thẻ đến hạn; giới hạn chiều rộng nội dung, cho cuộn trên màn hình nhỏ.
  - ✅ **Giao diện Liquid Glass (15/11/2026):** tab Ôn tập và thư viện dùng chung nền chuyển sắc, lớp kính mờ, card bo tròn, nút dạng viên, màu chủ đạo lấy trực tiếp từ lựa chọn trong tab Tôi (`themePreset`); đồng nhất quiz, bộ lọc, ô nhập và dialog. Header Ôn tập là một khối kính nổi gộp tiêu đề/lời dẫn, có nút thư viện bên phải và co giãn theo cỡ chữ. Style được giới hạn trong luồng Ôn tập.

---

### 4.6. Tab "Tôi" (Hồ sơ & Lịch)

- **Tệp UI:** `lib/features/profile/profile_calendar_screen.dart`
- **Giao diện:**
  - **AppBar "Hành trình & Lịch học"**, icon **cửa hàng** và **cài đặt**.
  - **Thẻ hồ sơ:** avatar chữ cái, tên, cấp học + robot đồng hành, trạng thái đồng bộ (email/Đã đồng bộ/Chế độ khách), nút **Đăng xuất** hoặc **Đăng nhập đồng bộ**.
  - **Banner lỗi đồng bộ** màu đỏ nếu có xung đột/mất mạng.
  - **Tile "Hồ sơ học tập và lịch chung"** mở Learning Hub.
  - **Ba chỉ số:** Chuỗi kỷ lục, Tổng thời gian, Cửa hàng sao.
  - **Lịch tháng:** lưới ngày, chấm/màu đánh dấu ngày có hoạt động, chú thích "Có lịch học / Đã hoàn thành / Cấp độ lửa Streak".
  - **Bottom sheet ngày:** danh sách nhiệm vụ, giờ, môn, thời lượng, nút **đặt chuông**.
  - **"Nhật ký các phiên học gần đây":** ngày, số phút, tự đánh giá.
- **Trạng thái:** ✅ (hiển thị và điều hướng; đồng bộ có điều kiện)
- **Lỗi đang có:**
  - ⚪ Không có lỗi giao diện riêng được ghi nhận.
  - 🟠 **Banner lỗi đồng bộ** xuất hiện khi hai thiết bị sửa cùng dữ liệu; app giữ bản trên máy, **không tự giải quyết xung đột** — người dùng phải tự đối chiếu.
  - 🟠 **Đặt chuông cho ngày trong quá khứ** bị chặn với thông báo "Giờ đã qua, hãy chọn ngày trong tương lai"; trên Web nút này không có tác dụng thực (không có notification).
  - 🟡 Lịch tháng không có chế độ xem tuần/ngày; ngày có nhiều nhiệm vụ có thể khó đọc trên màn hình nhỏ.

---

### 4.7. Learning Hub (Hồ sơ học tập & lịch chung)

- **Tệp UI:** `lib/features/learning/learning_hub_screen.dart`
- **Giao diện:**
  - **AppBar + 3 tab:** **Tiến độ môn** / **Bài & lịch chung** / **Thời khóa biểu**.
  - **Tab Tiến độ môn:** nút sửa hồ sơ lớp/năm học/môn; card từng môn (ExpansionTile) hiện bộ sách + chủ đề; mỗi chủ đề có 3 chip tự đánh giá **Chưa học / Cần ôn / Tự đánh giá đã vững**.
  - **Tab Bài & lịch chung:** nút **Thêm bài / việc cần học**, **Xếp lịch chung**; dòng ngân sách toàn bộ môn; danh sách "Lịch đã áp dụng" (ngày · giờ · phút · môn, nút ▶ học phần); "Tất cả bài và nhiệm vụ".
  - **Dialog thêm việc:** việc cụ thể, môn, loại việc (Bài được giao / Chuẩn bị bài / Học phần mới / Ôn lại / Luyện mục tiêu / Luyện đề), tổng phút, hạn nộp, liên kết mục tiêu/chủ đề.
  - **Dialog xem trước lịch 7 ngày:** các block giờ, phần "Việc chưa được xếp / giữ nguyên", nút **Để sau** / **Áp dụng lịch**.
  - **Tab Thời khóa biểu:** nhập giờ lên lớp/học thêm theo tuần; **AI bóc tách TKB** từ văn bản hoặc ảnh (chọn ảnh/chụp ảnh), xem trước số tiết, **Lưu vào thời khóa biểu**.
- **Trạng thái:** ✅ logic xếp lịch (test 320→1366px, ngân sách, chia nhiều ngày, không chồng lấn); ⚠️ phần AI bóc TKB
- **Lỗi đang có:**
  - 🔴 **AI bóc tách thời khóa biểu cần đăng nhập + gateway.** Không đăng nhập hoặc mất mạng → báo lỗi, không có nhập tay thay thế trong cùng dialog (phải đóng và nhập từng tiết).
  - 🟠 Ảnh TKB gửi qua AI có thể bị giới hạn kích thước/8MB body; ảnh mờ cho kết quả sai, người dùng phải kiểm tra trước khi lưu.
  - 🟠 "Xếp lịch chung" là **xếp giờ theo ràng buộc**, không sinh nội dung bài học; nếu quỹ giờ kín, việc sẽ nằm ở "chưa được xếp" — dễ hiểu nhầm là lỗi.
  - 🟡 Hạn nộp/giờ lên lớp phụ thuộc người dùng nhập đúng; AI không tự đoán số tiết → giờ.
  - 🟡 Dữ liệu Learning Hub nằm trong JSON đồng bộ; file rất lớn có thể gây chậm/SharedPreferences phình to.

---

### 4.8. Lịch sinh hoạt cá nhân (Routine)

- **Tệp UI:** `lib/features/routine/routine_screen.dart`
- **Giao diện:**
  - **AppBar "Lịch sinh hoạt cá nhân"**.
  - **Mục "Lịch tuần":** 7 dòng (Thứ 2 → Chủ nhật), mỗi dòng hiện khung giờ học hoặc "Không có giờ học", nút sửa.
  - **Mục "Lịch riêng trong tháng":** nút chọn ngày, hiện "Lịch riêng d/m" hoặc "Không học", nút sửa.
  - **Dialog sửa ngày:** 2 ô **Giờ có thể học** và **Giờ bận cần loại trừ**, hướng dẫn "cách nhau bằng dấu phẩy", nút Hủy/Lưu; báo lỗi định dạng `HH:mm-HH:mm`.
- **Trạng thái:** ✅ (test ràng buộc lịch; dùng làm input cho Planner và Learning Hub)
- **Lỗi đang có:**
  - ⚪ Không có lỗi riêng được ghi nhận.
  - 🟡 Định dạng giờ rất chặt (`HH:mm-HH:mm`); nhập "19h30" hoặc "7:30" sẽ báo lỗi.
  - 🟡 Lịch riêng theo ngày ghi đè lịch tuần, nhưng UI không hiển thị rõ ngày nào đang bị ghi đè nếu có nhiều ngày.
  - 🟡 Nếu người dùng đổi múi giờ, cần mở lại app để tính lại nhắc (theo tài liệu).

---

### 4.9. Đồng hồ tập trung (Focus Timer)

- **Tệp UI:** `lib/features/focus/focus_timer_screen.dart`
- **Giao diện:**
  - Nền gradient tối, **pill chuyển chế độ:** **Pomodoro / Bấm giờ tự do**.
  - **Nút "Đặt thời lượng · N phút"** (hoặc "Đếm tiến") luôn hiện; mở dialog nhập 1–180 phút.
  - **Preset tự do:** Đếm tiến, 15p, 30p, 45p, 60p.
  - **Robot mascot** (đổi cảm xúc khi chạy), tên nhiệm vụ, nhãn "Phiên tập trung cao độ / Giờ nghỉ ngơi thư giãn".
  - **Vòng tròn đếm ngược** co giãn theo màn hình, nút bắt đầu/tạm dừng/kết thúc.
  - **Dialog hoàn thành:** "+N sao, +M XP", tự đánh giá mức tập trung 1–5, ô ghi chú, nút **Lưu vào nhật ký học tập**; phần **AI tổng kết phiên**.
  - Nút hỏi AI nhanh trong màn hình.
- **Trạng thái:** ✅ (test `timer_duration_test` ở 390×844, 320×568, 844×390; test phiên học ghi sao/XP/streak)
- **Lỗi đang có:**
  - 🟠 **Giao thông báo nền không ổn định.** Audit trên Honor ghi nhận alarm từng bị trì hoãn ~3 ngày; build sau qua được một lần nhưng chưa lặp lại được. Phụ thuộc chính sách pin/Doze của hãng.
  - 🟠 **Force-stop dừng alarm**; **chưa có khôi phục phiên đếm giờ sau khi khởi động lại máy**.
  - 🟡 **Chế độ "Đếm tiến" không có chuông kết thúc** — đúng thiết kế nhưng dễ bị hiểu là lỗi.
  - 🟡 Cần quyền thông báo + quyền báo thức chính xác để nhắc sát giờ; nếu thiếu, app dùng inexact và có thể trễ.
  - 🟡 Nếu AI tổng kết lỗi, người dùng vẫn lưu được phiên nhưng không có phần tổng kết.

---

### 4.10. Cửa hàng Robot (Robot Shop)

- **Tệp UI:** `lib/features/rewards/robot_shop_screen.dart`, `lib/features/robot/robot_mascot_widget.dart`
- **Giao diện:**
  - **AppBar "Robot Shop & Phụ kiện"**, góc phải hiện **số sao**.
  - **"Phòng thử đồ" nền tối:** robot mascot lớn đang mặc phụ kiện, tên robot, "Chuỗi hiện tại: N ngày liên tục", dãy chấm chọn màu.
  - **Chip danh mục:** Tất cả / Phụ kiện / Trang phục / Đặc biệt.
  - **Lưới vật phẩm:** ảnh/icon, tên, mô tả, giá sao hoặc "Cần chuỗi N ngày", nút **Mua / Nhận quà / Mặc ngay / Tháo ra**.
- **Trạng thái:** ✅ (test `mochi_unit_test`: mua trừ sao, mặc trang bị)
- **Lỗi đang có:**
  - ⚪ Không có lỗi riêng được ghi nhận.
  - 🟡 **Kinh tế sao/XP tính hoàn toàn phía client.** Người dùng sửa JSON backup hoặc dùng bản mod có thể thay đổi sao/vật phẩm; không có xác thực server.
  - 🟡 Một số vật phẩm khóa theo streak; streak có thể bị ảnh hưởng khi đồng bộ/đổi múi giờ.
  - 🟡 Không có xác nhận trước khi mua; bấm nhầm sẽ trừ sao ngay.

---

### 4.11. Cài đặt & Tùy chọn

- **Tệp UI:** `lib/features/settings/settings_screen.dart`, `personalization_card.dart`, `notification_settings_card.dart`, `smart_reminder_settings.dart`
- **Giao diện:**
  - **AppBar "Cài đặt & Tùy chọn"**, danh sách card cuộn dọc:
  - **Cá nhân hóa:** 6 sắc màu chủ đạo, đổi tên bạn đồng hành, phong cách trả lời (Thân thiện / Nghiêm túc / Truyền cảm hứng), độ sâu giải thích (Từng bước / Ngắn gọn).
  - **Thông báo:** trạng thái quyền, nút **Bật thông báo**, **Cài đặt Android**, trạng thái "Nhắc giờ: đã cấp quyền báo thức chính xác / Android có thể trì hoãn", nút **Cho phép báo thức chính xác**.
  - **Nhắc học thông minh:** công tắc tổng, công tắc **AI soạn lời nhắc**, trạng thái nguồn nội dung (AI/mẫu quy tắc), lời nhắc kế tiếp, nút **Soạn lại lời nhắc**.
  - **Lịch sinh hoạt:** tile mở Routine.
  - **Hiển thị & Tương tác:** Tương phản cao, Giảm chuyển động, Rung phản hồi.
  - **Sao lưu & Chuyển dữ liệu:** **Sao chép dữ liệu** (JSON vào clipboard), **Khôi phục** (dán JSON).
  - **Về ứng dụng:** tên app, phiên bản/build.
  - **Đặt lại dữ liệu:** dialog xác nhận "Xác nhận xóa".
- **Trạng thái:** ✅ (test `concise_settings_test`, `personalization_hub_test`, `notification_service_test`)
- **Lỗi đang có:**
  - 🟠 **Thông báo chỉ hỗ trợ Android.** Trên Web/iOS, card hiện "Nhắc học và báo hết giờ được hỗ trợ trong ứng dụng Android" — không phải lỗi nhưng là giới hạn lớn.
  - 🟠 **Khôi phục dữ liệu không có chọn file**, chỉ dán chuỗi JSON; JSON sai định dạng báo "Lỗi: Định dạng dữ liệu không hợp lệ!".
  - 🟠 **Đặt lại dữ liệu chỉ xóa trên máy**, không xóa bản trên Supabase; đăng nhập lại có thể kéo dữ liệu cũ về.
  - 🟡 Bật "Tương phản cao" có thể làm mất hiệu ứng blur/glass (đúng thiết kế) nhưng một số màn hình tối vẫn giữ chữ trắng — cần kiểm tra tương phản thực tế.
  - 🟡 Các nút âm thanh/rung chi tiết không có; phải chỉnh trong cài đặt Android.

---

### 4.12. Tài khoản & Đồng bộ đám mây

- **Tệp UI:** `lib/features/auth/auth_screen.dart`, `lib/features/profile/profile_calendar_screen.dart`, `lib/core/services/cloud_sync_service.dart`
- **Giao diện:**
  - **Màn đăng nhập/đăng ký:** tiêu đề "Đăng nhập tài khoản" / "Tạo tài khoản học tập", phụ đề, ô Email, ô Mật khẩu (tối thiểu 6 ký tự), nút chính **Đăng nhập ngay / Tạo tài khoản & Đồng bộ**, link chuyển chế độ, nút **"Bỏ qua & Dùng thử trực tiếp"**.
  - **Thông báo lỗi** dưới dạng text đỏ; thông báo "Kiểm tra email để xác nhận tài khoản…".
  - **Trạng thái trong hồ sơ:** email/Đã đồng bộ/Chế độ khách; nút đăng xuất.
  - **Banner lỗi đồng bộ** ở trang hồ sơ.
- **Trạng thái:** ⚠️ (đăng nhập/đồng bộ chạy khi dự án Supabase còn sống; xung đột chưa nghiệm thu)
- **Lỗi đang có:**
  - 🔴 **Phụ thuộc dự án Supabase hiện tại.** Gói không kèm quyền quản trị, SMTP, redirect URL hay dữ liệu; nếu dự án bị tạm dừng/xóa, đăng nhập và đồng bộ hỏng.
  - 🟠 **Không có chức năng quên mật khẩu / đổi mật khẩu** trong app.
  - 🟠 **Xung đột hai thiết bị không tự giải quyết.** App giữ bản trên máy và báo "Hai thiết bị đã sửa cùng dữ liệu…", người dùng phải tự đối chiếu.
  - 🟠 **Sửa đồng thời điện thoại + trình duyệt chưa được nghiệm thu đầy đủ** (theo `docs/acceptance-audit-20261102.md`).
  - 🟡 Đồng bộ poll mỗi 15 giây; có thể tốn pin/dữ liệu và tạo độ trễ khi hai thiết bị cùng mở.
  - 🟡 Đăng xuất không xóa cache tài khoản cũ ngay; dữ liệu vẫn nằm trên máy dưới khóa cache riêng.

---

### 4.13. Nhắc học thông minh

- **Tệp UI:** `lib/features/settings/smart_reminder_settings.dart`, `lib/core/services/smart_reminder_service.dart`, `notification_service.dart`
- **Giao diện:**
  - Nằm trong **Cài đặt**, card **"Nhắc học thông minh"**.
  - Mô tả: "Đến lịch, nhiệm vụ chưa xong và lâu chưa học hoặc mở app."
  - Công tắc tổng, công tắc **AI soạn lời nhắc**, dòng trạng thái "Nội dung: AI soạn, đã lưu trên máy" hoặc "mẫu theo quy tắc".
  - Hiển thị **"Lời nhắc tiếp theo: dd/MM HH:mm"**, nút **Soạn lại lời nhắc**.
  - Thông báo hệ thống Android hiển thị tiêu đề/nội dung đã lưu.
- **Trạng thái:** ✅ logic quy tắc (22 test `smart_reminder_test`); ⚠️ giao thông báo thực tế
- **Lỗi đang có:**
  - 🟠 **Giao thông báo phụ thuộc Android/Doze/chính sách pin.** Honor từng trì hoãn nhiều ngày; force-stop dừng nhắc.
  - 🟠 **Không có backend push.** FCM chỉ nhận; không có cron/server gửi nhắc tự động khi app đóng.
  - 🟠 **Chỉ Android.** Web/iOS không có nhắc.
  - 🟡 AI soạn lời nhắc cần đăng nhập + mạng; nếu lỗi, app dùng mẫu quy tắc (không gắn nhãn AI giả) — đúng thiết kế nhưng nội dung kém cá nhân hóa.
  - 🟡 Hạn mức 2 nhắc tự động/ngày, cách ≥3 giờ, không hẹn 22:00–08:00; nhiệm vụ quá hạn khi mở app bị lùi ≥2 giờ. Người dùng có thể thấy "không nhắc" dù đã bật.

---

### 4.14. Nhập phiên học trực tiếp (Live Import)

- **Tệp UI:** `lib/features/live_study/live_import_screen.dart`, `lib/core/services/live_bridge_service.dart`, `android/.../MainActivity.kt`, `tool/gemini_live_bridge.py`
- **Giao diện:**
  - **AppBar "Nhập phiên học"**.
  - Tiêu đề **"Phiên học trực tiếp"**, mô tả phiên đã kết thúc/chỉ có lời thoại, cảnh báo "Lịch sử đang lưu cục bộ trên thiết bị; chưa xác nhận đồng bộ đám mây."
  - **ExpansionTile "Xem lời thoại gốc"** (SelectableText).
  - Trạng thái **"Đang tạo bản ôn tập từ nội dung phiên…"**.
  - Kết quả: tiêu đề bộ thẻ, tóm tắt, danh sách **"Thẻ đề xuất — kiểm tra trước khi lưu"**, nút **Lưu bộ thẻ**, lời nhắc, nút **Nhắc ôn lại sau 24 giờ**.
  - Nút **Thử lại** khi lỗi.
- **Trạng thái:** ⚠️ thử nghiệm (parse/bridge có test; chưa QA thiết bị cho build 2047)
- **Lỗi đang có:**
  - 🔴 **Phụ thuộc công cụ ngoài:** cần app Gemini, ADB, `uiautomator2`, thiết bị được cho phép và đường dẫn máy cụ thể. Không phải API chính thức.
  - 🟠 **Lịch sử chỉ lưu cục bộ**, không đồng bộ đám mây.
  - 🟠 **Cần AI/gateway** để tạo bộ thẻ; nếu không đăng nhập/mất mạng, chỉ giữ được lời thoại.
  - 🟡 Nhận `ACTION_SEND` text/plain: nội dung chia sẻ từ app khác có thể là URL hoặc văn bản không phải transcript; app có chặn URL nhưng vẫn có thể tạo bộ thẻ kém chất lượng.
  - 🟡 Giới hạn 100.000 ký tự; bridge base64 tối đa 180.000 ký tự.
  - 🟡 Nút "Nhắc ôn lại sau 24 giờ" chỉ Android; có thể trễ do chính sách pin.

---

### 4.15. Các tính năng dùng chung (xuyên màn hình)

Các lỗi dưới đây ảnh hưởng nhiều tính năng, không thuộc riêng một màn hình:

| Lỗi | Mức | Ảnh hưởng | Chi tiết |
|---|---|---|---|
| **AI bắt buộc đăng nhập** | 🔴 | AI Tutor, quiz, tạo thẻ, ôn tập AI, chia mục tiêu, bóc TKB, tổng kết phiên, nhắc AI | `AIGatewayClient.send` ném `AIAuthenticationRequired` nếu không có access token Supabase |
| **CORS gateway hardcode** | 🔴 | Toàn bộ AI trên Web | `server.mjs`: `const origin = 'https://bendocs.tailc1f51b.ts.net'`; origin khác → 403 |
| **Gateway mặc định là host Tailscale riêng** | 🔴 | Toàn bộ AI | `https://bendocs.tailc1f51b.ts.net/mochi-ai`; người nhận không có tailnet không gọi được |
| **Hạn mức AI trong RAM** | 🟠 | AI | 200/ngày/user, 20/phút/user, 1.000/ngày toàn hệ, 6 đồng thời; reset khi restart |
| **APK ký debug** | 🔴 | Phát hành | Không thể đưa lên store; không cập nhật đè bản ký release khác |
| **Không có backend push** | 🟠 | Nhắc học/FCM | Chỉ có client nhận; không có cron/server gửi |
| **Web thiếu tính năng native** | 🟠 | Web | Không thông báo, không FCM, không chia sẻ/nhập phiên, không bridge camera |
| **`flutter analyze` 120 issue** | 🟡 | Bảo trì | Chủ yếu lint/deprecated; 0 error, không chặn build |
| **Migration SQL không idempotent** | 🟡 | Supabase | `create policy account_read` không có `drop policy if exists`; chạy lại lỗi |
| **Trường dữ liệu di sản** | 🟡 | Mã nguồn | `companions`, `parentPerms`, `teacherPerms` không có UI |

---

## 5. Tổng hợp lỗi & rủi ro

### 5.1. Lỗi test tự động đang trượt (0/152)

| # | Test | Kết quả |
|---|---|---|
| — | Toàn bộ suite Flutter | ✅ **152 pass / 0 fail / 2 skip** |

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
7. Live bridge thử nghiệm, phụ thuộc ADB/Gemini/uiautomator2.
8. Kinh tế sao/XP không có xác thực server.
9. Không có quên/đổi mật khẩu; phụ thuộc SMTP/redirect URL của Supabase.
10. "Đặt lại dữ liệu" chỉ xóa local, không xóa cloud.
11. Không streaming câu trả lời AI; mỗi lượt chờ tới 30 giây/model (có nút Huỷ).

**🟡 Rủi ro / cần kiểm chứng**

12. AI có thể trả lời sai, đặc biệt công thức/bài giải; quiz/đáp án chưa xác minh độc lập (UI đã có ghi chú kiểm chứng).
13. Kế hoạch AI không phải lúc nào cũng khớp mọi xung đột lịch; người dùng phải xem trước.
14. Hạn mức AI trong RAM, reset khi restart, không phù hợp nhiều instance.
15. `/health` chỉ báo gateway đang sống, không xác nhận Gemini API key hoặc quota còn dùng được.
16. Chat AI Tutor chỉ gửi 12 tin gần nhất và cắt tin > 6.000 ký tự để kiểm soát chi phí.
17. SharedPreferences JSON có thể phình to khi dữ liệu học nhiều.
18. Migration Supabase không chạy lặp an toàn.
19. 120 issue analyze (lint/deprecated), dễ che lỗi mới.
20. Breakpoint 768px cứng; tablet dọc có thể chật (riêng Planner đã nâng lên 900px).
21. Đã bổ sung tìm kiếm/lọc flashcard trong bản mã nguồn cập nhật 15/11/2026.
22. Onboarding tự điền dữ liệu mẫu, không có nút bỏ qua.

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
