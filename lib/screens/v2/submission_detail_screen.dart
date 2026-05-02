import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/nav.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/recording_manager.dart';
import '../../models/recording.dart';
import '../../fixtures/data.dart';
import '../../widgets/export_progress.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final String sessionId;
  const SubmissionDetailScreen({super.key, required this.sessionId});

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  final _manager = RecordingManager();
  Recording? _recording;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _manager.loadRecordings();
    final r = all.firstWhere(
      (r) => r.sessionId == widget.sessionId,
      orElse: () => Recording(sessionId: widget.sessionId, capturedAt: DateTime.now(), directoryPath: ''),
    );
    if (!mounted) return;
    setState(() {
      _recording = r;
      _loading = false;
    });
  }

  Future<void> _share() async {
    if (_recording == null) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    try {
      // Build the archive while the progress modal is up so the user has
      // a clear "I'm working on it" signal even on long recordings; then
      // hand off to the system share sheet only after compression is done.
      final archivePath = await withExportProgress<String?>(
        context,
        initialMessage: 'Compressing recording…',
        work: (_) => _manager.exportRecording(_recording!.sessionId),
      );
      if (archivePath == null || !mounted) return;
      await Share.shareXFiles(
        [XFile(archivePath)],
        subject: 'Egocentric Video Recording',
        text: 'Egocentric video recording data package',
        sharePositionOrigin: origin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _delete() async {
    if (_recording == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text('This removes the local copy of recording ${_recording!.sessionId.substring(0, 8)}.'),
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
    await _manager.deleteRecording(_recording!.sessionId);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    if (_loading) {
      return Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    final r = _recording!;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DCNavBar(title: 'Submissions', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                DCImagePlaceholder(
                  height: 210,
                  caption: r.sessionId.substring(0, 8),
                  overlays: [
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDuration(r.durationSeconds),
                          style: DCText.mono(size: 11, weight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const DCStatusBadge(status: SubmissionStatus.ondevice),
                const SizedBox(height: 14),
                Text(
                  recordingDisplayTitle(r),
                  style: DCText.inter(size: 22, weight: FontWeight.w700, color: c.text, letterSpacing: -0.44),
                ),
                const SizedBox(height: 18),
                DCCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SAVED ON DEVICE', style: DCText.eyebrow(color: c.textDim, size: 10)),
                      const SizedBox(height: 6),
                      Text(
                        'Not uploaded yet. Use Export to share the recording package via the share sheet.',
                        style: DCText.inter(size: 13, weight: FontWeight.w500, color: c.textDim, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    DCKVTile(label: 'Session ID', value: r.sessionId.substring(0, 12)),
                    DCKVTile(label: 'Captured', value: _formatDate(r.capturedAt)),
                    DCKVTile(label: 'Size', value: '${r.fileSizeMB ?? 0} MB'),
                    DCKVTile(label: 'Codec', value: 'HEVC'),
                    const DCKVTile(label: 'Resolution', value: '1920×1080'),
                    const DCKVTile(label: 'Intrinsics', value: 'Per-frame'),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: DCButton(label: 'Export', leadingIcon: Icons.upload, onPressed: _share)),
                    const SizedBox(width: 10),
                    DCIconButton(
                      icon: Icons.delete_outline,
                      color: c.danger,
                      bg: c.danger.withValues(alpha: 0.12),
                      size: 56,
                      onPressed: _delete,
                      semanticLabel: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
