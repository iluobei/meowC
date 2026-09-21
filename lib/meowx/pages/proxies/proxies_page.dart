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
import '../../panel/account.dart';
import '../../state/meow_settings.dart';
import '../../state/status.dart';
import '../../theme/badges.dart';
import '../../theme/page_title.dart';
import '../../theme/tokens.dart';
import '../../theme/two_pane.dart';
import '../../theme/unlock_badge.dart';

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

/// 组当前选中的节点，沿选中链解析到叶子（组里选的是另一个组就继续往下找）。
final _currentLeafProvider = Provider.autoDispose.family<String, String>((ref, groupName) {
  var name = groupName;
  final seen = <String>{};
  while (seen.add(name)) {
    final next = ref.watch(getSelectedProxyNameProvider(name));
    if (next == null || next.isEmpty) break;   // 不是组（已到叶子）或还没有选中
    name = next;
  }
  return name == groupName ? '' : name;
});

/// 组当前选中节点（叶子）的回程奖牌 + 解锁徽标，放在组行 / 组头的延迟胶囊前。
class _CurrentBadges extends ConsumerWidget {
  const _CurrentBadges({required this.groupName});
  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaf = ref.watch(_currentLeafProvider(groupName));
    if (leaf.isEmpty) return const SizedBox.shrink();
    final medal = ref.watch(medalsProvider.select((m) => m[leaf]));
    final unlocks = ref.watch(unlocksProvider.select((m) => m[leaf]));
    if (medal == null && unlocks == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (medal != null) ...[MedalBadge(medal, size: 14), const SizedBox(width: 4)],
        if (unlocks != null) ...[UnlockBadge(unlocks, size: 14), const SizedBox(width: 4)],
      ],
    );
  }
}

const _cardRadius = 26.0;
const _cardPadding = 14.0;
const _gridSpacing = 9.0;

/// 节点格高度：两行（名 + 副标题）。
const _cellHeight = 58.0;

/// 代理页。手机端整页是一个 CustomScrollView：每个组卡 = DecoratedSliver（卡片底）+ 组头 + 懒加载的 SliverGrid，
/// 300 个节点展开时只构建可见的格子（之前 shrinkWrap GridView 一次建全部，展开 / 选节点都会掉帧）。
class ProxiesPage extends ConsumerStatefulWidget {
  const ProxiesPage({super.key});

  @override
  ConsumerState<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends ConsumerState<ProxiesPage> {
  bool _testingAll = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(meowTabProvider, (prev, next) {
      if (next == MeowTab.proxies) _refreshExtras();
    }, fireImmediately: true);
  }

  void _refreshExtras() {
    if (demoExtras) {
      seedDemoExtras(
        ref,
        _allLeafProxies(
          ref.read(currentGroupsStateProvider).value,
        ).map((p) => p.name).toList(),
      );
      return;
    }
    if (ref.read(isLoggedInProvider)) {
      ref.read(accountActionsProvider).refreshExtras(ifStale: true);
    }
  }

  /// 一个组 = 头（上圆角卡）+ 展开时的节点网格（直角底）+ 下圆角收尾。
  /// 不用 SliverMainAxisGroup：它滚动后的命中测试有偏移，节点点不中。
  List<Widget> _groupSlivers(Group g, int columns) {
    final mm = context.mm;
    final expanded = ref.watch(
      expandedGroupsProvider.select((s) => s.contains(g.name)),
    );
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, expanded ? 0 : 12),
        sliver: SliverToBoxAdapter(
          child: _GroupHead(group: g, expanded: expanded),
        ),
      ),
      if (expanded) ...[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: DecoratedSliver(
            decoration: BoxDecoration(color: mm.elev),
            sliver: SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: _cardPadding),
              sliver: _NodeSliverGrid(group: g, columns: columns),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Container(
              height: _cardPadding,
              decoration: BoxDecoration(
                color: mm.elev,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_cardRadius),
                ),
              ),
            ),
          ),
        ),
      ],
    ];
  }

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
    final wide = ref.watch(isTwoPaneProvider);
    final groups = ref.watch(currentGroupsStateProvider.select((s) => s.value));
    final hasProfile = ref.watch(currentProfileProvider) != null;
    final size = ref.watch(meowSettingProvider.select((s) => s.nodeCardSize));
    final layout = ref.watch(meowSettingProvider.select((s) => s.proxyLayout));
    final nodeCount = _allLeafProxies(groups).length;

    final title = PageTitle(
      S.proxies,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<Object>(
            tooltip: S.nodeView,
            onSelected: (v) => ref
                .read(meowSettingProvider.notifier)
                .updateState(
                  (s) => switch (v) {
                    ProxyLayout l => s.copyWith(proxyLayout: l),
                    NodeCardSize c => s.copyWith(nodeCardSize: c),
                    _ => s,
                  },
                ),
            itemBuilder: (_) => [
              // 宽屏恒为两栏，布局切换只给手机
              if (!wide) ...[
                _menuCaption(S.layout, mm),
                for (final v in ProxyLayout.values)
                  CheckedPopupMenuItem<Object>(
                    value: v,
                    checked: v == layout,
                    child: Text(v.label),
                  ),
                const PopupMenuDivider(),
                _menuCaption(S.cardSize, mm),
              ],
              for (final v in NodeCardSize.values)
                CheckedPopupMenuItem<Object>(
                  value: v,
                  checked: v == size,
                  child: Text(v.label),
                ),
            ],
            child: RoundGlassButton(
              icon: layout == ProxyLayout.tabs && !wide
                  ? Icons.view_carousel_rounded
                  : Icons.grid_view_rounded,
              onTap: null,
            ),
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
                    ref.read(currentPageLabelProvider.notifier).value =
                        PageLabel.profiles;
                  },
          ),
        ],
      );
    }

    if (!wide && layout == ProxyLayout.tabs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: title,
          ),
          Expanded(
            child: _GroupTabs(
              groups: groups,
              columns: size == NodeCardSize.large ? 1 : 2,
            ),
          ),
        ],
      );
    }

    if (!wide) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(child: title),
          ),
          for (final g in groups)
            ..._groupSlivers(g, size == NodeCardSize.large ? 1 : 2),
          SliverPadding(padding: EdgeInsets.only(bottom: 12 + MediaQuery.paddingOf(context).bottom)),
        ],
      );
    }

    final selectedName = ref.watch(selectedGroupProvider);
    final selected = groups.where((g) => g.name == selectedName).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 16),
          child: title,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TwoPane(
            left: ListView.builder(
              padding: const EdgeInsets.only(right: 12, bottom: 16),
              itemCount: groups.length,
              itemBuilder: (_, i) => _GroupRow(
                group: groups[i],
                selected: groups[i].name == selectedName,
                onTap: () => ref.read(selectedGroupProvider.notifier).state =
                    groups[i].name,
              ),
            ),
            right: selected == null
                ? const _EmptyState(
                    icon: Icons.hexagon_outlined,
                    title: S.chooseGroup,
                  )
                : _GroupDetail(group: selected, size: size),
          ),
        ),
      ],
    );
  }
}

PopupMenuItem<Object> _menuCaption(String text, MeowTokens mm) => PopupMenuItem(
  enabled: false,
  height: 28,
  child: Text(
    text,
    style: TextStyle(fontSize: MeowFont.caption, color: mm.t3),
  ),
);

/// 标签布局（手机）：顶部一条横向滚动的组标签，下面是 PageView——一页一个组，左右滑动换组。
/// 一次只构建当前页（及滑动中的相邻页）的可见格子。停在哪个组按订阅记在 `Profile.currentGroupName`。
class _GroupTabs extends ConsumerStatefulWidget {
  const _GroupTabs({required this.groups, required this.columns});
  final List<Group> groups;
  final int columns;

  @override
  ConsumerState<_GroupTabs> createState() => _GroupTabsState();
}

class _GroupTabsState extends ConsumerState<_GroupTabs> {
  late final PageController _pages = PageController(initialPage: _index);
  final _chipKeys = <String, GlobalKey>{};

  /// 点标签触发的翻页动画期间，途经页的 onPageChanged 不算数。
  bool _programmatic = false;

  int get _index {
    final name = ref.read(
      currentProfileProvider.select((p) => p?.currentGroupName),
    );
    final i = widget.groups.indexWhere((g) => g.name == name);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChip(_index));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _revealChip(int i) {
    if (!mounted || i >= widget.groups.length) return;
    final ctx = _chipKeys[widget.groups[i].name]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _setCurrent(int i) {
    globalState.appController.updateCurrentGroupName(widget.groups[i].name);
    _revealChip(i);
  }

  Future<void> _tapChip(int i) async {
    final from = _pages.page?.round() ?? 0;
    if (from == i) return;
    _setCurrent(i);
    if ((from - i).abs() > 1) {
      _pages.jumpToPage(i); // 隔得远就直接跳，不让中间几十页一闪而过
      return;
    }
    _programmatic = true;
    await _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
    _programmatic = false;
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final groups = widget.groups;
    final current = ref.watch(
      currentProfileProvider.select((p) => p?.currentGroupName),
    );
    var index = groups.indexWhere((g) => g.name == current);
    if (index < 0) index = 0;
    // 换订阅 / 组列表变了：页码对不上就跳过去
    if (!_programmatic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pages.hasClients || _programmatic) return;
        if (_pages.page?.round() != index) _pages.jumpToPage(index);
      });
    }

    return Column(
      children: [
        SizedBox(
          height: 38,
          width: double.infinity,   // 标签少时也靠左，不被 Column 居中
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (i, g) in groups.indexed)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: _GroupChip(
                      key: _chipKeys.putIfAbsent(g.name, GlobalKey.new),
                      group: g,
                      selected: i == index,
                      onTap: () => _tapChip(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: groups.length,
            onPageChanged: (i) {
              if (!_programmatic) _setCurrent(i);
            },
            itemBuilder: (_, i) {
              final g = groups[i];
              return CustomScrollView(
                key: PageStorageKey('tab-${g.name}'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: _TabGroupHead(group: g)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: DecoratedSliver(
                      decoration: BoxDecoration(color: mm.elev),
                      sliver: SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _cardPadding,
                        ),
                        sliver: _NodeSliverGrid(
                          group: g,
                          columns: widget.columns,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + MediaQuery.paddingOf(context).bottom),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        height: _cardPadding,
                        decoration: BoxDecoration(
                          color: mm.elev,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(_cardRadius),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 组标签：icon + 组名；选中 = 与节点格同款的淡强调色底 + 描边。
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    super.key,
    required this.group,
    required this.selected,
    required this.onTap,
  });
  final Group group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? mm.accent.withValues(alpha: 0.10) : mm.elev,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected ? mm.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (group.icon.isNotEmpty) ...[
              CommonTargetIcon(src: group.icon, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              group.name,
              style: TextStyle(
                fontSize: MeowFont.subheadline,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? mm.accent : mm.t1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签布局里组卡的头（上圆角）：TypeBadge + 成员数 + 当前选中 + 延迟 + 整组测速。组名已经在标签上，这里不重复。
class _TabGroupHead extends ConsumerWidget {
  const _TabGroupHead({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final badge = groupBadge(group.type.name, mm);
    final selectedName =
        ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    return Container(
      padding: const EdgeInsets.fromLTRB(_cardPadding, 8, 6, 8),
      decoration: BoxDecoration(
        color: mm.elev,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_cardRadius),
        ),
      ),
      child: Row(
        children: [
          TypeBadge(badge.label, color: badge.color),
          const SizedBox(width: 6),
          Text(
            '${group.all.length}',
            style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3),
          ),
          const SizedBox(width: 10),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: mm.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              selectedName.isEmpty ? S.currentSelected : selectedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2),
            ),
          ),
          _CurrentBadges(groupName: group.name),
          if (selectedName.isNotEmpty)
            LatencyChip(
              ref.watch(
                getDelayProvider(
                  proxyName: selectedName,
                  testUrl: group.testUrl,
                ),
              ),
              mode: mode,
            ),
          _GroupTestButton(group: group),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
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
              Text(
                title,
                style: TextStyle(
                  fontSize: MeowFont.headline,
                  fontWeight: FontWeight.w600,
                  color: mm.t1,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: MeowFont.subheadline,
                    color: mm.t2,
                  ),
                ),
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
  const _GroupHeader({
    required this.group,
    this.expanded,
    this.onToggle,
    this.dense = false,
  });
  final Group group;
  final bool? expanded;
  final VoidCallback? onToggle;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final badge = groupBadge(group.type.name, mm);
    final selectedName =
        ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    final delay = selectedName.isEmpty
        ? null
        : ref.watch(
            getDelayProvider(proxyName: selectedName, testUrl: group.testUrl),
          );
    return Row(
      children: [
        if (group.icon.isNotEmpty) ...[
          CommonTargetIcon(src: group.icon, size: 20),
          const SizedBox(width: 8),
        ],
        // 名 + 徽标 + 成员数占满左侧，闪电 / 箭头贴右（之前 Flexible 与 Spacer 平分空间，右侧按钮停在半路）
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MeowFont.headline,
                      fontWeight: FontWeight.w600,
                      color: mm.t1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TypeBadge(badge.label, color: badge.color),
              const SizedBox(width: 6),
              Text(
                '${group.all.length}',
                style: MeowFont.mono(size: MeowFont.caption2, color: mm.t3),
              ),
            ],
          ),
        ),
        if (!dense && delay != null && delay != 0)
          LatencyChip(delay, mode: mode),
        const SizedBox(width: 4),
        _GroupTestButton(group: group),
        if (expanded != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Icon(
              expanded! ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
              color: mm.t3,
            ),
          ),
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
              ? Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: mm.accent,
                    ),
                  ),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(Icons.bolt_rounded, color: mm.accent),
                  tooltip: S.testGroup,
                  onPressed: () => delayTest(
                    group.all,
                    testUrl: group.testUrl,
                    groupName: group.name,
                  ),
                ),
        );
      },
    );
  }
}

/// 手机端组卡的头：收起时是完整圆角卡（含「当前选中」行）；展开时只有上圆角，下面接节点网格。
/// 整个头（含空白处）点按 = 展开 / 收起；闪电按钮自己吃掉点击。
class _GroupHead extends ConsumerWidget {
  const _GroupHead({required this.group, required this.expanded});
  final Group group;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final selectedName =
        ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    void toggle() {
      final set = {...ref.read(expandedGroupsProvider)};
      if (!set.remove(group.name)) set.add(group.name);
      ref.read(expandedGroupsProvider.notifier).state = set;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          _cardPadding,
          _cardPadding,
          _cardPadding,
          expanded ? 10 : _cardPadding,
        ),
        decoration: BoxDecoration(
          color: mm.elev,
          borderRadius: expanded
              ? const BorderRadius.vertical(top: Radius.circular(_cardRadius))
              : BorderRadius.circular(_cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GroupHeader(
              group: group,
              expanded: expanded,
              onToggle: toggle,
              dense: true,
            ),
            if (!expanded) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: mm.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedName.isEmpty ? S.currentSelected : selectedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: MeowFont.subheadline,
                        color: mm.t2,
                      ),
                    ),
                  ),
                  _CurrentBadges(groupName: group.name),
                  if (selectedName.isNotEmpty)
                    LatencyChip(
                      ref.watch(
                        getDelayProvider(
                          proxyName: selectedName,
                          testUrl: group.testUrl,
                        ),
                      ),
                      mode: mode,
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

/// 宽屏左栏组行：icon + 名 + TypeBadge / 当前选中 + LatencyChip / 成员数 / 闪电；选中行底 accent 0.16。
class _GroupRow extends ConsumerWidget {
  const _GroupRow({
    required this.group,
    required this.selected,
    required this.onTap,
  });
  final Group group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final badge = groupBadge(group.type.name, mm);
    final selectedName =
        ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    // 每个组一张独立卡片、之间留缝；选中 = 淡强调色底 + 描边
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? mm.accent.withValues(alpha: 0.16) : mm.elev,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: selected
              ? BorderSide(color: mm.accent.withValues(alpha: 0.55))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (group.icon.isNotEmpty) ...[
                  CommonTargetIcon(src: group.icon, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: MeowFont.body,
                                fontWeight: FontWeight.w600,
                                color: mm.t1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TypeBadge(badge.label, color: badge.color),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedName.isEmpty ? '—' : selectedName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: MeowFont.footnote,
                                color: mm.t2,
                              ),
                            ),
                          ),
                          _CurrentBadges(groupName: group.name),
                          if (selectedName.isNotEmpty)
                            LatencyChip(
                              ref.watch(
                                getDelayProvider(
                                  proxyName: selectedName,
                                  testUrl: group.testUrl,
                                ),
                              ),
                              mode: mode,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '${group.all.length}',
                            style: MeowFont.mono(
                              size: MeowFont.caption2,
                              color: mm.t3,
                            ),
                          ),
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
      ),
    );
  }
}

/// 宽屏右栏：组头 + 懒加载节点网格（按宽度自适应列数）。
class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.group, required this.size});
  final Group group;
  final NodeCardSize size;

  @override
  Widget build(BuildContext context) {
    final minW = size == NodeCardSize.large ? 260.0 : 185.0;
    return LayoutBuilder(
      builder: (context, c) {
        final columns = ((c.maxWidth - 32) / minW).floor().clamp(1, 8);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverToBoxAdapter(child: _GroupHeader(group: group)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: _NodeSliverGrid(group: group, columns: columns),
            ),
          ],
        );
      },
    );
  }
}

/// 懒加载节点网格：只构建可见格子；每格自带 RepaintBoundary。
class _NodeSliverGrid extends ConsumerWidget {
  const _NodeSliverGrid({required this.group, required this.columns});
  final Group group;
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedName =
        ref.watch(getSelectedProxyNameProvider(group.name)) ?? '';
    final metas = ref.watch(proxyMetaProvider);
    final mode = ref.watch(meowSettingProvider.select((s) => s.latencyMode));
    final isSelector = group.type == GroupType.Selector;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: _gridSpacing,
        crossAxisSpacing: _gridSpacing,
        mainAxisExtent: _cellHeight,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final p = group.all[i];
        return _NodeCell(
          key: ValueKey(p.name),
          proxy: p,
          group: group,
          meta: metas[p.name],
          selected: p.name == selectedName,
          mode: mode,
          onTap: isSelector
              ? () {
                  final c = globalState.appController;
                  c.updateCurrentSelectedMap(group.name, p.name);
                  c.changeProxyDebounce(group.name, p.name);
                }
              : null,
        );
      }, childCount: group.all.length),
    );
  }
}

/// 节点格：协议色点 + 名；行 2 副标题 + 延迟胶囊（点 = 测该成员）；底 primary 0.05 圆角 13；选中 accent 描边 + 发光。
class _NodeCell extends ConsumerWidget {
  const _NodeCell({
    super.key,
    required this.proxy,
    required this.group,
    required this.meta,
    required this.selected,
    required this.mode,
    required this.onTap,
  });

  final Proxy proxy;
  final Group group;
  final ProxyMeta? meta;
  final bool selected;
  final LatencyMode mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final nested = isGroupType(proxy.type);
    final builtin = builtinSubtitle(proxy.name);
    final style = protoStyle(proxy.type, mm);
    final dotColor = builtin != null
        ? mm.good
        : (nested ? mm.accent : style.color);
    final subtitle =
        builtin ??
        (nested
            ? '${S.nestedGroup} · ${groupBadge(proxy.type, mm).label}'
            : (meta?.securitySubtitle.isNotEmpty == true
                  ? '${style.label} · ${meta!.securitySubtitle}'
                  : style.label));
    final delay = ref.watch(
      getDelayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    final medal = ref.watch(medalsProvider.select((m) => m[proxy.name]));
    final unlocks = ref.watch(unlocksProvider.select((m) => m[proxy.name]));
    final testable = !const {
      'REJECT',
      'REJECT-DROP',
      'PASS',
    }.contains(proxy.name.toUpperCase());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // 选中：淡强调色底 + 描边。不加发光——格子底是半透明的，阴影会透上来把整格染蓝、盖住延迟
          color: selected
              ? mm.accent.withValues(alpha: 0.10)
              : mm.t1.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? mm.accent : mm.t1.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    proxy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MeowFont.subheadline,
                      fontWeight: FontWeight.w500,
                      color: mm.t1,
                    ),
                  ),
                ),
                if (nested) Icon(Icons.layers_rounded, size: 14, color: mm.t3),
                if (medal != null) ...[
                  const SizedBox(width: 2),
                  MedalBadge(medal, size: 14),
                ],
                if (unlocks != null) ...[
                  const SizedBox(width: 2),
                  UnlockBadge(unlocks, size: 14),
                ],
              ],
            ),
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
                    child: LatencyChip(delay, mode: mode),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
