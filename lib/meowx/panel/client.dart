import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bett_box/common/common.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto.dart';
import 'models.dart';

/// 妙妙屋X 主控客户端：证书拉取 / 缓存 / 验签 + 加密 RPC。
/// 自带直连 HttpClient（不走 Bettbox 全局 HttpOverrides 的本地代理，避免 Windows 系统代理模式下成环）。
class PanelClient {
  PanelClient(String base, {Dio? dio, CertCache? cache})
    : base = _normalize(base),
      _dio = dio ?? _directDio(),
      _cache = cache ?? const PrefsCertCache();

  /// 发给主控的 User-Agent：主控日志与安全事件里认得出是 MeowX 客户端；启动后由 MeowRoot 补上版本号。
  static String userAgent = 'MeowX (${Platform.isAndroid ? 'Android' : Platform.isWindows ? 'Windows' : Platform.operatingSystem})';

  /// `https://host[:port]`，无尾斜杠
  final String base;
  final Dio _dio;
  final CertCache _cache;
  Uint8List? _masterPub;

  String get host => Uri.parse(base).host;

  static String _normalize(String s) {
    var b = s.trim();
    if (!b.startsWith('http://') && !b.startsWith('https://')) b = 'https://$b';
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  static Dio _directDio() {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
    return dio;
  }

  /// 主控 X25519 公钥：缓存命中即用（后台重拉），否则拉取 `/api/secure/cert` 验签后缓存。
  Future<Uint8List> masterPub({bool refresh = false}) async {
    if (_masterPub != null && !refresh) return _masterPub!;
    final cached = refresh ? null : await _cache.read(host);
    if (cached != null) {
      _masterPub = cached;
      // 后台刷新，失败不影响本次
      unawaited(_fetchCert().then((p) {
        _masterPub = p;
      }, onError: (Object e) => commonPrint.log('cert refresh failed: $e')));
      return cached;
    }
    return _masterPub = await _fetchCert();
  }

  Future<Uint8List> _fetchCert() async {
    final res = await _dio.get<dynamic>(
      '$base/api/secure/cert',
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 15),
        headers: {HttpHeaders.userAgentHeader: userAgent},
      ),
    );
    if (res.statusCode != 200 || res.data is! Map) throw PanelException('无法获取主控证书（HTTP ${res.statusCode}）');
    final json = (res.data as Map).cast<String, dynamic>();
    final pub = await MeowCrypto.verifyCert(json, host: host);
    final expire = switch (json['expireUnix']) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    await _cache.write(host, pub, expire);
    return pub;
  }

  /// 加密 RPC：内层 JSON = payload 平铺 + path / method / token? / ts / nonce；不看 HTTP 状态码，只看解密后的 JSON。
  Future<Map<String, dynamic>> rpc(
    String path, {
    String method = 'POST',
    Map<String, dynamic> payload = const {},
    String? token,
  }) async {
    final pub = await masterPub();
    final inner = <String, dynamic>{
      ...payload,
      'path': path,
      'method': method,
      if (token != null && token.isNotEmpty) 'token': token,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'nonce': _uuid(),
    };
    final ephemeral = await MeowCrypto.newEphemeral();
    final envelope = await MeowCrypto.sealRpcRequest(ephemeral: ephemeral, masterPub: pub, plain: utf8.encode(json.encode(inner)));
    final Response<List<int>> res;
    try {
      res = await _dio.post<List<int>>(
        '$base/api/secure/rpc',
        data: Stream.fromIterable([envelope]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'application/octet-stream',
            Headers.contentLengthHeader: envelope.length,
            HttpHeaders.userAgentHeader: userAgent,
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw PanelException('无法连接主控：${e.message ?? e.type.name}');
    }
    final body = res.data ?? const [];
    if (body.length < 12 + 16) {
      throw PanelException('主控响应异常（HTTP ${res.statusCode}）');
    }
    final Uint8List plain;
    try {
      plain = await MeowCrypto.openRpcResponse(ephemeral: ephemeral, masterPub: pub, body: body);
    } catch (_) {
      // 主控可能换了密钥：丢弃缓存证书重拉一次
      await _cache.clear(host);
      _masterPub = null;
      throw PanelException('主控响应无法解密，请重试');
    }
    final decoded = json.decode(utf8.decode(plain));
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return {'data': decoded};
  }

  static String _uuid() {
    final b = MeowCrypto.randomBytes(16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ---- 业务 ----

  static String? _error(Map<String, dynamic> r) {
    if (r['success'] == false || r['error'] != null || r['message'] != null && r['token'] == null && r['requires_2fa'] != true) {
      return (r['error'] ?? r['message'] ?? '请求失败').toString();
    }
    return null;
  }

  Future<LoginResult> login({required String username, required String password}) async {
    final r = await rpc('/login', payload: {'username': username, 'password': password, 'remember_me': true, 'turnstile_token': ''});
    return _loginResult(r);
  }

  Future<LoginResult> login2fa({required String twoFactorToken, required String code}) async {
    return _loginResult(await rpc('/login/2fa', payload: {'two_factor_token': twoFactorToken, 'code': code}));
  }

  Future<LoginResult> loginRecovery({required String twoFactorToken, required String recoveryCode}) async {
    return _loginResult(await rpc('/login/recovery', payload: {'two_factor_token': twoFactorToken, 'recovery_code': recoveryCode}));
  }

  /// 扫码登录：一次性码，无 token
  Future<LoginResult> loginQr(String code) async => _loginResult(await rpc('/login/qr', payload: {'code': code}));

  LoginResult _loginResult(Map<String, dynamic> r) {
    if (r['requires_2fa'] == true) {
      return LoginNeeds2FA(r['two_factor_token']?.toString() ?? '');
    }
    final ok = LoginSuccess.tryParse(r);
    if (ok != null) return ok;
    throw PanelException(_error(r) ?? '登录失败');
  }

  /// 订阅令牌（与会话 token 不同）
  Future<String> subscriptionToken(String token) async {
    final r = await rpc('/user/token', method: 'GET', token: token);
    final t = r['token']?.toString();
    if (t == null || t.isEmpty) throw PanelException(_error(r) ?? '未拿到订阅令牌');
    return t;
  }

  Future<List<RemoteSubscription>> subscriptions(String token) async {
    final r = await rpc('/subscriptions', method: 'GET', token: token);
    final err = _error(r);
    if (err != null && r['subscriptions'] == null && r['items'] == null && r['data'] == null) throw PanelException(err);
    return RemoteSubscription.parseList(r.containsKey('data') && r['data'] is List && r.length == 1 ? r['data'] : r);
  }

  /// 主控功能开关（回程金牌 / 解锁检测）。
  Future<PanelFeatures> features(String token) async {
    return PanelFeatures.parse(await rpc('/user/features', method: 'GET', token: token));
  }

  Future<Map<String, NodeUnlocks>> unlocks(String token) async {
    return NodeUnlocks.parse(await rpc('/user/unlocks', method: 'GET', token: token));
  }

  Future<Map<String, NodeMedal>> returnRoutes(String token) async {
    final r = await rpc('/user/return-routes', method: 'GET', token: token);
    return NodeMedal.parse(r);
  }
}

class PanelException implements Exception {
  const PanelException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 主控证书缓存：`masterCert.<host>` = {pub, expire}
abstract class CertCache {
  const CertCache();
  Future<Uint8List?> read(String host);
  Future<void> write(String host, Uint8List pub, int expireUnix);
  Future<void> clear(String host);
}

class PrefsCertCache extends CertCache {
  const PrefsCertCache();

  @override
  Future<Uint8List?> read(String host) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('masterCert.$host');
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map;
      final expire = (m['expire'] as num).toInt();
      if (expire <= DateTime.now().millisecondsSinceEpoch ~/ 1000) return null;
      final pub = base64.decode(m['pub'] as String);
      return pub.length == 32 ? Uint8List.fromList(pub) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String host, Uint8List pub, int expireUnix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('masterCert.$host', json.encode({'pub': base64.encode(pub), 'expire': expireUnix}));
  }

  @override
  Future<void> clear(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('masterCert.$host');
  }
}

class MemoryCertCache extends CertCache {
  MemoryCertCache();
  final Map<String, (Uint8List, int)> _m = {};
  @override
  Future<Uint8List?> read(String host) async => _m[host]?.$1;
  @override
  Future<void> write(String host, Uint8List pub, int expireUnix) async => _m[host] = (pub, expireUnix);
  @override
  Future<void> clear(String host) async => _m.remove(host);
}
