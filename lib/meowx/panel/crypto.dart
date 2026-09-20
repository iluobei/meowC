import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 妙妙屋X 主控加密通道的原语（与 iOS 端字节级一致）：
/// - 主控证书：Ed25519 验签，被签名串 `mmx-cert-v1\n<masterPub b64>\n<domain>\n<expireUnix>`
/// - RPC：每请求临时 X25519；salt = ePub‖masterPub；HKDF-SHA256 出 32B；info c2s / s2c；ChaCha20-Poly1305
///   上行 `ePub(32)‖nonce12‖ct‖tag16`，下行 `nonce12‖ct‖tag16`
/// - WS：会话密钥 info `mmx-secure-ws-c2s-v1` / `s2c-v1`；帧 `counter(8B BE)‖ct‖tag16`，nonce = 4 零字节‖counter BE
class MeowCrypto {
  MeowCrypto._();

  /// 信任根公钥（Ed25519，base64）
  static const trustRootB64 = '/cKXW8AIOPE6ChoZtXjP8N+KkIYvKLvnpLyaLPrpTQM=';

  static const rpcC2S = 'mmx-secure-rpc-c2s-v1';
  static const rpcS2C = 'mmx-secure-rpc-s2c-v1';
  static const wsC2S = 'mmx-secure-ws-c2s-v1';
  static const wsS2C = 'mmx-secure-ws-s2c-v1';

  static final _x25519 = X25519();
  static final _aead = Chacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _rng = Random.secure();

  static Uint8List randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  static Future<SimpleKeyPair> newEphemeral() => _x25519.newKeyPair();

  static Future<SimpleKeyPair> ephemeralFromSeed(List<int> seed) => _x25519.newKeyPairFromSeed(seed);

  /// 由临时私钥与主控公钥派生方向密钥：HKDF(ikm = X25519 共享密钥, salt = ePub‖masterPub, info)。
  static Future<SecretKey> deriveKey({
    required SimpleKeyPair ephemeral,
    required List<int> masterPub,
    required String info,
  }) async {
    final ePub = (await ephemeral.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(masterPub, type: KeyPairType.x25519),
    );
    // cryptography 包的 `nonce:` 参数即 HKDF 的 salt
    return _hkdf.deriveKey(secretKey: shared, nonce: [...ePub, ...masterPub], info: utf8.encode(info));
  }

  static Future<Uint8List> seal(List<int> plain, {required SecretKey key, required List<int> nonce}) async {
    final box = await _aead.encrypt(plain, secretKey: key, nonce: nonce);
    return Uint8List.fromList(box.concatenation()); // nonce‖ct‖mac，与 CryptoKit combined 一致
  }

  static Future<Uint8List> open(List<int> combined, {required SecretKey key}) async {
    final box = SecretBox.fromConcatenation(combined, nonceLength: 12, macLength: 16);
    return Uint8List.fromList(await _aead.decrypt(box, secretKey: key));
  }

  /// RPC 上行信封：`ePub‖nonce‖ct‖tag`
  static Future<Uint8List> sealRpcRequest({
    required SimpleKeyPair ephemeral,
    required List<int> masterPub,
    required List<int> plain,
    List<int>? nonce,
  }) async {
    final key = await deriveKey(ephemeral: ephemeral, masterPub: masterPub, info: rpcC2S);
    final ePub = (await ephemeral.extractPublicKey()).bytes;
    final body = await seal(plain, key: key, nonce: nonce ?? randomBytes(12));
    return Uint8List.fromList([...ePub, ...body]);
  }

  /// RPC 下行：`nonce‖ct‖tag`
  static Future<Uint8List> openRpcResponse({
    required SimpleKeyPair ephemeral,
    required List<int> masterPub,
    required List<int> body,
  }) async {
    final key = await deriveKey(ephemeral: ephemeral, masterPub: masterPub, info: rpcS2C);
    return open(body, key: key);
  }

  /// 验证主控证书；通过则返回 masterPub 原始字节。nowUnix 可注入用于测试。
  static Future<Uint8List> verifyCert(
    Map<String, dynamic> json, {
    required String host,
    List<int>? rootPub,
    int? nowUnix,
  }) async {
    final masterPubB64 = json['masterPub']?.toString() ?? '';
    final domain = json['domain']?.toString() ?? '';
    final expire = switch (json['expireUnix']) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    final sigB64 = json['sig']?.toString() ?? '';
    if (masterPubB64.isEmpty || domain.isEmpty || sigB64.isEmpty) {
      throw const CertException('主控证书格式不合法');
    }
    final now = nowUnix ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expire <= now) throw const CertException('主控证书已过期');
    if (domain.toLowerCase() != host.toLowerCase()) throw CertException('主控证书域名不匹配：$domain ≠ $host');
    final masterPub = base64.decode(masterPubB64);
    if (masterPub.length != 32) throw const CertException('主控公钥长度不合法');
    final msg = utf8.encode('mmx-cert-v1\n$masterPubB64\n$domain\n$expire');
    final ok = await Ed25519().verify(
      msg,
      signature: Signature(
        base64.decode(sigB64),
        publicKey: SimplePublicKey(rootPub ?? base64.decode(trustRootB64), type: KeyPairType.ed25519),
      ),
    );
    if (!ok) throw const CertException('主控证书签名无效');
    return Uint8List.fromList(masterPub);
  }
}

class CertException implements Exception {
  const CertException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// WS 会话：一对方向密钥 + 单调计数器。
class SecureSession {
  SecureSession._(this._c2s, this._s2c);

  final SecretKey _c2s, _s2c;
  int _send = 0;
  int _recv = 0;

  static Future<SecureSession> create({required SimpleKeyPair ephemeral, required List<int> masterPub}) async {
    final c2s = await MeowCrypto.deriveKey(ephemeral: ephemeral, masterPub: masterPub, info: MeowCrypto.wsC2S);
    final s2c = await MeowCrypto.deriveKey(ephemeral: ephemeral, masterPub: masterPub, info: MeowCrypto.wsS2C);
    return SecureSession._(c2s, s2c);
  }

  static Uint8List _nonceFor(int counter) {
    final b = ByteData(12)..setUint64(4, counter, Endian.big);
    return b.buffer.asUint8List();
  }

  static Uint8List _be64(int v) => (ByteData(8)..setUint64(0, v, Endian.big)).buffer.asUint8List();

  /// 发送帧：`counter(8B BE)‖ct‖tag`
  Future<Uint8List> seal(List<int> plain) async {
    final counter = _send++;
    final combined = await MeowCrypto.seal(plain, key: _c2s, nonce: _nonceFor(counter));
    return Uint8List.fromList([..._be64(counter), ...combined.sublist(12)]);
  }

  /// 收帧：counter 必须 ≥ 期望值（防重放），解出明文。
  Future<Uint8List> open(List<int> frame) async {
    if (frame.length < 8 + 16) throw const FormatException('帧太短');
    final counter = ByteData.sublistView(Uint8List.fromList(frame.sublist(0, 8))).getUint64(0, Endian.big);
    if (counter < _recv) throw FormatException('帧计数器回退：$counter < $_recv');
    final plain = await MeowCrypto.open([..._nonceFor(counter), ...frame.sublist(8)], key: _s2c);
    _recv = counter + 1;
    return plain;
  }
}
