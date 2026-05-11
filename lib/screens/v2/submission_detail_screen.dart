import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/l10n.dart';
import '../../l10n/localized_fixtures.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/nav.dart';
import '../../widgets/recording_thumbnail.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/compression_queue.dart';
import '../../services/recording_manager.dart';
import '../../models/recording.dart';
import '../../state/upload_controller.dart';
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
      orElse: () => Recording(
          sessionId: widget.sessionId,
          capturedAt: DateTime.now(),
          directoryPath: ''),
    );
    if (!mounted) return;
    setState(() {
      _recording = r;
      _loading = false;
    });
  }

  Future<void> _share() async {
    if (_recording == null) return;
    final l10n = context.l10n;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final queue = context.read<CompressionQueue>();
    final sid = _recording!.sessionId;
    try {
      // Common case after we ship: the archive was built right after the
      // recording stopped, so this returns instantly. Slow path covers
      // legacy recordings + ones whose compression hadn't finished yet
      // when the user tapped Share — the modal then sits up while the
      // queue's worker isolate finishes the build.
      final String? archivePath = queue.isReady(sid)
          ? await _manager.exportRecording(sid)
          : await withExportProgress<String?>(
              context,
              initialMessage: l10n.compressingRecording,
              work: (_) => queue.waitForReady(sid),
            );
      if (archivePath == null || !mounted) return;
      // The archive on disk already has the slug-based filename, so no
      // XFile.name override is needed.
      await Share.shareXFiles(
        [XFile(archivePath)],
        subject: l10n.shareSubjectRecording,
        text: l10n.shareTextRecording,
        sharePositionOrigin: origin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))));
    }
  }

  Future<void> _delete() async {
    if (_recording == null) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecordingTitle),
        content: Text(
            l10n.deleteRecordingContent(_recording!.sessionId.substring(0, 8))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: Color(0xFFFF453A))),
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
    final l10n = context.l10n;
    if (_loading) {
      return Scaffold(
          backgroundColor: c.bg,
          body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    final r = _recording!;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          DCNavBar(title: l10n.submissionsTitle, onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RecordingThumbnail(
                        recording: r,
                        surface: c.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatDuration(r.durationSeconds),
                            style: DCText.mono(
                                size: 11,
                                weight: FontWeight.w500,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const DCStatusBadge(status: SubmissionStatus.ondevice),
                const SizedBox(height: 14),
                Text(
                  localizedRecordingDisplayTitle(r, l10n),
                  style: DCText.inter(
                      size: 22,
                      weight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: -0.44),
                ),
                const SizedBox(height: 18),
                DCCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.savedOnDevice,
                          style: DCText.eyebrow(color: c.textDim, size: 10)),
                      const SizedBox(height: 6),
                      Text(
                        l10n.notUploadedYet,
                        style: DCText.inter(
                            size: 13,
                            weight: FontWeight.w500,
                            color: c.textDim,
                            height: 1.5),
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
                    DCKVTile(
                        label: l10n.sessionId,
                        value: r.sessionId.substring(0, 12)),
                    DCKVTile(
                        label: l10n.captured, value: _formatDate(r.capturedAt)),
                    DCKVTile(
                        label: l10n.size, value: '${r.fileSizeMB ?? 0} MB'),
                    DCKVTile(label: l10n.codec, value: 'HEVC'),
                    DCKVTile(label: l10n.resolution, value: '1920×1080'),
                    DCKVTile(label: l10n.intrinsics, value: l10n.perFrame),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _CloudUploadButton(
                        recording: r,
                        onSnack: (msg) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    DCIconButton(
                      icon: Icons.ios_share,
                      color: c.text,
                      bg: c.surface,
                      size: 56,
                      onPressed: _share,
                      semanticLabel: l10n.export,
                    ),
                    const SizedBox(width: 10),
                    DCIconButton(
                      icon: Icons.delete_outline,
                      color: c.danger,
                      bg: c.danger.withValues(alpha: 0.12),
                      size: 56,
                      onPressed: _delete,
                      semanticLabel: l10n.delete,
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

// State-aware primary CTA for uploading a recording to the digients-api S3
// pipeline. Switches between idle / queued / uploading (with progress bar)
// / uploaded (✓) / failed (tap to retry) based on UploadController state.
class _CloudUploadButton extends StatelessWidget {
  final Recording recording;
  final void Function(String message) onSnack;

  const _CloudUploadButton({
    required this.recording,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.dc;
    final controller = context.watch<UploadController>();
    final entry = controller.entryFor(recording.sessionId);
    final status = entry.status;

    switch (status) {
      case UploadStatus.idle:
      case UploadStatus.queued:
        final isQueued = status == UploadStatus.queued;
        return DCButton(
          label: isQueued ? l10n.uploadQueuedLabel : l10n.uploadToCloud,
          leadingIcon: Icons.cloud_upload_outlined,
          onPressed: isQueued ? null : () => controller.enqueue(recording),
        );
      case UploadStatus.uploading:
        return _UploadingProgress(
          fraction: entry.progress,
          label: l10n.uploadingPercent((entry.progress * 100).round()),
          accent: c.accent,
          bg: c.surface,
          border: c.borderStrong,
        );
      case UploadStatus.uploaded:
        return _UploadedPill(label: l10n.uploadedLabel, color: c.accent);
      case UploadStatus.failed:
        return DCButton(
          label: l10n.uploadFailedRetry,
          leadingIcon: Icons.refresh,
          danger: c.danger,
          primary: false,
          onPressed: () {
            final err = entry.errorMessage;
            if (err != null) onSnack(l10n.uploadFailedSnack(err));
            controller.enqueue(recording);
          },
        );
    }
  }
}

class _UploadingProgress extends StatelessWidget {
  final double fraction;
  final String label;
  final Color accent;
  final Color bg;
  final Color border;

  const _UploadingProgress({
    required this.fraction,
    required this.label,
    required this.accent,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(color: accent.withValues(alpha: 0.18)),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: DCText.inter(
                    size: 17,
                    weight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadedPill extends StatelessWidget {
  final String label;
  final Color color;

  const _UploadedPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: DCText.inter(
              size: 17,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
