import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/http.dart';
import 'package:bett_box/meowx/update/update_http.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// 测试专用的自签证书（CN=localhost，SAN 127.0.0.1，有效期 100 年），不在任何信任库里。
const _cert = '''
-----BEGIN CERTIFICATE-----
MIIDJzCCAg+gAwIBAgIUNRBXVRILEEQ06GgHq4saFsGt2dgwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MDkyMzEzMTMwNVoYDzIxMjYw
ODMwMTMxMzA1WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQCRBMqVsANWv+0AZVL4qlqlWFN4UMYmM/dGjZZLaevL
mGyCtOLUjNlAmPwkEGirJrc18WiArzKGv6ocwKoPTRnCcL5Mwqb/pPgqROx9ODq8
XStMnKQeNssri8ZPO8bgNDt7ORvX0Anm9H76RFjNyfre1VpUu2oDKK09077leGTp
H3sNfAH8RsdFdy0H4gipOfNKS4XuUB307af7AZslSXIjGeSd6vCsobMJCvKww1e6
ndSh1CaEqMFN38wlL0HJ89hUsLCrPFnpuHHbtzgFoPTL8uIHdBEw622C5QMBi0pW
7+fSHPo6xGI5+LcOvjI85quPUuwEvpr1QV6ckz/nVLh9AgMBAAGjbzBtMB0GA1Ud
DgQWBBQRn2Tgwn7YKmkywnlD4jkoz+q2TzAfBgNVHSMEGDAWgBQRn2Tgwn7YKmky
wnlD4jkoz+q2TzAPBgNVHRMBAf8EBTADAQH/MBoGA1UdEQQTMBGHBH8AAAGCCWxv
Y2FsaG9zdDANBgkqhkiG9w0BAQsFAAOCAQEAd6tLPyqM16iyCqftTV6ABGGu1zmE
3wg3kHwzB79vEa8O1IHeveN70+db9akpVjbx2Fy8JjxvUXhz6a7wVq/XohQQEBc6
GqUpIwy6rvxtDMBUm0WpgT1TfTANHIBRpU3tOUUagC4naeZQY9l/cvOZtCIyKuUZ
Yuu+W7TzBWWLeq0pvZUWL1O6voYQKKfAsY7nBW/pQjKJ2by9XD9vEtbIYESY5Wxs
pIhiQ7z9zm4qYH045xrp8btIijTQmKLDhTdzxgK3AeVGBPut32lWWZsT+KbIBxsf
nlDNfiWdl5YR9RvZDAOybJHC3eHrPnV1PI13+k3Vh/tv7+X/s22b8uXoWw==
-----END CERTIFICATE-----
''';

const _key = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCRBMqVsANWv+0A
ZVL4qlqlWFN4UMYmM/dGjZZLaevLmGyCtOLUjNlAmPwkEGirJrc18WiArzKGv6oc
wKoPTRnCcL5Mwqb/pPgqROx9ODq8XStMnKQeNssri8ZPO8bgNDt7ORvX0Anm9H76
RFjNyfre1VpUu2oDKK09077leGTpH3sNfAH8RsdFdy0H4gipOfNKS4XuUB307af7
AZslSXIjGeSd6vCsobMJCvKww1e6ndSh1CaEqMFN38wlL0HJ89hUsLCrPFnpuHHb
tzgFoPTL8uIHdBEw622C5QMBi0pW7+fSHPo6xGI5+LcOvjI85quPUuwEvpr1QV6c
kz/nVLh9AgMBAAECggEAHugJweWhjIk6Wjl9+aOazn7YyT1TwZwVIOr3g0qHd5xc
Ue35osmC2q7QG+KIYCOP69Xviu9rwgaSm26fP8QTj5pGIGdivnya7C1ExnonoHHt
0rXWj17npXf0U3oerDVNkPkumyvKFHf6oN1UnMUla3zGc+T+Vr6CT3kzh8XFId6i
zOD74hk7vW7AQn/7tQ+3dXbTOow1LgccD5tY0va5XDtCDLu6ni1J9iOEbeZELCXR
3ZYrwNFDQUPnhUKqctxi+0EC3+ROqEu6wtLV45q+CTxFgF3lGClU+Yv6NqqGjBcC
OKNvDZCALKMfhiSeSeyjEu2GVE6vuuJ7kjMXt1dNeQKBgQDFXo/hlz/9KgekvD0V
1vgKueBNyvk/3dJvLoavO8Q+CBleLmPLy+TfPUboz2vSvUak7tWBoIqy/RuU/yG9
VB6+EZLcjGopV40M+3EXkT7s7K4BXR259tDYFNqqZ6XPz5dCJIrJzn7ZwHu/g1Wz
ODmD38ZXy+/HrqtUWH6ooLT+xQKBgQC8GRg9GH948yBujY8Duock8u4G4woKAX3b
BWkTSRSDb+AAH7hZkdk2EObPrxTPr01aUJxZzugGyCyfowzlHsUi/kBmBuPGbZ/W
0JU4S/BA4jWxTm0F6BSGC5NVc1oA2P/GepnaAPA7Z6dP7edGuc4yaU6+JtFvui48
qDTefinuWQKBgQChpi1ZqrMx+jaAadvuAz7sKgjYLiGueVNc1FJjOyQjWibMyFnc
FIbDgECPdTLuSy+M7j/YB1ER/9OTWNKdakQzj9kk4awhaB+SPm4Fy2QqUD7DxywN
n2S1VX8yiel4JqHP/nXdi07BsbCozjxmqOoSZDjit5kPhrO0RTaXjegvsQKBgHv3
LfpWAuz7jwxNT0vtytOXJzhyuVMO2JtYXX/QUiyttrteLGkbrkPrr7KAeP7HUfuL
1P97VX/ivUYYd48pUFNXramQMN29sfIpVa7cnWKlsy0/uqqB4cTWLCvM8ixM14U/
l9YNeEYuch5DdIEwQ60Fqle3zaAM3Bwt32ojTA9BAoGBAIBX9c4J/Sfy2rzZItrd
FUbP2ToxxTyiJPAnQx6Anrs9oNkVirOXPyPEVAJ42J5Dy8KZzLs1MF2jTCHB728W
8pMUUkDFy+tiLHsPBPLLFPVhAr4jZqfbBnvXE3RMPrHoC3nMTwcVbdFfm0l7wdF2
SMmMjIOEYeZJQ60jjwgAX7TZ
-----END PRIVATE KEY-----
''';

Future<HttpServer> _selfSignedServer() async {
  final ctx = SecurityContext()
    ..useCertificateChainBytes(utf8.encode(_cert))
    ..usePrivateKeyBytes(utf8.encode(_key));
  final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
  server.listen((req) {
    req.response
      ..write('ok')
      ..close();
  });
  return server;
}

Future<int> _get(HttpClient client, Uri url) async {
  final req = await client.getUrl(url);
  final res = await req.close();
  await res.drain<void>();
  return res.statusCode;
}

void main() {
  // 和 main.dart 一样装上 Bettbox 的全局覆盖：它把证书一律放行
  setUp(() => HttpOverrides.global = BettboxHttpOverrides());
  tearDown(() => HttpOverrides.global = null);

  test('全局覆盖下普通 HttpClient 接受自签证书（对照组，证明覆盖真的生效）', () async {
    final server = await _selfSignedServer();
    addTearDown(server.close);
    expect(await _get(HttpClient(), Uri.parse('https://127.0.0.1:${server.port}/')), 200);
  });

  test('strictHttpClient 绕开全局覆盖：自签证书握手失败', () async {
    final server = await _selfSignedServer();
    addTearDown(server.close);
    await expectLater(
      _get(strictHttpClient(), Uri.parse('https://127.0.0.1:${server.port}/')),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('strictUpdateDio 同样拒绝自签证书（DioException 里包着握手错误）', () async {
    final server = await _selfSignedServer();
    addTearDown(server.close);
    await expectLater(
      strictUpdateDio().get<String>('https://127.0.0.1:${server.port}/'),
      throwsA(isA<DioException>().having((e) => e.error, 'error', isA<HandshakeException>())),
    );
  });

  test('strictHttpClient 明文 / 本机地址照常可达（findProxy 沿用全局逻辑：本机直连）', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) {
      req.response
        ..write('ok')
        ..close();
    });
    expect(await _get(strictHttpClient(), Uri.parse('http://127.0.0.1:${server.port}/')), 200);
  });
}
