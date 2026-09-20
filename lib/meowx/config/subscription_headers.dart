import 'dart:convert';

/// 订阅响应头：`profile-title`（可带 `base64:` 前缀）→ 档案名；`profile-update-interval`（小时，默认 24）。
String? subscriptionTitle(String? header) {
  if (header == null) return null;
  var v = header.trim();
  if (v.isEmpty) return null;
  if (v.toLowerCase().startsWith('base64:')) {
    try {
      v = utf8.decode(base64.decode(base64.normalize(v.substring(7).trim())));
    } catch (_) {
      return null;
    }
  }
  v = v.trim();
  return v.isEmpty ? null : v;
}

Duration subscriptionUpdateInterval(String? header, {int defaultHours = 24}) {
  final h = int.tryParse((header ?? '').trim());
  if (h == null || h <= 0) return Duration(hours: defaultHours);
  return Duration(hours: h);
}
