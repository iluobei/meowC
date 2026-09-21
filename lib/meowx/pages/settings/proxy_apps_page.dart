import 'dart:async';
import 'dart:typed_data';

import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';

/// 代理应用（Android 分应用代理）：开启后只有勾选的应用走 VPN，其余应用直连。
/// 数据沿用 Bettbox 的 `VpnProps.accessControl`（白名单模式 acceptSelected），VPN 服务按它调 addAllowedApplication；
/// 运行中改动由 Bettbox 的 VpnManager 弹「重启生效」提示。更细的选项（黑名单、排序、手动包名）在「高级 → 访问控制」。
class ProxyAppsPage extends ConsumerStatefulWidget {
  const ProxyAppsPage({super.key});

  @override
  ConsumerState<ProxyAppsPage> createState() => _ProxyAppsPageState();
}

class _ProxyAppsPageState extends ConsumerState<ProxyAppsPage> with WidgetsBindingObserver {
  final _search = TextEditingController();
  bool _loading = false;
  bool _denied = false;
  bool _showSystem = false;

  /// 进页面时已勾选的应用：排在最前。勾选过程中不重排，免得刚点的那一行跳走。
  late Set<String> _pinned = ref.read(vpnSettingProvider).accessControl.acceptList.toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(vpnSettingProvider).accessControl.enable) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置授权「读取应用列表」回来后重试
    if (state == AppLifecycleState.resumed && _denied) unawaited(_load(force: true));
  }

  Future<void> _load({bool force = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final list = await globalState.appController.getPackages(forceRefresh: force);
      if (mounted) {
        setState(() {
          _denied = list.isEmpty;
          _pinned = ref.read(vpnSettingProvider).accessControl.acceptList.toSet();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setEnabled(bool on) {
    ref.read(vpnSettingProvider.notifier).updateState(
      (s) => s.copyWith.accessControl(enable: on, mode: AccessControlMode.acceptSelected),
    );
    if (on) unawaited(_load());
  }

  void _toggle(String packageName, bool on) {
    ref.read(vpnSettingProvider.notifier).updateState((s) {
      final list = [...s.accessControl.acceptList];
      if (on) {
        if (!list.contains(packageName)) list.add(packageName);
      } else {
        list.remove(packageName);
      }
      return s.copyWith.accessControl(acceptList: list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final access = ref.watch(vpnSettingProvider.select((s) => s.accessControl));
    final packages = ref.watch(packagesProvider);
    final selected = access.acceptList.toSet();
    final q = _search.text.trim().toLowerCase();

    // 没有联网权限的应用代理不代理都一样，不列；系统应用默认收起（已勾选的始终显示）
    final visible = packages.where((p) {
      final chosen = selected.contains(p.packageName);
      if (!p.internet && !chosen) return false;
      if (!_showSystem && p.system && !chosen) return false;
      if (q.isEmpty) return true;
      return p.label.toLowerCase().contains(q) || p.packageName.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final sa = _pinned.contains(a.packageName), sb = _pinned.contains(b.packageName);
        if (sa != sb) return sa ? -1 : 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    return Scaffold(
      backgroundColor: mm.bg,
      appBar: AppBar(
        title: const Text('代理应用'),
        backgroundColor: mm.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Material(
              color: mm.elev,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile.adaptive(
                title: Text('只代理勾选的应用', style: TextStyle(fontSize: MeowFont.body, color: mm.t1)),
                subtitle: Text(
                  access.enable ? '已选 ${selected.length} 个应用，其余应用直连' : '关闭时全部应用都走代理',
                  style: TextStyle(fontSize: MeowFont.caption, color: mm.t3),
                ),
                value: access.enable,
                onChanged: _setEnabled,
              ),
            ),
          ),
          if (access.enable) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '搜索应用 / 包名',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: mm.elev,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('系统应用'),
                    selected: _showSystem,
                    onSelected: (v) => setState(() => _showSystem = v),
                  ),
                ],
              ),
            ),
            Expanded(child: _list(mm, visible, selected)),
          ] else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '开启后在这里勾选需要走代理的应用。\n修改名单后需要重新连接才会生效。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(MeowTokens mm, List<Package> visible, Set<String> selected) {
    if (_loading && visible.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apps_outage_rounded, size: 46, color: mm.t3),
              const SizedBox(height: 12),
              Text('读不到应用列表', style: TextStyle(fontSize: MeowFont.headline, fontWeight: FontWeight.w600, color: mm.t1)),
              const SizedBox(height: 4),
              Text(
                '部分系统需要单独授予「读取应用列表」权限',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => app.requestPackageListPermission(),
                child: const Text('去授权'),
              ),
            ],
          ),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _showSystem ? '没有匹配的应用' : '没有匹配的应用，试试打开右上的「系统应用」',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t3),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: visible.length,
        itemBuilder: (_, i) {
          final p = visible[i];
          final on = selected.contains(p.packageName);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: on ? mm.accent.withValues(alpha: 0.10) : mm.elev,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: on ? BorderSide(color: mm.accent.withValues(alpha: 0.55)) : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _toggle(p.packageName, !on),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      _AppIcon(packageName: p.packageName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: MeowFont.subheadline, fontWeight: FontWeight.w500, color: mm.t1),
                            ),
                            Text(
                              p.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(value: on, onChanged: (v) => _toggle(p.packageName, v ?? false)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppIcon extends StatefulWidget {
  const _AppIcon({required this.packageName});
  final String packageName;

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  late Future<Uint8List?> _icon = _fetch();

  Future<Uint8List?> _fetch() => app.getPackageIcon(widget.packageName);

  @override
  void didUpdateWidget(_AppIcon old) {
    super.didUpdateWidget(old);
    if (old.packageName != widget.packageName) _icon = _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final size = 36 * MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: FutureBuilder<Uint8List?>(
        future: _icon,
        builder: (_, snap) {
          final data = snap.data;
          if (data == null) return Icon(Icons.android_rounded, size: 26, color: mm.t3);
          return Image.memory(
            data,
            gaplessPlayback: true,
            cacheWidth: size.ceil(),
            cacheHeight: size.ceil(),
            errorBuilder: (_, _, _) => Icon(Icons.android_rounded, size: 26, color: mm.t3),
          );
        },
      ),
    );
  }
}
