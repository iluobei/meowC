import 'package:bett_box/meowx/state/latency.dart';
import 'package:bett_box/meowx/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mm = MeowTokens.light;

  test('HTTPS / TCPing 阈值 100 / 200', () {
    expect(latencyColor(100, LatencyMode.url, mm), mm.good);
    expect(latencyColor(101, LatencyMode.url, mm), mm.mid);
    expect(latencyColor(200, LatencyMode.tcping, mm), mm.mid);
    expect(latencyColor(201, LatencyMode.tcping, mm), mm.slow);
  });

  test('真连接阈值 300 / 600', () {
    expect(latencyColor(300, LatencyMode.urlFull, mm), mm.good);
    expect(latencyColor(600, LatencyMode.urlFull, mm), mm.mid);
    expect(latencyColor(601, LatencyMode.urlFull, mm), mm.slow);
  });

  test('延迟值语义', () {
    expect(latencyStateOf(null), LatencyState.untested);
    expect(latencyStateOf(0), LatencyState.testing);
    expect(latencyStateOf(-1), LatencyState.timeout);
    expect(latencyStateOf(88), LatencyState.value);
  });
}
