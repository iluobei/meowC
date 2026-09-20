import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 出口 IP：两列——「国内 · 直连出口」查国内 IP 源（规则模式下命中 GEOIP,CN 走 DIRECT），
/// 「国际 · 经代理」查国际 IP 源（只在隧道运行时查，经核心走代理）。
/// 不复用 Bettbox 的 DetectionState：它只查一路，且只在 Bettbox 首页放了「网络检测」卡片时才会随连接刷新。
class ExitIpState {
  const ExitIpState({this.domestic, this.global, this.loadingDomestic = false, this.loadingGlobal = false});
  final IpInfo? domestic, global;
  final bool loadingDomestic, loadingGlobal;

  ExitIpState copyWith({IpInfo? domestic, IpInfo? global, bool? loadingDomestic, bool? loadingGlobal, bool clearGlobal = false, bool clearDomestic = false}) =>
      ExitIpState(
        domestic: clearDomestic ? null : (domestic ?? this.domestic),
        global: clearGlobal ? null : (global ?? this.global),
        loadingDomestic: loadingDomestic ?? this.loadingDomestic,
        loadingGlobal: loadingGlobal ?? this.loadingGlobal,
      );
}

class ExitIpController extends Notifier<ExitIpState> {
  CancelToken? _domesticToken, _globalToken;
  int _seq = 0;

  @override
  ExitIpState build() => const ExitIpState();

  /// [running] 为 false 时只查国内（国际列显示「未连接」）。
  Future<void> refresh({required bool running}) async {
    final seq = ++_seq;
    _domesticToken?.cancel();
    _globalToken?.cancel();
    _domesticToken = CancelToken();
    _globalToken = CancelToken();
    state = state.copyWith(loadingDomestic: true, loadingGlobal: running, clearGlobal: !running);
    const timeout = Duration(seconds: 6);
    final futures = <Future<void>>[
      request.checkIpDomestic(cancelToken: _domesticToken, timeout: timeout).then((r) {
        if (seq != _seq) return;
        state = state.copyWith(domestic: r.data, loadingDomestic: false, clearDomestic: r.data == null);
      }).catchError((e) {
        if (seq == _seq) state = state.copyWith(loadingDomestic: false);
      }),
      if (running)
        request.checkIp(cancelToken: _globalToken, timeout: timeout).then((r) {
          if (seq != _seq) return;
          state = state.copyWith(global: r.data, loadingGlobal: false, clearGlobal: r.data == null);
        }).catchError((e) {
          if (seq == _seq) state = state.copyWith(loadingGlobal: false);
        }),
    ];
    await Future.wait(futures);
  }

  void clearGlobal() => state = state.copyWith(clearGlobal: true, loadingGlobal: false);
}

final exitIpProvider = NotifierProvider<ExitIpController, ExitIpState>(ExitIpController.new);
