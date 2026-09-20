/// 与 iOS 端一致的数值格式：字节最小 KB（`%.0f KB / %.1f MB / %.2f GB`），速率 = 字节 + "/s"，时长 `Ns / MmSs / HhMm`。
String fmtSize(num bytes) {
  const kb = 1024.0, mb = kb * 1024, gb = mb * 1024;
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}

String fmtRate(num bytesPerSecond) => '${fmtSize(bytesPerSecond)}/s';

/// 已运行 HH:MM:SS
String fmtUptime(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// 连接持续：Ns / MmSs / HhMm
String fmtElapsed(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m${d.inSeconds % 60}s';
  return '${d.inHours}h${d.inMinutes % 60}m';
}

/// 订阅到期：`expire ≥ 4102444799`（2099-12-31）视为永久。
const permanentExpireThreshold = 4102444799;

bool isPermanentExpire(int expireUnix) => expireUnix >= permanentExpireThreshold;

String fmtDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// 相对时间：刚刚 / N 分钟前 / N 小时前 / N 天前
String fmtRelative(DateTime t, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  return '${diff.inDays} 天前';
}
