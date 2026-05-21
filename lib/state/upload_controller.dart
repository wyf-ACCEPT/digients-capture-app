import 'dart:async';
import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../fixtures/data.dart' show sceneMinorFromTaskId;
import '../models/recording.dart';
import '../services/recording_manager.dart';
import '../services/upload_service.dart';
import 'auth_controller.dart';

// Per-recording upload status. `idle` is the implicit default for any
// sessionId we haven't touched yet. Under the /v2 multi-file pipeline
// (plan 6e19) the flow is:
//   idle / failed -> queued -> uploading -> finalizing -> uploaded
// The old `compressing` stage is gone — we no longer build a tar.gz on
// the upload path. `finalizing` is a no-percent sentinel emitted by the
// service after the last PUT lands while the trailing /complete?file=
// round-trip is in flight.
enum UploadStatus {
  idle,
  queued,
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

// Orchestrates uploads of completed recordings to the digients-api
// backend.
//
// `uploaded` sessionIds are persisted to secure storage so the App can
// remember across cold launches which recordings already shipped —
// without this, the row pill flips back to idle after every restart and
// the user re-triggers an upload that the server then has to dedup. The
// server-side dedup in /v2/submissions/init is the source of truth; this
// cache just keeps the UI honest and avoids a wasted round-trip per
// stale recording.
//
// Concurrency: one upload at a time. Bulk requests queue serially. The
// rationale is bandwidth fairness on a phone tethered to factory Wi-Fi —
// running two large PUTs in parallel mostly just halves each one's speed
// while doubling failure surface.
class UploadController extends ChangeNotifier {
  static const _persistKey = 'upload_controller.uploaded_session_ids';

  final UploadService _service;
  final RecordingManager _manager;
  final AuthController _auth;
  final FlutterSecureStorage _storage;

  final Map<String, UploadEntry> _entries = {};
  final Map<String, Recording> _pending = {};
  final List<String> _queue = [];
  String? _current;
  StreamSubscription<UploadProgress>? _activeSub;

  UploadController({
    required UploadService service,
    required RecordingManager manager,
    required AuthController auth,
    FlutterSecureStorage? storage,
  })  : _service = service,
        _manager = manager,
        _auth = auth,
        _storage = storage ?? const FlutterSecureStorage();

  // Restore the persisted "already uploaded" set from secure storage.
  // Call once at App startup before runApp so the first frame already
  // reflects remembered state and we don't briefly show idle pills for
  // known-uploaded recordings.
  //
  // Also drives cold-start recovery:
  //   1. Enable background_downloader's persistent task DB (idempotent
  //      across calls) so allTasks / recordForId can see tasks queued
  //      in a previous app session.
  //   2. Restore the `uploaded` set from secure storage.
  //   3. Ask UploadService.recoverPendingCompletes() to retry
  //      /complete?file=<kind> for any per-file PUT that finished while
  //      the app was killed but whose /complete call never landed.
  //      Recovered sessionIds (= all per-file entries resolved) are
  //      folded into the uploaded set.
  Future<void> hydrate() async {
    try {
      await FileDownloader().trackTasks();
    } catch (e) {
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
        // ignore: unawaited_futures
        _persistUploaded();
        // Best-effort post-recovery cleanup so resurrected uploads
        // shed their originals like a happy-path completion would.
        for (final sid in recovered) {
          // ignore: unawaited_futures
          _manager.cleanupOriginalsAfterUpload(sid);
        }
      }
    } catch (e) {
      debugPrint(
          '[UploadController] hydrate recoverPendingCompletes failed: $e');
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

  // Queue [recording] for upload. No-op if it's already in flight,
  // queued, or already uploaded. A previously-failed recording can be
  // re-queued — that's the retry path.
  void enqueue(Recording recording) {
    final sid = recording.sessionId;
    final current = entryFor(sid).status;
    if (current == UploadStatus.queued ||
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

  // Reset a failed recording back to idle so the UI can re-offer the
  // upload button. Used when the user dismisses an error without
  // retrying.
  void clearError(String sessionId) {
    if (entryFor(sessionId).status != UploadStatus.failed) return;
    _entries.remove(sessionId);
    notifyListeners();
  }

  // Cancel any in-flight upload for [sessionId] and wipe all controller-
  // side state for it. Called when the user deletes the recording from
  // disk — files are about to disappear, so leaving the background
  // tasks pointed at the (soon to be) missing files would just generate
  // noise. Idempotent.
  //
  // Order of operations:
  //   1. If this sid is currently uploading, cancel the active stream
  //      sub and release wakelock if it's the last in-flight upload.
  //   2. Ask UploadService to cancel its per-file background tasks for
  //      this sid (under /v2 that's up to 4 tasks).
  //   3. Clear all pending-complete markers for this sid so a future
  //      hydrate doesn't try to replay /complete for a canceled upload.
  //   4. Wipe our local entry + queue tracking + persist. If the sid
  //      was in the `uploaded` set, remove it from there too — the user
  //      deleted the recording, so we don't owe them a "remembered as
  //      uploaded" marker either.
  Future<void> cancel(String sessionId) async {
    final wasCurrent = _current == sessionId;

    _queue.remove(sessionId);
    _pending.remove(sessionId);
    final hadEntry = _entries.remove(sessionId) != null;

    if (wasCurrent) {
      await _activeSub?.cancel();
      _activeSub = null;
      _current = null;
      _reconcileWakelock();
    }

    try {
      await _service.cancelInFlight(sessionId);
    } catch (e) {
      debugPrint('[UploadController] cancelInFlight($sessionId) failed: $e');
    }

    try {
      await _service.clearPendingComplete(sessionId);
    } catch (e) {
      debugPrint('[UploadController] clearPendingComplete failed: $e');
    }

    if (hadEntry) {
      // ignore: unawaited_futures
      _persistUploaded();
      notifyListeners();
    }

    if (wasCurrent) {
      _pump();
    }
  }

  void _pump() {
    if (_current != null) return;
    if (_queue.isEmpty) return;
    final next = _queue.removeAt(0);
    final recording = _pending.remove(next);
    if (recording == null) {
      _pump();
      return;
    }
    _current = next;
    _reconcileWakelock();
    // Skip straight to `uploading`. Under /v2 there's no compression
    // step on the upload path — the 4 source files go straight to S3.
    _entries[next] = const UploadEntry(
      status: UploadStatus.uploading,
      progress: 0,
    );
    notifyListeners();
    _start(recording);
  }

  // Keep the screen awake while any upload is in flight. The
  // background_downloader plugin survives lock screen on iOS via
  // nsurlsessiond, but holding the wakelock is still cheap insurance
  // against jetsam pressure on low-RAM devices.
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

    // Make sure the thumbnail is on disk — the backend requires all 4
    // file slots to flip the submission to `queued`, and there's no
    // mid-flight retry path if thumbnail generation fails after the
    // other 3 files have already been ack'd.
    try {
      final thumb = await _manager.ensureThumbnail(sid);
      if (thumb == null) {
        _finishFailure(sid, 'Failed to generate thumbnail');
        return;
      }
    } catch (e) {
      _finishFailure(sid, 'Thumbnail error: $e');
      return;
    }

    final String recordingDir;
    try {
      recordingDir = await _manager.recordingDirFor(sid);
    } catch (e) {
      _finishFailure(sid, 'Recording dir lookup failed: $e');
      return;
    }

    if (_current != sid) return; // Cancelled / superseded; bail.

    final durationSec = (recording.durationSeconds ?? 0).toDouble();

    // WF2 (plan 6e20) scene tags. categoryId on Recording is the major
    // slug; sceneMinorFromTaskId strips the `<major>-` prefix from the
    // composite task id (e.g. `kitchen-cook` -> `cook`). When either is
    // missing (older recordings made before the catalog was wired through),
    // pass null and let the backend fall back to the pre-WF2 layout.
    final sceneMajor =
        (recording.categoryId != null && recording.categoryId!.isNotEmpty)
            ? recording.categoryId
            : null;
    final sceneMinor = sceneMinorFromTaskId(recording.taskId, sceneMajor);

    try {
      _activeSub = _service
          .upload(
            sessionId: sid,
            recordingDir: recordingDir,
            durationSec: durationSec,
            getAccessToken: _auth.getFreshAccessToken,
            sceneMajor: sceneMajor,
            sceneMinor: sceneMinor,
          )
          .listen(
            (p) {
              // `finalizing` is the service's signal that the byte stream
              // closed and the trailing /complete is in flight. Render a
              // spinner so the user knows we aren't hung at 100%.
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
    // Drop the loose source files now that S3 has the canonical copy.
    // The thumbnail stays for the submissions-list card preview.
    // ignore: unawaited_futures
    _manager.cleanupOriginalsAfterUpload(sessionId);
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
    // ignore: unawaited_futures
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }
}
