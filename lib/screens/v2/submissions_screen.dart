import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chips.dart';
import '../../services/recording_manager.dart';
import '../../models/recording.dart';
import '../../fixtures/data.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({super.key});

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  static const _filters = ['All', 'On Device', 'Uploading', 'In Review', 'Approved', 'Rejected'];
  String _filter = 'All';
  final _manager = RecordingManager();
  List<Recording> _recordings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _manager.loadRecordings();
    list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    if (!mounted) return;
    setState(() {
      _recordings = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final totalMb = _recordings.fold<int>(0, (s, r) => s + (r.fileSizeMB ?? 0));
    final totalGb = (totalMb / 1024).toStringAsFixed(2);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submissions',
                        style: DCText.inter(size: 28, weight: FontWeight.w700, color: c.text, letterSpacing: -0.56),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_recordings.length} total · $totalGb GB on device',
                        style: DCText.mono(size: 12, weight: FontWeight.w500, color: c.textDim),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: c.text, size: 22),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) => DCChip(
                label: _filters[i],
                active: _filter == _filters[i],
                onTap: () => setState(() => _filter = _filters[i]),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : _recordings.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('NO ITEMS', style: DCText.eyebrow(color: c.textDim, size: 11)),
                              const SizedBox(height: 8),
                              Text('Tap a category from Home to start recording.',
                                  textAlign: TextAlign.center,
                                  style: DCText.inter(size: 13, weight: FontWeight.w500, color: c.textFaint)),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: c.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _recordings.length,
                          itemBuilder: (_, i) {
                            final r = _recordings[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecordingRow(
                                recording: r,
                                onShare: () => _share(r, i),
                                onDelete: () => _delete(r),
                                onTap: () => context.push('/submissions/${r.sessionId}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(Recording r, int index) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    try {
      await _manager.shareRecording(r.sessionId, sharePositionOrigin: origin);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _delete(Recording r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text('This removes the local copy of recording ${r.sessionId.substring(0, 8)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF453A))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _manager.deleteRecording(r.sessionId);
    await _load();
  }
}

class _RecordingRow extends StatelessWidget {
  final Recording recording;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _RecordingRow({
    required this.recording,
    required this.onShare,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  children: [
                    Container(color: c.surface2),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(recording.durationSeconds),
                          style: DCText.mono(size: 9, weight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    recordingDisplayTitle(recording),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DCText.inter(size: 14, weight: FontWeight.w600, color: c.text, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(recording.capturedAt)} · ${recording.fileSizeMB ?? 0} MB',
                    style: DCText.mono(size: 10, weight: FontWeight.w500, color: c.textFaint),
                  ),
                  const SizedBox(height: 6),
                  const DCStatusBadge(status: SubmissionStatus.ondevice),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                DCIconButton(
                  icon: Icons.upload,
                  color: c.accent,
                  bg: c.accentTint,
                  onPressed: onShare,
                  semanticLabel: 'Export',
                ),
                const SizedBox(height: 6),
                DCIconButton(
                  icon: Icons.delete_outline,
                  color: c.danger,
                  bg: c.danger.withValues(alpha: 0.12),
                  onPressed: onDelete,
                  semanticLabel: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int? sec) {
    if (sec == null) return '--:--';
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
