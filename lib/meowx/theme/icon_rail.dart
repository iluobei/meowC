import 'package:flutter/material.dart';

import 'tokens.dart';

class RailItem {
  const RailItem({required this.icon, required this.label, this.badge});
  final IconData icon;
  final String label;
  final int? badge;
}

/// iPad 式左侧图标栏：宽 88、圆角 28、毛玻璃底（这里用卡片底色）、项间距 6，
/// 图标 22 + 文字 11，选中底 primary 0.10 圆角 18，角标 Capsule 11pt 白字（>99 → 99+），最后一项沉底。
class IconRail extends StatelessWidget {
  const IconRail({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.bottomItemIndex,
  });

  final List<RailItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 沉底项（通常是「设置」）
  final int? bottomItemIndex;

  static const width = 88.0;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    Widget tile(int i) {
      final it = items[i];
      final on = i == selected;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: on ? mm.accent.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelect(i),
            child: SizedBox(
              width: width - 16,
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(it.icon, size: 22, color: on ? mm.accent : mm.t2),
                        const SizedBox(height: 4),
                        Text(
                          it.label,
                          style: TextStyle(
                            fontSize: MeowFont.caption2,
                            fontWeight: FontWeight.w600,
                            color: on ? mm.accent : mm.t2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((it.badge ?? 0) > 0)
                    Positioned(
                      top: 3,
                      right: 2,   // 贴右上角，别盖住图标（99+ 比较宽）
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: mm.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          it.badge! > 99 ? '99+' : '${it.badge}',
                          style: const TextStyle(
                            fontSize: MeowFont.caption2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final top = <Widget>[];
    Widget? bottom;
    for (var i = 0; i < items.length; i++) {
      if (i == bottomItemIndex) {
        bottom = tile(i);
      } else {
        top.add(tile(i));
      }
    }
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: mm.elev,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          ...top,
          const Spacer(),
          ?bottom,
        ],
      ),
    );
  }
}
