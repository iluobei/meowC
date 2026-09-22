import 'package:flutter/material.dart';

/// MeowX 颜色 token（对齐 iOS 端 MM 颜色：系统语义色 + 分组底色）。
@immutable
class MeowTokens extends ThemeExtension<MeowTokens> {
  const MeowTokens({
    required this.bg,
    required this.elev,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.accent,
    required this.pur,
    required this.orange,
    required this.good,
    required this.mid,
    required this.slow,
    required this.down,
    required this.teal,
    required this.glassTint,
    required this.glassEdge,
    required this.cardEdge,
  });

  /// 页面底 / 卡片底 / 文本三级
  final Color bg, elev, t1, t2, t3;

  /// 强调色（系统蓝）、紫、橙、绿 / 橙 / 红（延迟三档）、下载靛、青
  final Color accent, pur, orange, good, mid, slow, down, teal;

  /// 玻璃底与描边（搜索框等）
  final Color glassTint, glassEdge;

  /// 卡片 1px 描边：白卡放在浅灰底上只差几个灰阶，靠描边把卡片和页面底分开（对齐 Surfing 的卡片观感）
  final Color cardEdge;

  static const light = MeowTokens(
    bg: Color(0xFFF2F2F7),
    elev: Color(0xFFFFFFFF),
    t1: Color(0xFF000000),
    t2: Color(0x993C3C43),
    t3: Color(0x993C3C43),
    accent: Color(0xFF007AFF),
    pur: Color(0xFFAF52DE),
    orange: Color(0xFFFF9500),
    good: Color(0xFF34C759),
    mid: Color(0xFFFF9500),
    slow: Color(0xFFFF3B30),
    down: Color(0xFF5856D6),
    teal: Color(0xFF30B0C7),
    glassTint: Color(0xFFFFFFFF),
    glassEdge: Color(0xFF000000),
    cardEdge: Color(0x17000000),
  );

  static const dark = MeowTokens(
    bg: Color(0xFF000000),
    elev: Color(0xFF1C1C1E),
    t1: Color(0xFFFFFFFF),
    t2: Color(0x99EBEBF5),
    t3: Color(0x99EBEBF5),
    accent: Color(0xFF0A84FF),
    pur: Color(0xFFBF5AF2),
    orange: Color(0xFFFF9F0A),
    good: Color(0xFF30D158),
    mid: Color(0xFFFF9F0A),
    slow: Color(0xFFFF453A),
    down: Color(0xFF5E5CE6),
    teal: Color(0xFF40C8E0),
    glassTint: Color(0xFF1C1C1E),
    glassEdge: Color(0xFFFFFFFF),
    cardEdge: Color(0x1FFFFFFF),
  );

  @override
  MeowTokens copyWith() => this;

  @override
  MeowTokens lerp(ThemeExtension<MeowTokens>? other, double t) {
    if (other is! MeowTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MeowTokens(
      bg: c(bg, other.bg),
      elev: c(elev, other.elev),
      t1: c(t1, other.t1),
      t2: c(t2, other.t2),
      t3: c(t3, other.t3),
      accent: c(accent, other.accent),
      pur: c(pur, other.pur),
      orange: c(orange, other.orange),
      good: c(good, other.good),
      mid: c(mid, other.mid),
      slow: c(slow, other.slow),
      down: c(down, other.down),
      teal: c(teal, other.teal),
      glassTint: c(glassTint, other.glassTint),
      glassEdge: c(glassEdge, other.glassEdge),
      cardEdge: c(cardEdge, other.cardEdge),
    );
  }
}

/// iOS 字号阶梯（pt）。等宽用于延迟、字节、规则、YAML。
class MeowFont {
  MeowFont._();
  static const largeTitle = 34.0;
  static const title2 = 22.0;
  static const title3 = 20.0;
  static const headline = 17.0;
  static const body = 17.0;
  static const callout = 16.0;
  static const subheadline = 15.0;
  static const footnote = 13.0;
  static const caption = 12.0;
  static const caption2 = 11.0;

  static const monoFamily = 'monospace';
  static const monoFallback = ['Consolas', 'Menlo', 'Roboto Mono', 'monospace', 'Twemoji'];

  static TextStyle mono({
    double size = footnote,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

extension MeowContext on BuildContext {
  MeowTokens get mm =>
      Theme.of(this).extension<MeowTokens>() ??
      (Theme.of(this).brightness == Brightness.dark ? MeowTokens.dark : MeowTokens.light);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
