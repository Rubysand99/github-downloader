import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// Lưu file vào thư mục Download công khai của máy qua code Android gốc (Kotlin),
/// dùng MediaStore API trực tiếp - không phụ thuộc thư viện bên thứ 3 (tránh lỗi
/// xung đột phiên bản compileSdk như đã từng gặp).
class DownloadsService {
  static const _channel = MethodChannel('github_downloader/downloads');

  /// Lý do của lần lưu thất bại GẦN NHẤT (null nếu lần gần nhất thành công).
  /// Trước đây mọi lỗi bị nuốt thành `null` nên người dùng chỉ thấy "không lưu
  /// được file" mà không biết vì sao (hết dung lượng, bị chặn quyền, tên file
  /// không hợp lệ...). Nay lý do được giữ lại để hiện kèm trong thông báo.
  static String? lastError;

  /// Ghi [bytes] ra thư mục Download công khai với tên [fileName].
  /// Trả về tên hiển thị cho người dùng, hoặc null nếu lỗi (xem [lastError]).
  static Future<String?> saveBytes(String fileName, List<int> bytes) async {
    lastError = null;
    try {
      if (!Platform.isAndroid) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$fileName';
        await File(path).writeAsBytes(bytes);
        return path;
      }

      // Đã là Uint8List thì dùng thẳng, tránh nhân đôi dữ liệu trong RAM.
      final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final savedName = await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'bytes': data,
      });
      if (savedName == null) {
        lastError = 'Android không trả về tên file đã lưu';
        return null;
      }
      return 'Download/$savedName';
    } catch (e) {
      lastError = e is PlatformException ? (e.message ?? e.code) : e.toString();
      LogService.instance.error('Lưu file "$fileName" thất bại: $lastError');
      return null;
    }
  }
}
