import 'package:flutter/material.dart';

import 'tokens.dart';

/// 宽屏两栏：左栏固定 360 + 1px 分隔线 + 右栏。
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.left, required this.right, this.leftWidth = 360});

  final Widget left;
  final Widget right;
  final double leftWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: leftWidth, child: left),
        Container(width: 1, color: context.mm.t3.withValues(alpha: 0.2)),
        Expanded(child: right),
      ],
    );
  }
}

/// 宽屏内容限宽 1100 居中。
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
