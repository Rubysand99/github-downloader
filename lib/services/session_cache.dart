/// Nơi các bộ nhớ đệm (cache) trong RAM tự đăng ký cách xoá mình, để lúc đăng
/// xuất [AuthService.logout] xoá sạch MỌI cache một lượt. Nếu không, danh sách
/// repo/file của tài khoản cũ (kể cả repo private) vẫn nằm trong RAM và có thể
/// hiện ra khi đăng nhập sang tài khoản khác ngay trong cùng phiên chạy app.
class SessionCache {
  static final List<void Function()> _clearers = [];

  /// Gọi 1 lần cho mỗi cache (cache tự gọi khi được ghi dữ liệu lần đầu).
  static void register(void Function() clearer) => _clearers.add(clearer);

  static void clearAll() {
    for (final clear in _clearers) {
      clear();
    }
  }
}
