import 'dart:convert';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../l10n/strings.dart';
import 'log_service.dart';
import 'ci_watch_service.dart';
import 'session_cache.dart';
import 'widget_service.dart';

class AuthService {
  static const String clientId = 'Ov23liXVhIzWQiZDPVmF';

  static const String backendUrl = 'https://oauth-backend-production-99e7.up.railway.app';

  // Tên các khoá lưu thông tin đăng nhập trong kho mã hoá. logout() chỉ xoá đúng
  // những khoá này (không xoá cài đặt, repo đã ghim... lưu cùng kho).
  static const _kToken = 'github_token';
  static const _kUsername = 'github_username';
  static const _kEmail = 'github_email';

  static const String callbackScheme = 'githubdownloader';
  static const String redirectUri = '$callbackScheme://callback';

  final _storage = const FlutterSecureStorage();

  /// Mở trình duyệt để user đăng nhập GitHub, sau đó đổi code lấy access token
  /// thông qua backend (client_secret không bao giờ nằm trong app).
  /// Trả về null nếu thành công, hoặc chuỗi mô tả lỗi nếu thất bại.
  Future<String?> login() async {
    LogService.instance.info('Bắt đầu đăng nhập GitHub OAuth');
    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'repo user:email notifications delete_repo gist user:follow',
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) {
        LogService.instance.error('Đăng nhập thất bại: không nhận được code từ GitHub');
        return t('login.err_no_code', {'url': result});
      }

      final response = await http.post(
        Uri.parse('$backendUrl/oauth/callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode != 200) {
        final location = response.headers['location'] ?? '-';
        LogService.instance.error(
          'Đăng nhập thất bại: backend trả mã ${response.statusCode}, location=$location',
        );
        return t('login.err_backend', {'code': '${response.statusCode}', 'location': location, 'body': response.body});
      }

      final data = jsonDecode(response.body);
      final token = data['access_token'];
      if (token == null) {
        LogService.instance.error('Đăng nhập thất bại: backend không trả access_token');
        return t('login.err_no_token', {'body': response.body});
      }

      await _storage.write(key: _kToken, value: token);

      // Lấy username + email thật từ GitHub, khỏi cần user tự nhập
      final userInfo = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (userInfo.statusCode == 200) {
        final user = jsonDecode(userInfo.body);
        await _storage.write(key: _kUsername, value: user['login'] ?? '');
        await _storage.write(key: _kEmail, value: user['email'] ?? '');
        LogService.instance.info('Đăng nhập thành công: user=${user['login']}');
      } else {
        LogService.instance.warn('Đăng nhập thành công nhưng không lấy được thông tin user (mã ${userInfo.statusCode})');
      }

      return null;
    } catch (e) {
      LogService.instance.error('Đăng nhập lỗi: $e');
      return t('common.error_prefix', {'error': '$e'});
    }
  }

  Future<String?> getToken() => _storage.read(key: _kToken);
  Future<String?> getUsername() => _storage.read(key: _kUsername);
  Future<String?> getEmail() => _storage.read(key: _kEmail);

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  /// Đăng xuất SẠCH: tắt theo dõi CI nền (kèm xoá dữ liệu nó giữ), xoá widget màn
  /// hình chính, xoá cache trong RAM, rồi mới xoá thông tin đăng nhập.
  ///
  /// Trước đây hàm này gọi `_storage.deleteAll()` nên xoá LUÔN cả cài đặt app và
  /// danh sách repo đã ghim (cùng nằm trong kho mã hoá này), còn dịch vụ theo dõi
  /// CI nền thì không bị tắt và vẫn chạy tiếp với token cũ. Giờ chỉ xoá đúng 3
  /// khoá đăng nhập.
  Future<void> logout() async {
    LogService.instance.info('Đăng xuất');
    // Mỗi bước tự bắt lỗi riêng: 1 bước hỏng không được chặn việc xoá token.
    try {
      await CiWatchService.instance.disable();
    } catch (e) {
      LogService.instance.warn('Đăng xuất: không tắt được theo dõi CI: $e');
    }
    try {
      await WidgetService.clear();
    } catch (e) {
      LogService.instance.warn('Đăng xuất: không xoá được widget: $e');
    }
    SessionCache.clearAll();
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kEmail);
  }
}
