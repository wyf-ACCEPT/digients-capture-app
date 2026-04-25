import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/nav.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = [
    DCTabItem(
      iconOutlined: Icons.home_outlined,
      iconFilled: Icons.home_filled,
      label: 'Home',
      route: '/home',
    ),
    DCTabItem(
      iconOutlined: Icons.folder_outlined,
      iconFilled: Icons.folder,
      label: 'Submissions',
      route: '/submissions',
    ),
    DCTabItem(
      iconOutlined: Icons.person_outline,
      iconFilled: Icons.person,
      label: 'Me',
      route: '/me',
    ),
  ];

  int _indexFromLocation(String location) {
    if (location.startsWith('/submissions')) return 1;
    if (location.startsWith('/me')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: DCTabBar(
        tabs: _tabs,
        currentIndex: index,
        onSelect: (i) => context.go(_tabs[i].route),
      ),
    );
  }
}
