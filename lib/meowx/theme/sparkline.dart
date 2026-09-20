import 'package:flutter/material.dart';

import 'tokens.dart';

/// 网速图：60 点，双线（上传 accent 在上层、下载靛）+ 10% 填充，线宽 2，基线 t3 0.25，底 t3 0.06 圆角 10。
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.up, required this.down, this.height = 84, this.points = 60});

  final List<double> up;
  final List<double> down;
  final double height;
  final int points;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        color: mm.t3.withValues(alpha: 0.06),
        child: CustomPaint(
          painter: _SparkPainter(
            up: up,
            down: down,
            points: points,
            upColor: mm.accent,
            downColor: mm.down,
            baseline: mm.t3.withValues(alpha: 0.25),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.up,
    required this.down,
    required this.points,
    required this.upColor,
    required this.downColor,
    required this.baseline,
  });

  final List<double> up, down;
  final int points;
  final Color upColor, downColor, baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = [...up, ...down].fold<double>(0, (m, v) => v > m ? v : m);
    final scale = maxV <= 0 ? 0.0 : (size.height * 0.85) / maxV;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    void line(List<double> data, Color color) {
      if (data.length < 2) return;
      final dx = size.width / (points - 1);
      final start = points - data.length;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = (start + i) * dx;
        final y = size.height - data[i] * scale;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final fill = Path.from(path)
        ..lineTo((start + data.length - 1) * dx, size.height)
        ..lineTo(start * dx, size.height)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.10));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line(down, downColor);
    line(up, upColor);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.up != up || old.down != down || old.upColor != upColor || old.downColor != downColor;
}
