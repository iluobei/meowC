import 'dart:ui';

import 'package:flutter/material.dart';

import 'tokens.dart';

class GlassTabItem {
  const GlassTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// 手机底栏：对齐 iOS 26 的液态玻璃 Tab 栏——悬浮胶囊、背后内容透过来（模糊 + 半透明底 + 高光描边），
/// 选中项是一颗会滑动的胶囊高亮。放在 Scaffold.bottomNavigationBar 且 `extendBody: true`，页面内容从它下面滚过去；
/// 各页的滚动容器要把 `MediaQuery.padding.bottom`（= 本栏占的高度）加进底部留白。
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.items, required this.selected, required this.onSelect});

  final List<GlassTabItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _height = 64.0;
  static const _radius = 32.0;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final n = items.length;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: _height,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  // 上亮下暗的一层薄雾 + 高光描边 = 玻璃的厚度感
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [const Color(0xFF3A3A3E).withValues(alpha: 0.62), const Color(0xFF1C1C1E).withValues(alpha: 0.62)]
                        : [Colors.white.withValues(alpha: 0.78), Colors.white.withValues(alpha: 0.58)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.14 : 0.65)),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(n <= 1 ? 0 : -1 + 2 * selected / (n - 1), 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / n,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: mm.t1.withValues(alpha: dark ? 0.14 : 0.08),
                            borderRadius: BorderRadius.circular(_radius - 5),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (i, item) in items.indexed)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == selected,
                              label: item.label,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onSelect(i),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(item.icon, size: 23, color: i == selected ? mm.accent : mm.t1),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: i == selected ? mm.accent : mm.t1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
