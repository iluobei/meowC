import 'package:bett_box/models/meow.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

export 'package:bett_box/models/meow.dart' show LatencyMode;

/// 延迟三档颜色：≤良好 绿、≤一般 橙、否则红。
Color latencyColor(int ms, LatencyMode mode, MeowTokens mm) {
  final (good, mid) = mode.thresholds;
  if (ms <= good) return mm.good;
  if (ms <= mid) return mm.mid;
  return mm.slow;
}

/// 延迟值语义（沿用 Bettbox 的 delayMap）：null = 未测，0 = 测试中，<0 = 超时，>0 = 毫秒。
enum LatencyState { untested, testing, timeout, value }

LatencyState latencyStateOf(int? v) {
  if (v == null) return LatencyState.untested;
  if (v == 0) return LatencyState.testing;
  if (v < 0) return LatencyState.timeout;
  return LatencyState.value;
}
