# Hướng dẫn test AI trên APK nội bộ

Tài liệu này dành cho việc tự test trên điện thoại Android, không phát hành Google Play. APK gửi câu hỏi đến gateway chạy trên máy tính; gateway gọi Gemini. Gemini API key không được đóng gói vào APK.

## Cần chuẩn bị

- Windows có Flutter và Node.js 22.
- Điện thoại Android có Internet. USB debugging chỉ cần nếu muốn dùng `flutter run` và hot reload trực tiếp.
- `cloudflared` đã cài (cách cài ở mục bên dưới).
- Tài khoản Supabase đang dùng để đăng nhập app.
- Gemini API key tạo trong [Google AI Studio → API Keys](https://aistudio.google.com/app/apikey): đăng nhập Google → **Create API key** → chọn/tạo project → sao chép key. Tài khoản mới có thể được AI Studio tạo project và key mặc định.

> Bản Gemini API Free có quota theo model và có thể thay đổi. Ở cấu hình hiện tại, gateway mặc định dùng `gemini-3.8-flash`, dự phòng bằng `gemini-3.5-flash-lite`. Có thể đổi bằng hai biến `GEMINI_PRIMARY_MODEL` và `GEMINI_FALLBACK_MODEL` trong file môi trường.

## Cài `cloudflared` trên Windows

Mở PowerShell và chạy:

```powershell
winget install --id Cloudflare.cloudflared
```

Đóng rồi mở lại PowerShell, kiểm tra đã cài được:

```powershell
cloudflared --version
```

Nếu máy báo không tìm thấy `winget`, tải **MSI 64-bit** từ [trang tải chính thức của Cloudflare](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/), cài đặt, mở lại PowerShell rồi chạy lệnh kiểm tra phía trên.

## 1. Tạo file cấu hình riêng trên máy

Mở PowerShell tại thư mục gốc dự án (nơi có `ProjectOverview.md`) và tạo thư mục lưu cấu hình bên ngoài repository:

```powershell
$configDir = Join-Path $env:LOCALAPPDATA 'Mochii'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$envFile = Join-Path $configDir 'gateway.env'
notepad $envFile
```

Dán nội dung sau, rồi thay ba giá trị Supabase/Gemini bằng thông tin dự án của bạn:

```dotenv
PORT=8897
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
GEMINI_PRIMARY_MODEL=gemini-3.8-flash
GEMINI_FALLBACK_MODEL=gemini-3.5-flash-lite
```

Lấy `SUPABASE_URL` và publishable key từ cùng dự án Supabase mà bản app đang dùng. Để file này ngoài thư mục mã nguồn, không commit hoặc gửi file có API key cho người khác.

## Khởi chạy nhanh bằng file `.bat`

Sau khi đã tạo `gateway.env`, bạn có thể chạy các script trong `05-operations` thay cho việc tự gõ lệnh:

1. Mở `run-ai-gateway.bat`; giữ cửa sổ mở.
2. Mở `run-ai-tunnel.bat`; đợi URL `https://....trycloudflare.com` hiện ra và giữ cửa sổ mở.
3. Muốn test Chrome: mở `run-ai-chrome.bat`, dán URL tunnel khi được hỏi.
4. Muốn gửi APK cho điện thoại ở xa: mở `build-ai-apk.bat`, dán URL tunnel. APK được tạo tại `02-source/flutter-app/build/app/outputs/flutter-apk/app-debug.apk`.

Nếu tunnel đã dừng và khởi động lại, URL sẽ đổi; mở lại script Chrome/build APK và nhập URL mới. Không cần cắm điện thoại vào laptop để build APK.

## 2. Chạy gateway

Mở PowerShell thứ nhất:

```powershell
cd .\02-source\ai-gateway
node --env-file="$env:LOCALAPPDATA\Mochii\gateway.env" server.mjs
```

Giữ cửa sổ này mở. Gateway lắng nghe tại `127.0.0.1:8897`.

## 3. Mở gateway qua HTTPS tạm thời

Mở PowerShell thứ hai:

```powershell
cloudflared tunnel --url http://127.0.0.1:8897
```

Trong kết quả, tìm URL dạng `https://ten-ngau-nhien.trycloudflare.com`. Gán URL đó vào biến sau, thêm `/mochi-ai` ở cuối:

```powershell
$aiGateway = 'https://ten-ngau-nhien.trycloudflare.com/mochi-ai'
Invoke-RestMethod "$aiGateway/health"
```

Kết quả đúng là `status: ready`. Giữ cả hai cửa sổ PowerShell mở trong suốt lúc test. Quick Tunnel không cần domain riêng, nhưng URL sẽ đổi mỗi lần tạo tunnel mới và ngừng hoạt động khi tắt `cloudflared`.

## Chạy trên Chrome

Chrome áp dụng CORS; gateway mặc định đã cho phép hai origin dev ở cổng `8600`. Nếu file `gateway.env` của bạn có dòng `ALLOWED_ORIGINS`, thêm các origin này vào danh sách và khởi động lại gateway:

```dotenv
ALLOWED_ORIGINS=https://bendocs.tailc1f51b.ts.net,http://127.0.0.1:8600,http://localhost:8600
```

Mở PowerShell mới tại thư mục gốc dự án, dán URL tunnel thật rồi chạy:

```powershell
cd .\02-source\flutter-app
$aiGateway = 'https://ten-ngau-nhien.trycloudflare.com/mochi-ai'
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8600 "--dart-define=MOCHI_AI_GATEWAY=$aiGateway"
```

Đăng nhập app trên Chrome rồi thử AI Tutor. Nếu đổi port Chrome, phải thêm chính xác origin mới vào `ALLOWED_ORIGINS` và khởi động lại gateway. Nhớ truyền `MOCHI_AI_GATEWAY`; nếu bỏ qua, app web trên localhost sẽ dùng proxy `/mochi-ai` cùng origin thay vì URL tunnel.

## 4. Chạy app trên điện thoại gần laptop (hot reload)

Trong PowerShell thứ ba, dán lại URL vừa nhận được ở cửa sổ `cloudflared` (biến PowerShell không tự dùng chung giữa các cửa sổ):

```powershell
cd .\02-source\flutter-app
$aiGateway = 'https://ten-ngau-nhien.trycloudflare.com/mochi-ai'
flutter devices
$deviceId = 'ID-cua-dien-thoai'
flutter run -d $deviceId "--dart-define=MOCHI_AI_GATEWAY=$aiGateway"
```

Thay URL mẫu và `$deviceId` bằng giá trị thật. Nếu chỉ có một thiết bị kết nối, bỏ `-d $deviceId`. Đợi app cài và mở trên điện thoại, sau đó đăng nhập tài khoản Supabase.

Khi điện thoại cắm USB vào laptop, `flutter run` cho phép hot reload: nhấn `r` sau khi sửa giao diện hoặc mã Dart.

## 5. Cài APK lên điện thoại ở xa laptop

Điện thoại **không cần cùng Wi-Fi, không cần kết nối USB**. Quick Tunnel đưa cổng gateway trên laptop ra một URL HTTPS Internet; APK gọi URL đó từ bất cứ mạng nào. Laptop phải bật, có Internet, và cả gateway lẫn `cloudflared` phải đang chạy.

Mở PowerShell mới tại thư mục gốc dự án, dán URL do `cloudflared` in ra rồi build APK có nhúng URL đó:

```powershell
cd .\02-source\flutter-app
$aiGateway = 'https://ten-ngau-nhien.trycloudflare.com/mochi-ai'
flutter build apk --debug "--dart-define=MOCHI_AI_GATEWAY=$aiGateway"
```

Gửi file `build\app\outputs\flutter-apk\app-debug.apk` đến điện thoại qua cách chuyển file bạn tin cậy, mở file đó và cho phép cài APK nếu Android hỏi. Sau khi cài, đăng nhập app bằng tài khoản Supabase.

Vì thiết bị ở xa không kết nối với `flutter run`, mỗi lần sửa app cần build APK mới rồi chuyển/cài lại. Nếu tắt và mở lại Quick Tunnel, URL thường đổi; khi đó phải build APK với URL mới. Nếu chỉ sửa gateway mà giữ URL tunnel, không cần build lại app.

Không gửi URL tunnel công khai. URL có thể truy cập từ Internet; gateway vẫn kiểm tra JWT đăng nhập Supabase, nhưng đây chỉ là đường tạm để test, không phải endpoint phát hành.

## 6. Kiểm tra các tính năng AI

Đăng nhập trước, rồi thử lần lượt:

- **AI Tutor:** gửi một câu hỏi và kiểm tra câu trả lời.
- **Planner:** dùng “AI chia nhỏ việc” cho một mục tiêu.
- **Học tập cá nhân:** thử “Nhập TKB bằng AI” bằng văn bản; có thể thử ảnh nếu thiết bị hỗ trợ chọn ảnh.
- **Ôn tập:** thử tạo quiz/flashcard hoặc giải thích nội dung AI ở màn hình ôn tập.

Gateway xác thực JWT Supabase trước khi gọi Gemini. Không cần mở CORS riêng cho request native từ APK. Nội dung gửi lên Gemini Free có thể được Google dùng để cải thiện sản phẩm; khi test, nên dùng dữ liệu giả hoặc không nhạy cảm. Xem [quota và chính sách Free tier](https://ai.google.dev/gemini-api/docs/pricing).

## Gỡ lỗi nhanh

| Hiện tượng | Kiểm tra |
|---|---|
| `health` không trả `ready` | Gateway đã chạy chưa; URL tunnel và hậu tố `/mochi-ai` có đúng không. |
| App log `MOCHI_AI unavailable reason=network` | Mở `https://<URL-tunnel>/mochi-ai/health` trên cả laptop và điện thoại. Nếu một bên không ra `status: ready`, kiểm tra gateway/tunnel và Internet. Nếu cả hai đều ra `ready`, dừng `flutter run` rồi chạy lại với đúng `--dart-define=MOCHI_AI_GATEWAY=...`; hot reload không cập nhật URL đã nhúng. |
| App báo cần đăng nhập/phiên hết hạn | Đăng nhập lại trong app bằng tài khoản Supabase của dự án đang cấu hình ở gateway. |
| Gateway báo `ai_unconfigured` | `GEMINI_API_KEY`, `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` trong `gateway.env` đã đúng chưa; sau khi sửa cần khởi động lại gateway. |
| Gateway trả `ai_capacity_reached` | Có thể đã chạm giới hạn của gateway hoặc quota Gemini Free; thử lại sau và xem quota trong AI Studio. |
| Gateway trả `ai_request_failed` | Kiểm tra model ID trong `gateway.env`, API key và log ở cửa sổ chạy gateway. |
| App vẫn gọi host cũ | Chạy lại `flutter run` hoặc build APK với `--dart-define=MOCHI_AI_GATEWAY=...` chứa URL tunnel hiện tại. |

## Giới hạn của cách test này

- Chỉ phù hợp test cá nhân/nội bộ; URL Quick Tunnel là tạm thời và người biết URL có thể gửi request đến gateway. Gateway vẫn yêu cầu JWT Supabase và áp dụng giới hạn lượt gọi.
- Không dùng làm dịch vụ production hoặc APK phát hành rộng.
- Tắt gateway hoặc `cloudflared` thì AI trên APK sẽ không kết nối được.
- Đây chỉ thay provider ở gateway; luồng đăng nhập, prompt, kiểm tra dữ liệu và cách app xử lý kết quả vẫn giữ nguyên.
