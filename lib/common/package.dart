import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  // 与 iOS 端一致：主控据此识别 MeowX 客户端并输出完整 clash YAML
  String get ua => 'mihomo/1.19.0 (miaomiaowu; ${Platform.isAndroid ? 'Android' : Platform.isWindows ? 'Windows' : Platform.operatingSystem})';
}
