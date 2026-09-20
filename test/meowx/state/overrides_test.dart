import 'package:bett_box/meowx/state/overrides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('域名归一化：trim / 小写 / 去尾点 / 剥 +. 与 . 前缀，*. 保留', () {
    expect(normalizeDomain('  Example.COM. '), 'example.com');
    expect(normalizeDomain('+.example.com'), '+.example.com');
    expect(normalizeDomain('.example.com'), '+.example.com');
    expect(normalizeDomain('*.example.com'), '*.example.com');
    expect(normalizeDomain('*'), '*');
    expect(normalizeDomain('-bad.com'), isNull);
    expect(normalizeDomain('a..b'), isNull);
    expect(normalizeDomain('${'a' * 64}.com'), isNull);
    expect(validateDomain('bad_domain'), domainInvalidMessage);
    expect(validateDomain('ok.example.com'), isNull);
  });

  test('CIDR 校验', () {
    expect(normalizeCidr('1.2.3.4'), '1.2.3.4');
    expect(normalizeCidr('10.0.0.0/8'), '10.0.0.0/8');
    expect(normalizeCidr('2001:DB8::/32'), '2001:db8::/32');
    expect(normalizeCidr('::1'), '::1');
    expect(normalizeCidr('1.2.3.256'), isNull);
    expect(normalizeCidr('10.0.0.0/33'), isNull);
    expect(normalizeCidr('10.0.0.0/'), isNull);
    expect(normalizeCidr('2001:db8:::1'), isNull);
    expect(validateCidr('x'), cidrInvalidMessage);
  });

  test('DNS 劫持 IP 校验', () {
    expect(validateHijackIp('1.1.1.1'), isNull);
    expect(validateHijackIp('198.18.0.5'), fakeIpRangeMessage);
    expect(validateHijackIp('2001:db8::1'), ipv4InvalidMessage);
    expect(validateHijackIp('1.2.3'), ipv4InvalidMessage);
  });

  test('绕过规则生成', () {
    expect(bypassRules(['example.com', '+.a.com', '*.b.com', 'bad_'], ['1.2.3.4', '10.0.0.0/8', '2001:db8::/32', 'x']), [
      'DOMAIN,example.com,DIRECT',
      'DOMAIN-SUFFIX,a.com,DIRECT',
      'DOMAIN-WILDCARD,*.b.com,DIRECT',
      'IP-CIDR,1.2.3.4/32,DIRECT,no-resolve',
      'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
      'IP-CIDR6,2001:db8::/32,DIRECT,no-resolve',
    ]);
  });
}
