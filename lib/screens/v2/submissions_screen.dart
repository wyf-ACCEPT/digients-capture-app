import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../l10n/localized_fixtures.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chips.dart';
import '../../widgets/export_progress.dart';
import '../../widgets/recording_thumbnail.dart';
import '../../services/compression_queue.dart';
import '../../services/recording_manager.dart';
import '../../models/recording.dart';
import '../../state/upload_controller.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({super.key});

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  static const _filters = [
    _SubmissionFilter.all,
    _SubmissionFilter.onDevice,
    _SubmissionFilter.uploading,
    _SubmissionFilter.inReview,
    _SubmissionFilter.approved,
    _SubmissionFilter.rejected,
  ];
  _SubmissionFilter _filter = _SubmissionFilter.all;
  final _manager = RecordingManager();
  List<Recording> _recordings = [];
  bool _loading = true;

  // Selection mode state. Entered via long-press on a row or via the
  // "Select" icon in the header; exited via the "Done" button or after a
  // successful bulk export.
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

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

  void _enterSelection({String? initialId}) {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      if (initialId != null) _selectedIds.add(initialId);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _recordings.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_recordings.map((r) => r.sessionId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    final totalMb = _recordings.fold<int>(0, (s, r) => s + (r.fileSizeMB ?? 0));
    final totalGb = (totalMb / 1024).toStringAsFixed(2);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _selectionMode
                    ? _buildSelectionHeader(c)
                    : _buildDefaultHeader(c, totalGb),
              ),
              if (!_selectionMode)
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, i) => DCChip(
                      label: _filters[i].label(l10n),
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
                        ? _buildEmpty(c)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: c.accent,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                _selectionMode ? 110 : 24,
                              ),
                              itemCount: _recordings.length,
                              itemBuilder: (_, i) {
                                final r = _recordings[i];
                                final selected =
                                    _selectedIds.contains(r.sessionId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RecordingRow(
                                    recording: r,
                                    selectionMode: _selectionMode,
                                    selected: selected,
                                    onShare: () => _share(r),
                                    onDelete: () => _delete(r),
                                    onTap: () {
                                      if (_selectionMode) {
                                        _toggleSelected(r.sessionId);
                                      } else {
                                        context.push(
                                            '/submissions/${r.sessionId}');
                                      }
                                    },
                                    onLongPress: () {
                                      if (!_selectionMode) {
                                        _enterSelection(initialId: r.sessionId);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          if (_selectionMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SelectionActionBar(
                count: _selectedIds.length,
                onUploadToCloud: _bulkUploadToCloud,
                onExport: _bulkShare,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader(DCColors c, String totalGb) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.submissionsTitle,
                style: DCText.inter(
                    size: 28,
                    weight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -0.56),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.submissionsTotal(_recordings.length, totalGb),
                style: DCText.mono(
                    size: 12, weight: FontWeight.w500, color: c.textDim),
              ),
            ],
          ),
        ),
        if (_recordings.isNotEmpty)
          IconButton(
            icon: Icon(Icons.checklist_rounded, color: c.text, size: 22),
            tooltip: l10n.selectMultiple,
            onPressed: () => _enterSelection(),
          ),
        IconButton(
          icon: Icon(Icons.refresh, color: c.text, size: 22),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(DCColors c) {
    final l10n = context.l10n;
    final allSelected =
        _recordings.isNotEmpty && _selectedIds.length == _recordings.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedIds.isEmpty
                    ? l10n.selectRecordings
                    : l10n.selectedCount(_selectedIds.length),
                style: DCText.inter(
                    size: 24,
                    weight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: -0.48),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.selectionHint,
                style: DCText.mono(
                    size: 12, weight: FontWeight.w500, color: c.textDim),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _toggleSelectAll,
          child: Text(
            allSelected ? l10n.clear : l10n.selectAll,
            style: DCText.mono(
                size: 12,
                weight: FontWeight.w600,
                color: c.accent,
                letterSpacing: 1.2),
          ),
        ),
        TextButton(
          onPressed: _exitSelection,
          child: Text(
            l10n.done,
            style: DCText.mono(
                size: 12,
                weight: FontWeight.w600,
                color: c.text,
                letterSpacing: 1.2),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(DCColors c) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.noItems,
                style: DCText.eyebrow(color: c.textDim, size: 11)),
            const SizedBox(height: 8),
            Text(
              l10n.noItemsPrompt,
              textAlign: TextAlign.center,
              style: DCText.inter(
                  size: 13, weight: FontWeight.w500, color: c.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(Recording r) async {
    final l10n = context.l10n;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final queue = context.read<CompressionQueue>();
    try {
      final archivePath = queue.isReady(r.sessionId)
          ? await _manager.exportRecording(r.sessionId)
          : await withExportProgress<String?>(
              context,
              initialMessage: l10n.compressingRecording,
              work: (_) => queue.waitForReady(r.sessionId),
            );
      if (archivePath == null || !mounted) return;
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

  Future<void> _bulkShare() async {
    if (_selectedIds.isEmpty) return;
    final l10n = context.l10n;
    // Snapshot the selection at click-time so updates while we're packing
    // don't affect the in-flight batch.
    final selected =
        _recordings.where((r) => _selectedIds.contains(r.sessionId)).toList();
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final queue = context.read<CompressionQueue>();

    try {
      // Skip the modal entirely when every selected take is already
      // compressed — a fast tap-and-share rhythm shouldn't flash a
      // pointless spinner.
      final allReady = selected.every((r) => queue.isReady(r.sessionId));
      final List<String> paths;
      if (allReady) {
        paths = <String>[];
        for (final r in selected) {
          final p = await _manager.exportRecording(r.sessionId);
          if (p != null) paths.add(p);
        }
      } else {
        paths = await withExportProgress<List<String>>(
          context,
          initialMessage: l10n.compressingProgress(1, selected.length),
          work: (progress) async {
            final results = <String>[];
            for (int i = 0; i < selected.length; i++) {
              progress
                  .update(l10n.compressingProgress(i + 1, selected.length));
              final p = await queue.waitForReady(selected[i].sessionId);
              if (p != null) results.add(p);
            }
            return results;
          },
        );
      }
      if (paths.isEmpty || !mounted) return;
      await Share.shareXFiles(
        paths.map((p) => XFile(p)).toList(),
        subject: l10n.shareSubjectRecordings(paths.length),
        text: l10n.shareTextRecordings,
        sharePositionOrigin: origin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
      if (mounted) _exitSelection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))));
    }
  }

  Future<void> _bulkUploadToCloud() async {
    if (_selectedIds.isEmpty) return;
    final l10n = context.l10n;
    final upload = context.read<UploadController>();
    final queue = context.read<CompressionQueue>();
    final selected =
        _recordings.where((r) => _selectedIds.contains(r.sessionId)).toList();

    try {
      // Ensure archives exist before queueing uploads. The UploadController
      // would fail-fast otherwise; warming the compression queue first means
      // the user sees a single "compressing…" modal instead of a parade of
      // per-recording failure SnackBars.
      final allReady = selected.every((r) => queue.isReady(r.sessionId));
      if (!allReady) {
        await withExportProgress<void>(
          context,
          initialMessage: l10n.compressingProgress(1, selected.length),
          work: (progress) async {
            for (int i = 0; i < selected.length; i++) {
              progress.update(l10n.compressingProgress(i + 1, selected.length));
              await queue.waitForReady(selected[i].sessionId);
            }
          },
        );
      }
      if (!mounted) return;
      upload.enqueueAll(selected);
      _exitSelection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.uploadFailedSnack(e.toString()))));
    }
  }

  Future<void> _delete(Recording r) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecordingTitle),
        content: Text(l10n.deleteRecordingContent(r.sessionId.substring(0, 8))),
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
    await _manager.deleteRecording(r.sessionId);
    await _load();
  }
}

class _SelectionActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onUploadToCloud;
  final VoidCallback onExport;

  const _SelectionActionBar({
    required this.count,
    required this.onUploadToCloud,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    final disabled = count == 0;
    return Container(
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary action: upload to cloud (factory-contractor main path).
                GestureDetector(
                  onTap: disabled ? null : onUploadToCloud,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined,
                            color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          count == 0
                              ? l10n.uploadToCloud.toUpperCase()
                              : l10n.uploadToCloudCount(count),
                          style: DCText.mono(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Secondary action: export via system share sheet (existing
                // flow, kept for users who want to AirDrop / email / Files.app).
                GestureDetector(
                  onTap: disabled ? null : onExport,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ios_share, color: c.text, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          count == 0
                              ? l10n.exportSelected
                              : l10n.exportRecordingCount(count),
                          style: DCText.mono(
                              size: 12,
                              weight: FontWeight.w600,
                              color: c.text,
                              letterSpacing: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  final Recording recording;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RecordingRow({
    required this.recording,
    required this.selectionMode,
    required this.selected,
    required this.onShare,
    required this.onDelete,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? c.accentTint : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RecordingThumbnail(recording: recording, surface: c.surface2),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(recording.durationSeconds),
                          style: DCText.mono(
                              size: 9,
                              weight: FontWeight.w500,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    if (selectionMode)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected
                                ? c.accent
                                : Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                                width: 1.5),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.black)
                              : null,
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
                    localizedRecordingDisplayTitle(recording, l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DCText.inter(
                        size: 14,
                        weight: FontWeight.w600,
                        color: c.text,
                        height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(recording.capturedAt)} · ${recording.fileSizeMB ?? 0} MB',
                    style: DCText.mono(
                        size: 10, weight: FontWeight.w500, color: c.textFaint),
                  ),
                  const SizedBox(height: 6),
                  // Compose: "on device" status badge + cloud upload action +
                  // (optional) compression progress, all on one horizontal
                  // line. Filling the blank space to the right of the status
                  // badge with a tappable upload pill means a one-shot cloud
                  // upload is reachable without entering the detail screen.
                  Row(
                    children: [
                      const DCStatusBadge(status: SubmissionStatus.ondevice),
                      const SizedBox(width: 6),
                      Consumer<UploadController>(
                        builder: (_, upload, __) => _UploadActionPill(
                          entry: upload.entryFor(recording.sessionId),
                          onTap: () => upload.enqueue(recording),
                        ),
                      ),
                      const Spacer(),
                      Consumer<CompressionQueue>(
                        builder: (_, queue, __) {
                          // Compression sub-state only surfaces when the
                          // archive isn't ready — once it is, the on-device
                          // badge already says everything that needs saying.
                          switch (queue.stateOf(recording.sessionId)) {
                            case CompressionState.ready:
                              return const SizedBox.shrink();
                            case CompressionState.failed:
                              return Text('compress failed',
                                  style: DCText.mono(
                                      size: 9,
                                      weight: FontWeight.w500,
                                      color: c.danger,
                                      letterSpacing: 1.2));
                            case CompressionState.compressing:
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5, color: c.accent),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('compressing',
                                      style: DCText.mono(
                                          size: 9,
                                          weight: FontWeight.w500,
                                          color: c.textDim,
                                          letterSpacing: 1.2)),
                                ],
                              );
                            case CompressionState.pending:
                              return Text('queued',
                                  style: DCText.mono(
                                      size: 9,
                                      weight: FontWeight.w500,
                                      color: c.textFaint,
                                      letterSpacing: 1.2));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!selectionMode) ...[
              const SizedBox(width: 8),
              DCIconButton(
                icon: Icons.delete_outline,
                color: c.danger,
                bg: c.danger.withValues(alpha: 0.12),
                onPressed: onDelete,
                semanticLabel: l10n.delete,
              ),
            ],
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

enum _SubmissionFilter {
  all,
  onDevice,
  uploading,
  inReview,
  approved,
  rejected
}

extension _SubmissionFilterLabel on _SubmissionFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      _SubmissionFilter.all => l10n.filterAll,
      _SubmissionFilter.onDevice => l10n.statusOnDevice,
      _SubmissionFilter.uploading => l10n.statusUploading,
      _SubmissionFilter.inReview => l10n.statusInReview,
      _SubmissionFilter.approved => l10n.statusApproved,
      _SubmissionFilter.rejected => l10n.statusRejected,
    };
  }
}

// Tappable inline pill that drives Cloud upload from the list row. Visually
// matches DCStatusBadge (same padding, radius, mono uppercase font, leading
// glyph) so it reads as a sibling to the "on device" badge it sits next to,
// but is interactive in the idle / failed states. While uploading, a
// progress fill animates the pill background.
class _UploadActionPill extends StatelessWidget {
  final UploadEntry entry;
  final VoidCallback onTap;

  const _UploadActionPill({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;

    late final IconData icon;
    late final String label;
    late final Color fg;
    late final Color bg;
    VoidCallback? handler;

    switch (entry.status) {
      case UploadStatus.idle:
        icon = Icons.cloud_upload_outlined;
        label = l10n.uploadShort;
        fg = c.accent;
        bg = c.accentTint;
        handler = onTap;
        break;
      case UploadStatus.queued:
        icon = Icons.schedule;
        label = l10n.uploadQueuedLabel;
        fg = c.textDim;
        bg = c.surface2;
        handler = null;
        break;
      case UploadStatus.uploading:
        icon = Icons.cloud_upload_outlined;
        label = '${(entry.progress * 100).round()}%';
        fg = c.accent;
        bg = c.accentTint;
        handler = null;
        break;
      case UploadStatus.uploaded:
        icon = Icons.cloud_done_outlined;
        label = l10n.uploadedLabel;
        fg = c.accent;
        bg = c.accentTint;
        handler = null;
        break;
      case UploadStatus.failed:
        icon = Icons.refresh;
        label = l10n.uploadRetryShort;
        fg = c.danger;
        bg = c.danger.withValues(alpha: 0.12);
        handler = onTap;
        break;
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      // While uploading, a thin progress bar overlays the bottom edge of the
      // pill so the percent text is reinforced visually. Other states draw
      // only the text/icon row.
      child: Stack(
        children: [
          if (entry.status == UploadStatus.uploading)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FractionallySizedBox(
                  widthFactor: entry.progress.clamp(0.0, 1.0),
                  heightFactor: 0.14,
                  child: Container(color: c.accent.withValues(alpha: 0.55)),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: DCText.mono(
                    size: 10,
                    weight: FontWeight.w600,
                    color: fg,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handler,
      child: pill,
    );
  }
}
