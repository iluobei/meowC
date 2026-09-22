import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/meow_settings.dart';
import 'client.dart';
import 'models.dart';
import 'unlock_catalog.dart';

export 'models.dart';

/// 当前账户绑定的主控客户端（按 host 缓存一个实例，证书缓存跟着实例走）。
final panelClientProvider = Provider<PanelClient?>((ref) {
  final host = ref.watch(meowSettingProvider.select((s) => s.account.host));
  return host.isEmpty ? null : PanelClient(host);
});

final isLoggedInProvider = Provider<bool>((ref) => ref.watch(meowSettingProvider.select((s) => s.account.token.isNotEmpty)));

/// 「我的订阅」列表。
final remoteSubsProvider = StateProvider<AsyncValue<List<RemoteSubscription>>>((ref) => const AsyncValue.data([]));

/// 主控功能开关：未开启的功能不调接口、不显示图标。
final panelFeaturesProvider = StateProvider<PanelFeatures>((ref) => const PanelFeatures());

/// 节点奖牌（服务端判定）。
final medalsProvider = StateProvider<Map<String, NodeMedal>>((ref) => const {});

/// 节点解锁结论（服务端判定）。
final unlocksProvider = StateProvider<Map<String, NodeUnlocks>>((ref) => const {});

/// 正在导入的远端订阅（按名字）。
final importingSubProvider = StateProvider<String?>((ref) => null);

/// 账户动作：登录 / 二步验证 / 扫码 / 登出 / 拉订阅 / 导入并切换 / 奖牌。
class AccountActions {
  AccountActions(this.ref);
  final Ref ref;

  MeowAccount get _account => ref.read(meowSettingProvider).account;

  void _update(MeowAccount Function(MeowAccount) f) {
    ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(account: f(s.account)));
  }

  PanelClient _client([String? host]) {
    final h = host ?? _account.host;
    if (h.isEmpty) throw const PanelException('尚未设置主控地址');
    return h == _account.host ? (ref.read(panelClientProvider) ?? PanelClient(h)) : PanelClient(h);
  }

  Future<LoginResult> login({required String host, required String username, required String password}) async {
    final client = _client(host);
    final r = await client.login(username: username, password: password);
    if (r is LoginSuccess) await _store(client.base, r);
    if (r is LoginNeeds2FA) _update((a) => a.copyWith(host: client.base));
    return r;
  }

  Future<LoginResult> complete2fa({required String twoFactorToken, required String code, bool recovery = false}) async {
    final client = _client();
    final r = recovery
        ? await client.loginRecovery(twoFactorToken: twoFactorToken, recoveryCode: code)
        : await client.login2fa(twoFactorToken: twoFactorToken, code: code);
    if (r is LoginSuccess) await _store(client.base, r);
    return r;
  }

  /// 扫码 / 深链登录：一次性码，成功后立即拉订阅。
  Future<void> loginWithCode({required String host, required String code}) async {
    final client = _client(host);
    final r = await client.loginQr(code);
    if (r is! LoginSuccess) throw const PanelException('登录失败');
    await _store(client.base, r);
    await refreshSubscriptions();
  }

  /// 登录 sheet 用：按填的主控地址拿客户端（同一地址复用缓存的实例，轮询时不必每次重建）。
  PanelClient clientFor(String host) => _client(host);

  /// Telegram 登录是否可用：主控没开机器人 / 连不上都算不可用，按钮不显示。
  Future<bool> telegramLoginAvailable(PanelClient client) async {
    try {
      return await client.telegramLoginAvailable();
    } catch (e) {
      commonPrint.log('telegramLoginAvailable failed: $e');
      return false;
    }
  }

  Future<TelegramLoginStart> telegramLoginStart(PanelClient client) => client.telegramLoginStart();

  Future<TelegramLoginPush> telegramLoginPush(PanelClient client, String username) => client.telegramLoginPush(username);

  /// 轮询一次；机器人侧确认后与密码登录一样入库，成功顺带拉订阅（同 loginWithCode）。
  Future<TelegramLoginPoll> telegramLoginPoll(PanelClient client, String nonce) async {
    final r = await client.telegramLoginPoll(nonce);
    if (r is TelegramLoginDone) {
      switch (r.result) {
        case LoginSuccess ok:
          await _store(client.base, ok);
          await refreshSubscriptions();
        case LoginNeeds2FA():
          _update((a) => a.copyWith(host: client.base));
      }
    }
    return r;
  }

  Future<void> _store(String base, LoginSuccess ok) async {
    _update((a) => a.copyWith(host: base, token: ok.token, nickname: ok.nickname, avatarUrl: ok.avatarUrl));
  }

  /// 登出只清 token / 昵称 / 头像，保留主控地址。
  void logout() {
    _update((a) => a.copyWith(token: '', nickname: '', avatarUrl: ''));
    ref.read(remoteSubsProvider.notifier).state = const AsyncValue.data([]);
    ref.read(medalsProvider.notifier).state = const {};
    ref.read(unlocksProvider.notifier).state = const {};
    ref.read(panelFeaturesProvider.notifier).state = const PanelFeatures();
    _extrasAt = null;
  }

  Future<void> refreshSubscriptions() async {
    final token = _account.token;
    if (token.isEmpty) return;
    ref.read(remoteSubsProvider.notifier).state = const AsyncValue.loading();
    try {
      final list = await _client().subscriptions(token);
      ref.read(remoteSubsProvider.notifier).state = AsyncValue.data(list);
      unawaited(refreshExtras());
    } catch (e, st) {
      commonPrint.log('refreshSubscriptions failed: $e');
      ref.read(remoteSubsProvider.notifier).state = AsyncValue.error(e, st);
    }
  }

  /// 点某条订阅 = 下载并切换为当前（同 url 已存在则刷新它）；连着就重连。
  Future<void> importSubscription(RemoteSubscription sub) async {
    final token = _account.token;
    if (token.isEmpty) throw const PanelException('请先登录');
    ref.read(importingSubProvider.notifier).state = sub.name;
    try {
      final client = _client();
      final subToken = await client.subscriptionToken(token);
      final url = sub.downloadUrl(client.base, subscriptionToken: subToken);
      final controller = globalState.appController;
      final existing = ref.read(profilesProvider).where((p) => p.url == url).firstOrNull;
      if (existing != null) {
        await controller.updateProfile(existing.copyWith(label: sub.name));
        _switchTo(existing.id);
        return;
      }
      final profile = await Profile.normal(url: url, label: sub.name).update();
      await controller.addProfile(profile);
      _switchTo(profile.id);
    } finally {
      ref.read(importingSubProvider.notifier).state = null;
    }
  }

  /// 切换当前档案：改 currentProfileId 即可，Bettbox 的 ClashManager 监听 needSetup 后自动重载
  void _switchTo(String id) {
    if (ref.read(currentProfileIdProvider) != id) {
      ref.read(currentProfileIdProvider.notifier).value = id;
    }
  }

  DateTime? _extrasAt;

  /// 节点附加信息（奖牌 / 解锁）：先问主控开了哪些，没开的不调接口、清空本地数据。
  Future<void> refreshExtras({bool ifStale = false}) async {
    final token = _account.token;
    if (token.isEmpty) return;
    if (ifStale && _extrasAt != null && DateTime.now().difference(_extrasAt!) < const Duration(minutes: 10)) return;
    _extrasAt = DateTime.now();
    final client = _client();
    PanelFeatures features;
    try {
      features = await client.features(token);
    } catch (e) {
      commonPrint.log('features failed: $e');
      return;
    }
    ref.read(panelFeaturesProvider.notifier).state = features;
    if (features.returnRoutes) {
      try {
        ref.read(medalsProvider.notifier).state = await client.returnRoutes(token);
      } catch (e) {
        commonPrint.log('returnRoutes failed: $e');
      }
    } else {
      ref.read(medalsProvider.notifier).state = const {};
    }
    if (features.unlockCheck) {
      try {
        ref.read(unlocksProvider.notifier).state = await client.unlocks(token);
      } catch (e) {
        commonPrint.log('unlocks failed: $e');
      }
    } else {
      ref.read(unlocksProvider.notifier).state = const {};
    }
  }
}

final accountActionsProvider = Provider<AccountActions>((ref) => AccountActions(ref));

/// `--dart-define=MEOWX_DEMO_EXTRAS=true`：不登录也给节点塞一批假奖牌 / 解锁结论，用来截图核对界面。
const demoExtras = bool.fromEnvironment('MEOWX_DEMO_EXTRAS');

void seedDemoExtras(WidgetRef ref, List<String> names) {
  if (ref.read(unlocksProvider).isNotEmpty || names.isEmpty) return;
  final medals = <String, NodeMedal>{};
  final unlocks = <String, NodeUnlocks>{};
  for (var i = 0; i < names.length; i++) {
    final n = names[i];
    if (i % 2 == 0) {
      medals[n] = NodeMedal(name: n, medal: i % 4 == 0 ? 'gold' : 'silver', routes: [
        ReturnRoute(carrier: 'telecom', region: '广东', routeType: i % 4 == 0 ? 'CN2 GIA' : '163', gold: i % 4 == 0),
        const ReturnRoute(carrier: 'unicom', routeType: '9929', gold: true),
        const ReturnRoute(carrier: 'mobile', routeType: 'CMI', gold: false),
      ]);
    }
    if (i % 3 != 2) {
      final statuses = ['yes', 'no', 'originals_only', 'banned', 'failed'];
      unlocks[n] = NodeUnlocks(name: n, entries: [
        for (var k = 0; k < unlockServices.length; k++)
          UnlockEntry(
            service: unlockServices[k].key,
            status: unlockServices[k].info ? 'yes' : statuses[(i + k) % statuses.length],
            region: (i + k) % 2 == 0 ? ['HK', 'US', 'JP', 'SG'][(i + k) % 4] : null,
          ),
      ]);
    }
  }
  ref.read(panelFeaturesProvider.notifier).state = const PanelFeatures(returnRoutes: true, unlockCheck: true);
  ref.read(medalsProvider.notifier).state = medals;
  ref.read(unlocksProvider.notifier).state = unlocks;
}
