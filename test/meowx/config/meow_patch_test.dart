import 'package:bett_box/meowx/config/meow_patch.dart';
import 'package:bett_box/models/meow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveDnsMode', () {
    test('follow：声明 fake-ip 才 fake-ip，其它（含未声明）→ redir-host', () {
      expect(effectiveDnsMode(MeowDnsMode.follow, 'fake-ip'), 'fake-ip');
      expect(effectiveDnsMode(MeowDnsMode.follow, 'redir-host'), 'redir-host');
      expect(effectiveDnsMode(MeowDnsMode.follow, 'normal'), 'redir-host');
      expect(effectiveDnsMode(MeowDnsMode.follow, null), 'redir-host');
    });
    test('强制档不看声明', () {
      expect(effectiveDnsMode(MeowDnsMode.fakeIp, 'redir-host'), 'fake-ip');
      expect(effectiveDnsMode(MeowDnsMode.redirHost, 'fake-ip'), 'redir-host');
    });
  });

  group('applyMeowDns', () {
    test('follow 不动配置', () {
      final raw = <String, dynamic>{'dns': {'enable': false, 'enhanced-mode': 'fake-ip'}};
      applyMeowDns(raw, MeowDnsMode.follow);
      expect(raw['dns'], {'enable': false, 'enhanced-mode': 'fake-ip'});
    });
    test('redir-host：强制 enable + 写模式，其它键保留', () {
      final raw = <String, dynamic>{'dns': {'enable': false, 'enhanced-mode': 'fake-ip', 'nameserver': ['https://1.1.1.1/dns-query']}};
      applyMeowDns(raw, MeowDnsMode.redirHost);
      expect(raw['dns']['enable'], true);
      expect(raw['dns']['enhanced-mode'], 'redir-host');
      expect(raw['dns']['nameserver'], ['https://1.1.1.1/dns-query']);
    });
    test('fake-ip：缺 range / filter 才补默认', () {
      final raw = <String, dynamic>{};
      applyMeowDns(raw, MeowDnsMode.fakeIp);
      expect(raw['dns']['enhanced-mode'], 'fake-ip');
      expect(raw['dns']['fake-ip-range'], defaultFakeIpRange);
      expect(raw['dns']['fake-ip-filter'], defaultFakeIpFilter);

      final own = <String, dynamic>{'dns': {'fake-ip-range': '28.0.0.1/8', 'fake-ip-filter': ['*.lan']}};
      applyMeowDns(own, MeowDnsMode.fakeIp);
      expect(own['dns']['fake-ip-range'], '28.0.0.1/8');
      expect(own['dns']['fake-ip-filter'], ['*.lan']);
    });
    test('declaredDnsMode', () {
      expect(declaredDnsMode({'dns': {'enhanced-mode': 'fake-ip'}}), 'fake-ip');
      expect(declaredDnsMode({'dns': {}}), isNull);
      expect(declaredDnsMode({}), isNull);
    });
  });
}
