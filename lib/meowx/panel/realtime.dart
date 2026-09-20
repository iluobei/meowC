import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bett_box/common/common.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client.dart';
import 'crypto.dart';

/// 主控实时通道 `wss://host/api/secure/ws`：
/// 帧 1 明文 ePub(32B)；帧 2 加密 `{ts, nonce, token?}`；此后每帧 `counter‖ct‖tag`；25s 加密 ping；断线 5s 重连。
class RealtimeClient {
  RealtimeClient({required this.client, required this.token, required this.onEvent});

  final PanelClient client;
  final String token;
  final void Function(String type, Map<String, dynamic> json) onEvent;

  WebSocketChannel? _channel;
  SecureSession? _session;
  Timer? _ping, _reconnect;
  bool _running = false;

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_connect());
  }

  Future<void> stop() async {
    _running = false;
    _ping?.cancel();
    _reconnect?.cancel();
    _ping = _reconnect = null;
    final ch = _channel;
    _channel = null;
    _session = null;
    await ch?.sink.close();
  }

  Future<void> _connect() async {
    if (!_running) return;
    try {
      final masterPub = await client.masterPub();
      final ephemeral = await MeowCrypto.newEphemeral();
      final uri = Uri.parse(client.base).replace(scheme: 'wss', path: '/api/secure/ws');
      final ch = IOWebSocketChannel.connect(
        uri,
        customClient: HttpClient()..findProxy = (_) => 'DIRECT',
        connectTimeout: const Duration(seconds: 15),
      );
      await ch.ready;
      if (!_running) {
        await ch.sink.close();
        return;
      }
      _channel = ch;
      final session = await SecureSession.create(ephemeral: ephemeral, masterPub: masterPub);
      _session = session;
      ch.sink.add(Uint8List.fromList((await ephemeral.extractPublicKey()).bytes));
      ch.sink.add(await session.seal(utf8.encode(json.encode({
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'nonce': DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        if (token.isNotEmpty) 'token': token,
      }))));
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => _send({'type': 'ping'}));
      ch.stream.listen(_onFrame, onError: (_) => _scheduleReconnect(), onDone: _scheduleReconnect, cancelOnError: true);
      commonPrint.log('realtime connected: ${uri.host}');
    } catch (e) {
      commonPrint.log('realtime connect failed: $e');
      _scheduleReconnect();
    }
  }

  Future<void> _send(Map<String, dynamic> obj) async {
    final ch = _channel;
    final s = _session;
    if (ch == null || s == null) return;
    try {
      ch.sink.add(await s.seal(utf8.encode(json.encode(obj))));
    } catch (e) {
      commonPrint.log('realtime send failed: $e');
    }
  }

  Future<void> _onFrame(dynamic data) async {
    final s = _session;
    if (s == null) return;
    final bytes = switch (data) {
      List<int> b => b,
      String str => base64.decode(str),
      _ => null,
    };
    if (bytes == null) return;
    try {
      final plain = json.decode(utf8.decode(await s.open(bytes)));
      if (plain is Map) {
        final m = plain.cast<String, dynamic>();
        onEvent(m['type']?.toString() ?? '', m);
      }
    } catch (e) {
      commonPrint.log('realtime frame dropped: $e');
    }
  }

  void _scheduleReconnect() {
    _ping?.cancel();
    _ping = null;
    _channel = null;
    _session = null;
    if (!_running || _reconnect != null) return;
    _reconnect = Timer(const Duration(seconds: 5), () {
      _reconnect = null;
      unawaited(_connect());
    });
  }
}
