import 'package:bett_box/meowx/config/meow_patch.dart';
import 'package:bett_box/meowx/state/overrides.dart';
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

  group('用户覆写', () {
    test('DNS 劫持写 hosts，保留原有', () {
      final raw = <String, dynamic>{'hosts': {'a.com': '1.1.1.1'}};
      applyMeowHosts(raw, const MeowSettings(dnsHijack: {'b.com': '2.2.2.2'}));
      expect(raw['hosts'], {'a.com': '1.1.1.1', 'b.com': '2.2.2.2'});
    });
    test('前置规则：绕过 → 推送直连', () {
      expect(meowPrependRules(const MeowSettings(bypassDomains: ['x.com'], bypassCidrs: ['10.0.0.0/8'], pushDirect: true)), [
        'DOMAIN,x.com,DIRECT',
        'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
        ...pushDirectRules,
      ]);
      expect(meowPrependRules(const MeowSettings()), isEmpty);
    });
    test('本地代理凭据 → authentication', () {
      final raw = <String, dynamic>{};
      applyMeowAuthentication(raw, const MeowSettings(localProxy: MeowLocalProxy(username: 'u', password: 'p')));
      expect(raw['authentication'], ['u:p']);
      expect(raw['skip-auth-prefixes'], ['127.0.0.1/32', '::1/128']);
      final none = <String, dynamic>{};
      applyMeowAuthentication(none, const MeowSettings());
      expect(none.containsKey('authentication'), isFalse);
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
