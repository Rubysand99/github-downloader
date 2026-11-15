/// Kết quả chuẩn hoá ô nhập owner/repo.
class RepoRef {
  final String owner;
  final String repo;
  const RepoRef(this.owner, this.repo);
}

// Khớp các dạng: https://github.com/owner/repo(.git)(/...), github.com/owner/repo,
// git@github.com:owner/repo.git, ssh://git@github.com/owner/repo.git ...
final RegExp _githubUrlPattern = RegExp(
  r'^(?:git@github\.com:|(?:https?://|git://|ssh://git@)?(?:www\.)?github\.com[/:])([^/\s]+)/([^/\s?#]+)',
  caseSensitive: false,
);

String _cleanRepoName(String s) {
  var r = s.trim();
  while (r.endsWith('/')) {
    r = r.substring(0, r.length - 1);
  }
  if (r.toLowerCase().endsWith('.git')) {
    r = r.substring(0, r.length - 4);
  }
  return r;
}

/// Chuẩn hoá nội dung 2 ô owner/repo: người dùng hay dán nguyên URL
/// (`https://github.com/owner/repo.git`), dạng `owner/repo`, hoặc tên repo có
/// đuôi `.git` - tất cả đều khiến GitHub API trả 404 nếu đưa thẳng vào đường dẫn.
RepoRef normalizeRepoInput(String owner, String repo) {
  for (final raw in [repo, owner]) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    final m = _githubUrlPattern.firstMatch(s);
    if (m != null) {
      return RepoRef(m.group(1)!, _cleanRepoName(m.group(2)!));
    }
    if (!s.contains('://') && s.contains('/')) {
      final parts = s.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return RepoRef(parts[0], _cleanRepoName(parts[1]));
      }
    }
  }
  return RepoRef(owner.trim(), _cleanRepoName(repo));
}
