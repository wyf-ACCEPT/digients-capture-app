import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/recording.dart';
import '../services/compression_queue.dart';
import '../services/recording_manager.dart';
import '../services/upload_service.dart';
import 'auth_controller.dart';

// Per-recording upload status. `idle` is the implicit default for any
// sessionId we haven't touched yet.
enum UploadStatus { idle, queued, uploading, uploaded, failed }

class UploadEntry {
  final UploadStatus status;
  final double progress; // 0..1 — meaningful when status == uploading
  final String? errorMessage;

  const UploadEntry({
    required this.status,
    this.progress = 0,
    this.errorMessage,
  });

  static const idle = UploadEntry(status: UploadStatus.idle);
}

// Orchestrates uploads of completed recordings to the digients-api backend.
//
// `uploaded` sessionIds are persisted to secure storage so the App can
// remember across cold launches which recordings already shipped — without
// this, the row pill flips back to idle after every restart and the user
// re-triggers an upload that the server then has to dedup. The server-side
// dedup in /v1/submissions/init is the source of truth; this cache just
// keeps the UI honest and avoids a wasted round-trip per stale recording.
//
// Concurrency: one upload at a time. Bulk requests queue serially. The
// rationale is bandwidth fairness on a phone tethered to factory Wi-Fi —
// running two large PUTs in parallel mostly just halves each one's speed
// while doubling failure surface.
class UploadController extends ChangeNotifier {
  static const _persistKey = 'upload_controller.uploaded_session_ids';

  final UploadService _service;
  final RecordingManager _recordings;
  final CompressionQueue _compression;
  final AuthController _auth;
  final FlutterSecureStorage _storage;

  final Map<String, UploadEntry> _entries = {};
  final Map<String, Recording> _pending = {};
  final List<String> _queue = [];
  String? _current;
  StreamSubscription<UploadProgress>? _activeSub;

  UploadController({
    required UploadService service,
    required RecordingManager recordings,
    required CompressionQueue compression,
    required AuthController auth,
    FlutterSecureStorage? storage,
  })  : _service = service,
        _recordings = recordings,
        _compression = compression,
        _auth = auth,
        _storage = storage ?? const FlutterSecureStorage();

  // Restore the persisted "already uploaded" set from secure storage. Call
  // once at App startup before runApp so the first frame already reflects
  // remembered state and we don't briefly show idle pills for known-uploaded
  // recordings.
  Future<void> hydrate() async {
    try {
      final raw = await _storage.read(key: _persistKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      var changed = false;
      for (final id in decoded) {
        if (id is! String || id.isEmpty) continue;
        _entries[id] = const UploadEntry(
          status: UploadStatus.uploaded,
          progress: 1.0,
        );
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('[UploadController] hydrate failed: $e');
    }
  }

  Future<void> _persistUploaded() async {
    final ids = _entries.entries
        .where((e) => e.value.status == UploadStatus.uploaded)
        .map((e) => e.key)
        .toList(growable: false);
    try {
      await _storage.write(key: _persistKey, value: jsonEncode(ids));
    } catch (e) {
      debugPrint('[UploadController] persist failed: $e');
    }
  }

  UploadEntry entryFor(String sessionId) =>
      _entries[sessionId] ?? UploadEntry.idle;
  UploadStatus statusOf(String sessionId) => entryFor(sessionId).status;
  double progressOf(String sessionId) => entryFor(sessionId).progress;

  bool get isAnyUploading => _current != null;
  String? get currentSessionId => _current;
  int get queuedCount => _queue.length + (_current != null ? 1 : 0);

  // Queue [recording] for upload. No-op if it's already in flight, queued,
  // or already uploaded. A previously-failed recording can be re-queued —
  // that's the retry path.
  void enqueue(Recording recording) {
    final sid = recording.sessionId;
    final current = entryFor(sid).status;
    if (current == UploadStatus.uploading ||
        current == UploadStatus.queued ||
        current == UploadStatus.uploaded) {
      return;
    }
    _entries[sid] = const UploadEntry(status: UploadStatus.queued);
    _pending[sid] = recording;
    _queue.add(sid);
    notifyListeners();
    _pump();
  }

  // Enqueue a whole batch in one go, preserving caller order.
  void enqueueAll(Iterable<Recording> recordings) {
    var changed = false;
    for (final r in recordings) {
      final sid = r.sessionId;
      final current = entryFor(sid).status;
      if (current == UploadStatus.uploading ||
          current == UploadStatus.queued ||
          current == UploadStatus.uploaded) {
        continue;
      }
      _entries[sid] = const UploadEntry(status: UploadStatus.queued);
      _pending[sid] = r;
      _queue.add(sid);
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _pump();
    }
  }

  // Reset a failed recording back to idle so the UI can re-offer the upload
  // button. Used when the user dismisses an error without retrying.
  void clearError(String sessionId) {
    if (entryFor(sessionId).status != UploadStatus.failed) return;
    _entries.remove(sessionId);
    notifyListeners();
  }

  void _pump() {
    if (_current != null) return;
    if (_queue.isEmpty) return;
    final next = _queue.removeAt(0);
    final recording = _pending.remove(next);
    if (recording == null) {
      // Shouldn't happen — pending is populated alongside the queue.
      _pump();
      return;
    }
    _current = next;
    _entries[next] = const UploadEntry(
      status: UploadStatus.uploading,
      progress: 0,
    );
    notifyListeners();
    _start(recording);
  }

  Future<void> _start(Recording recording) async {
    final sid = recording.sessionId;

    // The archive must exist on disk before we can upload it.
    final archive = _recordings.findArchivePathSync(sid);
    if (archive == null) {
      final compState = _compression.stateOf(sid);
      final hint = compState == CompressionState.compressing ||
              compState == CompressionState.pending
          ? ' (still compressing — try again in a moment)'
          : '';
      _finishFailure(sid, 'Archive not built yet$hint');
      return;
    }

    if (_auth.session == null) {
      _finishFailure(sid, 'Not signed in');
      return;
    }

    final sizeBytes = ((recording.fileSizeMB ?? 0) * 1024 * 1024).round();
    final durationSec = (recording.durationSeconds ?? 0).toDouble();

    try {
      _activeSub = _service
          .upload(
            sessionId: sid,
            archivePath: archive,
            sizeBytes: sizeBytes,
            durationSec: durationSec,
            // The service pulls a fresh JWT immediately before each /init
            // and /complete, so a long PUT can't strand the upload behind
            // an expired access token.
            getAccessToken: _auth.getFreshAccessToken,
          )
          .listen(
            (p) {
              _entries[sid] = UploadEntry(
                status: UploadStatus.uploading,
                progress: p.fraction,
              );
              notifyListeners();
            },
            onError: (Object e) {
              _finishFailure(sid, e.toString());
            },
            onDone: () {
              // If the stream closes after an error we've already finalized
              // the entry; don't overwrite the failure state with success.
              if (entryFor(sid).status == UploadStatus.uploading) {
                _finishSuccess(sid);
              }
            },
            cancelOnError: true,
          );
    } catch (e) {
      _finishFailure(sid, e.toString());
    }
  }

  void _finishSuccess(String sessionId) {
    _entries[sessionId] = const UploadEntry(
      status: UploadStatus.uploaded,
      progress: 1.0,
    );
    _activeSub = null;
    _current = null;
    notifyListeners();
    // ignore: unawaited_futures
    _persistUploaded();
    _pump();
  }

  void _finishFailure(String sessionId, String message) {
    _entries[sessionId] = UploadEntry(
      status: UploadStatus.failed,
      errorMessage: message,
    );
    _activeSub = null;
    _current = null;
    notifyListeners();
    _pump();
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    super.dispose();
  }
}
