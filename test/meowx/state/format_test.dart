import 'package:bett_box/meowx/state/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fmtSize 最小 KB，MB 一位小数，GB 两位', () {
    expect(fmtSize(0), '0 KB');
    expect(fmtSize(512), '1 KB');
    expect(fmtSize(1024 * 1023), '1023 KB');
    expect(fmtSize(1024 * 1024 * 1.55), '1.6 MB');
    expect(fmtSize(1024 * 1024 * 1024 * 2.345), '2.35 GB');
    expect(fmtRate(2048), '2 KB/s');
  });

  test('fmtUptime / fmtElapsed', () {
    expect(fmtUptime(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(fmtElapsed(const Duration(seconds: 42)), '42s');
    expect(fmtElapsed(const Duration(minutes: 3, seconds: 5)), '3m5s');
    expect(fmtElapsed(const Duration(hours: 2, minutes: 7)), '2h7m');
  });

  test('永久到期阈值', () {
    expect(isPermanentExpire(4102444799), isTrue);
    expect(isPermanentExpire(4102444798), isFalse);
  });

  test('fmtRelative', () {
    final now = DateTime(2026, 9, 20, 12);
    expect(fmtRelative(now.subtract(const Duration(seconds: 20)), now), '刚刚');
    expect(fmtRelative(now.subtract(const Duration(minutes: 5)), now), '5 分钟前');
    expect(fmtRelative(now.subtract(const Duration(hours: 3)), now), '3 小时前');
    expect(fmtRelative(now.subtract(const Duration(days: 2)), now), '2 天前');
  });
}
