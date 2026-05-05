import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chips.dart';
import '../../widgets/export_progress.dart';
import '../../services/compression_queue.dart';
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
                        ? _buildEmpty(c)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: c.accent,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16, 4, 16, _selectionMode ? 110 : 24,
                              ),
                              itemCount: _recordings.length,
                              itemBuilder: (_, i) {
                                final r = _recordings[i];
                                final selected = _selectedIds.contains(r.sessionId);
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
                                        context.push('/submissions/${r.sessionId}');
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
                onExport: _bulkShare,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader(DCColors c, String totalGb) {
    return Row(
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
        if (_recordings.isNotEmpty)
          IconButton(
            icon: Icon(Icons.checklist_rounded, color: c.text, size: 22),
            tooltip: 'Select multiple',
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
                    ? 'Select recordings'
                    : '${_selectedIds.length} selected',
                style: DCText.inter(size: 24, weight: FontWeight.w700, color: c.text, letterSpacing: -0.48),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to toggle · long-press a row to start',
                style: DCText.mono(size: 12, weight: FontWeight.w500, color: c.textDim),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _toggleSelectAll,
          child: Text(
            allSelected ? 'Clear' : 'Select all',
            style: DCText.mono(size: 12, weight: FontWeight.w600, color: c.accent, letterSpacing: 1.2),
          ),
        ),
        TextButton(
          onPressed: _exitSelection,
          child: Text(
            'Done',
            style: DCText.mono(size: 12, weight: FontWeight.w600, color: c.text, letterSpacing: 1.2),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(DCColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NO ITEMS', style: DCText.eyebrow(color: c.textDim, size: 11)),
            const SizedBox(height: 8),
            Text(
              'Tap a category from Home to start recording.',
              textAlign: TextAlign.center,
              style: DCText.inter(size: 13, weight: FontWeight.w500, color: c.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(Recording r) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final queue = context.read<CompressionQueue>();
    try {
      final archivePath = queue.isReady(r.sessionId)
          ? await _manager.exportRecording(r.sessionId)
          : await withExportProgress<String?>(
              context,
              initialMessage: 'Compressing recording…',
              work: (_) => queue.waitForReady(r.sessionId),
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

  Future<void> _bulkShare() async {
    if (_selectedIds.isEmpty) return;
    final selected = _recordings
        .where((r) => _selectedIds.contains(r.sessionId))
        .toList();
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final queue = context.read<CompressionQueue>();

    try {
      // Skip the modal entirely when every selected take is already
      // compressed — a fast tap-and-share rhythm shouldn't flash a
      // pointless spinner.
      final allReady =
          selected.every((r) => queue.isReady(r.sessionId));
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
          initialMessage: 'Compressing 1 of ${selected.length}…',
          work: (progress) async {
            final results = <String>[];
            for (int i = 0; i < selected.length; i++) {
              progress.update('Compressing ${i + 1} of ${selected.length}…');
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
        subject: 'Egocentric Video Recordings (${paths.length})',
        text: 'Egocentric video recording data packages',
        sharePositionOrigin: origin ?? const Rect.fromLTWH(0, 0, 1, 1),
      );
      if (mounted) _exitSelection();
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

class _SelectionActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onExport;

  const _SelectionActionBar({required this.count, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
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
            child: GestureDetector(
              onTap: disabled ? null : onExport,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      count == 0
                          ? 'EXPORT SELECTED'
                          : 'EXPORT $count RECORDING${count > 1 ? 'S' : ''}',
                      style: DCText.mono(size: 13, weight: FontWeight.w700, color: Colors.black, letterSpacing: 1.4),
                    ),
                  ],
                ),
              ),
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
                    if (selectionMode)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected ? c.accent : Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 14, color: Colors.black)
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
                  Consumer<CompressionQueue>(
                    builder: (_, queue, __) {
                      // Surface compression progress on the same row that
                      // hosts the share button. ondevice status is still
                      // the canonical "where this take lives" badge —
                      // shown as soon as the archive is ready or not at
                      // all if the queue keeps moving.
                      switch (queue.stateOf(recording.sessionId)) {
                        case CompressionState.ready:
                          return const DCStatusBadge(status: SubmissionStatus.ondevice);
                        case CompressionState.failed:
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const DCStatusBadge(status: SubmissionStatus.ondevice),
                              const SizedBox(width: 6),
                              Text('compress failed',
                                  style: DCText.mono(
                                      size: 9,
                                      weight: FontWeight.w500,
                                      color: c.danger,
                                      letterSpacing: 1.2)),
                            ],
                          );
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
                          return Text('queued for compression',
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
            ),
            if (!selectionMode) ...[
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
