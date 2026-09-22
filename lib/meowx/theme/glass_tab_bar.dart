import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

class GlassTabItem {
  const GlassTabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// 手机底栏：对齐 iOS 26 的液态玻璃 Tab 栏——悬浮胶囊、背后内容透过来（模糊 + 半透明底 + 高光描边），
/// 选中项是一颗会滑动的胶囊高亮。放在 Scaffold.bottomNavigationBar 且 `extendBody: true`，页面内容从它下面滚过去；
/// 各页的滚动容器要把 `MediaQuery.padding.bottom`（= 本栏占的高度）加进底部留白。
/// 交互同 iOS：轻点切换；按住后胶囊放大并跟手滑动，滑过每一项轻震一下，松手选中手指下的那一项。
class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<GlassTabItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar> {
  static const _height = 64.0;
  static const _radius = 32.0;
  static const _inset = 5.0;

  /// 按住时手指在栏内的横坐标；null = 没在按。
  double? _dragX;
  int? _hover;

  int _indexAt(double x, double width) => (x / (width / widget.items.length))
      .floor()
      .clamp(0, widget.items.length - 1);

  void _press(double x, double width) {
    setState(() {
      _dragX = x;
      _hover = _indexAt(x, width);
    });
  }

  void _move(double x, double width) {
    final i = _indexAt(x, width);
    if (i != _hover) HapticFeedback.selectionClick();
    setState(() {
      _dragX = x;
      _hover = i;
    });
  }

  void _release({required bool select}) {
    final i = _hover;
    setState(() {
      _dragX = null;
      _hover = null;
    });
    if (select && i != null && i != widget.selected) widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = widget.items;
    final n = items.length;
    final pressing = _dragX != null;
    final active = _hover ?? widget.selected;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: _height,
                padding: const EdgeInsets.all(_inset),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  // 上亮下暗的一层薄雾 + 高光描边 = 玻璃的厚度感
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [
                            const Color(0xFF3A3A3E).withValues(alpha: 0.62),
                            const Color(0xFF1C1C1E).withValues(alpha: 0.62),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.78),
                            Colors.white.withValues(alpha: 0.58),
                          ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? 0.14 : 0.65),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final width = c.maxWidth;
                    final itemW = width / n;
                    // 按住时胶囊中心跟手指走（夹在两端之内），松手后吸附到选中项
                    final left = pressing
                        ? (_dragX! - itemW / 2).clamp(0.0, width - itemW)
                        : widget.selected * itemW;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // 按下即浮起胶囊；若最终是轻点，pan 手势会被取消，由 onTapUp 选中
                      onPanDown: (d) => _press(d.localPosition.dx, width),
                      onPanUpdate: (d) => _move(d.localPosition.dx, width),
                      onPanEnd: (_) => _release(select: true),
                      onPanCancel: () => _release(select: false),
                      onTapUp: (d) {
                        final i = _indexAt(d.localPosition.dx, width);
                        if (i != widget.selected) widget.onSelect(i);
                      },
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: pressing
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            left: left,
                            top: 0,
                            bottom: 0,
                            width: itemW,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              scale: pressing ? 1.1 : 1.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: mm.t1.withValues(
                                    alpha: pressing
                                        ? (dark ? 0.22 : 0.13)
                                        : (dark ? 0.14 : 0.08),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    _radius - _inset,
                                  ),
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
                                    selected: i == widget.selected,
                                    label: item.label,
                                    onTap: () => widget.onSelect(i),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 23,
                                          color: i == active
                                              ? mm.accent
                                              : mm.t1,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: i == active
                                                ? mm.accent
                                                : mm.t1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
