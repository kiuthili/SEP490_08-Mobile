# SEP490_08-Mobile — StayHub Flutter

Ứng dụng mobile Android/iOS (Flutter) kết nối backend **StayHub** (C# microservices qua **GatewayAPI**).

## Cấu trúc thư mục `lib/`

```
lib/
├── main.dart              # Khởi tạo DI (GetX), storage, API client
├── app.dart               # GetMaterialApp, theme, routes
├── screens/               # Màn hình full-page
├── widgets/               # UI tái sử dụng
├── models/                # DTO khớp API C#
├── services/              # HTTP (Dio), auth, tour
├── controllers/           # State (GetX)
├── routes/                # Định tuyến
├── utils/                 # Validator, snackbar, format
├── constants/             # API URL, storage keys
└── theme/                 # Màu, typography, ThemeData (iOS 26 / Liquid Glass)
```

## Giao diện (iOS 26)

- **Font:** Inter (`google_fonts`)
- **Nền:** gradient nhẹ, tab bar glass nổi (`IosBottomNav`)
- **Màn push:** `AppScreen` + card bo góc (`IosSurfaceCard`, `IosGroupedSection`)
- **Auth:** hero gradient + form glass (`AuthScaffold`)

## Màn hình & tính năng

| Khu vực | Tính năng |
|---------|-----------|
| Auth | Đăng nhập, đăng ký (ngày sinh), Google, quên/đổi mật khẩu, sửa hồ sơ |
| Trang chủ | Banner, danh sách tour, tải thêm |
| Khám phá | Tìm kiếm, lọc thành phố/danh mục, **khảo sát AI**, gợi ý tour |
| Pháp lý | **Điều khoản dịch vụ**, **Chính sách quyền riêng tư** (nội dung khớp web) |
| Theo dõi công khai | `/track/:token` — bản đồ + SignalR live (không cần đăng nhập) |
| Tour | Chi tiết, lịch trình, hành trình, đánh giá, wishlist, đặt tour |
| Đặt tour | Nhiều hành khách, voucher, **VNPay/MoMo** |
| Đơn hàng | Lọc trạng thái, phân trang, thanh toán, hủy, vé **QR** |
| Xã hội | Bạn bè, moments, chat SignalR, nhóm tour, bản đồ, chia sẻ moment |
| Staff | Lịch trình, check-in QR, khách & vị trí live |
| Hồ sơ | Thông báo, wishlist, voucher, vé của tôi, trợ lý AI, social map |

## Cấu hình API

| Backend | Gateway URL |
|---------|-------------|
| **Docker** (`docker/scripts/deploy.sh`) | `http://localhost:7010` (mặc định app) |
| **dotnet run** Gateway local | `http://localhost:5046` |

| Mobile | Base URL (Docker) |
|--------|-------------------|
| Linux desktop | `http://127.0.0.1:7010` |
| Android Emulator | `http://10.0.2.2:7010` |
| Thiết bị thật | `http://<IP-máy-dev>:7010` |

Ghi đè khi build:

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:7010
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:7010
flutter run --dart-define=GOOGLE_CLIENT_ID=<web-client-id-oauth>
```

**Lưu ý:** Chạy **GatewayAPI** và các microservice (Auth, Tour, …) trước khi test app. `AndroidManifest` đã bật `usesCleartextTraffic` cho HTTP local.

## Chạy dự án

1. Cài [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Sau khi cài Android SDK (mục bên dưới), sửa `android/local.properties`:
   - `sdk.dir=/home/<user>/Android/Sdk` (đường dẫn thật)
   - `flutter.sdk=/home/<user>/flutter`
3. Thêm Flutter vào PATH (một lần): `export PATH="$HOME/flutter/bin:$PATH"` trong `~/.zshrc`
4. Trong thư mục dự án:

```bash
source tool/flutter_env.sh   # bắt buộc nếu gặp lỗi disk quota trên /tmp
flutter pub get
chmod +x tool/setup_linux.sh tool/run_linux.sh tool/run_android.sh
./tool/run_linux.sh          # Linux desktop (cách 3)
# ./tool/run_android.sh      # Android emulator / thiết bị
```

### Chạy trên Linux desktop (cách 3)

1. Cài toolchain (một lần):

```bash
./tool/setup_linux.sh
```

2. Backend Docker đã chạy (gateway `http://localhost:7010`).

3. Chạy app:

```bash
source tool/flutter_env.sh
./tool/run_linux.sh
```

API mặc định khi **backend Docker** đã chạy: `http://127.0.0.1:7010` (`./tool/run_linux.sh` tự nhận nếu gateway trả lời).

Chỉ dùng `5046` khi bạn chạy Gateway bằng `dotnet run` local (không Docker).

**Lưu ý Linux:** Google Sign-In, quét QR (`mobile_scanner`), GPS có thể không hoạt động đủ; đăng nhập email/mật khẩu và duyệt tour vẫn test được.

Hoặc chỉ định thiết bị:

```bash
flutter devices
# -d android chọn thiết bị Android đầu tiên; hoặc -d <device_id> từ flutter devices
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5046
```

### `Unable to find any emulator sources` / không có AVD

`flutter doctor` báo **Unable to locate Android SDK** → máy chưa cài SDK/emulator, không phả lỗi code app.

**Cách 1 — Android Studio (dễ nhất):**

1. Tải [Android Studio](https://developer.android.com/studio) và cài trên Ubuntu.
2. Mở **SDK Manager** → cài **Android SDK Platform** (API 34+) và **Android Emulator**.
3. **Device Manager → Create Virtual Device** (ví dụ Pixel 7, API 34, x86_64).
4. Cấu hình Flutter:

```bash
flutter config --android-sdk "$HOME/Android/Sdk"
```

5. Sửa `android/local.properties`:

```properties
sdk.dir=/home/kiuthi/Android/Sdk
flutter.sdk=/home/kiuthi/flutter
```

6. Kiểm tra:

```bash
source tool/flutter_env.sh
chmod +x tool/check_android.sh
./tool/check_android.sh
flutter emulators --launch Pixel_7_API_34
./tool/run_android.sh
```

**Cách 2 — Điện thoại thật (USB):** Bật **Developer options → USB debugging**, cắm USB, `flutter devices` phải thấy thiết bị. API URL dùng IP máy dev (không dùng `10.0.2.2`):

```bash
flutter run -d RZ8M1234567 --dart-define=API_BASE_URL=http://192.168.1.10:5046
```

(Thay `RZ8M...` bằng device id từ `flutter devices`, IP bằng IP LAN máy bạn.)

**Tạm thời (chưa cài Android):** Chỉ có **Linux desktop** — cần `clang`, `libgtk-3-dev` (xem mục dưới). Một số tính năng (camera, QR, Google Sign-In) có thể không chạy đủ trên Linux.

### Lỗi `Could not find compiler ... CXX: clang++` (build Linux)

`flutter run` không có `-d` sẽ chọn **Linux desktop** nếu không có emulator Android. CMake báo lỗi khi biến môi trường `CXX=clang++` nhưng chưa cài `clang`.

**Cách 1 — chạy Android (đúng mục tiêu mobile):**

```bash
flutter emulators
# Copy ID thật từ cột id (ví dụ Pixel_7_API_34), KHÔNG gõ chữ <id>:
flutter emulators --launch Pixel_7_API_34
./tool/run_android.sh
```

**Cách 2 — sửa build Linux:**

```bash
sudo apt install clang build-essential ninja-build libgtk-3-dev
# hoặc bỏ ép compiler:
unset CXX
./tool/run_linux.sh
```

Docker: API `http://127.0.0.1:7010`. `10.0.2.2` chỉ dành cho Android emulator.

### Lỗi `Disk quota exceeded` (errno 122)

Pub mặc định tải package qua `/tmp`. Nếu partition `/tmp` hoặc home đầy, chạy:

```bash
source tool/flutter_env.sh
flutter pub get
```

Script đặt `TMPDIR` và `PUB_CACHE` vào `Mobile/.tmp` và `Mobile/.pub-cache` (ngoài `/tmp`).

Gợi ý giải phóng dung lượng: xóa file cài đặt cũ không dùng (ví dụ `~/flutter_linux_*.tar.xz`), dọn `~/.pub-cache` cũ nếu trùng.

Nếu thiếu file platform (lần đầu trên máy mới):

```bash
source tool/flutter_env.sh
flutter create . --project-name stayhub_mobile --org com.stayhub
```

## Dependencies chính

- **get** — routing + controllers
- **dio** — HTTP + Bearer token + refresh token
- **get_storage** — lưu JWT local
- **cached_network_image** — ảnh tour từ API

## Mở rộng API

Thêm service trong `lib/services/`, model trong `lib/models/`, endpoint trong `lib/constants/api_constants.dart` (theo route YARP trong `GatewayAPI/appsettings.json`).
