import 'dart:convert';

import 'package:bett_box/meowx/config/subscription_headers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile-title 明文 / base64 / 空', () {
    expect(subscriptionTitle('喵喵屋 套餐'), '喵喵屋 套餐');
    expect(subscriptionTitle('base64:${base64.encode(utf8.encode('妙妙屋X'))}'), '妙妙屋X');
    expect(subscriptionTitle('base64:'), isNull);
    expect(subscriptionTitle('  '), isNull);
    expect(subscriptionTitle(null), isNull);
  });
  test('profile-update-interval 小时，默认 24', () {
    expect(subscriptionUpdateInterval('12'), const Duration(hours: 12));
    expect(subscriptionUpdateInterval('0'), const Duration(hours: 24));
    expect(subscriptionUpdateInterval('x'), const Duration(hours: 24));
    expect(subscriptionUpdateInterval(null), const Duration(hours: 24));
  });
}
