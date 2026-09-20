import 'package:bett_box/meowx/panel/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = {'name': '套餐 A', 'filename': 'a.yaml', 'subscription_path': '/s/abc', 'expire_at': '2027-01-02T03:04:05Z', 'traffic_used': 1024, 'traffic_total': '2048'};

  test('订阅列表三种形状', () {
    for (final shape in [
      [item],
      {'subscriptions': [item]},
      {'items': [item]},
      {'data': [item]},
    ]) {
      final list = RemoteSubscription.parseList(shape);
      expect(list.length, 1, reason: '$shape');
      final s = list.single;
      expect(s.name, '套餐 A');
      expect(s.expireAt, DateTime.utc(2027, 1, 2, 3, 4, 5));
      expect(s.trafficUsed, 1024);
      expect(s.trafficTotal, 2048);
    }
    expect(RemoteSubscription.parseList({'foo': 1}), isEmpty);
    // 旧面板缺流量字段 → null
    final old = RemoteSubscription.parseList([{'name': 'x', 'filename': 'x.yaml', 'subscription_path': ''}]).single;
    expect(old.trafficUsed, isNull);
  });

  test('下载地址：短链优先，回退 subscribe 接口', () {
    final s = RemoteSubscription.parseList([item]).single;
    expect(s.downloadUrl('https://panel.example.com/', subscriptionToken: 'T'), 'https://panel.example.com/s/abc');
    final noPath = RemoteSubscription.parseList([{'name': 'x', 'filename': 'x y.yaml', 'subscription_path': ''}]).single;
    expect(noPath.downloadUrl('https://panel.example.com', subscriptionToken: 'T'), 'https://panel.example.com/api/clash/subscribe?token=T&filename=x+y.yaml&t=clash');
  });

  test('登录结果解析', () {
    expect(LoginSuccess.tryParse({'token': 't', 'username': 'u'})?.nickname, 'u');
    expect(LoginSuccess.tryParse({'token': 't', 'username': 'u', 'nickname': 'N'})?.nickname, 'N');
    expect(LoginSuccess.tryParse({'requires_2fa': true}), isNull);
  });

  test('回程奖牌解析', () {
    final m = NodeMedal.parse({'success': true, 'nodes': [
      {'name': 'HK-1', 'medal': 'gold', 'routes': [{'carrier': 'CT', 'region': '广东', 'route_type': 'CN2 GIA', 'gold': true}]},
      {'name': 'JP-1', 'medal': 'silver'},
    ]});
    expect(m['HK-1']?.routes.single.routeType, 'CN2 GIA');
    expect(m['JP-1']?.medal, 'silver');
    expect(NodeMedal.parse({'success': false}), isEmpty);
  });

  test('登录深链', () {
    final r = parseLoginLink(Uri.parse('miaomiaowu://login?host=panel.example.com&code=abc'));
    expect(r?.base, 'https://panel.example.com');
    expect(r?.code, 'abc');
    expect(parseLoginLink(Uri.parse('miaomiaowu://login?host=https://p.example.com/&code=1'))?.base, 'https://p.example.com');
    expect(parseLoginLink(Uri.parse('clash://install-config?url=x')), isNull);
  });
}
