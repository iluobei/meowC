import 'dart:convert';

import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Config load(Map<String, Object?> json) => Config.compatibleFromJson(json);

void main() {
  test('新装：网速图默认隐藏', () {
    final c = load({});
    expect(c.meow.homeHiddenCards, contains('chart'));
    expect(c.meow.homeChartMigrated, isTrue);
  });

  test('老配置存的是空列表 → 补上 chart 并记标记', () {
    final c = load({
      'meow': {'homeHiddenCards': <String>[]},
    });
    expect(c.meow.homeHiddenCards, ['chart']);
    expect(c.meow.homeChartMigrated, isTrue);
  });

  test('老配置已经关了别的卡 → 追加 chart、不重复', () {
    final c = load({
      'meow': {'homeHiddenCards': ['ip', 'chart']},
    });
    expect(c.meow.homeHiddenCards, ['ip', 'chart']);
  });

  test('迁移过后用户再打开网速图 → 保留', () {
    final c = load({
      'meow': {'homeHiddenCards': <String>[], 'homeChartMigrated': true},
    });
    expect(c.meow.homeHiddenCards, isEmpty);
  });

  test('迁移不丢 meow 里的其他设置', () {
    final c = load({
      'meow': {'syncIntervalHours': 6},
    });
    expect(c.meow.homeHiddenCards, ['chart']);
    expect(c.meow.syncIntervalHours, 6);
  });

  test('迁移后的配置存盘再读回：标记与列表都保留', () {
    final saved = jsonDecode(jsonEncode(load({}))) as Map<String, Object?>;
    final again = load(saved);
    expect(again.meow.homeHiddenCards, ['chart']);
    expect(again.meow.homeChartMigrated, isTrue);
  });
}
