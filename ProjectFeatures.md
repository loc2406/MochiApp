# Mochii — Tổng hợp tính năng & luồng hoạt động

> **Phiên bản source:** 1.4.10 (build 2047) · **Rà soát:** 18/11/2026
> **Phạm vi:** toàn bộ app Flutter trong `02-source/flutter-app/lib`
> **Cách lập:** đọc trực tiếp mã nguồn, đối chiếu `ProjectOverview.md`, `docs/SMART_REMINDERS.md` và bộ test hiện có.
> **Lưu ý:** đây là mô tả hành vi theo mã nguồn, **không phải** biên bản QA trên thiết bị thật. Các luồng phụ thuộc Android (báo thức chính xác, kênh thông báo, quyền hệ thống) và phụ thuộc máy chủ (Supabase, AI gateway) cần được kiểm chứng lại trên môi trường tương ứng.

---

## Mục lục

- [0. Cách đọc tài liệu](#0-cách-đọc-tài-liệu)
- [1. Luồng hoạt động từ lúc mở app](#1-luồng-hoạt-động-từ-lúc-mở-app)
- [2. Onboarding lần đầu](#2-onboarding-lần-đầu)
- [3. Khung điều hướng chính](#3-khung-điều-hướng-chính)
- [4. Tính năng chi tiết](#4-tính-năng-chi-tiết)
  - [4.1 Tab Hôm nay](#41-tab-hôm-nay)
  - [4.2 Tab Kế hoạch](#42-tab-kế-hoạch)
  - [4.3 Tab AI Tutor](#43-tab-ai-tutor)
  - [4.4 Tab Ôn tập](#44-tab-ôn-tập)
  - [4.5 Thư viện kiến thức (Flashcards)](#45-thư-viện-kiến-thức-flashcards)
  - [4.6 Tab Tôi (Hồ sơ & lịch)](#46-tab-tôi-hồ-sơ--lịch)
  - [4.7 Hồ sơ học tập & lịch chung](#47-hồ-sơ-học-tập--lịch-chung)
  - [4.8 Focus Timer (Pomodoro)](#48-focus-timer-pomodoro)
  - [4.9 Nhắc học thông minh](#49-nhắc-học-thông-minh)
  - [4.10 Cài đặt & Tùy chọn](#410-cài-đặt--tùy-chọn)
  - [4.11 Lịch sinh hoạt](#411-lịch-sinh-hoạt)
  - [4.12 Cửa hàng Mochi](#412-cửa-hàng-mochi)
  - [4.13 Tài khoản, đồng bộ & chia sẻ](#413-tài-khoản-đồng-bộ--chia-sẻ)
- [5. Ma trận trạng thái giao diện](#5-ma-trận-trạng-thái-giao-diện)
- [6. Lỗi, hạn chế & rủi ro](#6-lỗi-hạn-chế--rủi-ro)
- [7. Phụ lục](#7-phụ-lục)

---

## 0. Cách đọc tài liệu

### 0.1 Ký hiệu tình trạng

| Ký hiệu | Ý nghĩa |
|---|---|
| ✅ | Hoạt động đầy đủ theo mã nguồn, có xử lý rỗng và lỗi |
| ⚠️ | Hoạt động nhưng có lỗi/hạn chế đã biết (ghi rõ bên dưới) |
| 🟡 | Hoạt động một phần: cần mạng, cần đăng nhập, hoặc chỉ đúng trên Android |
| ⛔ | Chưa có trong source hoặc không dùng được |

### 0.2 Quy ước mô tả mỗi tính năng

Mỗi mục trong phần 4 gồm bốn phần cố định:

1. **Mô tả** — người dùng làm gì, hệ thống làm gì.
2. **Tình trạng** — mức hoạt động thực tế theo source.
3. **Lỗi đã biết** — lỗi còn mở, kèm vị trí file/dòng khi có.
4. **Ba trạng thái giao diện** — bảng *Có dữ liệu / Không có dữ liệu / Gặp lỗi*, ghi nguyên văn chữ và nút hiển thị.

### 0.3 Nguồn dữ liệu của app

- **Local-first:** toàn bộ hồ sơ, nhiệm vụ, môn học, thẻ, phiên học lưu trong `SharedPreferences` dưới dạng JSON (`mochi_store.dart`).
- **Cloud tuỳ chọn:** chỉ bật khi người dùng đăng nhập; đồng bộ qua Supabase (`cloud_sync_service.dart`).
- **AI:** gọi qua `ai_service.dart` → gateway; nếu lỗi hoặc chưa đăng nhập, app rơi về dữ liệu local hoặc báo lỗi trong UI.
- **Nhắc học:** tính và hẹn giờ **trên máy** (`smart_reminder_service.dart`), không có daemon AI chạy ngầm.

---

## 1. Luồng hoạt động từ lúc mở app

### 1.1 Sơ đồ tổng quát

```
main()
  │
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ Đăng ký handler FCM nền (Android)
  └─ runApp(MochiiBootstrap)
        │
        ├─ NotificationService().init()
        │     • khởi tạo plugin + timezone (một lần / process)
        │     • tạo kênh "Thông báo Mochii"
        │     • đọc tap notification lúc app còn đóng (cold start)
        │
        ├─ MochiStore().init()
        │     • đọc snapshot JSON từ SharedPreferences
        │     • isFirstTime = (tên hồ sơ rỗng)
        │
        ├─ (nền, không chặn UI) FCMService().init()
        └─ (nền, không chặn UI) SmartReminderService().start(store)
              │
              ▼
        FutureBuilder
          ├─ đang chờ  → MochiiLoadingScreen(status)
          ├─ lỗi       → MochiiLoadingScreen(failed: true, onRetry)
          └─ xong      → RootGate
                            ├─ isFirstTime  → OnboardingScreen
                            └─ ngược lại    → 5 tab + thanh điều hướng
```

### 1.2 Các bước theo thứ tự

| # | Bước | Xử lý | Thời điểm |
|---|---|---|---|
| 1 | Nạp Flutter | `WidgetsFlutterBinding.ensureInitialized()` | ngay |
| 2 | FCM nền | `FirebaseMessaging.onBackgroundMessage(...)` nếu nền tảng hỗ trợ | trước `runApp` |
| 3 | Màn chờ | Hiện ngay, chữ "Mochii đang chuẩn bị góc học tập…" | frame đầu |
| 4 | Thông báo | `NotificationService().init()` — idempotent, gọi nhiều lần vẫn chỉ khởi tạo một lần | chặn khởi động |
| 5 | Đổi trạng thái | "Đang mở dữ liệu học tập…" | sau bước 4 |
| 6 | Dữ liệu | `MochiStore().init()` đọc local snapshot; tính `isFirstTime` | chặn khởi động |
| 7 | FCM | `FCMService().init()` chạy nền, lỗi không chặn app | không chặn |
| 8 | Nhắc học | `SmartReminderService().start(store)` chạy nền, lỗi chỉ `debugPrint` | không chặn |
| 9 | Vào app | `RootGate` quyết định Onboarding hay 5 tab | sau bước 6 |

### 1.3 Trạng thái màn hình khởi động

| Trạng thái | Hiển thị |
|---|---|
| Đang chờ (bước 3) | Vòng loading + "Mochii đang chuẩn bị góc học tập…" |
| Đang đọc dữ liệu (bước 5) | "Đang mở dữ liệu học tập…" |
| Lỗi khởi động | Màn `failed` + "Chưa mở được ứng dụng. Bạn thử lại nhé." + nút thử lại |
| Bấm thử lại | Chữ đổi thành "Mochii đang thử mở lại ứng dụng…" và chạy lại toàn bộ chuỗi |

**Ghi chú kỹ thuật:**
- Không có splash tối thiểu, animation không quyết định việc sẵn sàng (`mochii_bootstrap.dart`).
- Lỗi ở FCM hoặc Smart Reminder **không** làm hỏng màn khởi động; app vẫn vào bình thường.
- Timezone của plugin thông báo chỉ được nạp một lần cho mỗi process (thay đổi P1), tránh parse lại toàn bộ tz database mỗi lần hẹn giờ.

### 1.4 Sau khởi động

- Nếu hồ sơ chưa có tên → **Onboarding** (mục 2).
- Nếu đã có hồ sơ → **5 tab** (mục 3).
- Chỉ khi đã qua Onboarding app mới xin quyền thông báo (thay đổi P1), nên hộp thoại hệ thống không đè lên màn chào lần đầu.
- Nếu người dùng mở app bằng cách chạm một lời nhắc đã hẹn, app chuyển thẳng sang tab **Kế hoạch** (thay đổi P2), áp dụng cho cả trường hợp app đang chạy và app bị đóng.

---

## 2. Onboarding lần đầu

**File:** `lib/features/onboarding/onboarding_screen.dart`

### 2.1 Mô tả

Ba bước, có thanh tiến độ 3 đoạn và nút "Tiếp tục" / "Bắt đầu hành trình cùng Mochi", nút "Quay lại" xuất hiện từ bước 2.

| Bước | Nội dung | Trường nhập | Mặc định khi bỏ trống |
|---|---|---|---|
| 1 | "Chào mừng bạn đến với Mochi!" | Tên/biệt danh; chip cấp học: Tiểu học, THCS, THPT, Đại học, Tự học | Tên → **"Bạn nhỏ"**; cấp học → **THCS** |
| 2 | "Mục tiêu học tập lớn của bạn" | Chip môn: Toán, Vật lý, Hóa học, Tiếng Anh, Ngữ văn, Tin học, Sinh học; ô mục tiêu cụ thể | Môn → **Toán**; mục tiêu → **"Chinh phục kỳ thi học kỳ"** |
| 3 | "Tùy chỉnh người bạn Robot" | Tên robot; bảng màu robot | Tên robot → **"Mochi"**; màu → xanh mint mặc định |

Bấm hoàn tất: lưu màu robot, tên người học, cấp học, tên robot, mục tiêu, môn tập trung → `MochiStore.completeOnboarding(...)` → `isFirstTime = false` → vào app.

### 2.2 Tình trạng

✅ Hoạt động. Dữ liệu ghi local ngay, không cần mạng.

### 2.3 Lỗi đã biết

- Không có validate nội dung: người dùng có thể giữ nguyên giá trị mặc định và đi tiếp.
- Nút "Tiếp tục" luôn bấm được; lỗi chỉ có thể xảy ra ở bước ghi dữ liệu và hiện không có UI báo lỗi riêng cho trường hợp này.
- Màn này không có trạng thái rỗng/lỗi riêng vì luôn có dữ liệu mặc định.

### 2.4 Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| Có dữ liệu | Giá trị đang nhập + chip được chọn (viền/nền accent) |
| Không có dữ liệu | Ô trống với placeholder: "Ví dụ: Minh Khang, Lan Anh...", "Ví dụ: Đạt điểm 9 môn Toán học kỳ này, Thuộc 300 từ vựng IELTS...", "Mochi, Pi, Bobo, Astra..." |
| Gặp lỗi | Không có UI lỗi; nếu ghi thất bại người dùng vẫn ở lại màn hình và có thể bấm lại |

---

## 3. Khung điều hướng chính

**File:** `lib/main.dart`

### 3.1 Mô tả

| Nền tảng / bề rộng | Điều hướng |
|---|---|
| Mobile (< 768) | Bottom bar 5 mục, ẩn/hiện theo thao tác cuộn |
| Desktop / tablet (≥ 768) | Sidebar dọc bên trái |

Năm mục theo thứ tự: **Hôm nay · Kế hoạch · AI Tutor · Ôn tập · Tôi**. Mục AI Tutor được làm nổi bật (prominent).

Sidebar hiển thị thêm: tên người dùng, trạng thái đồng bộ, "Chuỗi N ngày học".

### 3.2 Hành vi đáng chú ý

- Bottom bar tự ẩn khi cuộn xuống và hiện lại khi cuộn lên/dừng cuộn.
- Mọi màn con đều chừa khoảng trống cuối danh sách bằng `FloatingBarInset` để không bị thanh nổi che.
- Chạm lời nhắc đã hẹn → tab Kế hoạch (P2). Push thường chỉ mở app, không đổi tab.
- Đổi tab có rung nhẹ nếu người dùng bật "Rung phản hồi".

### 3.3 Tình trạng

✅ Hoạt động.

### 3.4 Lỗi đã biết

- Hiệu ứng ẩn/hiện bottom bar có test cũ fail do thay đổi bố cục (`navigation_hit_test.dart`), chưa phải lỗi người dùng thấy trên máy.
- Không có màn "không tìm thấy trang" vì điều hướng bằng index nội bộ.

### 3.5 Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| Có dữ liệu | 5 tab + nội dung tab đang chọn; sidebar có tên và chuỗi ngày |
| Không có dữ liệu | Vẫn hiện đủ 5 tab; từng tab tự hiện trạng thái rỗng của nó |
| Gặp lỗi | Không có lỗi cấp khung điều hướng; lỗi được xử lý trong từng tab |

---

## 4. Tính năng chi tiết

### 4.1 Tab Hôm nay

**File:** `lib/features/today/today_screen.dart`

#### Mô tả

Màn tổng hợp trong ngày, cuộn dọc, kéo xuống để làm mới (`store.init()`).

Thứ tự khối:

1. **Khối chào** — avatar robot, "Chào {tên}!" (fallback "Chào bạn!"), "Học cùng {tên robot}", chip lửa "{N} ngày".
2. **Thẻ hero robot** — 3 ô số liệu: **XP**, **Phút học**, **Cửa hàng → Robot** (chạm mở Cửa hàng Mochi).
3. **Thẻ tiến độ** — "Bạn đã hoàn thành {P}% nhiệm vụ hôm nay."
4. **Danh sách nhiệm vụ hôm nay** — header "Nhiệm vụ hôm nay" + nút "Xem tất cả" (sang tab Kế hoạch).
5. **Mục đã hoàn thành** — hiện riêng bên dưới danh sách đang làm.
6. **Banner AI Tutor** — mời hỏi Mochi.

Quy tắc chọn nhiệm vụ của ngày:
- Nếu nhiệm vụ có `scheduledDate` hợp lệ → hiện đúng ngày đó.
- Nếu không có ngày hợp lệ → hiện vào **ngày tạo**.

Mỗi dòng nhiệm vụ có checkbox; tick xong gọi `store.toggleTask` để cập nhật trạng thái, tiến độ ngày, cộng **+1 sao và +30 XP** (mỗi nhiệm vụ chỉ thưởng một lần), ghi hoạt động và cho robot biểu cảm ăn mừng.

#### Tình trạng

⚠️ Hoạt động, nhưng có lỗi tràn bố cục trên màn hẹp.

#### Lỗi đã biết

- **Tràn ngang header** tại `today_screen.dart:366`: `Row` chứa "Nhiệm vụ hôm nay" và nút "Xem tất cả" không có `Expanded`, gây overflow khi màn hẹp hoặc chữ lớn.
- Test `navigation_hit_test.dart` còn tìm nút **"Thêm nhiệm vụ học tập"** — nhãn này không còn trong source (đã đổi thành "Thêm nhiệm vụ mới"), nên test fail dù UI đúng.
- Nhiệm vụ không có ngày nhưng tạo từ lâu vẫn có thể xuất hiện lại nếu ngày tạo trùng hôm nay sau khi đổi múi giờ.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Khối chào + hero + tiến độ %; danh sách nhiệm vụ chưa xong; mục "đã hoàn thành" riêng; banner AI ở cuối |
| **Không có dữ liệu** | Thẻ rỗng: tiêu đề **"Chưa có bài tập nào hôm nay"**, mô tả ngắn, nút **"Thêm nhiệm vụ mới"**; tiến độ 0% |
| **Gặp lỗi** | Không có màn lỗi riêng. Lỗi tải dữ liệu rơi vào màn khởi động có nút thử lại; lỗi thao tác hiện snackbar của màn gọi |

---

### 4.2 Tab Kế hoạch

**File:** `lib/features/planner/planner_screen.dart`

#### Mô tả

Quản lý **Nhiệm vụ** và **Mục tiêu lớn**.

- Mobile: hai segment **"Nhiệm vụ"** / **"Mục tiêu lớn"**.
- Desktop: bố cục hai cột, nhãn chuyển thành **"Mục tiêu"** / **"Nhiệm vụ"**.

**Nhiệm vụ**
- Thêm bằng hộp thoại **"Thêm nhiệm vụ"** — phụ đề "Ghi lại việc cần làm và thời lượng dự kiến.", ô tiêu đề gợi ý "Ví dụ: Làm bài tập 1 đến 5 trang 42", ô thời lượng gợi ý "25", có thể đặt ngày/giờ hoặc "Bỏ lịch", nút lưu **"Lưu nhiệm vụ"**.
- Xoá có hộp thoại xác nhận **"Xóa nhiệm vụ?"**, nội dung "…sẽ bị xóa khỏi kế hoạch học tập. Thao tác này không thể hoàn tác.", nút **"Xóa"**.
- Nếu nhiệm vụ có giờ, app mời cấp quyền **báo thức chính xác** ngay sau khi lưu (P0).

**Mục tiêu lớn**
- Thêm bằng hộp thoại **"Thêm mục tiêu"** — phụ đề "Chọn một đích đến rõ ràng để Mochi giúp bạn chia nhỏ.", gợi ý "Ví dụ: Ôn tập đạt điểm A kỳ thi giữa kỳ", nút **"Lưu mục tiêu"**.
- Xoá mục tiêu có cảnh báo hệ quả: "N nhiệm vụ chỉ thuộc mục tiêu này sẽ bị xóa".
- Nút **"AI chia nhỏ việc"** gọi AI, dùng lịch sinh hoạt thật (giờ rảnh, số phút/ngày) để đề xuất các bước.

**Luồng AI Planner**
1. Bấm "AI chia nhỏ việc" → gọi `aiService.breakDownGoalIntoTasks(...)`.
2. Hiện bản xem trước, kèm ghi chú: "Đây là đề xuất chưa được lưu. Giờ học đã tránh các nhiệm vụ hiện có và giới hạn {N} phút/ngày; hãy kiểm tra lại trước khi áp dụng."
3. Người dùng xác nhận mới ghi vào kế hoạch; có nút "Bỏ qua".

**Thông báo sau khi lưu nhiệm vụ** (snackbar)
- Web: "Đã lưu {N} nhiệm vụ… Bản Web không có nhắc học trên thiết bị."
- Quyền thông báo tắt: "Đã lưu {N} nhiệm vụ… nhưng chưa đặt được nhắc học vì quyền thông báo đang tắt." + nút **"Mở cài đặt"**.
- Thành công: "Đã lưu {N} nhiệm vụ… và hẹn {M} lời nhắc gần nhất." hoặc "…Lịch nhắc sẽ cập nhật khi mở ứng dụng."
- Không kiểm tra được quyền: "Đã lưu {N} nhiệm vụ… Chưa kiểm tra được quyền thông báo." + "Mở cài đặt".

#### Tình trạng

✅ Hoạt động phần lớn. 🟡 Luồng AI cần mạng.

#### Lỗi đã biết

- Test `planner_screen_test.dart` tìm nút **"Thêm mục tiêu lớn"** không còn tồn tại → test fail, không phải lỗi UI hiện tại.
- AI Planner phụ thuộc chất lượng dữ liệu lịch sinh hoạt: nếu lịch trống, đề xuất dễ rơi về giờ tối mặc định.
- Khi AI lỗi, người dùng chỉ thấy snackbar, không có nút thử lại tại chỗ (phải bấm lại nút AI).
- Bản xem trước AI không lưu nháp: đóng hộp thoại là mất đề xuất.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Danh sách nhiệm vụ (chip môn, "{N} phút", giờ nếu có) hoặc danh sách mục tiêu kèm tiến độ; nút xoá từng dòng |
| **Không có dữ liệu** | Nhiệm vụ: **"Chưa có nhiệm vụ nào trong kế hoạch"** + nút thêm. Mục tiêu: **"Chưa có mục tiêu học tập"** + nút thêm |
| **Gặp lỗi** | Snackbar. AI: "Không đủ giờ rảnh…" + nút **"Mở lịch sinh hoạt"**, hoặc "…vượt ngân sách…", hoặc "Chưa tạo được kế hoạch. Kiểm tra Lịch sinh hoạt và kết nối mạng rồi thử lại." |

---

### 4.3 Tab AI Tutor

**File:** `lib/features/ai_tutor/ai_tutor_screen.dart`, `ai_tutor_sheet.dart`

#### Mô tả

Trợ lý học tập dạng hội thoại.

- Mở tab: lời chào theo ngữ cảnh, ví dụ "Bạn muốn cùng mình gỡ bài nào hôm nay? Gửi đề bài hoặc chỗ bạn chưa hiểu nhé."; nếu đang mở từ một nhiệm vụ, AI biết tên bài và môn.
- Gửi tin nhắn văn bản, hoặc **gửi/chụp ảnh đề bài** để AI đọc (vision).
- AI có thể trả về **thẻ quiz** (câu hỏi trắc nghiệm) và **thẻ đề xuất đổi lịch**. Thẻ đổi lịch **không tự áp dụng**: người dùng phải xác nhận, và app nói rõ "lịch chưa thay đổi".
- Dùng lại được trong **sheet 90% chiều cao** khi đang học (Focus Timer), với nút yêu cầu đăng nhập riêng.

#### Tình trạng

🟡 Hoạt động khi có mạng và đã đăng nhập. Khách dùng được một phần.

#### Lỗi đã biết

- Khách chưa đăng nhập: câu trả lời đánh dấu `authentication_required` kèm nút **"Đăng nhập ngay"** ngay dưới bong bóng. Riêng khi AI Tutor mở dạng sheet trong Focus Timer (không có thanh tab), app hiện snackbar **"Đóng phiên học rồi vào mục Tôi để đăng nhập nhé."**
- Câu trả lời bị cắt do giới hạn độ dài: app ghi "Câu trả lời có thể bị cắt vì giới hạn độ dài." + nút **"Viết tiếp"**.
- Ảnh không đọc được: "Chưa đọc được nội dung từ ảnh." hoặc "Chưa phân tích được ảnh đề bài lúc này. Bạn thử chụp rõ nét hơn hoặc gửi lại nhé."
- Quiz lỗi: "Chưa tạo được quiz hợp lệ. Bạn thử lại nhé; chưa có kết quả nào được lưu."
- Đổi lịch lỗi: "Chưa phân tích được yêu cầu dời lịch. Bạn thử lại nhé; chưa có lịch nào thay đổi."
- Hội thoại dài không có giới hạn hiển thị rõ ràng; chưa thấy cơ chế tóm tắt ngữ cảnh trong UI.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Bong bóng hội thoại, thẻ quiz, thẻ đề xuất đổi lịch, ô nhập "Hỏi Mochi…" |
| **Không có dữ liệu** | Luôn có lời chào mở đầu; không có màn rỗng riêng |
| **Gặp lỗi** | Bong bóng lỗi + dòng **"Chưa kết nối được AI"** và nút **"Thử lại"**, **"Đăng nhập lại"** (phiên hết hạn) hoặc **"Đăng nhập ngay"** (khách); trạng thái đang xử lý có nút **"Huỷ"** |

---

### 4.4 Tab Ôn tập

**File:** `lib/features/flashcards/review_screen.dart`

#### Mô tả

Ôn theo lịch giãn cách, giới hạn theo **quỹ giờ học** trong ngày.

Luồng:
1. Vào tab → app chọn thẻ đến hạn/sắp đến hạn vừa sức, hiện "Đang chọn kiến thức đến hạn và sắp lượt ôn vừa sức…".
2. Có phiên ôn: hiện từng thẻ, lật xem đáp án, tự đánh giá mức nhớ; có thể kèm quiz.
3. Kết thúc: màn "Đã hoàn thành lượt ôn", thống kê "Thẻ đã xếp lịch", "Câu quiz đã trả lời"; lịch ôn từng thẻ được cập nhật.
4. Nếu bỏ qua quiz giữa chừng, app giữ các câu đã trả lời và ghi rõ điều đó.

Thông điệp hoàn thành thay đổi theo chế độ:
- Offline: "Lịch ôn đã cập nhật theo mức tự nhớ từ thẻ đã lưu."
- Bỏ quiz: "Đã lưu mức nhớ của thẻ và bỏ qua phần quiz còn lại. Các câu đã trả lời vẫn được giữ."
- Bình thường: "Lịch ôn từng thẻ đã được cập nhật theo mức nhớ. Câu quiz sai được đưa về lượt ôn gần hơn, không tự đánh dấu đã vững."

#### Tình trạng

✅ Hoạt động, có chế độ offline.

#### Lỗi đã biết

- Quỹ giờ học đầy → không tạo phiên; người dùng chỉ được gợi ý chỉnh lịch sinh hoạt hoặc quản lý kiến thức, không có cách "ôn thêm" nhanh.
- Có nút **"Bỏ qua quiz chưa xác minh"**; nếu thao tác lỗi, app báo **"Chưa bỏ qua được quiz. Hãy kiểm tra lại lượt ôn."**
- Nút "Ôn lại từ đầu" ở màn hoàn thành tạo phiên mới, có thể vượt quỹ giờ nếu quỹ vừa được giải phóng.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Thẻ câu hỏi, nút "Xem đáp án", mức tự đánh giá, tiến độ "Thẻ N / M", quiz |
| **Không có dữ liệu** | **"Không có thẻ phù hợp đến hạn lúc này. Phần đã nhớ được giãn lịch; bạn không cần ôn lại chỉ để giữ chuỗi."** Hoặc quỹ giờ kín: **"Quỹ giờ học hôm nay đã kín. Không tự thêm việc ôn lấn lịch bận; bạn có thể chỉnh lịch sinh hoạt hoặc quản lý kiến thức."** |
| **Gặp lỗi** | **"Chưa tạo được lượt ôn. Bạn có thể ôn thẻ đã lưu hoặc mở thư viện để thêm kiến thức."** |

---

### 4.5 Thư viện kiến thức (Flashcards)

**File:** `lib/features/flashcards/flashcards_screen.dart`

#### Mô tả

- Tiêu đề "Quản lý kiến thức", phụ đề "Thẻ và bộ thẻ của bạn, dùng được cả khi offline."
- Tìm kiếm thẻ/bộ thẻ, lọc theo môn, lọc "Đến hạn ôn".
- Hiện chip "{N} thẻ phù hợp".
- Tạo bộ thẻ thủ công, thêm thẻ, sửa nội dung thẻ.
- Tạo thẻ bằng AI theo chủ đề: nhập chủ đề → **"Tạo bản xem trước"** → kiểm tra → **"Lưu {N} thẻ"**. Có cảnh báo "Nội dung AI có thể chưa chính xác. Hãy kiểm tra trước khi lưu."
- Sửa thẻ sẽ đưa thẻ về lịch ôn gần nhất và tạo lại lượt ôn đang dùng thẻ cũ.

#### Tình trạng

✅ Phần thủ công và offline. 🟡 Phần tạo bằng AI cần đăng nhập + mạng.

#### Lỗi đã biết

- Khách bấm tạo bằng AI: snackbar **"Đăng nhập để tạo flashcard bằng AI."**
- Tạo thất bại: "Chưa tạo được thẻ. Kiểm tra kết nối/đăng nhập rồi thử lại."
- Lưu thất bại: "Chưa lưu được bộ thẻ. Hãy thử lại."
- Chưa nhập chủ đề: "Nhập chủ đề trước khi tạo."
- Không có tìm kiếm nâng cao (theo độ khó, ngày tạo).

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Danh sách bộ thẻ/thẻ, chip lọc đang chọn, số thẻ phù hợp, nút sửa từng thẻ |
| **Không có dữ liệu** | **"Chưa có bộ thẻ nào"** / "Chưa có bộ thẻ. Tạo và lưu kiến thức để ôn cả khi offline." + nút **"Tự tạo bộ thẻ"**. Bộ thẻ rỗng: **"Bộ thẻ này chưa có thẻ nào"** + **"Thêm thẻ đầu tiên"** |
| **Gặp lỗi** | Snackbar hoặc dòng lỗi trong hộp thoại AI (xem trên); không có màn lỗi toàn trang |

---

### 4.6 Tab Tôi (Hồ sơ & lịch)

**File:** `lib/features/profile/profile_calendar_screen.dart`

#### Mô tả

Cuộn dọc, gồm:

1. **Thẻ hồ sơ** — avatar chữ cái đầu, tên (fallback **"Người học Mochi"**), dòng "{Cấp học} · Đồng hành: {tên robot}". Hai nút: **Cửa hàng robot**, **Cài đặt**. Nếu đã đăng nhập: icon đồng bộ + email + nút đăng xuất.
2. **Thống kê thành tựu** — XP, Chuỗi kỷ lục, Tổng thời gian (phút).
3. **Banner lỗi đồng bộ** — chỉ hiện khi `syncError != null`.
4. **Thẻ Hồ sơ học tập và lịch chung** — vào Learning Hub.
5. **Lịch tháng** — mỗi ngày có hoạt động hay không; chạm ngày xem việc trong ngày.
6. **Nhật ký học tập gần đây** — các phiên đã hoàn thành.

#### Tình trạng

✅ Hoạt động. 🟡 Banner đồng bộ chỉ xuất hiện khi có tài khoản cloud.

#### Lỗi đã biết

- Thẻ Learning Hub từng nằm trong tab này đã bị **comment out** (`profile_calendar_screen.dart:60-62`); lối vào hiện chỉ còn qua thẻ "Hồ sơ học tập và lịch chung" thấp hơn trên trang.
- Hàm `_buildLearningHubTile` còn trong file nhưng không dùng → cảnh báo `unused_element`.
- Ô ngày không có hoạt động hiện "Chưa có hoạt động nào hoàn thành" / "Chưa học"; chữ nhỏ, dễ bỏ qua.
- Chưa có nút đổi tên người học ngay tại thẻ hồ sơ (phải qua Cài đặt → Cá nhân hoá).

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Đủ 6 khối; lịch tô màu ngày có học; nhật ký liệt kê phiên |
| **Không có dữ liệu** | Nhật ký: **"Chưa có nhật ký học tập nào."**; lịch tháng vẫn hiện lưới ngày, các ngày trống ghi "Chưa học" |
| **Gặp lỗi** | Banner **"Lỗi đồng bộ"** + nút **"Thử lại"** ở đầu trang; lỗi lưu lịch hiện snackbar |

---

### 4.7 Hồ sơ học tập & lịch chung

**File:** `lib/features/learning/learning_hub_screen.dart`

#### Mô tả

Trung tâm dữ liệu học tập, chia 3 tab: **Tiến độ môn · Bài & lịch · Thời khóa biểu**.

**Tiến độ môn**
- Khối "Tổng quan — Xem lại tiến độ từng môn đang theo học" với 5 chỉ số: Môn đang học, Đã vững, Cần ôn, Chưa học, Chưa đánh giá.
- Thẻ từng môn: chủ đề, mức sẵn sàng, nút cập nhật.
- Hộp thoại **"Lớp và môn đang học"**: Lớp, Năm học, chọn môn, **"Lưu hồ sơ"**. Thiếu dữ liệu → "Chọn môn và nhập năm học."

**Bài & lịch**
- Danh sách việc/bài tập, thêm bằng hộp thoại **"Bài tập và việc cần học"**: Việc cụ thể, Môn, Loại việc, Tổng thời lượng dự kiến (phút), ngày/giờ, liên kết mục tiêu/chủ đề, nút **"Thêm việc"**.
- Có thể xếp lịch tự động: **"Xem trước lịch chung 7 ngày"** → hiện từng ngày kèm lý do và số phút còn lại → **"Để sau"** hoặc **"Áp dụng lịch"**.
- Nếu lịch cũ không còn hợp lệ sau khi đổi môn/tiến độ/TKB, app hiện cảnh báo "Lịch cũ không còn áp dụng sau khi thay đổi môn học, tiến độ hoặc thời khóa biểu. Hãy xếp và áp dụng lịch mới để cập nhật các phiên học."

**Thời khóa biểu**
- Hai nút: **"Nhập TKB bằng AI"**, **"Thêm giờ lên lớp"**.
- Hộp thoại **"Thêm giờ lên lớp / học thêm"**: Môn, "Lặp lại hàng tuần", giờ bắt đầu/kết thúc, **"Lưu giờ học"**.
- Hộp thoại AI: dán văn bản, **"Chọn ảnh TKB"**, **"Chụp ảnh TKB"** → "AI đang bóc tách thời khóa biểu..." → xem trước → **"Lưu vào thời khóa biểu"**.
- TKB giúp Mochi tránh xếp giờ tự học trùng giờ lên lớp.

#### Tình trạng

✅ CRUD và xếp lịch hoạt động. 🟡 Nhập TKB bằng AI cần mạng.

#### Lỗi đã biết

- **Tab Tiến độ môn không có trạng thái rỗng**: khi chưa có môn nào, app vẫn hiện 5 ô số liệu bằng 0 và không có thẻ hướng dẫn thêm môn. Người dùng mới dễ bị "trang trắng" về mặt thông tin.
- `learning_hub_screen_test.dart` fail ở text scale 2.0 do overflow 18px — bố cục chưa chịu được chữ rất lớn.
- Tiết trùng khi lưu TKB bị bỏ qua thầm lặng, chỉ gộp vào một câu: **"Đã lưu {N} tiết học; các tiết trùng đã được bỏ qua."** Nếu không lưu được tiết nào: **"Thời khóa biểu này đã có sẵn."**
- AI không nhận diện được tiết nào: **"AI chưa nhận diện được tiết học. Hãy kiểm tra nội dung rồi thử lại."**
- Xếp lịch tự động không có nút hoàn tác sau khi "Áp dụng lịch".

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Chỉ số + thẻ môn; danh sách bài tập; lưới TKB theo thứ |
| **Không có dữ liệu** | Bài tập: **"Chưa có bài tập nào"** / "Thêm việc thật từ lớp hoặc mục tiêu để bắt đầu." + **"Thêm việc mới"**. TKB: **"Chưa có giờ học nào trong thời khóa biểu"** / "Thêm giờ lên lớp hoặc nhập thời khóa biểu để Mochi tránh xếp lịch tự học trùng giờ." + **"Thêm giờ lên lớp"**. Xếp lịch: **"Chưa có phiên có thể xếp. Kiểm tra việc cần làm, giờ rảnh và tổng thời lượng học mỗi ngày."** |
| **Gặp lỗi** | Snackbar lỗi thao tác; AI TKB: **"Vui lòng chọn ảnh hoặc dán nội dung thời khóa biểu."**; lưu TKB lỗi hiện thông báo trong hộp thoại, không đóng |

---

### 4.8 Focus Timer (Pomodoro)

**File:** `lib/features/focus/focus_timer_screen.dart`

#### Mô tả

- Hai chế độ: **Pomodoro** (có chu kỳ tập trung/nghỉ) và **Bấm giờ tự do**.
- Đặt thời lượng qua hộp thoại **"Đặt thời lượng học"** + **"Áp dụng"**.
- Khi chạy: đếm ngược, có thể kết thúc sớm.
- Hết giờ tập trung: hộp thoại hoàn thành phiên + **tổng kết do AI viết** ("Mochi AI đang chuẩn bị tổng kết phiên học..."), lưu phiên với chế độ `pomodoro` hoặc `freestyle`.
- Hết giờ nghỉ: thông báo "Hết giờ nghỉ! Sẵn sàng cho phiên tập trung tiếp theo chưa?"
- Có thể mở AI Tutor dạng sheet trong lúc học.

#### Tình trạng

✅ Hoạt động trên thiết bị. ⚠️ Chuông hết giờ phụ thuộc quyền thông báo.

#### Lỗi đã biết

- Không đặt được chuông: **"Chưa đặt được chuông hết giờ. Kiểm tra quyền thông báo rồi thử lại."** — phiên vẫn chạy nhưng người dùng có thể không biết đã hết giờ nếu rời app.
- Tổng kết AI có thể chậm; UI chỉ hiện dòng chờ, không có nút bỏ qua tổng kết.
- Hộp thoại hoàn thành cho nhập **mức tự đánh giá** và **phản tư**, rồi bấm **"Lưu vào nhật ký học tập"**. Việc lưu là thao tác đồng bộ, không có trạng thái lỗi; nếu người dùng đóng app trước khi bấm lưu, phiên học đó không được ghi.
- Lưu phiên dùng `operationKey` để chống ghi trùng khi bấm nhiều lần.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Đồng hồ đếm ngược/đếm lên, nhãn "Tập trung"/"Giờ nghỉ ngơi thư giãn", nút dừng/kết thúc |
| **Không có dữ liệu** | Luôn có giá trị mặc định (Pomodoro); không có màn rỗng |
| **Gặp lỗi** | Snackbar quyền thông báo; hộp thoại hoàn thành vẫn hiện nếu phiên kết thúc trong app |

---

### 4.9 Nhắc học thông minh

**Files:** `core/services/smart_reminder_service.dart`, `smart_reminder_policy.dart`, `notification_service.dart`, `docs/SMART_REMINDERS.md`

#### Mô tả

Toàn bộ quyết định nhắc nằm trên máy; không có AI chạy ngầm liên tục.

**Các loại lời nhắc**

| Loại | Điều kiện | Ghi chú |
|---|---|---|
| `due` | Nhiệm vụ có ngày/giờ | Nhắc đúng lịch; **không giới hạn 7 ngày** (P2) |
| `overdue` | Nhiệm vụ quá hạn khi mở app | Lùi ít nhất 2 giờ để tránh dồn |
| `inactiveStudy` | 2 / 4 / 6 ngày không có hoạt động học | Dựa trên phiên học, lúc bắt đầu tập trung, lúc hoàn thành nhiệm vụ |
| `inactiveApp` | 3 / 6 ngày không mở app | Ghi nhận khi foreground/resume |

**Giới hạn**
- Tối đa **2 lời nhắc tự động/ngày**, cách nhau **ít nhất 3 giờ**.
- Không hẹn trong **22:00–08:00**.
- Lời nhắc theo giờ nhiệm vụ được ưu tiên hơn lời mời chung.
- Hạn mức tính cả các reservation đã tới giờ, không reset chỉ vì mở lại app.
- Làm mới khi mở app và khi nhiệm vụ/hoạt động học thay đổi.
- Lời nhắc `due` cho nhiệm vụ xa vẫn được hẹn; các lời mời chung chỉ chuẩn bị trong 7 ngày tới để danh sách alarm gọn.
- Chạm lời nhắc → mở tab **Kế hoạch**.

**Nội dung lời nhắc**
- Mặc định theo bộ quy tắc, có thể để AI soạn khi có mạng; AI không nhận tên hay nội dung nhiệm vụ.
- Có nút **"Soạn lại lời nhắc"** trong Cài đặt.

#### Tình trạng

✅ Hoạt động trên Android. ⛔ Không hỗ trợ Web/iOS (plugin chỉ bật cho Android).

#### Lỗi đã biết

- Nếu người dùng tắt **kênh** "Nhắc học thông minh" trong cài đặt Android, mọi reminder im lặng; app đã phát hiện và cảnh báo (P0) nhưng không tự bật lại.
- Báo thức chính xác cần quyền riêng; nếu chưa cấp, Android có thể trì hoãn → nhắc muộn.
- Lời nhắc không đảm bảo hiển thị nếu hệ thống tối ưu pin mạnh (OEM).
- AI soạn lời nhắc có thể thất bại; app rơi về mẫu mặc định nhưng không báo rõ nguồn cho người dùng (`copySource` chỉ dùng nội bộ).

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Thẻ "Nhắc học thông minh" + công tắc bật; chip **"Đang bật"**; danh sách lời nhắc sắp tới nếu có |
| **Không có dữ liệu** | Chưa có nhiệm vụ/hoạt động → không có lời nhắc nào; thẻ vẫn hiện mô tả và công tắc |
| **Gặp lỗi** | Chip **"Kênh bị tắt"** + banner **"Kênh "Nhắc học thông minh" đang bị tắt nên mọi lời nhắc sẽ không hiện ra."** + **"Mở kênh"**; banner báo thức: "Nhắc giờ: Android có thể trì hoãn. Cho phép báo thức chính xác để nhắc sát giờ hơn." + **"Cho phép báo thức chính xác"** |

---

### 4.10 Cài đặt & Tùy chọn

**File:** `lib/features/settings/settings_screen.dart`

#### Mô tả

Các khối theo thứ tự:

1. **Cá nhân hoá** — sắc màu chủ đạo, chế độ Sáng/Tối/Hệ thống, đổi tên robot, phong cách trả lời ("Từng bước chi tiết" / "Ngắn gọn súc tích"), chọn nền (màu/gradient hoặc ảnh nền).
2. **Chia sẻ tiến độ** — tạo mã mời một lần cho phụ huynh/giáo viên, danh sách người xem, quyền xem chi tiết.
3. **Thông báo** — trạng thái, bật thông báo, mở cài đặt Android, cảnh báo kênh bị tắt, báo thức chính xác.
4. **Nhắc học thông minh** — bật/tắt, AI soạn lời nhắc, soạn lại.
5. **Lịch sinh hoạt** — vào màn Routine.
6. **Hiển thị & Tương tác** — Tương phản cao, Giảm chuyển động, Rung phản hồi.
7. **Âm thanh và rung** — mở cài đặt hệ thống (chỉ Android).
8. **Phiên bản** — "Mochi-Học cùng nhau" + số phiên bản.

#### Tình trạng

✅ Hoạt động. 🟡 Một số mục chỉ có trên Android.

#### Lỗi đã biết

- Đổi theme (Sáng/Tối) chỉ có hiệu lực khi đã đăng nhập; khách luôn ở theme sáng (`main.dart`: `themeMode` phụ thuộc `hasActiveUser`). Đây là hành vi có chủ đích nhưng dễ gây hiểu nhầm.
- "Âm thanh và rung" chỉ mở cài đặt hệ thống, không có công tắc trong app.
- Mục chia sẻ yêu cầu đăng nhập; khách thấy thẻ nhưng thao tác sẽ lỗi/không khả dụng.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Giá trị hiện tại của theme, tên robot, kiểu trả lời, nền, công tắc |
| **Không có dữ liệu** | Giá trị mặc định: theme Hệ thống (hoặc Sáng khi khách), robot "Mochi", kiểu trả lời mặc định |
| **Gặp lỗi** | Banner trong thẻ Thông báo (kênh tắt/báo thức); các mục khác không có trạng thái lỗi riêng |

---

### 4.11 Lịch sinh hoạt

**File:** `lib/features/routine/routine_screen.dart`

#### Mô tả

- **Lịch học hàng tuần** — mỗi thứ có ô "Thời gian có thể học" và "Thời gian bận", định dạng `HH:mm-HH:mm`, nhiều khung cách nhau dấu phẩy.
- **Lịch riêng theo ngày** — ưu tiên hơn lịch tuần khi trùng ngày.
- Nút **"Lưu thay đổi"**; nút **"Hủy"** trong hộp thoại.
- Dữ liệu này được AI Planner và bộ xếp lịch dùng để tính giờ rảnh.

#### Tình trạng

✅ Hoạt động, lưu local.

#### Lỗi đã biết

- Sai định dạng: **"Định dạng chưa hợp lệ. Hãy sử dụng HH:mm-HH:mm và kiểm tra thứ tự thời gian."** — chỉ báo một lỗi chung, không chỉ rõ khung nào sai.
- Không có kiểm tra chồng lấn giữa "thời gian học" và "thời gian bận"; người dùng có thể nhập mâu thuẫn.
- Không có nút xoá toàn bộ lịch tuần nhanh.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | 7 thẻ thứ với khung giờ đã nhập; danh sách "Lịch riêng" theo ngày |
| **Không có dữ liệu** | Lịch tuần để trống; mục lịch riêng hiện **"Chưa có lịch riêng"** + **"Thêm lịch riêng"** |
| **Gặp lỗi** | Dòng lỗi đỏ dưới ô nhập khi định dạng sai; không có màn lỗi toàn trang |

---

### 4.12 Cửa hàng Mochi

**File:** `lib/features/rewards/robot_shop_screen.dart`

#### Mô tả

- Tiêu đề "Cửa hàng Mochi", phụ đề "Phụ kiện và trang phục cho bạn đồng hành".
- Hiện số **sao** hiện có và **"Chuỗi hiện tại: N ngày"**.
- Danh sách vật phẩm: tên, chip "Chuỗi N ngày" nếu cần chuỗi, giá sao.
- Trạng thái từng vật phẩm: **"Mua"**, **"Nhận quà"** (giá 0), **"Đã sở hữu"**, **"Đang mặc"** → nút **"Mặc ngay"**/**"Tháo ra"**.
- Mua thành công: snackbar **"Đã mở khóa {tên}!"**.
- Có phần chọn màu robot (mở khoá theo điều kiện).

#### Tình trạng

✅ Hoạt động, thuần local.

#### Lỗi đã biết

- Nút mua **bị disable** khi thiếu sao hoặc chưa đủ chuỗi, nhưng không có tooltip/giải thích lý do — người dùng chỉ thấy nút xám.
- Không có màn xác nhận trước khi mua; chạm là trừ sao ngay.
- `robot_shop_screen.dart:33` có biến `palette` không dùng → cảnh báo analyzer.

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Số sao, chuỗi, lưới vật phẩm với giá/trạng thái, nút hành động |
| **Không có dữ liệu** | Danh sách vật phẩm là hằng số trong app nên luôn có; ví sao 0 → mọi nút mua bị disable |
| **Gặp lỗi** | Không có trạng thái lỗi; mua thất bại chỉ là không có phản hồi (nút đã disable từ trước) |

---

### 4.13 Tài khoản, đồng bộ & chia sẻ

**Files:** `features/auth/auth_screen.dart`, `student_overview_screen.dart`, `features/settings/student_sharing_card.dart`, `student_sharing_permissions_screen.dart`, `core/services/cloud_sync_service.dart`

#### Mô tả

**Đăng nhập học sinh**
- Chế độ **Đăng nhập** / **Đăng ký**: email + mật khẩu (tối thiểu 6 ký tự).
- Đăng ký xong có thể yêu cầu xác nhận email; app báo "Kiểm tra email để xác nhận tài khoản, sau đó đăng nhập để đồng bộ."
- Đăng nhập thành công → bật đồng bộ cloud, theme tối/sáng theo hồ sơ.

**Chế độ người xem (phụ huynh/giáo viên)**
- Nhập email đã được cấp quyền + **mã mời dùng một lần**.
- Mã hết hạn sau 5 phút: "Mã mời đã hết hạn sau 5 phút. Hãy nhờ học sinh tạo và gửi mã mới."
- Sai/đã dùng/bị thu hồi: "Email hoặc mã mời không đúng, mã đã được sử dụng, hoặc quyền truy cập đã bị thu hồi."

**Chia sẻ từ phía học sinh**
- Tạo mã mời một lần cho email người xem, chọn vai trò **Phụ huynh** / **Giáo viên**.
- Danh sách người xem: email, lần xem gần nhất ("Chưa xem lần nào"), nút thu hồi.
- Màn **"Quyền xem thông tin"** bật/tắt từng nhóm: Hồ sơ học sinh, Điểm XP, Chuỗi ngày học, Thời gian học, Mục tiêu học tập, Môn học & chủ đề, Tiến độ chủ đề, Hoạt động gần đây.
- Tắt hết → người xem vẫn vào được nhưng thấy "Học sinh chưa chia sẻ thông tin nào".

**Màn tổng quan cho người xem**
- Tiêu đề "Tổng quan học tập"; 4 khối: Mục tiêu học tập, Môn học, Tiến độ chủ đề, Hoạt động gần đây.
- Mỗi khối có câu rỗng riêng (xem bảng dưới).

#### Tình trạng

🟡 Hoạt động khi có Supabase và mạng. Phần local vẫn dùng được khi chưa đăng nhập.

#### Lỗi đã biết

- Không có đăng nhập Google/OTP email; chỉ email + mật khẩu, nên người dùng phải nhớ mật khẩu.
- Quên mật khẩu chưa thấy luồng khôi phục trong UI.
- Mã mời 5 phút khá ngắn nếu phụ huynh nhận qua tin nhắn chậm.
- Lỗi đồng bộ hiện banner ở tab Tôi nhưng không có log/chi tiết nguyên nhân cho người dùng.
- Thu hồi quyền không đăng xuất ngay phiên đang mở của người xem; họ chỉ mất quyền ở lần tải sau ("Quyền xem đã bị thu hồi hoặc chưa thể tải dữ liệu.").

#### Ba trạng thái giao diện

| Trạng thái | Hiển thị |
|---|---|
| **Có dữ liệu** | Thông tin hồ sơ + 4 khối dữ liệu; danh sách người xem kèm lần xem cuối; danh sách quyền có công tắc |
| **Không có dữ liệu** | Mục tiêu: **"Chưa có mục tiêu được chia sẻ."** · Môn học: **"Chưa có môn học được chia sẻ."** · Tiến độ: **"Chưa có tiến độ chủ đề được chia sẻ."** · Hoạt động: **"Chưa có hoạt động học nào được chia sẻ."** · Không chia sẻ gì: **"Học sinh chưa chia sẻ thông tin nào"** + **"Tải lại"** · Người xem: **"Chưa có người xem nào. Danh sách sẽ cập nhật sau khi mã được sử dụng."** |
| **Gặp lỗi** | Đăng nhập: dòng lỗi đỏ ngay trên form (các câu ở trên). Người xem: **"Quyền xem đã bị thu hồi hoặc chưa thể tải dữ liệu."** + **"Quay lại"**/**"Tải lại"**. Chia sẻ: **"Chưa thu hồi được quyền xem."**, **"Chưa lưu được thay đổi. Kiểm tra kết nối và thử lại."** |

---

## 5. Ma trận trạng thái giao diện

Bảng tra nhanh: mỗi màn có trạng thái rỗng/lỗi riêng hay không.

| Màn | Có dữ liệu | Không có dữ liệu | Lỗi |
|---|---|---|---|
| Khởi động | — | — | Màn `failed` + "Chưa mở được ứng dụng. Bạn thử lại nhé." + Thử lại |
| Onboarding | Form + chip chọn | Placeholder từng ô | Không có UI lỗi |
| Hôm nay | Chào + hero + tiến độ + việc | "Chưa có bài tập nào hôm nay" + "Thêm nhiệm vụ mới" | Không có; lỗi thao tác → snackbar nơi gọi |
| Kế hoạch – Nhiệm vụ | Danh sách việc | "Chưa có nhiệm vụ nào trong kế hoạch" | Snackbar AI/lưu |
| Kế hoạch – Mục tiêu | Danh sách mục tiêu + tiến độ | "Chưa có mục tiêu học tập" | Snackbar AI/lưu |
| AI Tutor | Hội thoại + thẻ | Lời chào mở đầu | "Chưa kết nối được AI" + Thử lại/Đăng nhập lại |
| Ôn tập | Thẻ + quiz | "Không có thẻ phù hợp…" / "Quỹ giờ học hôm nay đã kín…" | "Chưa tạo được lượt ôn…" |
| Thư viện kiến thức | Bộ thẻ/thẻ + lọc | "Chưa có bộ thẻ nào" / "Bộ thẻ này chưa có thẻ nào" | Snackbar/dòng lỗi trong hộp thoại |
| Tôi | 6 khối | "Chưa có nhật ký học tập nào." | Banner "Lỗi đồng bộ" + Thử lại |
| Learning Hub – Tiến độ | 5 chỉ số + thẻ môn | **Không có** (chỉ hiện số 0) ⚠️ | Snackbar |
| Learning Hub – Bài & lịch | Danh sách việc | "Chưa có bài tập nào" + Thêm việc mới | Snackbar + lý do không xếp được lịch |
| Learning Hub – TKB | Lưới giờ học | "Chưa có giờ học nào trong thời khóa biểu" + Thêm giờ lên lớp | Lỗi trong hộp thoại AI |
| Focus Timer | Đồng hồ | Giá trị mặc định | Snackbar "Chưa đặt được chuông hết giờ…" |
| Cài đặt | Giá trị hiện tại | Giá trị mặc định | Banner kênh tắt/báo thức |
| Lịch sinh hoạt | 7 ngày + lịch riêng | "Chưa có lịch riêng" + Thêm lịch riêng | Dòng lỗi định dạng |
| Cửa hàng | Ví sao + vật phẩm | Luôn có vật phẩm; ví 0 → nút disable | Không có |
| Đăng nhập | Form | — | Dòng lỗi đỏ trên form |
| Tổng quan người xem | 4 khối | 4 câu rỗng riêng + "Học sinh chưa chia sẻ thông tin nào" | "Quyền xem đã bị thu hồi…" + Tải lại |
| Chia sẻ tiến độ | Danh sách người xem + quyền | "Chưa có người xem nào…" | "Chưa thu hồi được quyền xem." / "Chưa lưu được thay đổi…" |

**Các màn thiếu trạng thái lỗi riêng (chỉ dựa snackbar hoặc im lặng):** Hôm nay, Onboarding, Cửa hàng, Lịch sinh hoạt, Cài đặt (ngoài thẻ Thông báo), Learning Hub (một phần).

---

## 6. Lỗi, hạn chế & rủi ro

### 6.1 Đã sửa trong đợt P0/P1/P2

| Mã | Nội dung | Kết quả |
|---|---|---|
| P0-1 | Nhiệm vụ có giờ nhưng chưa xin quyền báo thức chính xác | Mời cấp quyền ngay sau khi tạo việc có giờ |
| P0-2 | Kênh "Nhắc học thông minh" bị tắt nhưng app không biết | Phát hiện kênh tắt + chip "Kênh bị tắt" + banner "Mở kênh" |
| P0-3 | Một reminder lỗi làm hỏng cả loạt | Mỗi reminder có try/catch riêng; chỉ báo lỗi khi tất cả thất bại |
| P1-1 | Timezone được parse lại cho mỗi lần hẹn giờ | `_ensureTimeZones()` chạy một lần mỗi process |
| P1-2 | `SmartReminderService.start()` đặt latch sai, caller thứ hai thấy service nửa vời | Dùng `_starting` future dùng chung; lỗi prefs cho phép thử lại |
| P1-3 | Hộp thoại quyền thông báo đè lên Onboarding | Chỉ xin quyền sau khi hoàn tất Onboarding |
| P2-1 | Reminder `due` bị chặn bởi horizon 7 ngày | Nhiệm vụ xa vẫn được hẹn đúng giờ; lời mời chung vẫn trong 7 ngày |
| P2-2 | Code legacy chết (`scheduleTaskReminder`, `reconcileTasks`, `taskNotificationId`, `showDailyReminder`) | Đã xoá; giữ `cancelLegacyTaskReminders()` để dọn alarm cũ |
| P2-3 | Chạm reminder không mở đúng nơi | Mở tab Kế hoạch, hỗ trợ cả cold start |

### 6.2 Lỗi còn mở (theo mức ưu tiên)

| # | Mức | Lỗi | Vị trí | Ảnh hưởng |
|---|---|---|---|---|
| 1 | Cao | Groq/AI credential nằm trong client | `ai_service.dart` + cấu hình | Lộ khoá, lạm dụng quota; cần chuyển ra gateway |
| 2 | Cao | Overflow header "Nhiệm vụ hôm nay" | `today_screen.dart:366` | Vệt vàng/đen trên máy hẹp, chữ lớn |
| 3 | Trung bình | Overflow Learning Hub ở text scale 2.0 | `learning_hub_screen.dart` | Nội dung bị cắt khi phóng chữ |
| 4 | Trung bình | Tab Tiến độ môn không có empty state | `learning_hub_screen.dart:1074` | Người dùng mới thấy toàn số 0, không biết bắt đầu |
| 5 | Trung bình | Test cũ tìm nhãn đã xoá | `planner_screen_test.dart`, `navigation_hit_test.dart` | CI đỏ dù UI đúng; dễ che lỗi thật |
| 6 | Thấp | Mua vật phẩm không có xác nhận, không giải thích nút disable | `robot_shop_screen.dart` | Người dùng bối rối |
| 7 | Thấp | Không có luồng quên mật khẩu | `auth_screen.dart` | Người dùng mất tài khoản phải tạo mới |
| 8 | Thấp | Thu hồi quyền không đăng xuất ngay người xem | `cloud_sync_service.dart` | Người xem còn thấy dữ liệu cũ đến lần tải sau |
| 9 | Thấp | Không kiểm tra chồng lấn giờ học/giờ bận | `routine_screen.dart` | Lịch tự động có thể xếp vào giờ bận |
| 10 | Thấp | Code chết/cảnh báo analyzer | `profile_calendar_screen.dart:306`, `robot_shop_screen.dart:33`, `review_screen.dart:21`, `app_version_caption.dart:5` | Rác bảo trì |

### 6.3 Trạng thái test & build

- `flutter test test/notification_service_test.dart test/smart_reminder_test.dart test/reminder_alarm_prompt_test.dart` → **46/46 pass**.
- `flutter analyze` toàn project: **0 error**, còn ~118 warning/info có sẵn.
- Các suite fail có sẵn, **không liên quan thay đổi P0–P2**:
  - `global_pastel_test.dart` — overflow 320px/theme.
  - `planner_screen_test.dart` — tìm "Thêm mục tiêu lớn" (không còn).
  - `navigation_hit_test.dart` — tìm "Thêm nhiệm vụ học tập" (không còn) + overflow Today.
  - `learning_hub_screen_test.dart` — overflow 18px ở text scale 2.0.
- `flutter test` luôn trả exit code 1 do cảnh báo plugin `shared_preferences:windows`; phải đọc dòng "All tests passed!" thay vì mã thoát.

### 6.4 Phạm vi chưa có trong source

| Thư mục | Trạng thái |
|---|---|
| `lib/features/community` | Rỗng |
| `lib/features/family` | Rỗng |
| `lib/features/live_study` | Rỗng |

Không có tính năng cộng đồng, phụ huynh trong app (khác với chế độ người xem qua mã mời), hay lớp học trực tuyến.

---

## 7. Phụ lục

### 7.1 Thuật ngữ

| Thuật ngữ | Nghĩa trong app |
|---|---|
| **XP** | Điểm kinh nghiệm tích luỹ từ hoạt động học |
| **Chuỗi (streak)** | Số ngày liên tiếp có hoạt động học |
| **Sao** | Tiền tệ trong app, dùng mua vật phẩm ở Cửa hàng |
| **Quỹ giờ học** | Tổng số phút được phép dùng cho việc ôn trong ngày, suy ra từ lịch sinh hoạt |
| **Due** | Lời nhắc đúng lúc nhiệm vụ tới giờ |
| **Overdue** | Nhiệm vụ đã quá hạn nhưng chưa hoàn thành |
| **Readiness** | Mức sẵn sàng của chủ đề: Đã vững / Cần ôn / Chưa học / Chưa đánh giá |
| **Mã mời** | Mã một lần, hết hạn sau 5 phút, dùng để cấp quyền xem cho phụ huynh/giáo viên |
| **Báo thức chính xác** | Quyền Android cho phép hẹn giờ sát phút, không bị hệ thống dời |

### 7.2 Bản đồ file → tính năng

| File | Tính năng |
|---|---|
| `lib/main.dart` | Khung app, 5 tab, sidebar, chuyển tab do notification |
| `lib/core/mochii_bootstrap.dart` | Luồng khởi động, loading/retry |
| `lib/core/database/mochi_store.dart` | Toàn bộ state + lưu local + đồng bộ |
| `lib/core/services/ai_service.dart` | Gọi AI, phân rã mục tiêu, quiz, tổng kết phiên, đọc ảnh |
| `lib/core/services/notification_service.dart` | Kênh, hẹn giờ, quyền, tap routing |
| `lib/core/services/smart_reminder_service.dart` | Vòng đời nhắc học, prefs, fingerprint |
| `lib/core/services/smart_reminder_policy.dart` | Quy tắc chọn thời điểm và hạn mức |
| `lib/core/services/smart_reminder_policy.dart` + `reminder_copy_writer.dart` | Nội dung lời nhắc (mẫu/AI) |
| `lib/features/onboarding/onboarding_screen.dart` | Onboarding 3 bước |
| `lib/features/today/today_screen.dart` | Tab Hôm nay |
| `lib/features/planner/planner_screen.dart` | Tab Kế hoạch + AI Planner |
| `lib/features/ai_tutor/ai_tutor_screen.dart` | Tab AI Tutor |
| `lib/features/flashcards/review_screen.dart` | Tab Ôn tập |
| `lib/features/flashcards/flashcards_screen.dart` | Thư viện kiến thức |
| `lib/features/profile/profile_calendar_screen.dart` | Tab Tôi |
| `lib/features/learning/learning_hub_screen.dart` | Hồ sơ học tập, bài & lịch, TKB |
| `lib/features/focus/focus_timer_screen.dart` | Focus Timer |
| `lib/features/settings/*` | Cài đặt, thông báo, chia sẻ, cá nhân hoá |
| `lib/features/routine/routine_screen.dart` | Lịch sinh hoạt |
| `lib/features/rewards/robot_shop_screen.dart` | Cửa hàng Mochi |
| `lib/features/auth/*` | Đăng nhập, tổng quan người xem |
| `lib/features/robot/robot_mascot_widget.dart` | Hiển thị robot theo màu |

### 7.3 Cách kiểm chứng lại tài liệu

1. **Chạy app** trên Android thật, đi qua 5 tab, tạo 1 nhiệm vụ có giờ, 1 mục tiêu, 1 thẻ.
2. **Kiểm tra nhắc học:** tắt kênh "Nhắc học thông minh" trong cài đặt Android → mở app → xem banner cảnh báo; bật lại → tạo nhiệm vụ cách 2 phút → chờ thông báo; chạm thông báo → phải mở tab Kế hoạch.
3. **Kiểm tra rỗng:** xoá hết nhiệm vụ, mục tiêu, bộ thẻ → so khớp bảng mục 5.
4. **Kiểm tra lỗi mạng:** bật chế độ máy bay → mở AI Tutor, tạo thẻ AI, nhập TKB AI → so khớp câu lỗi.
5. **Kiểm tra chữ lớn:** đặt cỡ chữ hệ thống 200% → rà các màn có cảnh báo overflow ở mục 6.2.
6. **Đối chiếu** `flutter analyze` và các suite test ở mục 6.3 sau mỗi lần sửa.

---

*Hết tài liệu. Cập nhật lần cuối: 18/11/2026.*
