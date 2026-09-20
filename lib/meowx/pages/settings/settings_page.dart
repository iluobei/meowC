import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../state/meow_settings.dart';
import '../../state/status.dart';
import '../../theme/glass_card.dart';
import '../../theme/page_title.dart';
import '../../theme/tokens.dart';
import '../../theme/two_pane.dart';

/// 设置页（P1：代理 / 外观 / 高级 / 关于；其余分组 P2 补齐）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mm = context.mm;
    final wide = ref.watch(isWideLayoutProvider);
    final themeMode = ref.watch(themeSettingProvider.select((s) => s.themeMode));
    final meow = ref.watch(meowSettingProvider);

    final body = ListView(
      padding: EdgeInsets.fromLTRB(wide ? 0 : 16, wide ? 16 : 0, 16, 40),
      children: [
        const PageTitle(S.settings),
        const SizedBox(height: 12),
        _Section(
          title: '代理',
          children: [
            _PickerRow<MeowDnsMode>(
              icon: Icons.dns_rounded,
              color: mm.teal,
              title: S.dnsMode,
              value: meow.dnsMode,
              values: MeowDnsMode.values,
              label: (v) => v.label,
              onChanged: (v) {
                ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(dnsMode: v));
                if (ref.read(isRunningProvider)) globalState.appController.applyProfileDebounce();
              },
            ),
            _PickerRow<LatencyMode>(
              icon: Icons.speed_rounded,
              color: mm.accent,
              title: '测速方式',
              value: meow.latencyMode,
              values: LatencyMode.values,
              label: (v) => v.label,
              onChanged: (v) {
                ref.read(meowSettingProvider.notifier).updateState((s) => s.copyWith(latencyMode: v));
                ref.read(delayDataSourceProvider.notifier).value = {};   // 三档口径不同，旧值作废
              },
            ),
          ],
        ),
        _Section(
          title: S.appearance,
          children: [
            _PickerRow<ThemeMode>(
              icon: Icons.brightness_6_rounded,
              color: mm.pur,
              title: S.theme,
              value: themeMode,
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              label: (v) => switch (v) {
                ThemeMode.system => S.themeSystem,
                ThemeMode.light => S.themeLight,
                ThemeMode.dark => S.themeDark,
              },
              onChanged: (v) {
                final n = ref.read(themeSettingProvider.notifier);
                n.value = ref.read(themeSettingProvider).copyWith(themeMode: v);
              },
            ),
          ],
        ),
        _Section(
          title: S.advanced,
          children: [
            _Row(
              icon: Icons.tune_rounded,
              color: mm.orange,
              title: S.advanced,
              subtitle: S.advancedDesc,
              trailing: Icon(Icons.chevron_right_rounded, color: mm.t3),
              onTap: () => BaseNavigator.push(context, const ToolsView()),
            ),
          ],
        ),
        _Section(
          title: S.about,
          children: [
            _Row(
              icon: Icons.info_rounded,
              color: mm.t2,
              title: S.version,
              trailing: Text(globalState.packageInfo.version, style: MeowFont.mono(size: MeowFont.subheadline, color: mm.t2)),
            ),
            _Row(
              icon: Icons.gavel_rounded,
              color: mm.good,
              title: S.openSourceLicense,
              subtitle: 'GPL-3.0 · 基于 Bettbox / FlClash / mihomo',
              trailing: Icon(Icons.open_in_new_rounded, size: 18, color: mm.t3),
              onTap: () => globalState.openUrl('https://github.com/iluobei/meowC'),
            ),
          ],
        ),
      ],
    );
    return wide ? PageWidth(child: body) : body;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 6),
            child: Text(title, style: TextStyle(fontSize: MeowFont.footnote, color: mm.t2)),
          ),
          GlassCard(
            radius: 18,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 56, color: mm.t3.withValues(alpha: 0.2)),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 行：29×29 圆角 7 纯色方块 + 白 symbol，标题 body，右侧任意。
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.title, this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: MeowFont.body, color: mm.t1)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: MeowFont.caption, color: mm.t3)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });
  final IconData icon;
  final Color color;
  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    return PopupMenuButton<T>(
      tooltip: '',
      onSelected: onChanged,
      itemBuilder: (_) => [for (final v in values) CheckedPopupMenuItem(value: v, checked: v == value, child: Text(label(v)))],
      child: _Row(
        icon: icon,
        color: color,
        title: title,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label(value), style: TextStyle(fontSize: MeowFont.subheadline, color: mm.t2)),
            const SizedBox(width: 2),
            Icon(Icons.unfold_more_rounded, size: 18, color: mm.t3),
          ],
        ),
      ),
    );
  }
}
