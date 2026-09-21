import 'dart:async';
import 'dart:io';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 出口 IP：两列。
/// - 「国内 · 直连出口」：国内 IP 源（规则模式下命中 GEOIP,CN 走 DIRECT），未连接也能查。
/// - 「国际 · 经 {出站}」：与 iOS 同一个探测地址 cp.cloudflare.com/cdn-cgi/trace，**显式**经核心的本地代理端口发出
///   （不依赖全局 HttpOverrides），查完立刻从连接表里读这条连接实际走的出站，标题里写出来——
///   规则把它判成 DIRECT 时一眼能看出来，而不是悄悄显示成国内 IP。
class ExitIpState {
  const ExitIpState({this.domestic, this.global, this.globalVia, this.loadingDomestic = false, this.loadingGlobal = false});
  final IpInfo? domestic, global;

  /// 国际探测实际走的出站（节点 / 组名；DIRECT 表示规则让它直连了）
  final String? globalVia;
  final bool loadingDomestic, loadingGlobal;

  ExitIpState copyWith({
    IpInfo? domestic,
    IpInfo? global,
    String? globalVia,
    bool? loadingDomestic,
    bool? loadingGlobal,
    bool clearGlobal = false,
    bool clearDomestic = false,
  }) => ExitIpState(
    domestic: clearDomestic ? null : (domestic ?? this.domestic),
    global: clearGlobal ? null : (global ?? this.global),
    globalVia: clearGlobal ? null : (globalVia ?? this.globalVia),
    loadingDomestic: loadingDomestic ?? this.loadingDomestic,
    loadingGlobal: loadingGlobal ?? this.loadingGlobal,
  );
}

const _traceHosts = ['cp.cloudflare.com', 'www.cloudflare.com'];

/// 解析 Cloudflare trace（`ip=…` / `loc=…` 逐行）。
IpInfo? parseCloudflareTrace(String body) {
  String ip = '', loc = '';
  for (final line in body.split('\n')) {
    if (line.startsWith('ip=')) ip = line.substring(3).trim();
    if (line.startsWith('loc=')) loc = line.substring(4).trim();
  }
  return ip.isEmpty ? null : IpInfo(ip: ip, countryCode: loc);
}

class ExitIpController extends Notifier<ExitIpState> {
  CancelToken? _domesticToken;
  int _seq = 0;

  @override
  ExitIpState build() => const ExitIpState();

  /// [running] 为 false 时只查国内（国际列显示「未连接」）。
  Future<void> refresh({required bool running}) async {
    final seq = ++_seq;
    _domesticToken?.cancel();
    _domesticToken = CancelToken();
    state = state.copyWith(loadingDomestic: true, loadingGlobal: running, clearGlobal: !running);
    await Future.wait([
      request.checkIpDomestic(cancelToken: _domesticToken, timeout: const Duration(seconds: 6)).then((r) {
        if (seq != _seq) return;
        state = state.copyWith(domestic: r.data, loadingDomestic: false, clearDomestic: r.data == null);
      }).catchError((e) {
        if (seq == _seq) state = state.copyWith(loadingDomestic: false);
      }),
      if (running)
        _queryGlobal().then((r) {
          if (seq != _seq) return;
          state = r == null
              ? state.copyWith(loadingGlobal: false, clearGlobal: true)
              : state.copyWith(global: r.$1, globalVia: r.$2, loadingGlobal: false);
        }),
    ]);
  }

  /// 经核心本地代理端口查 Cloudflare trace，并读出这条连接实际走的出站。
  Future<(IpInfo, String?)?> _queryGlobal() async {
    final port = globalState.config.patchClashConfig.mixedPort;
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 6), receiveTimeout: const Duration(seconds: 6), responseType: ResponseType.plain));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..findProxy = ((_) => 'PROXY 127.0.0.1:$port')
        ..badCertificateCallback = (_, _, _) => true,
    );
    try {
      for (final host in _traceHosts) {
        try {
          final res = await dio.get<String>('http://$host/cdn-cgi/trace');
          final info = parseCloudflareTrace(res.data ?? '');
          if (info == null) continue;
          // 连接还在 keep-alive 里，趁现在从连接表读它的出站链
          String? via;
          try {
            final conns = await clashCore.getConnections();
            final c = conns.where((c) => c.metadata.host == host).lastOrNull;
            via = c?.chains.firstOrNull;   // chains 首项 = 实际落地的节点（或 DIRECT）
          } catch (_) {}
          return (info, via);
        } catch (e) {
          commonPrint.log('exit ip via $host failed: $e');
        }
      }
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  void clearGlobal() => state = state.copyWith(clearGlobal: true, loadingGlobal: false);
}

final exitIpProvider = NotifierProvider<ExitIpController, ExitIpState>(ExitIpController.new);
