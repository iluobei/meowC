// 用户覆写（绕过代理 / DNS 劫持 / 推送直连）的校验、归一化与规则生成——纯函数，可单测。
// 文案与 iOS 端一致。

const overridesLimit = 1000;
const overridesLimitMessage = '最多 1000 条';
const domainInvalidMessage = '域名格式不合法（示例：example.com、+.example.com、*.example.com）';
const cidrInvalidMessage = 'IP / CIDR 格式不合法（示例：1.2.3.4、10.0.0.0/8、2001:db8::/32）';
const ipv4InvalidMessage = 'IPv4 地址不合法';
const fakeIpRangeMessage = '不能使用 fake-ip 段 198.18.0.0/16 内的地址';

final _label = RegExp(r'^(\*|[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)$');

/// 归一化：trim + 小写 + 去尾点；剥 `+.` / `.` 前缀（`*.` 不剥）。返回 null 表示不合法。
String? normalizeDomain(String input) {
  var d = input.trim().toLowerCase();
  while (d.endsWith('.')) {
    d = d.substring(0, d.length - 1);
  }
  var prefix = '';
  if (d.startsWith('+.')) {
    prefix = '+.';
    d = d.substring(2);
  } else if (d.startsWith('.')) {
    prefix = '+.';
    d = d.substring(1);
  } else if (d.startsWith('*.')) {
    prefix = '*.';
    d = d.substring(2);
  }
  if (d.isEmpty || d.length > 253) return null;
  final labels = d.split('.');
  if (labels.any((l) => l.isEmpty || l.length > 63 || !_label.hasMatch(l))) return null;
  return '$prefix$d';
}

String? validateDomain(String input) => normalizeDomain(input) == null ? domainInvalidMessage : null;

bool _isIPv4(String s) {
  final p = s.split('.');
  if (p.length != 4) return false;
  for (final x in p) {
    if (x.isEmpty || x.length > 3) return false;
    final n = int.tryParse(x);
    if (n == null || n < 0 || n > 255 || (x.length > 1 && x.startsWith('0'))) return false;
  }
  return true;
}

bool _isIPv6(String s) {
  if (!s.contains(':') || s.contains(':::')) return false;
  final dbl = '::'.allMatches(s).length;
  if (dbl > 1) return false;
  final groups = s.split(':');
  if (groups.length > 8 || (dbl == 0 && groups.length != 8)) return false;
  final hex = RegExp(r'^[0-9a-fA-F]{1,4}$');
  for (var i = 0; i < groups.length; i++) {
    final g = groups[i];
    if (g.isEmpty) {
      if (dbl == 0) return false;
      continue;
    }
    if (i == groups.length - 1 && g.contains('.')) {
      if (!_isIPv4(g)) return false;
      continue;
    }
    if (!hex.hasMatch(g)) return false;
  }
  return true;
}

/// IP 或 CIDR；返回归一化后的字符串（小写、无空白），不合法返回 null。
String? normalizeCidr(String input) {
  final s = input.trim().toLowerCase();
  if (s.isEmpty) return null;
  final slash = s.indexOf('/');
  final ip = slash == -1 ? s : s.substring(0, slash);
  final prefix = slash == -1 ? null : int.tryParse(s.substring(slash + 1));
  if (_isIPv4(ip)) {
    if (prefix != null && (prefix < 0 || prefix > 32)) return null;
    if (slash != -1 && prefix == null) return null;
    return s;
  }
  if (_isIPv6(ip)) {
    if (prefix != null && (prefix < 0 || prefix > 128)) return null;
    if (slash != -1 && prefix == null) return null;
    return s;
  }
  return null;
}

String? validateCidr(String input) => normalizeCidr(input) == null ? cidrInvalidMessage : null;

/// DNS 劫持目标：IPv4，且不在 fake-ip 段 198.18.0.0/16。
String? validateHijackIp(String input) {
  final s = input.trim();
  if (!_isIPv4(s)) return ipv4InvalidMessage;
  if (s.startsWith('198.18.')) return fakeIpRangeMessage;
  return null;
}

/// 绕过规则：`+.x` / `.x` → DOMAIN-SUFFIX，`*.x` → DOMAIN-WILDCARD，其余 DOMAIN；CIDR → IP-CIDR(6),…,DIRECT,no-resolve。
List<String> bypassRules(List<String> domains, List<String> cidrs) {
  final out = <String>[];
  for (final raw in domains) {
    final d = normalizeDomain(raw);
    if (d == null) continue;
    if (d.startsWith('+.')) {
      out.add('DOMAIN-SUFFIX,${d.substring(2)},DIRECT');
    } else if (d.startsWith('*.')) {
      out.add('DOMAIN-WILDCARD,$d,DIRECT');
    } else {
      out.add('DOMAIN,$d,DIRECT');
    }
  }
  for (final raw in cidrs) {
    final c = normalizeCidr(raw);
    if (c == null) continue;
    final v6 = c.contains(':');
    final cidr = c.contains('/') ? c : (v6 ? '$c/128' : '$c/32');
    out.add('${v6 ? 'IP-CIDR6' : 'IP-CIDR'},$cidr,DIRECT,no-resolve');
  }
  return out;
}

/// 代理推送服务（Android：FCM / GMS 直连）
const pushDirectRules = [
  'DOMAIN-SUFFIX,mtalk.google.com,DIRECT',
  'DOMAIN-SUFFIX,push.apple.com,DIRECT',
  'DST-PORT,5228-5230,DIRECT',
];
