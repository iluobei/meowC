import 'package:bett_box/views/views.dart';
import 'package:flutter/material.dart';

/// P2 之前暂用 Bettbox 的连接页（含日志入口在「高级」里）。
class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context) => const ConnectionsView(respectCurrentPage: false);
}
