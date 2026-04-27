import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  static const _filters = ['All', 'High Reward', 'Quick (<3 min)', 'Beginner', 'Verified'];
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final cat = findCategory(widget.categoryId);
    final tasks = tasksForCategory(widget.categoryId);
    final c = context.dc;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DCNavBar(
            title: cat?.title ?? 'Tasks',
            subtitle: '${tasks.length} tasks · sorted by reward',
            onBack: () => context.go('/home'),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) => DCChip(
                label: _filters[i],
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
                      'NO TASKS',
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
                caption: task.tag.toUpperCase(),
                radius: 0,
                overlays: [
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.tag.toUpperCase(),
                        style: DCText.mono(size: 10, weight: FontWeight.w500, color: Colors.white, letterSpacing: 1.4),
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
                      task.title,
                      style: DCText.inter(size: 16, weight: FontWeight.w600, color: c.text, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.publisher,
                      style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 13, color: c.textDim),
                        const SizedBox(width: 4),
                        Text(task.duration, style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim)),
                        const Spacer(),
                        Text(task.slots, style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.success)),
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
