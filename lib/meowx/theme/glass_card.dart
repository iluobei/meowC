import 'package:flutter/material.dart';

import 'tokens.dart';

/// iOS 端 GlassCard：纯色卡片底，无描边无阴影，圆角默认 26。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.border,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        color: color ?? context.mm.elev,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: body,
      ),
    );
  }
}
