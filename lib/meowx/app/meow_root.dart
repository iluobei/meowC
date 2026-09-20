import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/connections/connections_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/profiles/profiles_page.dart';
import '../pages/proxies/proxies_page.dart';
import '../pages/settings/settings_page.dart';
import '../state/status.dart';
import '../theme/icon_rail.dart';
import '../theme/tokens.dart';
import 'meow_tab.dart';

/// MeowX 壳：手机 = 底部 5 Tab；宽屏 = 左侧 IconRail + 内容。
/// Bettbox 内部的 toPage(PageLabel) 经 currentPageLabelProvider 映射到 Tab；非 Tab 页（日志 / 请求 / 资源 / 脚本）走 push。
class MeowRoot extends ConsumerStatefulWidget {
  const MeowRoot({super.key});

  @override
  ConsumerState<MeowRoot> createState() => _MeowRootState();
}

class _MeowRootState extends ConsumerState<MeowRoot> {
  late final ProviderSubscription<PageLabel> _pageSub;

  @override
  void initState() {
    super.initState();
    _pageSub = ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev == next) return;
      final tab = MeowTab.fromPageLabel(next);
      if (tab != null) {
        if (ref.read(meowTabProvider) != tab) {
          ref.read(meowTabProvider.notifier).state = tab;
        }
        return;
      }
      _pushBettboxPage(next);
    });
  }

  @override
  void dispose() {
    _pageSub.close();
    super.dispose();
  }

  void _pushBettboxPage(PageLabel label) {
    final items = navigation.getItems(openLogs: true, hasProxies: true);
    final item = items.where((e) => e.label == label).firstOrNull;
    if (item == null || !mounted) return;
    BaseNavigator.push(context, item.builder(context));
  }

  void _select(MeowTab tab) {
    if (ref.read(meowTabProvider) == tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(meowTabProvider.notifier).state = tab;
    // 同步 Bettbox 的当前页标签：连接页轮询、代理页测速等内部逻辑据此判断可见性
    ref.read(currentPageLabelProvider.notifier).value = tab.pageLabel;
  }

  Widget _page(MeowTab tab) => switch (tab) {
    MeowTab.home => const DashboardPage(),
    MeowTab.proxies => const ProxiesPage(),
    MeowTab.connections => const ConnectionsPage(),
    MeowTab.profiles => const ProfilesPage(),
    MeowTab.settings => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(meowTabProvider);
    final wide = ref.watch(isWideLayoutProvider);
    final mm = context.mm;
    final content = IndexedStack(
      index: tab.index,
      children: [for (final t in MeowTab.values) _page(t)],
    );

    final Widget body;
    if (wide) {
      final proxyCount = ref.watch(groupsProvider.select((g) {
        final names = <String>{};
        for (final group in g) {
          for (final p in group.all) {
            names.add(p.name);
          }
        }
        return names.length;
      }));
      body = Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
            child: IconRail(
              items: [
                for (final t in MeowTab.values)
                  RailItem(
                    icon: t.icon,
                    label: t.label,
                    badge: switch (t) {
                      MeowTab.proxies => proxyCount,
                      MeowTab.connections => ref.watch(connectionCountProvider),
                      _ => null,
                    },
                  ),
              ],
              selected: tab.index,
              bottomItemIndex: MeowTab.settings.index,
              onSelect: (i) => _select(MeowTab.values[i]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: content),
        ],
      );
    } else {
      body = content;
    }

    return MeowBackScope(
      child: Scaffold(
        backgroundColor: mm.bg,
        body: SafeArea(top: false, bottom: false, child: body),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: tab.index,
                height: 64,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (i) => _select(MeowTab.values[i]),
                destinations: [
                  for (final t in MeowTab.values)
                    NavigationDestination(icon: Icon(t.icon), label: t.label),
                ],
              ),
      ),
    );
  }
}

/// 连接数角标（宽屏 IconRail 用），由连接页 / 首页的轮询写入。
final connectionCountProvider = StateProvider<int>((ref) => 0);

/// Android 返回键：先弹子页 → 再回首页 → 最后交给 Bettbox 的退出 / 后台逻辑。
class MeowBackScope extends ConsumerWidget {
  const MeowBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!system.isAndroid) return child;
    final backBlock = ref.watch(backBlockProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || backBlock) return;
        final nav = globalState.navigatorKey.currentState;
        if (nav?.userGestureInProgress == true) return;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }
        if (ref.read(meowTabProvider) != MeowTab.home) {
          ref.read(meowTabProvider.notifier).state = MeowTab.home;
          ref.read(currentPageLabelProvider.notifier).value = PageLabel.dashboard;
          return;
        }
        await globalState.appController.handleBackOrExit();
      },
      child: child,
    );
  }
}
