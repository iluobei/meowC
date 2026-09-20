import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:bett_box/widgets/icon.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/meow_tab.dart';
import '../../app/strings.dart';
import '../../state/meow_settings.dart';
import '../../state/status.dart';
import '../../theme/badges.dart';
import '../../theme/glass_card.dart';
import '../../theme/page_title.dart';
import '../../theme/tokens.dart';
import '../../theme/two_pane.dart';

/// 展开的组（默认全部收起，不落盘）。
final expandedGroupsProvider = StateProvider<Set<String>>((ref) => {});

/// 宽屏左栏选中的组。
final selectedGroupProvider = StateProvider<String?>((ref) => null);

/// 全部叶子节点（去重）。
List<Proxy> _allLeafProxies(List<Group> groups) {
  final seen = <String>{};
  final out = <Proxy>[];
  for (final g in groups) {
    for (final p in g.all) {
      if (isGroupType(p.type)) continue;
      if (seen.add(p.name)) out.add(p);
    }
  }
  return out;
}

class ProxiesPage extends ConsumerStatefulWidget {
  const ProxiesPage({super.key});

  @override
  ConsumerState<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends ConsumerState<ProxiesPage> {
  bool _testingAll = false;

  Future<void> _testAll(List<Group> groups) async {
    if (_testingAll) return;
    setState(() => _testingAll = true);
    try {
      await delayTest(_allLeafProxies(groups));
    } finally {
      if (mounted) setState(() => _testingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final wide = ref.watch(isWideLayoutProvider);
    final groups = ref.watch(currentGroupsStateProvider.select((s) => s.value));
    final hasProfile = ref.watch(currentProfileProvider) != null;
    final size = ref.watch(meowSettingProvider.select((s) => s.nodeCardSize));
    final nodeCount = _allLeafProxies(groups).length;

    final title = PageTitle(
      S.proxies,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<NodeCardSize>(
            tooltip: S.nodeView,
            onSelected: (v) => ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(nodeCardSize: v)),
            itemBuilder: (_) => [
              for (final v in NodeCardSize.values)
                CheckedPopupMenuItem(value: v, checked: v == size, child: Text(v.label)),
            ],
            child: RoundGlassButton(icon: Icons.grid_view_rounded, onTap: null),
          ),
          const SizedBox(width: 8),
          RoundGlassButton(
            icon: Icons.bolt_rounded,
            color: mm.accent,
            busy: _testingAll,
            tooltip: S.testAll,
            onTap: groups.isEmpty ? null : () => _testAll(groups),
          ),
        ],
      ),
      subtitle: Text(
        S.groupsAndNodes(groups.length, nodeCount),
        style: TextStyle(fontSize: MeowFont.caption, color: mm.t3),
      ),
    );

    if (!hasProfile || groups.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(wide ? 0 : 16, wide ? 16 : 0, 16, 16),
        children: [
          title,
          const SizedBox(height: 80),
          _EmptyState(
            icon: Icons.bolt_rounded,
            title: hasProfile ? '暂无代理组' : S.noConfig,
            subtitle: hasProfile ? '当前订阅没有代理组，或核心尚未加载' : S.goImport,
            onTap: hasProfile
                ? null
                : () {
                    ref.read(meowTabProvider.notifier).state = MeowTab.profiles;
                    ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
                  },
          ),
        ],
      );
    }

    if (!wide) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        itemCount: groups.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 12), child: title);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(group: groups[i - 1], size: size),
          );
        },
      );
    }

    final selectedName = ref.watch(selectedGroupProvider);
    final selected = groups.where((g) => g.name == selectedName).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(right: 16, top: 16), child: title),
        const SizedBox(height: 8),
        Expanded(
          child: TwoPane(
            left: ListView.builder(
              padding: const EdgeInsets.only(right: 12, bottom: 16),
              itemCount: groups.length,
              itemBuilder: (_, i) => _GroupRow(
                group: groups[i],
                selected: groups[i].name == selectedName,
                onTap: () => ref.read(selectedGroupProvider.notifier).state = groups[i].name,
              ),
            ),
            right: selected == null
                ? const _EmptyState(icon: Icons.hexagon_outlined, title: S.chooseGroup)
                : _GroupDetail(group: selected, size: size),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: mm.t3),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: MeowFont.headline, fontWeight: FontWeight.w600, color: mm.t1)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 组头行：icon 20 + 名 headline + TypeBadge + 成员数 + 当前选中 LatencyChip + 闪电 + chevron。
class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.group, this.expanded, this.onToggle, this.dense = false});
  final Group group;
  final bool? expanded;
  final VoidCallback? onToggle;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final badge = groupBadge(group.type.name, mm);
    final selectedName = ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    final delay = selectedName.isEmpty ? null : ref.watch(getDelayProvider(proxyName: selectedName, testUrl: group.testUrl));
    return Row(
      children: [
        if (group.icon.isNotEmpty) ...[
          CommonTargetIcon(src: group.icon, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: MeowFont.headline, fontWeight: FontWeight.w600, color: mm.t1),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TypeBadge(badge.label, color: badge.color),
        const SizedBox(width: 6),
        Text('${group.all.length}', style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3)),
        const Spacer(),
        if (!dense && delay != null && delay != 0) LatencyChip(delay, mode: mode),
        const SizedBox(width: 4),
        _GroupTestButton(group: group),
        if (expanded != null)
          Icon(expanded! ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: mm.t3),
      ],
    );
  }
}

class _GroupTestButton extends StatelessWidget {
  const _GroupTestButton({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return ListenableBuilder(
      listenable: delayTestCoordinator,
      builder: (_, _) {
        final testing = delayTestCoordinator.isTestingGroup(group.name);
        return SizedBox(
          width: 32,
          height: 32,
          child: testing
              ? Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: mm.accent)))
              : IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(Icons.bolt_rounded, color: mm.accent),
                  tooltip: S.testGroup,
                  onPressed: () => delayTest(group.all, testUrl: group.testUrl, groupName: group.name),
                ),
        );
      },
    );
  }
}

/// 手机端组卡：默认收起，收起时常驻「当前选中」行；点名字展开 / 点闪电测速分离。
class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.size});
  final Group group;
  final NodeCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final expanded = ref.watch(expandedGroupsProvider.select((s) => s.contains(group.name)));
    final selectedName = ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    void toggle() {
      final set = {...ref.read(expandedGroupsProvider)};
      if (!set.remove(group.name)) set.add(group.name);
      ref.read(expandedGroupsProvider.notifier).state = set;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(group: group, expanded: expanded, onToggle: toggle, dense: true),
          const SizedBox(height: 10),
          if (!expanded)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: toggle,
              child: Row(
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: mm.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedName.isEmpty ? S.currentSelected : selectedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2),
                    ),
                  ),
                  if (selectedName.isNotEmpty)
                    LatencyChip(ref.watch(getDelayProvider(proxyName: selectedName, testUrl: group.testUrl)), mode: mode),
                ],
              ),
            )
          else
            _NodeGrid(group: group, size: size),
        ],
      ),
    );
  }
}

/// 宽屏左栏组行：icon + 名 + TypeBadge / 当前选中 + LatencyChip / 成员数 / 闪电；选中行底 accent 0.16。
class _GroupRow extends ConsumerWidget {
  const _GroupRow({required this.group, required this.selected, required this.onTap});
  final Group group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final badge = groupBadge(group.type.name, mm);
    final selectedName = ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    return Material(
      color: selected ? mm.accent.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (group.icon.isNotEmpty) ...[CommonTargetIcon(src: group.icon, size: 22), const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: MeowFont.body, fontWeight: FontWeight.w600, color: mm.t1)),
                        ),
                        const SizedBox(width: 6),
                        TypeBadge(badge.label, color: badge.color),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(selectedName.isEmpty ? '—' : selectedName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: MeowFont.footnote, color: mm.t2)),
                        ),
                        if (selectedName.isNotEmpty)
                          LatencyChip(ref.watch(getDelayProvider(proxyName: selectedName, testUrl: group.testUrl)), mode: mode),
                        const SizedBox(width: 6),
                        Text('${group.all.length}', style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3)),
                      ],
                    ),
                  ],
                ),
              ),
              _GroupTestButton(group: group),
            ],
          ),
        ),
      ),
    );
  }
}

/// 宽屏右栏：组头 + 节点网格。
class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.group, required this.size});
  final Group group;
  final NodeCardSize size;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _GroupHeader(group: group),
        const SizedBox(height: 12),
        _NodeGrid(group: group, size: size, wide: true),
      ],
    );
  }
}

/// 节点网格：紧凑 3 列 / 标准 2 列 / 大 1 列；宽屏按最小宽度自适应；间距 9。
class _NodeGrid extends ConsumerWidget {
  const _NodeGrid({required this.group, required this.size, this.wide = false});
  final Group group;
  final NodeCardSize size;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedName = ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final metas = ref.watch(proxyMetaProvider);
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    final isSelector = group.type == GroupType.Selector;
    final (minW, rowH) = switch (size) {
      NodeCardSize.compact => (112.0, 34.0),
      NodeCardSize.standard => (150.0, 58.0),
      NodeCardSize.large => (230.0, 58.0),
    };
    return LayoutBuilder(
      builder: (context, c) {
        final columns = wide
            ? (c.maxWidth / minW).floor().clamp(1, 8)
            : switch (size) { NodeCardSize.compact => 3, NodeCardSize.standard => 2, NodeCardSize.large => 1 };
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            mainAxisExtent: rowH,
          ),
          itemCount: group.all.length,
          itemBuilder: (_, i) {
            final p = group.all[i];
            return _NodeCell(
              proxy: p,
              group: group,
              meta: metas[p.name],
              selected: p.name == selectedName,
              size: size,
              mode: mode,
              onTap: isSelector
                  ? () {
                      final c = globalState.appController;
                      c.updateCurrentSelectedMap(group.name, p.name);
                      c.changeProxyDebounce(group.name, p.name);
                    }
                  : null,
            );
          },
        );
      },
    );
  }
}

/// 节点格：协议色点 + 名；行 2 副标题 + 延迟胶囊（点 = 测该成员）；底 primary 0.05 圆角 13；选中 accent 描边 + 发光。
class _NodeCell extends ConsumerWidget {
  const _NodeCell({
    required this.proxy,
    required this.group,
    required this.meta,
    required this.selected,
    required this.size,
    required this.mode,
    required this.onTap,
  });

  final Proxy proxy;
  final Group group;
  final ProxyMeta? meta;
  final bool selected;
  final NodeCardSize size;
  final LatencyMode mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final nested = isGroupType(proxy.type);
    final builtin = builtinSubtitle(proxy.name);
    final style = protoStyle(proxy.type, mm);
    final dotColor = builtin != null ? mm.good : (nested ? mm.accent : style.color);
    final subtitle = builtin ?? (nested ? '${S.nestedGroup} · ${groupBadge(proxy.type, mm).label}' : (meta?.securitySubtitle.isNotEmpty == true ? '${style.label} · ${meta!.securitySubtitle}' : style.label));
    final delay = ref.watch(getDelayProvider(proxyName: proxy.name, testUrl: group.testUrl));
    final compact = size == NodeCardSize.compact;
    final testable = !const {'REJECT', 'REJECT-DROP', 'PASS'}.contains(proxy.name.toUpperCase());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 7 : 10),
        decoration: BoxDecoration(
          color: mm.t1.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? mm.accent : mm.t1.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: mm.accent.withValues(alpha: 0.5), blurRadius: 10)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    proxy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 12 : MeowFont.subheadline, fontWeight: FontWeight.w500, color: mm.t1),
                  ),
                ),
                if (nested) Icon(Icons.layers_rounded, size: 14, color: mm.t3),
                if (compact && testable) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => proxyDelayTest(proxy, group.testUrl),
                    child: LatencyChip(delay, mode: mode, testing: delay == 0),
                  ),
                ],
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3),
                    ),
                  ),
                  if (testable)
                    GestureDetector(
                      onTap: () => proxyDelayTest(proxy, group.testUrl),
                      child: LatencyChip(delay, mode: mode, testing: delay == 0),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
