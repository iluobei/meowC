import 'package:flutter/material.dart';

import 'tokens.dart';

/// 手机端页内大标题：34pt bold，作为内容首行随滚动走；右侧可放圆形玻璃钮。
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.trailing, this.subtitle});

  final String title;
  final Widget? trailing;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: MeowFont.largeTitle,
                    fontWeight: FontWeight.bold,
                    color: mm.t1,
                    height: 1.15,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
        ],
      ),
    );
  }
}

/// 标题右侧的圆形玻璃钮（36pt）。
class RoundGlassButton extends StatelessWidget {
  const RoundGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.busy = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool busy;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final btn = Material(
      color: mm.elev,
      shape: CircleBorder(side: BorderSide(color: mm.cardEdge)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: mm.t2),
                  )
                : Icon(icon, size: 18, color: color ?? mm.t1),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
