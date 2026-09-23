/// 更新通道专用的 HTTP 客户端。
///
/// Bettbox 的全局 [HttpOverrides]（`BettboxHttpOverrides`）把 badCertificateCallback 设成一律放行——订阅源常见自签证书，
/// 那是它的需求；但 latest.json 与安装包最终会以管理员权限执行，证书必须按系统信任库端到端校验，否则中间人 / 恶意节点
/// 能伪造清单和安装包。这里用一个空的 [HttpOverrides] 在 zone 里绕开全局覆盖，拿到 dart:io 原生客户端（不带任何放行回调），
/// 代理仍沿用全局的 findProxy（核心跑着就走本地混合端口），可达性不变。
library;

import 'dart:io';

import 'package:bett_box/common/constant.dart' show browserUa;
import 'package:bett_box/common/http.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 空覆盖：基类 createHttpClient 返回原生 [HttpClient]。
class _StrictHttpOverrides extends HttpOverrides {}

/// 系统证书校验 + 本地代理的客户端。绝不设 badCertificateCallback。
HttpClient strictHttpClient() {
  final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _StrictHttpOverrides());
  client.findProxy = BettboxHttpOverrides.handleFindProxy;
  return client;
}

/// latest.json 与安装包下载共用的 Dio。
Dio strictUpdateDio() {
  final dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
  dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: strictHttpClient);
  return dio;
}
