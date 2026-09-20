import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/meow.freezed.dart';
part 'generated/meow.g.dart';

/// DNS 模式：跟随订阅 / 强制 redir-host / 强制 fake-ip（只改 dns.enhanced-mode，生效模式变了才重载）。
enum MeowDnsMode {
  follow,
  @JsonValue('redir-host')
  redirHost,
  @JsonValue('fake-ip')
  fakeIp;

  String get label => switch (this) {
    MeowDnsMode.follow => '跟随订阅',
    MeowDnsMode.redirHost => 'Redir-Host',
    MeowDnsMode.fakeIp => 'Fake-IP',
  };
}

/// 测速方式三档（与 iOS 端设置项一致）。
enum LatencyMode {
  /// HTTPS 延迟（去掉握手的 unified 口径，阈值 100 / 200）
  url,

  /// 真连接延迟（含 TCP + TLS 握手的完整往返，阈值 300 / 600）
  urlFull,

  /// TCPing（只连节点入口端口，阈值 100 / 200）
  tcping;

  String get label => switch (this) {
    LatencyMode.url => 'HTTPS 延迟',
    LatencyMode.urlFull => '真连接延迟',
    LatencyMode.tcping => 'TCPing',
  };

  /// （良好上限, 一般上限）
  (int, int) get thresholds => switch (this) {
    LatencyMode.url => (100, 200),
    LatencyMode.urlFull => (300, 600),
    LatencyMode.tcping => (100, 200),
  };

  /// 传给核心 asyncTestDelay 的 mode 字段
  String get wireName => switch (this) {
    LatencyMode.url => 'url',
    LatencyMode.urlFull => 'url-full',
    LatencyMode.tcping => 'tcping',
  };
}

/// 节点卡片三档：紧凑 3 列 / 标准 2 列 / 大 1 列。
enum NodeCardSize {
  compact,
  standard,
  large;

  String get label => switch (this) {
    NodeCardSize.compact => '紧凑',
    NodeCardSize.standard => '标准',
    NodeCardSize.large => '大',
  };
}

/// 本地代理（HTTP/SOCKS5 混合端口）设置。
@freezed
abstract class MeowLocalProxy with _$MeowLocalProxy {
  const factory MeowLocalProxy({
    @Default(false) bool enabled,
    @Default(7890) int port,
    @Default(false) bool allowLan,
    @Default('') String username,
    @Default('') String password,
  }) = _MeowLocalProxy;

  factory MeowLocalProxy.fromJson(Map<String, Object?> json) => _$MeowLocalProxyFromJson(json);
}

/// 妙妙屋X 主控账户。
@freezed
abstract class MeowAccount with _$MeowAccount {
  const factory MeowAccount({
    @Default('') String host,
    @Default('') String token,
    @Default('') String nickname,
    @Default('') String avatarUrl,
  }) = _MeowAccount;

  factory MeowAccount.fromJson(Map<String, Object?> json) => _$MeowAccountFromJson(json);
}

/// MeowX 壳自己的设置（挂在 Config.meow 上，随 Bettbox 的偏好一起落盘）。
@freezed
abstract class MeowSettings with _$MeowSettings {
  const factory MeowSettings({
    @Default(MeowDnsMode.follow) MeowDnsMode dnsMode,
    @Default(LatencyMode.url) LatencyMode latencyMode,
    @Default(NodeCardSize.standard) NodeCardSize nodeCardSize,

    /// 订阅同步间隔（小时），0 = 手动
    @Default(24) int syncIntervalHours,

    /// 代理推送服务（Android：FCM / GMS 直连开关）
    @Default(false) bool proxyPush,

    /// DNS 劫持：域名 → IPv4
    @Default({}) Map<String, String> dnsHijack,

    /// 绕过代理：域名与 CIDR
    @Default([]) List<String> bypassDomains,
    @Default([]) List<String> bypassCidrs,
    @Default(MeowLocalProxy()) MeowLocalProxy localProxy,
    @Default(MeowAccount()) MeowAccount account,
  }) = _MeowSettings;

  factory MeowSettings.fromJson(Map<String, Object?> json) => _$MeowSettingsFromJson(json);
}
