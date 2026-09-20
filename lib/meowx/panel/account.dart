import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/meow_settings.dart';
import 'client.dart';
import 'models.dart';

export 'models.dart';

/// 当前账户绑定的主控客户端（按 host 缓存一个实例，证书缓存跟着实例走）。
final panelClientProvider = Provider<PanelClient?>((ref) {
  final host = ref.watch(meowSettingProvider.select((s) => s.account.host));
  return host.isEmpty ? null : PanelClient(host);
});

final isLoggedInProvider = Provider<bool>((ref) => ref.watch(meowSettingProvider.select((s) => s.account.token.isNotEmpty)));

/// 「我的订阅」列表。
final remoteSubsProvider = StateProvider<AsyncValue<List<RemoteSubscription>>>((ref) => const AsyncValue.data([]));

/// 节点奖牌（服务端判定）。
final medalsProvider = StateProvider<Map<String, NodeMedal>>((ref) => const {});

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

  Future<void> _store(String base, LoginSuccess ok) async {
    _update((a) => a.copyWith(host: base, token: ok.token, nickname: ok.nickname, avatarUrl: ok.avatarUrl));
  }

  /// 登出只清 token / 昵称 / 头像，保留主控地址。
  void logout() {
    _update((a) => a.copyWith(token: '', nickname: '', avatarUrl: ''));
    ref.read(remoteSubsProvider.notifier).state = const AsyncValue.data([]);
    ref.read(medalsProvider.notifier).state = const {};
  }

  Future<void> refreshSubscriptions() async {
    final token = _account.token;
    if (token.isEmpty) return;
    ref.read(remoteSubsProvider.notifier).state = const AsyncValue.loading();
    try {
      final list = await _client().subscriptions(token);
      ref.read(remoteSubsProvider.notifier).state = AsyncValue.data(list);
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

  void _switchTo(String id) {
    if (ref.read(currentProfileIdProvider) != id) {
      ref.read(currentProfileIdProvider.notifier).value = id;
    }
    globalState.appController.applyProfileDebounce(silence: true);
  }

  Future<void> refreshMedals() async {
    final token = _account.token;
    if (token.isEmpty) return;
    try {
      ref.read(medalsProvider.notifier).state = await _client().returnRoutes(token);
    } catch (e) {
      commonPrint.log('returnRoutes failed: $e');
    }
  }
}

final accountActionsProvider = Provider<AccountActions>((ref) => AccountActions(ref));
