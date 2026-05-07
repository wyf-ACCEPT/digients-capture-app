import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recording.dart';
import '../services/compression_queue.dart';
import '../services/recording_manager.dart';

/// Renders the first-frame thumbnail for [recording] when one is on disk.
/// Falls back to a flat surface color while we wait for generation. Used
/// by both the submissions list and the submission detail header.
///
/// New recordings already have a thumbnail by the time the user lands on
/// any list (record_screen kicks off generation before navigation). Older
/// recordings get caught up by the compression queue's bootstrap pass;
/// this widget watches CompressionQueue so it re-stats and shows the file
/// the moment the catch-up produces it. Lazy-fires a single generation
/// on first build for the rare case of a thumbnail still missing at
/// render time.
class RecordingThumbnail extends StatefulWidget {
  final Recording recording;
  final Color surface;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const RecordingThumbnail({
    super.key,
    required this.recording,
    required this.surface,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  State<RecordingThumbnail> createState() => _RecordingThumbnailState();
}

class _RecordingThumbnailState extends State<RecordingThumbnail> {
  bool _kickedOff = false;

  @override
  Widget build(BuildContext context) {
    // Watch the queue so we re-render once its bootstrap pass produces
    // a thumbnail for a legacy recording.
    context.watch<CompressionQueue>();
    final mgr = RecordingManager();
    final p = mgr.thumbnailPathSync(widget.recording.sessionId);
    if (p != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Image.file(
          File(p),
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: widget.surface),
          gaplessPlayback: true,
        ),
      );
    }
    if (!_kickedOff) {
      _kickedOff = true;
      mgr.ensureThumbnail(widget.recording.sessionId).then((_) {
        if (mounted) setState(() {});
      });
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(color: widget.surface),
    );
  }
}
