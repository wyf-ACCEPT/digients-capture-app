import 'dart:async';

import 'package:flutter/foundation.dart';

import 'recording_manager.dart';

/// Per-recording archive state, derived from disk + this queue's in-memory
/// view of work-in-progress. Authoritative source of truth is the file on
/// disk: `recording_<sid>/archive.tar.gz` exists ⇒ [ready].
enum CompressionState { pending, compressing, ready, failed }

/// Single-worker FIFO that builds tar.gz archives for completed recordings
/// in the background. Started from `_stop()` after a take ends, and from
/// app startup for any recordings that are missing an archive (e.g. the
/// app was killed before the previous build finished, or recordings made
/// before this feature shipped).
///
/// Pauses while a recording is actively in progress so the encoder doesn't
/// have to share CPU with a worker isolate's tar+gzip pass.
class CompressionQueue extends ChangeNotifier {
  CompressionQueue(this._manager);

  final RecordingManager _manager;
  final List<String> _queue = [];
  String? _current;
  bool _paused = false;

  /// In-memory state cache for sessionIds we've touched this session.
  /// `ready` / `failed` are also derivable from disk; this map exists so
  /// listeners can render `compressing` without a stat() per build, and
  /// so `failed` survives within one app session for retry decisions.
  final Map<String, CompressionState> _states = {};
  final Map<String, List<Completer<String?>>> _waiters = {};

  String? get current => _current;
  bool get isPaused => _paused;
  List<String> get pending => List.unmodifiable(_queue);

  /// Live state for [sessionId]. Falls back to a disk check for ready —
  /// the queue itself doesn't track every recording, just ones we've
  /// scheduled or finished this session.
  CompressionState stateOf(String sessionId) {
    if (_current == sessionId) return CompressionState.compressing;
    if (_queue.contains(sessionId)) return CompressionState.pending;
    final cached = _states[sessionId];
    if (cached != null) return cached;
    if (_manager.findArchivePathSync(sessionId) != null) {
      return CompressionState.ready;
    }
    return CompressionState.pending;
  }

  bool isReady(String sessionId) =>
      stateOf(sessionId) == CompressionState.ready;

  bool isProcessing(String sessionId) {
    final s = stateOf(sessionId);
    return s == CompressionState.compressing || s == CompressionState.pending;
  }

  /// Add [sessionId] to the back of the queue if it isn't already in
  /// flight or done. No-op when the archive is already on disk.
  void enqueue(String sessionId) {
    if (_current == sessionId) return;
    if (_queue.contains(sessionId)) return;
    if (_manager.findArchivePathSync(sessionId) != null) {
      _states[sessionId] = CompressionState.ready;
      return;
    }
    _queue.add(sessionId);
    _states[sessionId] = CompressionState.pending;
    notifyListeners();
    _processNext();
  }

  /// Pause the worker. The currently in-flight job (if any) finishes; no
  /// new jobs start until [resume] is called. Used during active
  /// recording.
  void pause() {
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    notifyListeners();
    _processNext();
  }

  /// Resolve when the archive for [sessionId] is on disk. If it's not in
  /// the queue, this enqueues it. Resolves with the archive path, or null
  /// if the build failed.
  Future<String?> waitForReady(String sessionId) async {
    final existing = await _manager.findArchivePath(sessionId);
    if (existing != null) {
      _states[sessionId] = CompressionState.ready;
      return existing;
    }
    final completer = Completer<String?>();
    (_waiters[sessionId] ??= []).add(completer);
    if (!_queue.contains(sessionId) && _current != sessionId) {
      enqueue(sessionId);
    }
    return completer.future;
  }

  /// Bootstrap: scan persisted recordings and enqueue any that don't have
  /// an archive on disk. Call once at app launch so legacy recordings and
  /// recordings whose previous compression was interrupted get caught up
  /// in the background.
  Future<void> enqueueAllMissing() async {
    final recordings = await _manager.loadRecordings();
    for (final r in recordings) {
      final existing = await _manager.findArchivePath(r.sessionId);
      if (existing != null) continue;
      enqueue(r.sessionId);
    }
  }

  Future<void> _processNext() async {
    if (_paused) return;
    if (_current != null) return;
    if (_queue.isEmpty) return;
    final sid = _queue.removeAt(0);
    _current = sid;
    _states[sid] = CompressionState.compressing;
    notifyListeners();
    String? result;
    try {
      result = await _manager.buildArchive(sid);
    } catch (_) {
      result = null;
    }
    _states[sid] =
        result != null ? CompressionState.ready : CompressionState.failed;
    _current = null;
    notifyListeners();
    final waiters = _waiters.remove(sid);
    if (waiters != null) {
      for (final c in waiters) {
        if (!c.isCompleted) c.complete(result);
      }
    }
    if (_queue.isNotEmpty) _processNext();
  }
}
