# 📱 App iPhone Sweetgram

App mở thẳng trang **susosweet.levals.org** (cập nhật web là app cập nhật theo, không phải build lại), thêm:

- **Widget màn hình chính** (nhỏ / vừa / lớn): ảnh mới nhất của người ấy + số ngày bên nhau, tự làm mới mỗi ~15 phút và mỗi lần bạn thoát app. Cần **iOS 17** trở lên.
- **Thông báo đẩy kiểu app thật** (APNs) — chắc chắn hơn thông báo web.

Có 2 cách cài. Cả hai đều cần một **tài khoản Apple Developer (99 USD/năm)** để có widget + thông báo ổn định. Apple ID miễn phí chỉ dùng được cách B, app hết hạn sau 7 ngày, không có thông báo đẩy, và widget có thể không chạy (Apple hạn chế App Group với tài khoản miễn phí).

---

## Cách A — Không cần Mac: GitHub Actions build giúp → cài qua TestFlight

### 1. Chuẩn bị bên Apple (làm 1 lần)

1. Đăng ký **Apple Developer Program** tại developer.apple.com (99 USD/năm).
2. Lấy **Team ID**: developer.apple.com → Account → Membership details → *Team ID* (10 ký tự).
3. Tạo **khoá API App Store Connect**: appstoreconnect.apple.com → Users and Access → **Integrations** → App Store Connect API → ➕ → quyền **Admin** → tải file `AuthKey_XXXXXXXXXX.p8` (chỉ tải được 1 lần). Ghi lại **Key ID** và **Issuer ID** ở cùng trang.
4. Tạo **app** trên App Store Connect: Apps → ➕ New App → iOS · tên `Sweetgram` · Bundle ID `org.levals.sweetgram` (nếu chưa có trong danh sách: developer.apple.com → Identifiers → ➕ App IDs → nhập đúng `org.levals.sweetgram`, tích **App Groups** và **Push Notifications**).
   Muốn dùng bundle ID khác thì sửa `appId` trong `sweetgram.json`.

### 2. Đưa thư mục `ios-app` lên GitHub

1. Tạo repo **riêng tư** (private) mới trên github.com, ví dụ `sweetgram-ios`.
2. Tải toàn bộ nội dung thư mục `ios-app/` lên repo (kéo thả trên web GitHub cũng được — nhớ thư mục ẩn `.github/`).
3. Repo → Settings → Secrets and variables → **Actions** → New repository secret, thêm 4 mục:

| Tên | Giá trị |
|---|---|
| `APPLE_TEAM_ID` | Team ID (bước 1.2) |
| `ASC_KEY_ID` | Key ID (bước 1.3) |
| `ASC_ISSUER_ID` | Issuer ID (bước 1.3) |
| `ASC_KEY_P8` | Mở file `.p8` bằng Notepad, dán **toàn bộ** nội dung (cả dòng BEGIN/END) |

### 3. Build

Repo → tab **Actions** → **iOS** → **Run workflow**. Khoảng 10–20 phút. Xong thì bản build xuất hiện trong App Store Connect → TestFlight (Apple xử lý thêm ~10 phút).

### 4. Cài lên 2 iPhone

1. App Store Connect → Users and Access → mời Apple ID của người ấy làm thành viên (vai trò *Developer* hoặc *Marketing* là đủ).
2. TestFlight → **Internal Testing** → ➕ nhóm → thêm cả hai.
3. Trên iPhone: cài app **TestFlight** từ App Store → mở thư mời → **Install**.
4. Mở Sweetgram, đăng nhập. Giữ tay trên màn hình chính → ➕ → tìm **Sweetgram** → thêm widget.

Bản TestFlight dùng được 90 ngày; chạy lại workflow là có bản mới (tự cập nhật qua TestFlight).

### 5. Bật thông báo đẩy từ máy chủ

1. developer.apple.com → Keys → ➕ → tích **Apple Push Notifications service (APNs)** → tải `AuthKey_YYYYYYYYYY.p8`.
2. Chép file lên máy chủ, ví dụ `/www/wwwroot/locket10/server/storage/apns.p8` (`chmod 600`, chủ sở hữu `www`).
3. Thêm vào `/www/wwwroot/locket10/server/.env`:
   ```
   LOCKET_APNS_KEY_FILE=/www/wwwroot/locket10/server/storage/apns.p8
   LOCKET_APNS_KEY_ID=YYYYYYYYYY
   LOCKET_APNS_TEAM_ID=<Team ID>
   LOCKET_APNS_TOPIC=org.levals.sweetgram
   ```
4. Supervisor → Restart `locket-octane`. Mở app trên iPhone → cho phép thông báo.

---

## Cách B — Có Mac: cài thẳng bằng Xcode

1. Cài **Xcode** (App Store) và **Node.js** (nodejs.org).
2. Mở Terminal trong thư mục `ios-app`:
   ```
   bash scripts/mac-run.sh
   ```
   (Apple ID miễn phí: `SWEETGRAM_PUSH=0 bash scripts/mac-run.sh`)
3. Xcode mở ra → bấm lần lượt target **App** và **SweetWidget** → *Signing & Capabilities* → **Team** = tài khoản của bạn.
4. Cắm iPhone, chọn iPhone ở thanh trên → bấm ▶︎. Lần đầu trên iPhone: Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị → tin cậy nhà phát triển.

---

## Cách C — IPA chưa ký để sideload (không cần tài khoản Apple trả phí)

Hợp khi bạn muốn tự cài bằng **AltStore / Sideloadly** mà không mua tài khoản Developer 99 USD. Lưu ý: Apple ID miễn phí thì app **hết hạn sau 7 ngày** (mở lại Sideloadly/AltStore ký lại là dùng tiếp), **không có thông báo đẩy**, và **widget có thể không chạy** (Apple chặn App Group với tài khoản miễn phí). App vẫn mở thẳng trang web nên dùng bình thường.

### 1. Lấy file .ipa (GitHub build giúp, không cần Mac)

1. Đưa thư mục `ios-app/` lên một repo GitHub (như Cách A, nhớ cả thư mục ẩn `.github/`). **Không cần** thêm secrets nào.
2. Repo → tab **Actions** → **iOS IPA (sideload)** → **Run workflow**. Đợi ~15–25 phút.
3. Mở lần chạy vừa xong → kéo xuống mục **Artifacts** → tải **Sweetgram-ipa** (giải nén ra file `Sweetgram-unsigned.ipa`).

*(Có Mac thì build thẳng: `SWEETGRAM_PUSH=0 bash scripts/mac-run.sh` rồi Product → Archive, hoặc chạy các lệnh trong `.github/workflows/ios-ipa.yml`.)*

### Có chứng chỉ xịn (tài khoản Developer trả phí) — IPA ký thật, dùng ~1 năm

Dùng workflow **iOS IPA (đã ký)** (cần 4 secrets giống Cách A) để xuất `.ipa` đã ký:
1. Đăng ký UDID iPhone: developer.apple.com → **Devices** → ➕ (lấy UDID bằng Finder → chọn iPhone → bấm vào dòng Serial đến khi hiện UDID, hoặc dùng iMazing).
2. Actions → **iOS IPA (đã ký)** → Run workflow → chọn **development** (máy đã đăng ký) hoặc **ad-hoc** (tối đa 100 máy) → tải artifact **Sweetgram-ipa-signed**.
3. Cài file `.ipa` đó qua **Apple Configurator** (Mac), **Finder** (kéo IPA vào iPhone), hoặc Sideloadly/AltStore. Không bị hết hạn 7 ngày — dùng tới khi chứng chỉ hết hạn (~1 năm), và **có đủ widget + thông báo đẩy**.

*(Hoặc đơn giản nhất: dùng Cách A đẩy lên TestFlight, cài qua app TestFlight, tự cập nhật, không cần cáp.)*

### 2. Cài lên iPhone bằng Sideloadly (Windows/Mac)

1. Tải **Sideloadly** ở sideloadly.io, cài trên máy tính. (Hoặc **AltStore** nếu bạn quen.)
2. Cắm iPhone bằng cáp, mở Sideloadly.
3. Kéo file `Sweetgram-unsigned.ipa` vào Sideloadly, nhập **Apple ID** của bạn (nên tạo Apple ID phụ để sideload). Bấm **Start** → Sideloadly tự ký bằng Apple ID đó rồi cài vào máy.
4. Trên iPhone: **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị** → chọn Apple ID của bạn → **Tin cậy**.
5. Mở **Sweetgram**, đăng nhập.

App dùng Apple ID miễn phí hết hạn sau 7 ngày → mở lại Sideloadly, bấm ký lại là tiếp tục (AltStore có thể tự ký lại khi cùng mạng Wi-Fi). Muốn khỏi lo hết hạn và có đủ widget + thông báo đẩy thì dùng **Cách A** (TestFlight, tài khoản trả phí).

---

## Bản 11.5 — Live Activity, widget màn hình khoá, Chia sẻ vào Sweetgram

Build lại như bình thường (GitHub Actions hoặc Xcode) — `scripts/setup-ios.rb` tự thêm:
- target **ShareExt** (`org.levals.sweetgram.share`): hiện "Sweetgram" trong bảng Chia sẻ của app Ảnh / Safari;
- **Live Activity** (`NSSupportsLiveActivities`) + **widget màn hình khoá** trong target SweetWidget.

Bên Apple, thêm 1 lần: developer.apple.com → Identifiers → ➕ App IDs → `org.levals.sweetgram.share`, tích **App Groups** và chọn nhóm `group.org.levals.sweetgram` (giống app và widget). Dùng Cách A thì GitHub Actions tự tạo hồ sơ ký cho cả 3 target.

Trên iPhone:
- Widget màn hình khoá: giữ màn hình khoá → Tuỳ chỉnh → Màn hình khoá → thêm widget **Sweetgram · màn hình khoá** (tròn / chữ nhật / một dòng).
- Live Activity tự hiện khi đang chơi caro với nhau, đang xem chung, đang nghe nhạc chung; đếm ngược ngày gặp: Gặp nhau → **📌 Ghim đếm ngược**. Nếu không thấy: Cài đặt → Sweetgram → **Live Activities** bật. (iOS giữ một Live Activity tối đa ~8 giờ — ghim lại khi cần.)
- Chia sẻ: trong app Ảnh chọn ảnh/video → Chia sẻ → **Sweetgram** → app tự mở màn đăng với các ảnh đó.

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Workflow lỗi "No profiles for 'org.levals.sweetgram'…" | Khoá API phải có quyền **Admin**; Bundle ID đã tạo (bước 1.4). |
| Workflow lỗi "app record not found" khi đẩy lên | Chưa tạo app trong App Store Connect (bước 1.4) hoặc Bundle ID khác `appId`. |
| Widget báo "Mở Sweetgram để bật widget" | Mở app, đăng nhập, đợi vài giây; hoặc Cài đặt trong app → Widget → Làm mới. |
| Widget không có trong danh sách | Cần iOS 17+; khởi động lại iPhone sau khi cài lần đầu. |
| App mở ra trang trắng | Kiểm tra web chạy bình thường trên Safari; `url` trong `sweetgram.json` đúng địa chỉ. |
