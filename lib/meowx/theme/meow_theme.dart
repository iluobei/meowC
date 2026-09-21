import 'dart:io';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// MeowX 主题：Material 3 骨架 + MM token。强调色固定系统蓝（与 iOS 一致），不用动态取色。
ThemeData meowThemeData({
  required Brightness brightness,
  String? fontFamily,
  PageTransitionsTheme? pageTransitionsTheme,
}) {
  final tokens = brightness == Brightness.dark ? MeowTokens.dark : MeowTokens.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  ).copyWith(
    primary: tokens.accent,
    surface: tokens.bg,
    surfaceContainerLowest: tokens.elev,
    surfaceContainerLow: tokens.elev,
    surfaceContainer: tokens.elev,
    onSurface: tokens.t1,
    error: tokens.slow,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    // Windows 自带字体没有国旗 emoji（显示成 CN / US 字母），回落到随包的 Twemoji
    fontFamilyFallback: Platform.isWindows ? const ['Twemoji'] : null,
    pageTransitionsTheme: pageTransitionsTheme,
    scaffoldBackgroundColor: tokens.bg,
    canvasColor: tokens.bg,
    cardColor: tokens.elev,
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.elev,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.elev,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.elev,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    dividerTheme: DividerThemeData(color: tokens.t3.withValues(alpha: 0.2), space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.elev,
      indicatorColor: tokens.accent.withValues(alpha: 0.14),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: MeowFont.caption2, fontWeight: FontWeight.w500, color: tokens.t1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tokens.t1,
    ),
    listTileTheme: ListTileThemeData(tileColor: tokens.elev),
    extensions: [tokens],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: tokens.t1, displayColor: tokens.t1),
  );
}
