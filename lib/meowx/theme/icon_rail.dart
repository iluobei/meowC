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
    // 角标只是辅助计数，字号最多跟到 1.2 倍，大字时不至于盖住图标
    final badgeScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);

    /// compact：只有图标、高 44，标签进 Tooltip（长按可见，读屏也能读到）
    Widget tile(int i, {required bool compact}) {
      final it = items[i];
      final on = i == selected;
      // 角标锚在图标上：从图标中线偏右往右延伸，99+ 再宽也不压住图标主体
      final icon = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(it.icon, size: 22, color: on ? mm.accent : mm.t2),
          if ((it.badge ?? 0) > 0)
            Positioned(
              left: 13,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: mm.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  it.badge! > 99 ? '99+' : '${it.badge}',
                  textScaler: badgeScaler,
                  style: const TextStyle(
                    fontSize: MeowFont.caption2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      );
      Widget body = Material(
        color: on ? mm.accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelect(i),
          child: SizedBox(
            width: width - 16,
            height: compact ? 44 : 60,
            child: Center(
              child: compact
                  ? icon
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
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
          ),
        ),
      );
      if (compact) body = Tooltip(message: it.label, child: body);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: body,
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // 完整瓦片 60 + 上下 3、容器上下 padding 10：手机横屏常放不下 → 改紧凑瓦片（44 + 上下 3）；
        // 紧凑后还放不下就让栏内滚动，保证「设置」不画到栏外点不到
        final compact = c.maxHeight < items.length * 66 + 20;
        final scroll = compact && c.maxHeight < items.length * 50 + 20;
        final top = <Widget>[];
        Widget? bottom;
        for (var i = 0; i < items.length; i++) {
          if (i == bottomItemIndex) {
            bottom = tile(i, compact: compact);
          } else {
            top.add(tile(i, compact: compact));
          }
        }
        final column = Column(
          children: [
            ...top,
            const Spacer(),
            ?bottom,
          ],
        );
        return Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: mm.elev,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: mm.cardEdge),
          ),
          child: scroll
              // 只有几个瓦片，IntrinsicHeight 开销可忽略；它让 Spacer 在滚动视图里有界
              ? SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: (c.maxHeight - 20).clamp(0.0, double.infinity)),
                    child: IntrinsicHeight(child: column),
                  ),
                )
              : column,
        );
      },
    );
  }
}
