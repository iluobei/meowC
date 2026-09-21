import 'package:bett_box/meowx/state/exit_ip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cloudflare trace 解析', () {
    final info = parseCloudflareTrace('fl=1\nh=cp.cloudflare.com\nip=152.175.6.247\nts=1\nloc=US\ntls=off\n');
    expect(info?.ip, '152.175.6.247');
    expect(info?.countryCode, 'US');
    expect(parseCloudflareTrace('nothing'), isNull);
  });
}
