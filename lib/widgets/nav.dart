import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class DCNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const DCNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.chevron_left, color: c.text, size: 28),
                  onPressed: onBack,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: DCText.inter(size: 16, weight: FontWeight.w600, color: c.text),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: DCText.inter(size: 12, weight: FontWeight.w500, color: c.textDim),
                        ),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class DCTabItem {
  final IconData iconOutlined;
  final IconData iconFilled;
  final String label;
  final String route;
  const DCTabItem({
    required this.iconOutlined,
    required this.iconFilled,
    required this.label,
    required this.route,
  });
}

class DCTabBar extends StatelessWidget {
  final List<DCTabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const DCTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final active = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? tab.iconFilled : tab.iconOutlined,
                        size: 24,
                        color: active ? c.text : c.textDim,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: DCText.inter(
                          size: 10,
                          weight: FontWeight.w500,
                          color: active ? c.text : c.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
