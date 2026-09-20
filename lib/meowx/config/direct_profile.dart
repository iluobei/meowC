import 'dart:io';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';

/// 内置「直连（不走代理）」档：固定 id、恒在末尾、不可删；让没有订阅时也能启动隧道。
/// 切到它时同步 mode=direct，切回时恢复 rule（见 MeowRoot）。
const directProfileId = '00000000-0000-0000-0000-0000D1EC7000';
const directProfileLabel = '直连（不走代理）';

const directProfileYaml = '''
mixed-port: 7890
allow-lan: true
mode: direct
dns:
  enable: true
  enhanced-mode: redir-host
  nameserver:
    - https://1.12.12.12/dns-query
  direct-nameserver:
    - https://1.12.12.12/dns-query
proxies: []
proxy-groups: []
rules:
  - MATCH,DIRECT
''';

bool isDirectProfile(String? id) => id == directProfileId;

/// 确保档案文件在磁盘上，并返回应追加到列表末尾的 Profile（列表里已有则返回 null）。
Future<Profile?> ensureDirectProfile(List<Profile> profiles) async {
  final path = await appPath.getProfilePath(directProfileId);
  final file = File(path);
  if (!await file.exists()) {
    await file.create(recursive: true);
    await file.writeAsString(directProfileYaml);
  }
  if (profiles.any((p) => p.id == directProfileId)) return null;
  return Profile(
    id: directProfileId,
    label: directProfileLabel,
    autoUpdateDuration: const Duration(days: 1),
    autoUpdate: false,
    lastUpdateDate: DateTime.now(),
  );
}

/// 直连档恒在末尾。
List<Profile> withDirectProfileLast(List<Profile> profiles) {
  final direct = profiles.where((p) => p.id == directProfileId).toList();
  if (direct.isEmpty) return profiles;
  return [...profiles.where((p) => p.id != directProfileId), ...direct];
}
