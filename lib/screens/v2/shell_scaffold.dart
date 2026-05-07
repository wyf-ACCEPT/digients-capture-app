import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';
import '../../widgets/nav.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  int _indexFromLocation(String location) {
    if (location.startsWith('/submissions')) return 1;
    if (location.startsWith('/me')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = [
      DCTabItem(
        iconOutlined: Icons.home_outlined,
        iconFilled: Icons.home_filled,
        label: l10n.navHome,
        route: '/home',
      ),
      DCTabItem(
        iconOutlined: Icons.folder_outlined,
        iconFilled: Icons.folder,
        label: l10n.navSubmissions,
        route: '/submissions',
      ),
      DCTabItem(
        iconOutlined: Icons.person_outline,
        iconFilled: Icons.person,
        label: l10n.navMe,
        route: '/me',
      ),
    ];
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: DCTabBar(
        tabs: tabs,
        currentIndex: index,
        onSelect: (i) => context.go(tabs[i].route),
      ),
    );
  }
}
