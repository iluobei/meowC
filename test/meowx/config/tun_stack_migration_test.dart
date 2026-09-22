import 'dart:convert';

import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Config load(Map<String, Object?> json) => Config.compatibleFromJson(json);

Map<String, Object?> withStack(String stack, {bool? migrated}) => {
      'patchClashConfig': {
        'tun': {'stack': stack},
      },
      if (migrated != null) 'meow': {'tunStackMigrated': migrated},
    };

void main() {
  test('新装：默认 mips', () {
    final c = load({});
    expect(c.patchClashConfig.tun.stack, TunStack.mips);
    expect(c.meow.tunStackMigrated, isTrue);
  });

  test('老配置存的是旧默认 mixed → 迁到 mips 并记标记', () {
    final c = load(withStack('mixed'));
    expect(c.patchClashConfig.tun.stack, TunStack.mips);
    expect(c.meow.tunStackMigrated, isTrue);
  });

  test('老配置手选过 gvisor / system → 保留', () {
    expect(load(withStack('gvisor')).patchClashConfig.tun.stack, TunStack.gvisor);
    expect(load(withStack('system')).patchClashConfig.tun.stack, TunStack.system);
  });

  test('迁移过后再手选 mixed → 不再改回 mips', () {
    final c = load(withStack('mixed', migrated: true));
    expect(c.patchClashConfig.tun.stack, TunStack.mixed);
  });

  test('迁移不丢 meow 里的其他设置', () {
    final json = withStack('mixed');
    json['meow'] = {'syncIntervalHours': 6};
    final c = load(json);
    expect(c.patchClashConfig.tun.stack, TunStack.mips);
    expect(c.meow.syncIntervalHours, 6);
  });

  test('迁移后的配置存盘再读回：标记与栈都保留', () {
    // 与 preferences 落盘同路径：jsonEncode（深序列化）→ 读回
    final saved = jsonDecode(jsonEncode(load(withStack('mixed')))) as Map<String, Object?>;
    final again = load(saved);
    expect(again.patchClashConfig.tun.stack, TunStack.mips);
    expect(again.meow.tunStackMigrated, isTrue);
  });
}
