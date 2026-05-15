import 'dart:async';
import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/recording.dart';
import '../services/compression_queue.dart';
import '../services/upload_service.dart';
import 'auth_controller.dart';

// Per-recording upload status. `idle` is the implicit default for any
// sessionId we haven't touched yet. Pipeline (gated behind one button):
//   idle / failed -> queued -> compressing -> uploading -> finalizing -> uploaded
// `compressing` and `finalizing` carry no byte-level progress; the UI
// renders them as spinner+label so the user knows the App is working
// even though the percent isn't moving.
enum UploadStatus {
  idle,
  queued,
  compressing,
  uploading,
  finalizing,
  uploaded,
  failed,
}

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
    required CompressionQueue compression,
    required AuthController auth,
    FlutterSecureStorage? storage,
  })  : _service = service,
        _compression = compression,
        _auth = auth,
        _storage = storage ?? const FlutterSecureStorage();

  // Restore the persisted "already uploaded" set from secure storage. Call
  // once at App startup before runApp so the first frame already reflects
  // remembered state and we don't briefly show idle pills for known-uploaded
  // recordings.
  //
  // Phase C also drives cold-start recovery here:
  //   1. Enable background_downloader's persistent task DB (idempotent
  //      across calls) so allTasks / recordForId can see tasks queued in
  //      a previous app session.
  //   2. Restore the `uploaded` set from secure storage (original behavior).
  //   3. Ask UploadService.recoverPendingCompletes() to retry /complete for
  //      any upload whose S3 PUT finished while the app was killed but
  //      whose /complete call never landed. Recovered sessionIds are also
  //      folded into the uploaded set so the UI reflects them.
  Future<void> hydrate() async {
    try {
      await FileDownloader().trackTasks();
    } catch (e) {
      // Not fatal — trackTasks failing only means we lose recovery on
      // a subsequent cold start. Don't block hydrate.
      debugPrint('[UploadController] trackTasks failed: $e');
    }

    var changed = false;
    try {
      final raw = await _storage.read(key: _persistKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final id in decoded) {
            if (id is! String || id.isEmpty) continue;
            _entries[id] = const UploadEntry(
              status: UploadStatus.uploaded,
              progress: 1.0,
            );
            changed = true;
          }
        }
      }
    } catch (e) {
      debugPrint('[UploadController] hydrate uploaded-set failed: $e');
    }

    try {
      final recovered =
          await _service.recoverPendingCompletes(_auth.getFreshAccessToken);
      for (final sid in recovered) {
        _entries[sid] = const UploadEntry(
          status: UploadStatus.uploaded,
          progress: 1.0,
        );
        changed = true;
      }
      if (recovered.isNotEmpty) {
        // Fold the recovered ids into the persisted uploaded set so the
        // next cold start doesn't need to re-recover.
        // ignore: unawaited_futures
        _persistUploaded();
      }
    } catch (e) {
      debugPrint('[UploadController] hydrate recoverPendingCompletes failed: $e');
    }

    if (changed) notifyListeners();
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
    if (current == UploadStatus.queued ||
        current == UploadStatus.compressing ||
        current == UploadStatus.uploading ||
        current == UploadStatus.finalizing ||
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
      if (current == UploadStatus.queued ||
          current == UploadStatus.compressing ||
          current == UploadStatus.uploading ||
          current == UploadStatus.finalizing ||
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
    _reconcileWakelock();
    // Initial in-flight status is `compressing`: we now build the archive
    // on demand inside _start rather than relying on a pre-built one. If
    // it happens to already be on disk, _start will fast-path through
    // this stage in milliseconds.
    _entries[next] = const UploadEntry(
      status: UploadStatus.compressing,
      progress: 0,
    );
    notifyListeners();
    _start(recording);
  }

  // Keep the screen awake while any upload is in flight. iOS's default
  // URLSession (what dio rides on) is killed seconds after the app goes
  // into background — auto screen-lock counts as "background" and was the
  // top cause of failed multi-GB uploads in Dylan's factory testing.
  // This wakelock prevents the *idle timer* from firing; it does NOT stop
  // the user from manually locking the screen or switching apps. The
  // durable fix is Tier 2 (background URLSession via background_downloader)
  // tracked in .claude/plan/6e15-plan-background-upload.md.
  // Idempotent — multiple enable/disable calls collapse to the right state.
  void _reconcileWakelock() {
    final shouldHold = _current != null;
    () async {
      try {
        if (shouldHold) {
          await WakelockPlus.enable();
        } else {
          await WakelockPlus.disable();
        }
      } catch (e) {
        debugPrint('[UploadController] wakelock toggle failed: $e');
      }
    }();
  }

  Future<void> _start(Recording recording) async {
    final sid = recording.sessionId;

    if (_auth.session == null) {
      _finishFailure(sid, 'Not signed in');
      return;
    }

    // Stage 1: build the archive if it isn't on disk yet. `waitForReady`
    // enqueues the recording into the single-worker CompressionQueue and
    // resolves with the archive path once the worker isolate finishes.
    // We don't expose a byte-level percent here (the tar+gzip isolate
    // doesn't report progress); the UI shows a spinner labelled "压缩中".
    final String archive;
    try {
      final result = await _compression.waitForReady(sid);
      if (result == null) {
        _finishFailure(sid, 'Compression failed');
        return;
      }
      archive = result;
    } catch (e) {
      _finishFailure(sid, 'Compression error: $e');
      return;
    }

    // Stage 2: upload. Flip to `uploading` with a fresh 0% baseline so the
    // pill goes spinner -> progress bar at the right moment.
    if (_current != sid) return; // Cancelled / superseded; bail.
    _entries[sid] = const UploadEntry(
      status: UploadStatus.uploading,
      progress: 0,
    );
    notifyListeners();

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
              // `finalizing` is the service's signal that the byte stream
              // closed and /complete is in flight (cross-region D1 update
              // can take 1-3s). Render a spinner so the user knows we
              // aren't hung at 100%.
              final status = p.phase == UploadPhase.finalizing
                  ? UploadStatus.finalizing
                  : UploadStatus.uploading;
              _entries[sid] = UploadEntry(
                status: status,
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
              // Stream may close from either `uploading` (server 409 dedup
              // short-circuit) or `finalizing` (normal happy path after
              // /complete returns).
              final st = entryFor(sid).status;
              if (st == UploadStatus.uploading ||
                  st == UploadStatus.finalizing) {
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
    _reconcileWakelock();
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
    _reconcileWakelock();
    notifyListeners();
    _pump();
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    // Best-effort release on teardown — don't strand a held wakelock if the
    // controller is disposed mid-upload (e.g., app shutting down).
    // ignore: unawaited_futures
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }
}
