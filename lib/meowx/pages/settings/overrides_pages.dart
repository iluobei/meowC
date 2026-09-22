import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/meow_settings.dart';
import '../../state/overrides.dart';
import '../../state/status.dart';
import '../../theme/glass_card.dart';
import '../../theme/tokens.dart';

/// 改了覆写后：连着就重载（覆写只在 patchRawConfig 里生效）。
void _reloadIfRunning(WidgetRef ref) {
  if (ref.read(isRunningProvider)) globalState.appController.applyProfileDebounce(silence: true);
}

/// DNS 劫持：域名 → IPv4（不能落在 fake-ip 段）。
class DnsHijackPage extends ConsumerWidget {
  const DnsHijackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final map = ref.watch(meowSettingProvider.select((s) => s.dnsHijack));
    final entries = map.entries.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS 劫持'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: map.length >= overridesLimit
                ? null
                : () => _addHijack(context, ref),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Text('把某个域名的解析结果固定为指定 IPv4\n右上角「+」添加', textAlign: TextAlign.center, style: TextStyle(color: mm.t2)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  radius: 18,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) Divider(height: 1, indent: 14, color: mm.t3.withValues(alpha: 0.2)),
                        Dismissible(
                          key: ValueKey(entries[i].key),
                          direction: DismissDirection.endToStart,
                          background: Container(color: mm.slow, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete_rounded, color: Colors.white)),
                          onDismissed: (_) {
                            ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(dnsHijack: {...s.dnsHijack}..remove(entries[i].key)));
                            _reloadIfRunning(ref);
                          },
                          // 域名 / IP 上下两行：长域名不再和右侧 IP 抢宽度
                          child: ListTile(
                            title: Text(entries[i].key, maxLines: 2, overflow: TextOverflow.ellipsis, style: MeowFont.mono(size: MeowFont.subheadline, color: mm.t1)),
                            subtitle: Text(entries[i].value, style: MeowFont.mono(size: MeowFont.subheadline, color: mm.t2)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('${map.length} / $overridesLimit · 左滑删除', style: TextStyle(fontSize: MeowFont.caption, color: mm.t3)),
              ],
            ),
    );
  }

  Future<void> _addHijack(BuildContext context, WidgetRef ref) async {
    final domain = TextEditingController();
    final ip = TextEditingController();
    String? domainErr, ipErr;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          // 横屏弹键盘时高度不够：整体可滚，别把输入框压到按钮上
          scrollable: true,
          title: const Text('添加 DNS 劫持'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: domain, autofocus: true, decoration: InputDecoration(labelText: '域名', hintText: 'example.com', errorText: domainErr, errorMaxLines: 3)),
              const SizedBox(height: 8),
              TextField(controller: ip, decoration: InputDecoration(labelText: 'IPv4', hintText: '1.2.3.4', errorText: ipErr, errorMaxLines: 3), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final d = normalizeDomain(domain.text);
                final de = d == null ? domainInvalidMessage : null;
                final ie = validateHijackIp(ip.text);
                if (de != null || ie != null) {
                  setState(() {
                    domainErr = de;
                    ipErr = ie;
                  });
                  return;
                }
                ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(dnsHijack: {...s.dnsHijack, d!: ip.text.trim()}));
                _reloadIfRunning(ref);
                Navigator.of(ctx).pop();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 绕过代理：域名 + CIDR 两段。
class BypassPage extends ConsumerWidget {
  const BypassPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final meow = ref.watch(meowSettingProvider);
    final total = meow.bypassDomains.length + meow.bypassCidrs.length;
    Widget section(String title, List<String> items, void Function(List<String>) save) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: 14, bottom: 6), child: Text(title, style: TextStyle(fontSize: MeowFont.footnote, color: mm.t2))),
          GlassCard(
            radius: 18,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 14, color: mm.t3.withValues(alpha: 0.2)),
                  Dismissible(
                    key: ValueKey('$title-${items[i]}'),
                    direction: DismissDirection.endToStart,
                    background: Container(color: mm.slow, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete_rounded, color: Colors.white)),
                    onDismissed: (_) {
                      save([...items]..removeAt(i));
                      _reloadIfRunning(ref);
                    },
                    child: ListTile(dense: true, title: Text(items[i], style: MeowFont.mono(size: MeowFont.subheadline, color: mm.t1))),
                  ),
                ],
                if (items.isEmpty) ListTile(dense: true, title: Text('暂无', style: TextStyle(color: mm.t3))),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('绕过代理'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: total >= overridesLimit ? null : () => _add(context, ref)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('域名', meow.bypassDomains, (v) => ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(bypassDomains: v))),
          section('IP / CIDR', meow.bypassCidrs, (v) => ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(bypassCidrs: v))),
          Text('$total / $overridesLimit · 命中的域名 / IP 直连，不经代理 · 左滑删除', style: TextStyle(fontSize: MeowFont.caption, color: mm.t3)),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final input = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          scrollable: true,
          title: const Text('添加绕过'),
          content: TextField(
            controller: input,
            autofocus: true,
            // hint 默认只显示一行，三个示例会被截断
            decoration: InputDecoration(labelText: '域名或 IP / CIDR', hintText: 'example.com、+.example.com、10.0.0.0/8', hintMaxLines: 2, errorText: err, errorMaxLines: 3),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final raw = input.text.trim();
                final cidr = normalizeCidr(raw);
                final domain = cidr == null ? normalizeDomain(raw) : null;
                if (cidr == null && domain == null) {
                  setState(() => err = raw.contains(':') || RegExp(r'^[\d./]+$').hasMatch(raw) ? cidrInvalidMessage : domainInvalidMessage);
                  return;
                }
                ref.read(meowSettingProvider.notifier).updateState((s) => cidr != null
                    ? s.copyWith(bypassCidrs: {...s.bypassCidrs, cidr}.toList())
                    : s.copyWith(bypassDomains: {...s.bypassDomains, domain!}.toList()));
                _reloadIfRunning(ref);
                Navigator.of(ctx).pop();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
