import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../l10n/strings.dart';
import 'app_settings.dart';
import 'auth_service.dart';
import 'pinned_repos_service.dart';
import 'keep_alive_service.dart';

/// Điều phối tính năng theo dõi CI/CD nền: quyết định danh sách repo cần theo
/// dõi (= các repo đã ghim), đẩy dữ liệu cần thiết (danh sách repo) sang cho
/// TaskHandler chạy trong foreground service (xem keep_alive_service.dart), và
/// bật/tắt service tương ứng qua KeepAliveService. Việc polling GitHub thực sự
/// diễn ra bên trong TaskHandler (isolate riêng), không phải ở đây.
///
/// LƯU Ý BẢO MẬT: token đăng nhập KHÔNG được sao chép sang đây nữa. Trước đây
/// token bị lưu thêm 1 bản dạng chữ thường (qua FlutterForegroundTask.saveData,
/// thực chất là SharedPreferences) trái với việc README cam kết token chỉ nằm
/// trong kho mã hoá. Nay TaskHandler tự đọc token từ kho mã hoá mỗi lần poll.
class CiWatchService {
  static final CiWatchService instance = CiWatchService._internal();
  CiWatchService._internal();

  /// Bật tính năng. Trả false nếu chưa đăng nhập hoặc chưa ghim repo nào
  /// (không có gì để theo dõi) - gọi nơi hiển thị UI có thể dùng để báo lỗi phù hợp.
  ///
  /// [resetBaseline] = true khi NGƯỜI DÙNG vừa tự bật tính năng (từ Cài đặt): xoá
  /// "mốc" các lần chạy đã biết, để các build cũ sẵn có không bị báo dồn. Lúc app
  /// khởi động lại (main.dart) để mặc định false: giữ nguyên mốc, nhờ vậy build
  /// xong trong lúc app đang tắt vẫn được báo khi service chạy lại.
  Future<bool> enable({bool resetBaseline = false}) async {
    final token = await AuthService().getToken();
    final pinned = await PinnedReposService().getPinned();
    if (token == null || pinned.isEmpty) return false;

    final repos = pinned.toList();
    await FlutterForegroundTask.saveData(key: 'ci_watch_enabled', value: 'true');
    await FlutterForegroundTask.saveData(key: 'ci_watch_repos', value: jsonEncode(repos));
    // Dọn bản sao token dạng chữ thường mà các phiên bản cũ đã để lại trên máy.
    await FlutterForegroundTask.saveData(key: 'ci_watch_token', value: '');
    if (resetBaseline) await _resetState();

    await AppSettings.instance.setCiWatchEnabled(true);
    await KeepAliveService.instance.startCiWatch(label: t('ci.watch_label', {'n': '${repos.length}'}));
    return true;
  }

  Future<void> disable() async {
    await FlutterForegroundTask.saveData(key: 'ci_watch_enabled', value: 'false');
    await FlutterForegroundTask.saveData(key: 'ci_watch_token', value: ''); // dọn bản sao token của bản cũ
    await _resetState();
    await AppSettings.instance.setCiWatchEnabled(false);
    await KeepAliveService.instance.stopCiWatch();
  }

  /// Xoá "mốc" các lần chạy đã biết và đổi số phiên bản (epoch). TaskHandler đang
  /// chạy nền thấy epoch đổi sẽ tự nạp lại trạng thái từ kho - cần thiết vì
  /// service có thể vẫn sống (vd đang tải file) và giữ bản cũ trong RAM của nó.
  Future<void> _resetState() async {
    await FlutterForegroundTask.saveData(key: 'ci_known_runs', value: '');
    await FlutterForegroundTask.saveData(key: 'ci_baselined_repos', value: '');
    await FlutterForegroundTask.saveData(key: 'ci_watch_epoch', value: DateTime.now().microsecondsSinceEpoch.toString());
  }

  /// Gọi lại mỗi khi danh sách repo ghim thay đổi (ghim thêm/bỏ ghim) trong lúc
  /// tính năng đang bật, để service theo dõi đúng danh sách mới nhất mà không
  /// cần tắt/bật lại toàn bộ tính năng.
  Future<void> syncWatchedReposIfEnabled() async {
    if (!AppSettings.instance.ciWatchEnabled) return;
    final pinned = await PinnedReposService().getPinned();
    await FlutterForegroundTask.saveData(key: 'ci_watch_repos', value: jsonEncode(pinned.toList()));
  }
}
