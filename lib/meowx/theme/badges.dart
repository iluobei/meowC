import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../state/latency.dart';
import 'tokens.dart';

/// 延迟胶囊：caption2 等宽 bold，底同色 0.15；null →「—」灰；≤0 →「超时」灰。
class LatencyChip extends StatelessWidget {
  const LatencyChip(this.ms, {super.key, this.mode = LatencyMode.url, this.testing = false});

  final int? ms;
  final LatencyMode mode;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final String text;
    final Color color;
    if (ms == null) {
      text = '—';
      color = mm.t3;
    } else if (ms! <= 0 || ms! >= 100000) {
      text = S.timeout;
      color = mm.t3;
    } else {
      text = '$ms ms';
      color = latencyColor(ms!, mode, mm);
    }
    return Opacity(
      opacity: testing ? 0.35 : 1,
      child: Container(
        constraints: const BoxConstraints(minWidth: 30),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: MeowFont.mono(size: MeowFont.caption2, weight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

/// 类型徽标：caption2 等宽，底同色 0.16。
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: MeowFont.mono(size: MeowFont.caption2, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// 协议 → （显示名, 颜色）。mihomo /proxies 里的 type 首字母大写，统一小写比较。
({String label, Color color}) protoStyle(String type, MeowTokens mm) {
  final t = type.toLowerCase();
  return switch (t) {
    'vless' => (label: 'vless', color: mm.pur),
    'vmess' => (label: 'vmess', color: mm.accent),
    'trojan' => (label: 'trojan', color: mm.slow),
    'shadowsocks' || 'ss' => (label: 'ss', color: mm.good),
    'shadowsocksr' || 'ssr' => (label: 'ssr', color: mm.good),
    'hysteria2' || 'hysteria' => (label: 'hy2', color: mm.down),
    'tuic' => (label: 'tuic', color: mm.down),
    'anytls' => (label: 'anytls', color: mm.teal),
    'wireguard' => (label: 'wg', color: mm.orange),
    'mieru' => (label: 'mieru', color: const Color(0xFF3EB489)),
    'socks5' || 'http' || 'ssh' => (label: t, color: mm.t2),
    _ => (label: t, color: mm.t2),
  };
}

/// 代理组类型 → （显示名, 颜色）。
({String label, Color color}) groupBadge(String type, MeowTokens mm) {
  return switch (type.toLowerCase()) {
    'selector' || 'select' => (label: 'select', color: mm.pur),
    'urltest' || 'url-test' => (label: 'url-test', color: mm.accent),
    'fallback' => (label: 'fallback', color: mm.good),
    'loadbalance' || 'load-balance' => (label: 'load-balance', color: mm.orange),
    'relay' => (label: 'relay', color: mm.t2),
    final other => (label: other, color: mm.t2),
  };
}

const groupTypeNames = {'selector', 'urltest', 'fallback', 'loadbalance', 'relay'};

bool isGroupType(String type) => groupTypeNames.contains(type.toLowerCase());

/// 内置策略：DIRECT/REJECT/REJECT-DROP/PASS/GLOBAL 副标题
String? builtinSubtitle(String name) => switch (name.toUpperCase()) {
  'DIRECT' => S.builtinDirect,
  'REJECT' || 'REJECT-DROP' => S.builtinReject,
  'PASS' => S.builtinPass,
  'GLOBAL' => S.builtinGlobal,
  _ => null,
};

/// 节点奖牌（服务端判定）：金 / 银。
class MedalBadge extends StatelessWidget {
  const MedalBadge(this.medal, {super.key, this.size = 14, this.onTap});
  final String medal;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = medal == 'gold' ? const Color(0xFFD4A017) : const Color(0xFF9AA0A6);
    return GestureDetector(
      onTap: onTap,
      child: Icon(Icons.workspace_premium_rounded, size: size, color: color),
    );
  }
}
