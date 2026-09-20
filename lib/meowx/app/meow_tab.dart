import 'package:bett_box/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'strings.dart';

/// 五个 Tab（与 iOS 端顺序一致）。
enum MeowTab {
  home(S.home, Icons.home_rounded, PageLabel.dashboard),
  proxies(S.proxies, Icons.hexagon_rounded, PageLabel.proxies),
  connections(S.connections, Icons.monitor_heart_rounded, PageLabel.connections),
  profiles(S.profiles, Icons.description_rounded, PageLabel.profiles),
  settings(S.settings, Icons.settings_rounded, PageLabel.tools);

  const MeowTab(this.label, this.icon, this.pageLabel);

  final String label;
  final IconData icon;

  /// 对应的 Bettbox 页面标签（Bettbox 内部 toPage 时据此映射到 Tab）
  final PageLabel pageLabel;

  static MeowTab? fromPageLabel(PageLabel label) {
    for (final t in values) {
      if (t.pageLabel == label) return t;
    }
    return null;
  }
}

/// 当前 Tab。
final meowTabProvider = StateProvider<MeowTab>((ref) => MeowTab.home);
