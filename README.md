# GitHub Repo Downloader

App Android (Flutter) làm "GitHub trên điện thoại": đăng nhập GitHub, duyệt repo, xem/sửa/xoá/tải file lên (mỗi lần lưu là 1 commit), tải file hoặc cả thư mục dạng zip, xem và điều khiển GitHub Actions (xem log, tải artifact, chạy lại, huỷ), tìm code, xem commit, quản lý release/gist/collaborator/webhook, nhận thông báo GitHub, ghim repo, và nhận thông báo khi build CI của repo đã ghim chạy xong. App có tiếng Việt và tiếng Anh.

## Cấu trúc repo
- `lib/` — toàn bộ code Dart của app.
- `android_custom/` — code Kotlin và file giao diện widget cho Android. Thư mục `android/` **không** nằm trong repo (đã ghi trong `.gitignore`): GitHub Actions tự tạo bằng `flutter create`, rồi chép các file trong `android_custom/` vào.
- `.github/workflows/build_apk.yml` — build APK bản release.
- `.github/workflows/dart.yml` — kiểm tra code (`flutter analyze`), chỉ báo đỏ khi có lỗi thật.
- `SUA_LOI.md` — nhật ký các lần sửa lỗi.
- Server đổi mã đăng nhập (FastAPI) **nằm ở repo riêng**, không có trong repo này.

## Cài đặt từ đầu (chỉ cần làm nếu bạn dựng bản của riêng mình)
1. **Tạo GitHub OAuth App** tại https://github.com/settings/developers → *New OAuth App*. Điền *Authorization callback URL* là `githubdownloader://callback`. Lấy **Client ID**, rồi bấm *Generate a new client secret* để lấy **Client Secret** (chỉ hiện 1 lần, lưu lại ngay).
2. **Deploy server đổi mã đăng nhập** (repo riêng) lên Railway, thêm 2 biến môi trường `GITHUB_CLIENT_ID` và `GITHUB_CLIENT_SECRET`. Server này chỉ có một việc: đổi `code` lấy `access_token`, để `client_secret` không bao giờ nằm trong app.
3. **Điền thông tin vào app**: mở `lib/services/auth_service.dart`, sửa `clientId` và `backendUrl` (không có dấu `/` cuối). Bản trong repo đã điền sẵn giá trị của tác giả.
4. **Tạo secret cho khoá ký APK**: workflow dùng 1 keystore cố định để mọi bản build cài đè lên nhau được. Tạo bằng lệnh (Termux có sẵn `keytool` nếu đã cài JDK):
   ```bash
   keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey \
     -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
   base64 -w0 debug.keystore
   ```
   Dán kết quả vào secret tên `DEBUG_KEYSTORE_BASE64` của repo (Settings → Secrets and variables → Actions).
5. **Đẩy code lên GitHub.** Workflow *Build APK* tự chạy (khoảng 3–5 phút). Khi xong, vào lần chạy đó → mục *Artifacts* → tải `github-downloader-apk`, giải nén rồi cài file `.apk` (cần bật "Cho phép cài từ nguồn không xác định").

## Lưu ý bảo mật
- Token GitHub chỉ lưu trong `flutter_secure_storage` (kho mã hoá của Android). Tính năng theo dõi CI chạy nền cũng đọc token từ kho này mỗi lần kiểm tra, **không** giữ bản sao nào ở nơi lưu chữ thường.
- Đăng xuất sẽ: tắt theo dõi CI nền, làm trống widget màn hình chính, xoá bộ nhớ đệm trong RAM, rồi xoá thông tin đăng nhập. Cài đặt và danh sách repo đã ghim được giữ lại.
- `client_secret` chỉ nằm trên server, không có trong app hay repo này.
- Thu hồi quyền bất cứ lúc nào: GitHub → Settings → Applications → Authorized OAuth Apps → Revoke.
- Repo public duyệt/tải được không cần đăng nhập; repo private cần token.
