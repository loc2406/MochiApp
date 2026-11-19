# Xác minh email đăng ký trên Android

## 1. Hiện tượng

Sau khi đăng ký, email xác nhận chứa liên kết trỏ về `http://localhost:...` hoặc
`http://127.0.0.1:...`. Bấm vào trên điện thoại sẽ mở trình duyệt tới địa chỉ
không tồn tại, tài khoản không được xác nhận và không quay lại được app.

## 2. Nguyên nhân

Có ba tầng cấu hình, thiếu bất kỳ tầng nào cũng gây lỗi:

1. **App không gửi `emailRedirectTo`** — Supabase dùng `Site URL` trong dashboard.
   Giá trị mặc định của dự án là `http://localhost:3000`, nên link sinh ra trỏ về localhost.
2. **Android không có intent-filter** cho custom scheme, nên dù link đúng app cũng không được mở.
3. **Supabase không cho phép redirect URL** — nếu URL không nằm trong danh sách cho phép,
   Supabase bỏ qua `emailRedirectTo` và quay về `Site URL`.

## 3. Đã sửa trong mã nguồn

| Tầng | Thay đổi | Vị trí |
|---|---|---|
| App | `signUp` truyền `emailRedirectTo = mochiapp://auth-callback` | `lib/core/services/cloud_sync_service.dart` |
| App | Web dùng `Uri.base.origin` để quay lại đúng trang đang chạy | `CloudSyncService.emailRedirectTo` |
| App | Thêm `resendConfirmation()` để gửi lại email | `CloudSyncService` |
| App | Android nhận link qua intent-filter `mochiapp://auth-callback` | `android/app/src/main/AndroidManifest.xml` |
| App | Lắng nghe `onAuthStateChange`, đồng bộ `currentUserId` và đóng màn đăng nhập khi xác minh xong | `CloudSyncService`, `MochiStore`, `auth_screen.dart` |
| UI | Báo "Đã gửi email xác nhận…", thêm nút **Gửi lại email xác nhận**, dịch lỗi "Email not confirmed" | `lib/features/auth/auth_screen.dart` |

`supabase_flutter` đã tự bắt deep link và đổi `code` thành session (PKCE), nên app
không cần thư viện deep link riêng.

## 4. Cấu hình Supabase (bắt buộc)

Vào **Supabase Dashboard → Project → Authentication → URL Configuration**:

1. **Site URL**: đặt URL thật của bản web, ví dụ
   `https://mochi.example.com`. Nếu chưa có web, tạm đặt
   `https://aiukgaacbncpbosgbwzp.supabase.co` — mục đích chỉ là để không còn localhost.
2. **Redirect URLs**: thêm chính xác từng dòng sau (mỗi dòng một URL):

   ```
   mochiapp://auth-callback
   http://localhost:*/**
   https://mochi.example.com/**
   ```

   - Dòng 1 là bắt buộc cho Android.
   - Dòng 2 chỉ dùng khi dev web.
   - Dòng 3 thay bằng domain web thật; dùng `/**` để bao mọi đường dẫn.

3. **Authentication → Providers → Email**: bật **Confirm email** (nếu tắt, người dùng
   đăng ký xong có session ngay và không cần bước này).
4. Kiểm tra **Authentication → Email Templates → Confirm signup** vẫn dùng
   `{{ .ConfirmationURL }}`.

> Nếu bỏ qua bước 2, Supabase sẽ ghi log kiểu
> `redirect_to is not allowed` và tự thay bằng `Site URL`. Đây chính là lý do link
> vẫn hiện localhost dù app đã truyền `emailRedirectTo`.

## 5. Kiểm thử trên Android

### 5.1 Kiểm tra app nhận được scheme

Cài bản debug, chạy:

```powershell
adb shell am start -a android.intent.action.VIEW -d "mochiapp://auth-callback?code=test"
```

App phải mở lên (dù `code=test` sẽ bị Supabase từ chối và chỉ ghi log). Nếu Android
báo "No Activity found", intent-filter chưa được nhận — kiểm tra lại manifest và
chạy `flutter clean` rồi build lại.

### 5.2 Luồng đầy đủ

1. Đăng ký bằng email thật trên app Android.
2. Mở email **trên cùng điện thoại**, chạm liên kết.
3. Android hỏi mở bằng Mochii (hoặc mở thẳng nếu đã chọn mặc định).
4. App quay lại, màn đăng nhập tự đóng, tab Tôi hiện email và icon đồng bộ.
5. Nếu màn đăng nhập vẫn còn, bấm **Gửi lại email xác nhận** rồi thử lại.

### 5.3 Kiểm tra web

1. Chạy web ở `http://localhost:<port>`.
2. Đăng ký, mở link trong cùng trình duyệt.
3. Supabase trả `?code=...` về `Uri.base.origin`; `supabase_flutter` đổi code thành session.

## 6. Lưu ý

- **PKCE yêu cầu mở link trên cùng thiết bị** với lúc đăng ký, vì code verifier lưu local.
  Nếu người dùng đăng ký trên điện thoại rồi mở email trên máy tính, xác minh sẽ thất bại.
  Muốn hỗ trợ cross-device, phải đổi sang implicit flow (kém an toàn hơn) hoặc dùng OTP code.
- Một số ứng dụng email (Gmail web, Outlook) chặn custom scheme. Trên Android, liên kết
  `mochiapp://` thường mở được từ app Gmail; nếu không, dùng nút "Gửi lại" hoặc mở bằng
  trình duyệt điện thoại.
- Đổi scheme/host phải cập nhật **đồng thời** ba nơi: hằng số trong
  `CloudSyncService`, intent-filter trong `AndroidManifest.xml`, và Redirect URLs trong Supabase.
- `Site URL` không được để localhost. Đây là giá trị dự phòng khi redirect không hợp lệ.
- Link xác nhận hết hạn sau thời gian cấu hình của Supabase (mặc định 24 giờ); hết hạn thì
  dùng **Gửi lại email xác nhận**.

## 7. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Link vẫn là localhost | Chưa thêm `mochiapp://auth-callback` vào Redirect URLs | Thêm đúng chuỗi, lưu, đăng ký lại |
| Bấm link mở trình duyệt, không mở app | Manifest thiếu intent-filter hoặc build cũ | Kiểm tra manifest, `flutter clean`, build lại |
| App mở nhưng báo "invalid request" | Code đã dùng/hết hạn, hoặc mở trên thiết bị khác | Gửi lại email, mở trên đúng điện thoại |
| Đăng nhập báo "Email not confirmed" | Chưa bấm link | Bấm **Gửi lại email xác nhận** |
| Web quay về localhost sai cổng | `Uri.base.origin` khác cấu hình | Thêm đúng origin vào Redirect URLs |
