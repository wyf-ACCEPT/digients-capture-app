import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/cards.dart';
import '../../fixtures/data.dart';
import '../../models/task.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final profile = fixtureProfile;
    final cats = fixtureCategories;
    final totalTasks = cats.fold<int>(0, (s, c) => s + c.taskCount);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: DCText.eyebrow(color: c.textDim, size: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.displayName,
                      style: DCText.inter(size: 22, weight: FontWeight.w700, color: c.text, letterSpacing: -0.44),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/me'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.accent, c.accentStrong],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(profile.displayName),
                      style: DCText.inter(size: 14, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DCCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BALANCE', style: DCText.eyebrow(color: c.textDim, size: 10)),
                      const SizedBox(height: 6),
                      Text(
                        '${_format(profile.balancePoints)} pts',
                        style: DCText.mono(size: 24, weight: FontWeight.w600, color: c.text),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: c.border),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PENDING', style: DCText.eyebrow(color: c.textDim, size: 10)),
                      const SizedBox(height: 6),
                      Text(
                        '${_format(profile.pendingPoints)} pts',
                        style: DCText.mono(size: 24, weight: FontWeight.w600, color: c.warning),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Choose a category',
                  style: DCText.inter(size: 18, weight: FontWeight.w600, color: c.text, letterSpacing: -0.18),
                ),
              ),
              Text(
                '$totalTasks tasks',
                style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: cats.map((cat) => _CategoryTile(category: cat)).toList(),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
  }

  String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final disabled = category.soon;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : () => context.push('/pool/${category.id}'),
        child: DCCard(
          padding: const EdgeInsets.all(16),
          radius: 18,
          child: Stack(
            children: [
              if (disabled)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Text(
                      'SOON',
                      style: DCText.mono(size: 9, weight: FontWeight.w600, color: c.textFaint, letterSpacing: 1.4),
                    ),
                  ),
                ),
              Positioned(
                bottom: -10,
                right: -10,
                child: Opacity(
                  opacity: 0.30,
                  child: Icon(_iconFor(category.id), size: 110, color: c.accent),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category.title,
                    style: DCText.inter(size: 18, weight: FontWeight.w600, color: c.text, letterSpacing: -0.18),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${category.taskCount} tasks',
                          style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim),
                        ),
                        if (category.rewardPoints != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'up to +${category.rewardPoints}',
                            style: DCText.mono(size: 11, weight: FontWeight.w600, color: c.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'household':
        return Icons.kitchen_outlined;
      case 'industrial':
        return Icons.precision_manufacturing_outlined;
      case 'sports':
        return Icons.sports_basketball_outlined;
      case 'daily':
        return Icons.coffee_outlined;
      case 'cooking':
        return Icons.local_dining_outlined;
      case 'mobility':
        return Icons.directions_car_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
