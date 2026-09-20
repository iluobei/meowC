/// 面板返回的数据模型与纯解析函数（可单测）。

/// 「我的订阅」条目。
class RemoteSubscription {
  const RemoteSubscription({
    required this.name,
    required this.filename,
    required this.subscriptionPath,
    this.expireAt,
    this.trafficUsed,
    this.trafficTotal,
  });

  final String name;
  final String filename;
  final String subscriptionPath;
  final DateTime? expireAt;

  /// 旧面板缺失 → null
  final int? trafficUsed, trafficTotal;

  /// 顶层数组或 `subscriptions | items | data` 包裹
  static List<RemoteSubscription> parseList(dynamic json) {
    final list = switch (json) {
      List l => l,
      Map m => (m['subscriptions'] ?? m['items'] ?? m['data']) is List ? (m['subscriptions'] ?? m['items'] ?? m['data']) as List : const [],
      _ => const [],
    };
    return [
      for (final e in list)
        if (e is Map)
          RemoteSubscription(
            name: e['name']?.toString() ?? e['filename']?.toString() ?? '订阅',
            filename: e['filename']?.toString() ?? '',
            subscriptionPath: e['subscription_path']?.toString() ?? '',
            expireAt: DateTime.tryParse(e['expire_at']?.toString() ?? ''),
            trafficUsed: _int(e['traffic_used']),
            trafficTotal: _int(e['traffic_total']),
          ),
    ];
  }

  /// 下载地址：短链 `base + subscription_path` 优先，回退 `/api/clash/subscribe?token=&filename=&t=clash`
  String downloadUrl(String base, {required String subscriptionToken}) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (subscriptionPath.isNotEmpty) {
      return subscriptionPath.startsWith('/') ? '$b$subscriptionPath' : '$b/$subscriptionPath';
    }
    final q = Uri(queryParameters: {'token': subscriptionToken, 'filename': filename, 't': 'clash'}).query;
    return '$b/api/clash/subscribe?$q';
  }
}

int? _int(dynamic v) => switch (v) {
  int i => i,
  num n => n.toInt(),
  String s => int.tryParse(s),
  _ => null,
};

/// 登录结果：拿到 token，或需要二步验证。
sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  const LoginSuccess({required this.token, required this.username, required this.nickname, required this.avatarUrl});
  final String token, username, nickname, avatarUrl;

  static LoginSuccess? tryParse(Map<String, dynamic> json) {
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) return null;
    final username = json['username']?.toString() ?? '';
    return LoginSuccess(
      token: token,
      username: username,
      nickname: (json['nickname']?.toString() ?? '').isNotEmpty ? json['nickname'].toString() : username,
      avatarUrl: json['avatar_url']?.toString() ?? '',
    );
  }
}

class LoginNeeds2FA extends LoginResult {
  const LoginNeeds2FA(this.twoFactorToken);
  final String twoFactorToken;
}

/// 节点回程奖牌。
class ReturnRoute {
  const ReturnRoute({required this.carrier, this.region, required this.routeType, required this.gold});
  final String carrier;
  final String? region;
  final String routeType;
  final bool gold;
}

class NodeMedal {
  const NodeMedal({required this.name, required this.medal, required this.routes});
  final String name;

  /// gold | silver
  final String medal;
  final List<ReturnRoute> routes;

  static Map<String, NodeMedal> parse(dynamic json) {
    if (json is! Map || json['success'] != true || json['nodes'] is! List) return const {};
    final out = <String, NodeMedal>{};
    for (final n in json['nodes'] as List) {
      if (n is! Map) continue;
      final name = n['name']?.toString() ?? '';
      final medal = n['medal']?.toString() ?? '';
      if (name.isEmpty || medal.isEmpty) continue;
      out[name] = NodeMedal(
        name: name,
        medal: medal,
        routes: [
          for (final r in (n['routes'] is List ? n['routes'] as List : const []))
            if (r is Map)
              ReturnRoute(
                carrier: r['carrier']?.toString() ?? '',
                region: r['region']?.toString(),
                routeType: r['route_type']?.toString() ?? '',
                gold: r['gold'] == true,
              ),
        ],
      );
    }
    return out;
  }
}

/// 深链解析：`miaomiaowu://login?host=<base>&code=<一次性码>`（host 缺 scheme 补 https）。
({String base, String code})? parseLoginLink(Uri uri) {
  if (uri.scheme != 'miaomiaowu' || uri.host != 'login') return null;
  var host = uri.queryParameters['host'] ?? '';
  final code = uri.queryParameters['code'] ?? '';
  if (host.isEmpty || code.isEmpty) return null;
  if (!host.startsWith('http://') && !host.startsWith('https://')) host = 'https://$host';
  if (host.endsWith('/')) host = host.substring(0, host.length - 1);
  return (base: host, code: code);
}
