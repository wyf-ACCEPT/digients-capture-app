import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../l10n/localized_fixtures.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/nav.dart';
import '../../fixtures/data.dart';
import '../../models/task.dart';

class PoolScreen extends StatefulWidget {
  final String categoryId;
  const PoolScreen({super.key, required this.categoryId});

  @override
  State<PoolScreen> createState() => _PoolScreenState();
}

class _PoolScreenState extends State<PoolScreen> {
  static const _filters = [
    _PoolFilter.all,
    _PoolFilter.highReward,
    _PoolFilter.quick,
    _PoolFilter.beginner,
    _PoolFilter.verified,
  ];
  _PoolFilter _activeFilter = _PoolFilter.all;

  @override
  Widget build(BuildContext context) {
    final cat = findCategory(widget.categoryId);
    final tasks = tasksForCategory(widget.categoryId);
    final c = context.dc;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DCNavBar(
            title: cat?.localizedTitle(l10n) ?? l10n.tasksTitle,
            subtitle: l10n.poolSortedByReward(tasks.length),
            onBack: () => context.pop(),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) => DCChip(
                label: _filters[i].label(l10n),
                active: _filters[i] == _activeFilter,
                onTap: () => setState(() => _activeFilter = _filters[i]),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      l10n.noTasks,
                      style: DCText.eyebrow(color: c.textDim, size: 11),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemBuilder: (_, i) => _TaskCard(task: tasks[i]),
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemCount: tasks.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () => context.push('/task/${task.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DCImagePlaceholder(
                height: 160,
                caption: task.localizedTag(l10n).toUpperCase(),
                radius: 0,
                overlays: [
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.localizedTag(l10n).toUpperCase(),
                        style: DCText.mono(
                            size: 10,
                            weight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 1.4),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: DCPointsPill(points: task.rewardPoints),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.localizedTitle(l10n),
                      style: DCText.inter(
                          size: 16,
                          weight: FontWeight.w600,
                          color: c.text,
                          height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.localizedPublisher(l10n),
                      style: DCText.mono(
                          size: 11, weight: FontWeight.w500, color: c.textDim),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 13, color: c.textDim),
                        const SizedBox(width: 4),
                        Text(task.localizedDuration(l10n),
                            style: DCText.mono(
                                size: 11,
                                weight: FontWeight.w500,
                                color: c.textDim)),
                        const Spacer(),
                        Text(task.localizedSlots(l10n),
                            style: DCText.mono(
                                size: 11,
                                weight: FontWeight.w500,
                                color: c.success)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PoolFilter { all, highReward, quick, beginner, verified }

extension _PoolFilterLabel on _PoolFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      _PoolFilter.all => l10n.filterAll,
      _PoolFilter.highReward => l10n.filterHighReward,
      _PoolFilter.quick => l10n.filterQuick,
      _PoolFilter.beginner => l10n.filterBeginner,
      _PoolFilter.verified => l10n.filterVerified,
    };
  }
}
