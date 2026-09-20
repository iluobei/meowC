import 'dart:async';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/meow_root.dart';
import '../../app/meow_tab.dart';
import '../../app/strings.dart';
import '../../state/format.dart';
import '../../state/status.dart';
import '../../theme/badges.dart';
import '../../theme/glass_card.dart';
import '../../theme/page_title.dart';
import '../../theme/tokens.dart';
import '../../theme/two_pane.dart';

enum _Seg { connections, logs }

/// 连接页：「连接 | 日志」分段 + 胶囊搜索；仅在页可见且已连接时每 1.5s 轮询；宽屏右栏详情。
class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  _Seg _seg = _Seg.connections;
  String _query = '';
  List<TrackerInfo> _conns = const [];
  String? _selectedId;
  Timer? _timer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => unawaited(_poll()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _visible => ref.read(meowTabProvider) == MeowTab.connections;

  Future<void> _poll() async {
    if (!mounted || _polling) return;
    if (!ref.read(isRunningProvider)) {
      if (_conns.isNotEmpty) setState(() => _conns = const []);
      return;
    }
    if (!_visible) {
      if (_conns.isNotEmpty) setState(() => _conns = const []);   // 离屏清空
      return;
    }
    _polling = true;
    try {
      final list = await clashCore.getConnections();
      if (!mounted) return;
      ref.read(connectionCountProvider.notifier).state = list.length;
      setState(() => _conns = list);
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  List<TrackerInfo> get _filtered {
    if (_query.isEmpty) return _conns;
    final q = _query.toLowerCase();
    return _conns.where((c) {
      return c.metadata.host.toLowerCase().contains(q) ||
          c.metadata.destinationIP.contains(q) ||
          c.chains.any((s) => s.toLowerCase().contains(q)) ||
          c.rule.toLowerCase().contains(q) ||
          c.rulePayload.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final wide = ref.watch(isWideLayoutProvider);
    final running = ref.watch(isRunningProvider);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(S.connections),
        const SizedBox(height: 10),
        Row(
          children: [
            _Segment(
              value: _seg,
              onChanged: (v) => setState(() {
                _seg = v;
                _query = '';
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t1),
                  decoration: InputDecoration(
                    hintText: _seg == _Seg.connections ? '搜索域名 / 目标 / 规则' : '搜索日志',
                    hintStyle: TextStyle(fontSize: MeowFont.subheadline, color: mm.t3),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: mm.t3),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: mm.glassTint.withValues(alpha: 0.5),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: mm.glassEdge.withValues(alpha: 0.14))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: mm.accent)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );

    final Widget list;
    if (_seg == _Seg.logs) {
      list = _LogList(query: _query);
    } else if (!running) {
      list = const _Empty(icon: Icons.power_off_rounded, text: S.tunnelNotConnected);
    } else {
      final items = _filtered;
      final totalUp = items.fold<int>(0, (a, c) => a + c.upload);
      final totalDown = items.fold<int>(0, (a, c) => a + c.download);
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${items.length} 条', style: TextStyle(fontSize: MeowFont.footnote, color: mm.t2)),
              const SizedBox(width: 10),
              Text('↑ ${fmtSize(totalUp)}', style: MeowFont.mono(size: MeowFont.footnote, color: mm.accent)),
              const SizedBox(width: 8),
              Text('↓ ${fmtSize(totalDown)}', style: MeowFont.mono(size: MeowFont.footnote, color: mm.accent)),
              const Spacer(),
              if (_conns.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: mm.slow, visualDensity: VisualDensity.compact),
                  onPressed: () {
                    clashCore.closeConnections();
                    setState(() => _conns = const []);
                  },
                  child: const Text('全部关闭'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            _Empty(icon: Icons.inbox_rounded, text: _query.isEmpty ? '暂无活动连接' : '无匹配连接')
          else
            Expanded(
              child: wide
                  ? ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ConnRow(
                        c: items[i],
                        selected: items[i].id == _selectedId,
                        onTap: () => setState(() => _selectedId = items[i].id),
                        onClose: () => _close(items[i].id),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ConnRow(c: items[i], selected: false, onClose: () => _close(items[i].id)),
                    ),
            ),
        ],
      );
    }

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, Expanded(child: list)]),
      );
    }
    final selected = _conns.where((c) => c.id == _selectedId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(right: 16, top: 16), child: header),
        Expanded(
          child: TwoPane(
            left: Padding(padding: const EdgeInsets.only(right: 12), child: list),
            right: _seg == _Seg.logs
                ? const SizedBox.shrink()
                : selected == null
                    ? const _Empty(icon: Icons.touch_app_outlined, text: '选择一条连接')
                    : _ConnDetail(c: selected, onClose: () => _close(selected.id)),
          ),
        ),
      ],
    );
  }

  void _close(String id) {
    clashCore.closeConnection(id);
    setState(() {
      _conns = _conns.where((c) => c.id != id).toList();
      if (_selectedId == id) _selectedId = null;
    });
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.onChanged});
  final _Seg value;
  final ValueChanged<_Seg> onChanged;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    Widget seg(_Seg s, String label) {
      final on = s == value;
      return GestureDetector(
        onTap: () => onChanged(s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? mm.elev : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
          ),
          child: Text(label, style: TextStyle(fontSize: MeowFont.footnote, fontWeight: FontWeight.w600, color: on ? mm.t1 : mm.t2)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: mm.t1.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg(_Seg.connections, '连接'), seg(_Seg.logs, '日志')]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: mm.t3),
            const SizedBox(height: 10),
            Text(text, style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2)),
          ],
        ),
      ),
    );
  }
}

String _hostOf(TrackerInfo c) => c.metadata.host.isNotEmpty ? c.metadata.host : c.metadata.destinationIP;
String _targetOf(TrackerInfo c) => c.chains.isEmpty ? '—' : c.chains.first;
String _ruleOf(TrackerInfo c) => c.rulePayload.isEmpty ? c.rule : '${c.rule}(${c.rulePayload})';

/// 连接行：TypeBadge(UDP 橙 / TCP accent) + host；↳ target 紫 + rule t3；↑ ↓ 时长；右侧关闭。
class _ConnRow extends StatelessWidget {
  const _ConnRow({required this.c, required this.selected, required this.onClose, this.onTap});
  final TrackerInfo c;
  final bool selected;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final udp = c.metadata.network.toLowerCase() == 'udp';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 13,
        padding: const EdgeInsets.all(12),
        color: selected ? mm.accent.withValues(alpha: 0.16) : null,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TypeBadge(udp ? 'UDP' : 'TCP', color: udp ? mm.orange : mm.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${_hostOf(c)}:${c.metadata.destinationPort}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: MeowFont.subheadline, fontWeight: FontWeight.w500, color: mm.t1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: mm.t3),
                      const SizedBox(width: 4),
                      Flexible(child: Text(_targetOf(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: MeowFont.caption, color: mm.pur))),
                      const SizedBox(width: 8),
                      Flexible(child: Text(_ruleOf(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '↑ ${fmtSize(c.upload)}   ↓ ${fmtSize(c.download)}   ${fmtElapsed(DateTime.now().difference(c.start))}',
                    style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.cancel_rounded, color: mm.t3),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// 宽屏右栏：四卡「出站链路 / 命中规则 / 上传 / 下载」+ 三行「网络 / 主机 / 已持续」+ 红色「关闭连接」。
class _ConnDetail extends StatelessWidget {
  const _ConnDetail({required this.c, required this.onClose});
  final TrackerInfo c;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    Widget card(String title, String value, {Color? color, bool mono = false}) => GlassCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: MeowFont.caption, color: mm.t2)),
          const SizedBox(height: 6),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: mono ? MeowFont.mono(size: MeowFont.subheadline, weight: FontWeight.w600, color: color ?? mm.t1)
                  : TextStyle(fontSize: MeowFont.subheadline, fontWeight: FontWeight.w600, color: color ?? mm.t1)),
        ],
      ),
    );
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(k, style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2)),
          const Spacer(),
          Flexible(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: MeowFont.mono(size: MeowFont.subheadline, color: mm.t1))),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: card('出站链路', c.chains.reversed.join(' → '), color: mm.pur)),
          const SizedBox(width: 12),
          Expanded(child: card('命中规则', _ruleOf(c), mono: true)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: card('上传', fmtSize(c.upload), mono: true)),
          const SizedBox(width: 12),
          Expanded(child: card('下载', fmtSize(c.download), mono: true)),
        ]),
        const SizedBox(height: 12),
        GlassCard(
          radius: 16,
          child: Column(
            children: [
              line('网络', c.metadata.network.toUpperCase()),
              line('主机', '${_hostOf(c)}:${c.metadata.destinationPort}'),
              if (c.metadata.destinationIP.isNotEmpty && c.metadata.host.isNotEmpty) line('目标 IP', c.metadata.destinationIP),
              line('已持续', fmtElapsed(DateTime.now().difference(c.start))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: mm.slow),
          onPressed: onClose,
          child: const Text('关闭连接'),
        ),
      ],
    );
  }
}

/// 日志行：时间 HH:mm:ss 等宽 t3 + 6pt 级别点 + 消息 caption 等宽；默认关，环形 300；自动滚底。
class _LogList extends ConsumerStatefulWidget {
  const _LogList({required this.query});
  final String query;

  @override
  ConsumerState<_LogList> createState() => _LogListState();
}

class _LogListState extends ConsumerState<_LogList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static final _time = RegExp(r'\d{2}:\d{2}:\d{2}');

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final open = ref.watch(appSettingProvider.select((s) => s.openLogs));
    final all = ref.watch(logsProvider).list;
    final q = widget.query.toLowerCase();
    final logs = q.isEmpty ? all : all.where((l) => l.payload.toLowerCase().contains(q)).toList();
    if (!open) {
      return _Empty(icon: Icons.notes_rounded, text: '日志已关闭 · 在「设置 → 日志」打开');
    }
    if (logs.isEmpty) {
      return _Empty(icon: Icons.notes_rounded, text: q.isEmpty ? '暂无日志' : '无匹配日志');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && q.isEmpty) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
    return ListView.builder(
      controller: _scroll,
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final l = logs[i];
        final color = switch (l.logLevel) {
          LogLevel.error => mm.accent,
          LogLevel.warning => mm.orange,
          _ => mm.good,
        };
        final t = _time.firstMatch(l.dateTime)?.group(0) ?? l.dateTime;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(top: 4), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.payload, style: MeowFont.mono(size: MeowFont.caption, color: l.logLevel == LogLevel.error ? mm.accent : mm.t1)),
              ),
            ],
          ),
        );
      },
    );
  }
}
