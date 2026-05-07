import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';
import '../../l10n/localized_fixtures.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/nav.dart';
import '../../fixtures/data.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    final task = findTask(taskId);
    if (task == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
            child: Text(l10n.taskNotFound,
                style: DCText.inter(
                    size: 16, weight: FontWeight.w500, color: c.text))),
      );
    }
    final steps = task.localizedSteps(l10n);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DCNavBar(title: l10n.taskDetails, onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 140),
              children: [
                DCImagePlaceholder(
                    height: 200, caption: l10n.demoCaption, radius: 0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.localizedTitle(l10n),
                        style: DCText.inter(
                            size: 26,
                            weight: FontWeight.w700,
                            color: c.text,
                            height: 1.2,
                            letterSpacing: -0.52),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 28, color: c.accent),
                          const SizedBox(width: 4),
                          Text(
                            '+${task.rewardPoints}',
                            style: DCText.mono(
                                size: 36,
                                weight: FontWeight.w700,
                                color: c.accent,
                                letterSpacing: -1.08),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              l10n.pointsOnApproval,
                              style: DCText.inter(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: c.textDim),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      DCKVTile(
                          label: l10n.duration,
                          value: task.localizedDuration(l10n),
                          icon: Icons.access_time),
                      DCKVTile(
                          label: l10n.difficulty,
                          value: task.localizedDifficulty(l10n),
                          icon: Icons.tune),
                      DCKVTile(
                          label: l10n.lighting,
                          value: task.localizedLighting(l10n),
                          icon: Icons.wb_sunny_outlined),
                      DCKVTile(
                          label: l10n.surface,
                          value: task.localizedSurface(l10n),
                          icon: Icons.dashboard_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.steps,
                          style: DCText.eyebrow(color: c.textDim, size: 11)),
                      const SizedBox(height: 12),
                      ...List.generate(steps.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: c.surface2,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: DCText.mono(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: c.text),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  steps[i],
                                  style: DCText.inter(
                                      size: 14,
                                      weight: FontWeight.w500,
                                      color: c.text,
                                      height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DCCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.headsUp,
                            style: DCText.eyebrow(color: c.textDim, size: 10)),
                        const SizedBox(height: 8),
                        Text(
                          l10n.storageWarning,
                          style: DCText.inter(
                              size: 13,
                              weight: FontWeight.w500,
                              color: c.textDim,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: c.bg,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  l10n.storageAvailability,
                  style: DCText.mono(
                      size: 11, weight: FontWeight.w500, color: c.textDim),
                ),
              ),
              DCButton(
                label: l10n.record,
                leadingIcon: Icons.fiber_manual_record,
                onPressed: () => context.push('/record/${task.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
