import 'dart:async';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/meow_root.dart';
import '../../app/meow_tab.dart';
import '../../app/strings.dart';
import '../../config/direct_profile.dart';
import '../../config/meow_patch.dart';
import '../../state/exit_ip.dart';
import '../../state/format.dart';
import '../../state/meow_settings.dart';
import '../../state/status.dart';
import '../../theme/glass_card.dart';
import '../../theme/page_title.dart';
import '../../theme/sparkline.dart';
import '../../theme/tokens.dart';
import '../../theme/two_pane.dart';

const _gap = 12.0;
const _pad = 16.0;
const _wideRowHeight = 104.0;

/// 首页：compact 顺序 标题 → 上传|下载 → 网速图 → 连接主卡 → 代理|直连 → 内存|DNS → 出口 IP；
/// wide 左列「连接主卡 / 网速图」各 = 两行 + 12，右列四行各 104。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _proxyConns = 0, _directConns = 0;
  int _memory = 0;
  late final VoidCallback _tick1, _tick2;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _tick1 = () => unawaited(_pollConnections());
    _tick2 = () => unawaited(_pollMemory());
    dashboardRefreshManager.tick1s.addListener(_tick1);
    dashboardRefreshManager.tick2s.addListener(_tick2);
  }

  @override
  void dispose() {
    dashboardRefreshManager.tick1s.removeListener(_tick1);
    dashboardRefreshManager.tick2s.removeListener(_tick2);
    super.dispose();
  }

  bool get _visible => ref.read(meowTabProvider) == MeowTab.home || ref.read(isWideLayoutProvider);

  Future<void> _pollConnections() async {
    if (_polling || !mounted) return;
    if (!ref.read(isRunningProvider)) {
      if (_proxyConns != 0 || _directConns != 0) setState(() => _proxyConns = _directConns = 0);
      ref.read(connectionCountProvider.notifier).state = 0;
      return;
    }
    _polling = true;
    try {
      final conns = await clashCore.getConnections();
      var proxy = 0, direct = 0;
      for (final c in conns) {
        final first = c.chains.firstOrNull ?? '';
        if (first == 'DIRECT') {
          direct++;
        } else if (!first.startsWith('REJECT')) {
          proxy++;
        }
      }
      if (!mounted) return;
      ref.read(connectionCountProvider.notifier).state = conns.length;
      if (_visible && (proxy != _proxyConns || direct != _directConns)) {
        setState(() {
          _proxyConns = proxy;
          _directConns = direct;
        });
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollMemory() async {
    if (!mounted || !_visible || !ref.read(isRunningProvider)) return;
    try {
      final m = await clashCore.getMemory();
      if (mounted && m != _memory) setState(() => _memory = m);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final wide = ref.watch(isTwoPaneProvider);
    final running = ref.watch(isRunningProvider);
    final upload = _MetricCard(
      icon: Icons.arrow_upward_rounded,
      title: S.upload,
      color: context.mm.accent,
      value: _TotalTrafficValue(up: true),
      desc: '${S.session} · ${S.upload}',
    );
    final download = _MetricCard(
      icon: Icons.arrow_downward_rounded,
      title: S.download,
      color: context.mm.down,
      value: _TotalTrafficValue(up: false),
      desc: '${S.session} · ${S.download}',
    );
    final proxyCard = _MetricCard(
      icon: Icons.alt_route_rounded,
      title: S.proxyConnections,
      color: context.mm.pur,
      value: Text('${running ? _proxyConns : 0}'),
      desc: S.viaNodeGroup,
      onTap: () {
        ref.read(meowTabProvider.notifier).state = MeowTab.connections;
        ref.read(currentPageLabelProvider.notifier).value = PageLabel.connections;
      },
    );
    final directCard = _MetricCard(
      icon: Icons.arrow_forward_rounded,
      title: S.directConnections,
      color: context.mm.good,
      value: Text('${running ? _directConns : 0}'),
      desc: S.directBypass,
    );
    final memoryCard = _MetricCard(
      icon: Icons.memory_rounded,
      title: S.memory,
      color: context.mm.teal,
      value: Text(running ? fmtSize(_memory) : '—'),
      desc: S.coreMemory,
    );
    const dnsCard = _DnsModeCard();
    const exitIp = _ExitIpCard();
    const main = _ConnectionCard();
    final speed = _SpeedCard(chartHeight: wide ? 132 : 84);

    if (!wide) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(_pad, 0, _pad, _pad + 24),
        children: [
          const PageTitle(S.home),
          const SizedBox(height: _gap),
          _row(upload, download),
          const SizedBox(height: _gap),
          speed,
          const SizedBox(height: _gap),
          main,
          const SizedBox(height: _gap),
          _row(proxyCard, directCard),
          const SizedBox(height: _gap),
          _row(memoryCard, dnsCard),
          const SizedBox(height: _gap),
          exitIp,
        ],
      );
    }
    const leftHeight = _wideRowHeight * 2 + _gap;
    return PageWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, _pad, _pad, _pad),
        children: [
          const PageTitle(S.home),
          const SizedBox(height: _gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: leftHeight, child: main),
                    const SizedBox(height: _gap),
                    SizedBox(height: leftHeight, child: speed),
                  ],
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: _wideRowHeight, child: _row(upload, download, bounded: true)),
                    const SizedBox(height: _gap),
                    SizedBox(height: _wideRowHeight, child: _row(proxyCard, directCard, bounded: true)),
                    const SizedBox(height: _gap),
                    SizedBox(height: _wideRowHeight, child: _row(memoryCard, dnsCard, bounded: true)),
                    const SizedBox(height: _gap),
                    const SizedBox(height: _wideRowHeight, child: exitIp),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 两卡并排、等高。compact 下 ListView 的高度无界，Row 的 stretch 会把子项撑成无限高
  /// （release 不断言，表现为该行之后整页空白），所以套 IntrinsicHeight 取两卡中较高者；wide 下外层已给定高度。
  Widget _row(Widget a, Widget b, {bool bounded = false}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: a), const SizedBox(width: _gap), Expanded(child: b)],
    );
    return bounded ? row : IntrinsicHeight(child: row);
  }
}

/// 指标卡：图标 footnote + 标题 caption t2 / 数值 title2 semibold 等宽 / 说明 caption2 t3，padding 14。
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.value,
    required this.desc,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget value;
  final String desc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: MeowFont.footnote + 2, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: MeowFont.caption, color: mm.t2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: MeowFont.mono(size: MeowFont.title2, weight: FontWeight.w600, color: mm.t1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: value,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: MeowFont.caption2, color: mm.t3),
          ),
        ],
      ),
    );
  }
}

class _TotalTrafficValue extends ConsumerWidget {
  const _TotalTrafficValue({required this.up});
  final bool up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalTrafficProvider);
    return Text(fmtSize(up ? total.up.value : total.down.value));
  }
}

/// DNS 模式卡：跟随订阅 / Redir-Host / Fake-IP，点按循环 follow → redir → fake；生效模式变了才重载。
class _DnsModeCard extends ConsumerWidget {
  const _DnsModeCard();

  static String _effective(MeowDnsMode mode, String? declared) =>
      effectiveDnsMode(mode, declared) == 'fake-ip' ? S.dnsFakeIp : S.dnsRedirHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(meowSettingProvider.select((s) => s.dnsMode));
    final declared = ref.watch(declaredDnsModeProvider);
    return _MetricCard(
      icon: Icons.public_rounded,
      title: S.dnsMode,
      color: context.mm.teal,
      value: Text(_effective(mode, declared)),
      desc: mode == MeowDnsMode.follow ? S.dnsFollow : '${mode.label} · 点按切换',
      onTap: () {
        final next = MeowDnsMode.values[(mode.index + 1) % MeowDnsMode.values.length];
        final before = _effective(mode, declared);
        ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(dnsMode: next));
        if (_effective(next, declared) != before && ref.read(isRunningProvider)) {
          globalState.appController.applyProfileDebounce();
        }
      },
    );
  }
}

/// 网速图卡：60 点双线 + 「峰值 X」/「每秒采样 | 未连接」。
class _SpeedCard extends ConsumerWidget {
  const _SpeedCard({required this.chartHeight});
  final double chartHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final running = ref.watch(isRunningProvider);
    final traffics = ref.watch(trafficsProvider).list;
    final recent = traffics.length > 60 ? traffics.sublist(traffics.length - 60) : traffics;
    final up = [for (final t in recent) t.up.value.toDouble()];
    final down = [for (final t in recent) t.down.value.toDouble()];
    final last = recent.isEmpty ? null : recent.last;
    final peak = [...up, ...down].fold<double>(0, (m, v) => v > m ? v : m);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: MeowFont.footnote + 2, color: mm.accent),
              const SizedBox(width: 5),
              Text('↑ ${fmtRate(last?.up.value ?? 0)}', style: MeowFont.mono(size: MeowFont.caption, weight: FontWeight.w600, color: mm.accent)),
              const SizedBox(width: 10),
              Text('↓ ${fmtRate(last?.down.value ?? 0)}', style: MeowFont.mono(size: MeowFont.caption, weight: FontWeight.w600, color: mm.down)),
              const Spacer(),
              Text('${S.peak} ${fmtRate(peak)}', style: TextStyle(fontSize: MeowFont.caption2, color: mm.t3)),
            ],
          ),
          const SizedBox(height: 8),
          Sparkline(up: up, down: down, height: chartHeight),
          const SizedBox(height: 6),
          Text(
            running ? S.samplingPerSecond : S.disconnected,
            style: TextStyle(fontSize: MeowFont.caption2, color: mm.t3),
          ),
        ],
      ),
    );
  }
}

/// 连接主卡：状态点 + 文案 + 已运行；电源键 54；订阅栏；「规则 | 直连」分段。
class _ConnectionCard extends ConsumerStatefulWidget {
  const _ConnectionCard();

  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  bool _busy = false;
  bool? _optimistic;

  Future<void> _toggle() async {
    if (_busy) return;
    final isStart = ref.read(isRunningProvider);
    setState(() {
      _busy = true;
      _optimistic = !isStart;
    });
    try {
      await globalState.appController.updateStatus(!isStart);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _optimistic = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final runTime = ref.watch(runTimeProvider);
    final selector = ref.watch(startButtonSelectorStateProvider);
    final restarting = ref.watch(isRestartingCoreProvider);
    final profile = ref.watch(currentProfileProvider);
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));
    final hasProfile = selector.hasProfile && profile != null;
    final running = runTime != null;
    final connecting = (_optimistic == true && !running) || restarting;

    final Color dot;
    final String status;
    final String sub;
    if (running) {
      dot = mm.good;
      status = S.connected;
      sub = '${S.running} ${fmtUptime(Duration(milliseconds: runTime))}';
    } else if (connecting) {
      dot = mm.orange;
      status = S.connecting;
      sub = S.ready;
    } else {
      dot = mm.t3;
      status = S.disconnected;
      sub = hasProfile ? S.ready : S.notConfigured;
    }

    final powerColor = running ? mm.slow : (hasProfile ? mm.t2.withValues(alpha: 0.55) : mm.t3.withValues(alpha: 0.28));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(status, style: TextStyle(fontSize: MeowFont.headline, fontWeight: FontWeight.w600, color: mm.t1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(sub, style: MeowFont.mono(size: MeowFont.footnote, color: mm.t2)),
                  ],
                ),
              ),
              _PowerButton(
                color: powerColor,
                glow: running,
                enabled: hasProfile && !_busy && !restarting,
                onTap: _toggle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (profile != null) _SubscriptionBar(profile: profile) else _EmptySubscriptionBar(),
          const SizedBox(height: 12),
          _ModeSegment(
            mode: mode,
            onChanged: (m) => globalState.appController.changeMode(m),
          ),
        ],
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.color, required this.glow, required this.enabled, required this.onTap});
  final Color color;
  final bool glow, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 2)] : null,
        ),
        child: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// 订阅栏：名称 + 「已用 / 总量」等宽 + 4pt 进度条，圆角 12 底 primary 0.05。
class _SubscriptionBar extends ConsumerWidget {
  const _SubscriptionBar({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final info = profile.subscriptionInfo;
    final used = (info?.upload ?? 0) + (info?.download ?? 0);
    final total = info?.total ?? 0;
    final frac = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final hasUsage = info != null && (total > 0 || used > 0 || (info.expire) > 0);
    final profiles = withDirectProfileLast(ref.watch(profilesProvider));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: mm.t1.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.copy_all_rounded, size: 14, color: mm.t2),
              const SizedBox(width: 6),
              Expanded(
                child: PopupMenuButton<String>(
                  tooltip: '',
                  padding: EdgeInsets.zero,
                  onSelected: (id) {
                    final p = profiles.getProfile(id);
                    if (p != null) globalState.appController.setProfileAndAutoApply(p);
                  },
                  itemBuilder: (_) => [
                    for (final p in profiles)
                      PopupMenuItem(value: p.id, child: Text(p.label ?? p.id, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.label ?? profile.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: MeowFont.subheadline, fontWeight: FontWeight.w500, color: mm.t1),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, size: 16, color: mm.t3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasUsage)
                Text(
                  total > 0 ? '${fmtSize(used)} / ${fmtSize(total)}' : '${fmtSize(used)} / ${S.unlimited}',
                  style: MeowFont.mono(size: MeowFont.caption, color: mm.t2),
                ),
            ],
          ),
          if (hasUsage) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 4,
                backgroundColor: mm.t3.withValues(alpha: 0.15),
                color: frac > 0.9 ? mm.slow : mm.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySubscriptionBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ref.read(meowTabProvider.notifier).state = MeowTab.profiles;
        ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: mm.t1.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 16, color: mm.accent),
            const SizedBox(width: 6),
            Text('${S.noSubscription} · ${S.goImport}', style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2)),
          ],
        ),
      ),
    );
  }
}

/// 「规则 | 全局 | 直连」分段。全局 = 全部流量走 GLOBAL 组选中的节点（代理页顶部会出现 GLOBAL 组）。
class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.mode, required this.onChanged});
  final Mode mode;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    Widget seg(Mode m, String label) {
      final on = mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: on ? mm.elev : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: MeowFont.footnote, fontWeight: FontWeight.w600, color: on ? mm.t1 : mm.t2),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: mm.t1.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(11)),
      child: Row(children: [seg(Mode.rule, S.modeRule), seg(Mode.global, S.modeGlobal), seg(Mode.direct, S.modeDirect)]),
    );
  }
}

/// 出口 IP：两列「国内 · 直连出口」|「国际 · 经 代理」；国旗 + 标题 caption2 + IP footnote 等宽；右上刷新。
/// 连接状态或节点变化（checkIpNum）后延迟 1.5s 重查；国内列不需要连接。
class _ExitIpCard extends ConsumerStatefulWidget {
  const _ExitIpCard();

  @override
  ConsumerState<_ExitIpCard> createState() => _ExitIpCardState();
}

class _ExitIpCardState extends ConsumerState<_ExitIpCard> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    ref.listenManual(isRunningProvider, (prev, next) => _schedule(running: next));
    ref.listenManual(checkIpNumProvider, (prev, next) => _schedule(running: ref.read(isRunningProvider)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule(running: ref.read(isRunningProvider), delay: Duration.zero));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule({required bool running, Duration delay = const Duration(milliseconds: 1500)}) {
    _debounce?.cancel();
    if (!running) ref.read(exitIpProvider.notifier).clearGlobal();
    _debounce = Timer(delay, () {
      if (!mounted) return;
      unawaited(ref.read(exitIpProvider.notifier).refresh(running: ref.read(isRunningProvider)));
    });
  }

  static String flag(String code) {
    final c = code.toUpperCase();
    if (c.length != 2) return '🌐';
    return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + (u - 65)));
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final running = ref.watch(isRunningProvider);
    final st = ref.watch(exitIpProvider);
    Widget col(String title, IpInfo? info, {required bool loading, required String placeholder}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: MeowFont.caption2, color: mm.t2)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (info != null) ...[Text(flag(info.countryCode), style: const TextStyle(fontSize: 14)), const SizedBox(width: 5)],
            Expanded(
              child: Text(
                info?.ip ?? (loading ? S.querying : placeholder),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MeowFont.mono(size: MeowFont.footnote, color: info == null ? mm.t3 : mm.t1),
              ),
            ),
          ],
        ),
      ],
    );
    final busy = st.loadingDomestic || st.loadingGlobal;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, size: MeowFont.footnote + 2, color: mm.accent),
              const SizedBox(width: 5),
              Text(S.exitIp, style: TextStyle(fontSize: MeowFont.caption, color: mm.t2)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: busy ? null : () => _schedule(running: running, delay: Duration.zero),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: busy
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: mm.t3))
                      : Icon(Icons.refresh_rounded, size: 16, color: mm.t2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: col(S.domesticDirect, st.domestic, loading: st.loadingDomestic, placeholder: '—')),
                Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 10), color: mm.t3.withValues(alpha: 0.2)),
                Expanded(child: col('${S.globalVia} ${st.globalVia ?? '代理'}', st.global, loading: st.loadingGlobal, placeholder: running ? '—' : S.disconnected)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

