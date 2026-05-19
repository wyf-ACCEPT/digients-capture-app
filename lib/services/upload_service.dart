import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'device_id_service.dart';

// Client surface for the v2 multi-file upload pipeline
// (digients-api /v2/submissions).
//
// Replaces the v1 tar.gz-bundled flow with a 4-file direct-PUT pipeline:
//   1. POST /v2/submissions/init with {session_id, device_uuid, device_model}
//      -> returns submission_id + 4 pre-signed S3 PUT URLs (one per kind:
//      video, metadata, motion, thumbnail). A url is `null` when the
//      backend has already ack'd that file (server-side dedup on retry).
//   2. PUT each file body to its URL in series. We serialize on purpose so
//      a single phone's uplink isn't divided four ways — video alone is
//      ~99% of the bytes anyway.
//   3. After each PUT completes, POST
//      /v2/submissions/<id>/complete?file=<kind> with {size_bytes,
//      duration_sec} to mark that file ack'd. The backend flips status
//      uploading -> queued only once all 4 columns are NOT NULL.
//
// UI code talks only to UploadService, so we can swap Mock <-> Http via
// --dart-define=UPLOAD_BACKEND=mock|http exactly like AuthService.
//
// Each call returns a [Stream<UploadProgress>] that emits a combined,
// byte-weighted progress fraction across all 4 files. The stream
// terminates with done() on success or addError() on failure.

// The 4 files that make up a single recording submission. Order in this
// list is also the upload order — keep video first so the user sees the
// big bar move right away (it's ~99% of the bytes).
enum FileKind { video, metadata, motion, thumbnail }

const List<FileKind> _kFileKinds = [
  FileKind.video,
  FileKind.metadata,
  FileKind.motion,
  FileKind.thumbnail,
];

extension FileKindExt on FileKind {
  String get wireName {
    switch (this) {
      case FileKind.video:
        return 'video';
      case FileKind.metadata:
        return 'metadata';
      case FileKind.motion:
        return 'motion';
      case FileKind.thumbnail:
        return 'thumbnail';
    }
  }

  String get filename {
    switch (this) {
      case FileKind.video:
        return 'video.mp4';
      case FileKind.metadata:
        return 'metadata.json';
      case FileKind.motion:
        return 'motion.jsonl';
      case FileKind.thumbnail:
        return 'thumbnail.jpg';
    }
  }

  // Must match digients-api/src/lib/s3.ts CONTENT_TYPE_BY_KIND exactly —
  // SigV4 verification on S3 fails if the PUT Content-Type doesn't match
  // what was signed at /v2/init time.
  String get contentType {
    switch (this) {
      case FileKind.video:
        return 'video/mp4';
      case FileKind.metadata:
        return 'application/json';
      case FileKind.motion:
        return 'application/x-ndjson';
      case FileKind.thumbnail:
        return 'image/jpeg';
    }
  }
}

FileKind? _fileKindFromWire(String s) {
  for (final k in _kFileKinds) {
    if (k.wireName == s) return k;
  }
  return null;
}

// Where in the multi-stage upload pipeline a given progress event was
// emitted. `uploading` carries a byte-weighted fraction across all 4
// files; `finalizing` is a no-percent sentinel meaning the last PUT has
// landed and we're waiting on the trailing /complete round-trip.
enum UploadPhase { uploading, finalizing }

class UploadProgress {
  final double fraction;
  final int bytesSent;
  final int bytesTotal;
  final UploadPhase phase;

  const UploadProgress({
    required this.fraction,
    required this.bytesSent,
    required this.bytesTotal,
    this.phase = UploadPhase.uploading,
  });

  @override
  String toString() =>
      'UploadProgress(${phase.name}, ${(fraction * 100).toStringAsFixed(1)}%, $bytesSent/$bytesTotal)';
}

class UploadException implements Exception {
  final String message;
  final String? code;

  UploadException(this.message, {this.code});

  @override
  String toString() => 'UploadException($code): $message';
}

// Callback the service uses each time it needs an access token. We don't
// take a token by value because uploads can run long (10+ min on slow
// links) — by the time `complete` fires, the 15-minute access token
// captured at upload-start may have expired. The callback resolves to a
// fresh token each call, so the implementation can auto-refresh
// transparently.
typedef AccessTokenProvider = Future<String> Function();

abstract class UploadService {
  // Streams progress events while the upload is in flight; closes
  // normally on success and emits an [UploadException] via addError on
  // failure. [recordingDir] holds the 4 source files
  // (video.mp4 / metadata.json / motion.jsonl / thumbnail.jpg); the
  // thumbnail is required (caller must ensureThumbnail before calling).
  Stream<UploadProgress> upload({
    required String sessionId,
    required String recordingDir,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  });

  // Cold-start recovery: replay /complete for any (sessionId, fileKind)
  // whose S3 PUT succeeded (background_downloader reports
  // `TaskStatus.complete`) but whose follow-up /complete?file=<kind>
  // never landed — typically because the App was killed in the narrow
  // window between PUT returning and /complete being invoked.
  //
  // Returns sessionIds that were fully recovered (all 4 file acks
  // replayed), so UploadController.hydrate can flip them to `uploaded`.
  Future<List<String>> recoverPendingCompletes(
      AccessTokenProvider getAccessToken);

  // Drop any persisted pending-complete markers for [sessionId]. Used
  // when the user deletes a recording while its upload is in flight —
  // the caller will cancel background tasks separately.
  Future<void> clearPendingComplete(String sessionId);

  // Cancel any in-flight background_downloader tasks for [sessionId].
  // Per-file taskIds are an implementation detail of HttpUploadService;
  // wrapping the cancel here keeps callers (UploadController) ignorant
  // of how many tasks back a single session.
  Future<void> cancelInFlight(String sessionId);
}

// In-memory fake. Walks 0% -> 100% across `_durationMs` and either
// completes or fails depending on `_failureRate`. Used by Jason to drive
// UX iteration in the simulator/device before the real Http
// implementation is wired.
class MockUploadService implements UploadService {
  final Duration _duration;
  final double _failureRate;
  final int _tickCount;
  final Random _rng;

  MockUploadService({
    Duration duration = const Duration(seconds: 6),
    double failureRate = 0.15,
    int tickCount = 30,
    Random? rng,
  })  : _duration = duration,
        _failureRate = failureRate.clamp(0.0, 1.0),
        _tickCount = tickCount,
        _rng = rng ?? Random();

  @override
  Stream<UploadProgress> upload({
    required String sessionId,
    required String recordingDir,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  }) {
    final controller = StreamController<UploadProgress>();
    final tickInterval = Duration(
      microseconds: (_duration.inMicroseconds / _tickCount).round(),
    );
    final willFail = _rng.nextDouble() < _failureRate;
    final failAtTick = willFail
        ? (_tickCount * (0.2 + _rng.nextDouble() * 0.6)).round()
        : -1;

    // Pretend the take is ~1.5 GB for the mock progress display.
    const fakeTotal = 1500 * 1024 * 1024;

    var tick = 0;
    Timer.periodic(tickInterval, (t) {
      tick++;
      if (tick == failAtTick) {
        t.cancel();
        controller.addError(
          UploadException(
            'Mock network error at ${(tick / _tickCount * 100).toStringAsFixed(0)}%',
            code: 'mock_network',
          ),
        );
        controller.close();
        return;
      }
      final fraction = (tick / _tickCount).clamp(0.0, 1.0);
      controller.add(UploadProgress(
        fraction: fraction,
        bytesSent: (fakeTotal * fraction).round(),
        bytesTotal: fakeTotal,
      ));
      if (tick >= _tickCount) {
        t.cancel();
        controller.close();
      }
    });

    return controller.stream;
  }

  @override
  Future<List<String>> recoverPendingCompletes(
          AccessTokenProvider getAccessToken) async =>
      const <String>[];

  @override
  Future<void> clearPendingComplete(String sessionId) async {}

  @override
  Future<void> cancelInFlight(String sessionId) async {}
}

// Routing slot for a single in-flight S3 PUT. The HttpUploadService
// singleton listener on `FileDownloader().updates` keys events by taskId
// (which is "<sessionId>:<wireName>") and dispatches to the matching
// entry's completer / onProgress.
class _ActiveTask {
  final Completer<void> completer;
  final void Function(double fraction) onProgress;
  _ActiveTask({required this.completer, required this.onProgress});
}

class HttpUploadService implements UploadService {
  // Per-file pending-complete map: `{ "<sid>:<wireName>": submissionId }`.
  // We persist BEFORE each PUT enqueues so a cold start can match the
  // background_downloader task record back to a submission id and replay
  // /complete?file=<kind>. Entries are removed once the matching
  // /complete returns 2xx.
  static const _pendingCompleteKey = 'upload_service.pending_complete_v2';

  final String baseUrl;
  final DeviceIdService _deviceId;
  final http.Client _client;
  final Duration _controlTimeout;
  final FlutterSecureStorage _secureStorage;

  // Per-taskId state for in-flight S3 PUTs, plus the single subscription
  // that fans events out. `FileDownloader().updates` is backed by a
  // non-broadcast StreamController, so listening per upload would crash
  // on the second attempt with "Bad state: Stream has already been
  // listened to". One service-wide listener matches the plugin's
  // intended usage pattern.
  final Map<String, _ActiveTask> _activeTasks = {};
  StreamSubscription<TaskUpdate>? _updatesSub;

  HttpUploadService({
    required this.baseUrl,
    required DeviceIdService deviceId,
    http.Client? client,
    Duration controlTimeout = const Duration(seconds: 30),
    FlutterSecureStorage? secureStorage,
  })  : _deviceId = deviceId,
        _client = client ?? http.Client(),
        _controlTimeout = controlTimeout,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  void _ensureUpdatesListener() {
    if (_updatesSub != null) return;
    _updatesSub = FileDownloader().updates.listen((update) {
      final taskId = update.task.taskId;
      final active = _activeTasks[taskId];
      if (active == null) return; // foreign task or already resolved
      if (update is TaskProgressUpdate) {
        final fraction = update.progress.clamp(0.0, 1.0);
        active.onProgress(fraction);
      } else if (update is TaskStatusUpdate) {
        if (active.completer.isCompleted) return;
        switch (update.status) {
          case TaskStatus.complete:
            active.completer.complete();
            break;
          case TaskStatus.failed:
            active.completer.completeError(UploadException(
              update.exception?.description ?? 'Upload task failed',
              code: 'put_failed',
            ));
            break;
          case TaskStatus.canceled:
            active.completer.completeError(UploadException(
              'Upload canceled',
              code: 'put_canceled',
            ));
            break;
          case TaskStatus.notFound:
            active.completer.completeError(UploadException(
              'Upload task not found in system DB',
              code: 'put_not_found',
            ));
            break;
          default:
            break;
        }
      }
    });
  }

  String _taskId(String sessionId, FileKind kind) =>
      '$sessionId:${kind.wireName}';

  @override
  Stream<UploadProgress> upload({
    required String sessionId,
    required String recordingDir,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  }) {
    final controller = StreamController<UploadProgress>();
    // ignore: unawaited_futures
    _run(
      controller: controller,
      sessionId: sessionId,
      recordingDir: recordingDir,
      durationSec: durationSec,
      getAccessToken: getAccessToken,
    );
    return controller.stream;
  }

  Future<void> _run({
    required StreamController<UploadProgress> controller,
    required String sessionId,
    required String recordingDir,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  }) async {
    try {
      final deviceUuid = await _deviceId.getOrCreateUuid();
      final deviceModel = await _deviceId.getDeviceModelLabel();

      // Stat the 4 source files up front. The thumbnail must exist —
      // the backend requires all 4 columns NOT NULL to flip status, and
      // there's no upstream retry path mid-flight if it's missing.
      // Caller (UploadController) is responsible for ensureThumbnail()
      // before invoking us.
      final files = <FileKind, File>{};
      final sizes = <FileKind, int>{};
      for (final kind in _kFileKinds) {
        final f = File(path.join(recordingDir, kind.filename));
        if (!await f.exists()) {
          throw UploadException(
            '${kind.filename} not found in $recordingDir',
            code: 'source_missing',
          );
        }
        files[kind] = f;
        sizes[kind] = await f.length();
      }
      final totalBytes = sizes.values.fold<int>(0, (a, b) => a + b);

      // Leg 1: init.
      final init = await _postInit(
        sessionId: sessionId,
        deviceUuid: deviceUuid,
        deviceModel: deviceModel,
        accessToken: await getAccessToken(),
      );

      // Server-side dedup: all 4 already ack'd (HTTP 409 path). Skip
      // PUTs entirely and synthesize a 100% event so the UI flips to
      // uploaded.
      if (init['already_uploaded'] == true) {
        controller.add(UploadProgress(
          fraction: 1.0,
          bytesSent: totalBytes,
          bytesTotal: totalBytes,
        ));
        await controller.close();
        return;
      }

      final submissionId = init['submission_id'] as String;
      final urlsRaw = (init['urls'] as Map?) ?? const {};
      // Map every kind to either its URL or null (= already ack'd, skip).
      final urls = <FileKind, String?>{
        for (final k in _kFileKinds)
          k: (urlsRaw[k.wireName] is String) ? urlsRaw[k.wireName] as String : null,
      };

      // Persist (sid:kind -> submissionId) for every kind we're about to
      // PUT, BEFORE any enqueue. Cold-start recovery walks this map and
      // looks up the matching background_downloader record; if the PUT
      // landed during the killed-app window, recovery fires /complete.
      for (final k in _kFileKinds) {
        if (urls[k] != null) {
          await _persistPendingComplete(sessionId, k, submissionId);
        }
      }

      // Leg 2: serial PUTs + per-file /complete after each.
      final bytesUploaded = <FileKind, int>{
        for (final k in _kFileKinds) k: 0,
      };

      void emitOverall() {
        if (controller.isClosed) return;
        final sent = bytesUploaded.values.fold<int>(0, (a, b) => a + b);
        final fraction = totalBytes == 0 ? 1.0 : sent / totalBytes;
        controller.add(UploadProgress(
          fraction: fraction.clamp(0.0, 1.0),
          bytesSent: sent,
          bytesTotal: totalBytes,
        ));
      }

      for (final kind in _kFileKinds) {
        final url = urls[kind];
        if (url == null) {
          // Server already has this file (partial dedup). Credit its full
          // byte count to keep the progress bar honest.
          bytesUploaded[kind] = sizes[kind]!;
          emitOverall();
          continue;
        }

        await _putToS3(
          sessionId: sessionId,
          kind: kind,
          uploadUrl: url,
          file: files[kind]!,
          fileLength: sizes[kind]!,
          onProgress: (fraction) {
            bytesUploaded[kind] = (sizes[kind]! * fraction).round();
            emitOverall();
          },
        );

        // Clamp this file to its full size in case the final progress tick
        // was throttled out before emitOverall saw 100%.
        bytesUploaded[kind] = sizes[kind]!;
        emitOverall();

        // Per-file /complete ack. Re-fetch the token: long video PUTs
        // can outlive the 15-min access TTL captured at /init.
        await _postComplete(
          submissionId: submissionId,
          kind: kind,
          sizeBytes: sizes[kind]!,
          durationSec: kind == FileKind.video ? durationSec : null,
          accessToken: await getAccessToken(),
        );
        await _clearPendingComplete(sessionId, kind);
      }

      // Signal finalizing — kept for parity with the v1 UI, though under
      // /v2 the per-file /complete is interleaved with the PUTs so the
      // tail is much shorter than the cross-region D1 round-trip used to
      // be on v1.
      if (!controller.isClosed) {
        controller.add(UploadProgress(
          fraction: 1.0,
          bytesSent: totalBytes,
          bytesTotal: totalBytes,
          phase: UploadPhase.finalizing,
        ));
      }

      await controller.close();
    } catch (e, st) {
      debugPrint('[HttpUploadService] upload failed: $e\n$st');
      if (!controller.isClosed) {
        controller.addError(
          e is UploadException
              ? e
              : UploadException(e.toString(), code: 'unexpected'),
        );
        await controller.close();
      }
    }
  }

  Future<Map<String, dynamic>> _postInit({
    required String sessionId,
    required String deviceUuid,
    required String deviceModel,
    required String accessToken,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v2/submissions/init'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'session_id': sessionId,
            'device_uuid': deviceUuid,
            'device_model': deviceModel,
          }),
        )
        .timeout(_controlTimeout);
    if (res.statusCode == 200 || res.statusCode == 409) {
      // 200 = fresh init or partial dedup (some urls null);
      // 409 = full dedup (`already_uploaded: true` in body).
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _httpException(res, fallbackCode: 'init_failed');
  }

  Future<void> _putToS3({
    required String sessionId,
    required FileKind kind,
    required String uploadUrl,
    required File file,
    required int fileLength,
    required void Function(double fraction) onProgress,
  }) async {
    // Background URLSession via background_downloader — outlives the app
    // process so multi-GB video PUTs survive lock screen / app switch /
    // jetsam. (See git history before plan 6e19 for the v1 OOM and
    // dio-vs-http journey that landed us here.)
    _ensureUpdatesListener();

    final taskId = _taskId(sessionId, kind);

    // Purge any stale terminal record so a retry on the same taskId
    // doesn't re-emit the old canceled / failed status to our new
    // completer.
    try {
      final stale = await FileDownloader().database.recordForId(taskId);
      if (stale != null &&
          (stale.status == TaskStatus.canceled ||
              stale.status == TaskStatus.failed ||
              stale.status == TaskStatus.notFound)) {
        await FileDownloader().database.deleteRecordWithId(taskId);
      }
    } catch (e) {
      debugPrint(
          '[HttpUploadService] stale record purge for $taskId failed: $e');
    }

    final completer = Completer<void>();
    _activeTasks[taskId] = _ActiveTask(
      completer: completer,
      onProgress: onProgress,
    );

    try {
      final task = UploadTask.fromFile(
        file: file,
        taskId: taskId,
        url: uploadUrl,
        httpRequestMethod: 'PUT',
        // `post: 'binary'` puts the raw file body as the HTTP body
        // (vs multipart/form-data, the plugin default). S3 presigned PUT
        // expects raw bytes.
        post: 'binary',
        headers: {'Content-Type': kind.contentType},
        updates: Updates.statusAndProgress,
      );
      final enqueued = await FileDownloader().enqueue(task);
      if (!enqueued) {
        throw UploadException(
          'FileDownloader.enqueue returned false (taskId=$taskId)',
          code: 'enqueue_failed',
        );
      }
      await completer.future;
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  Future<void> _postComplete({
    required String submissionId,
    required FileKind kind,
    required int sizeBytes,
    required double? durationSec,
    required String accessToken,
  }) async {
    final body = <String, dynamic>{'size_bytes': sizeBytes};
    if (durationSec != null) body['duration_sec'] = durationSec;
    final res = await _client
        .post(
          Uri.parse(
              '$baseUrl/v2/submissions/$submissionId/complete?file=${kind.wireName}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body),
        )
        .timeout(_controlTimeout);
    if (res.statusCode != 204) {
      throw _httpException(res, fallbackCode: 'complete_failed');
    }
  }

  UploadException _httpException(
    http.Response res, {
    required String fallbackCode,
  }) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final detail = (json['detail'] as String?) ??
          (json['title'] as String?) ??
          'HTTP ${res.statusCode}';
      return UploadException(detail, code: 'http_${res.statusCode}');
    } catch (_) {
      return UploadException(
        'HTTP ${res.statusCode}: ${res.body.isEmpty ? '(empty)' : res.body}',
        code: fallbackCode,
      );
    }
  }

  // --- pending-complete recovery (per-file) ---

  Future<Map<String, String>> _readPendingComplete() async {
    try {
      final raw = await _secureStorage.read(key: _pendingCompleteKey);
      if (raw == null || raw.isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('[HttpUploadService] read pending-complete failed: $e');
      return <String, String>{};
    }
  }

  Future<void> _writePendingComplete(Map<String, String> map) async {
    try {
      await _secureStorage.write(
        key: _pendingCompleteKey,
        value: jsonEncode(map),
      );
    } catch (e) {
      debugPrint('[HttpUploadService] write pending-complete failed: $e');
    }
  }

  Future<void> _persistPendingComplete(
      String sessionId, FileKind kind, String submissionId) async {
    final m = await _readPendingComplete();
    m[_taskId(sessionId, kind)] = submissionId;
    await _writePendingComplete(m);
  }

  Future<void> _clearPendingComplete(String sessionId, FileKind kind) async {
    final m = await _readPendingComplete();
    if (m.remove(_taskId(sessionId, kind)) != null) {
      await _writePendingComplete(m);
    }
  }

  @override
  Future<void> clearPendingComplete(String sessionId) async {
    final m = await _readPendingComplete();
    final keys = m.keys
        .where((k) => k.startsWith('$sessionId:'))
        .toList(growable: false);
    if (keys.isEmpty) return;
    for (final k in keys) {
      m.remove(k);
    }
    await _writePendingComplete(m);
  }

  @override
  Future<void> cancelInFlight(String sessionId) async {
    for (final k in _kFileKinds) {
      final taskId = _taskId(sessionId, k);
      try {
        await FileDownloader().cancelTaskWithId(taskId);
      } catch (e) {
        debugPrint(
            '[HttpUploadService] cancelTaskWithId($taskId) failed: $e');
      }
    }
  }

  @override
  Future<List<String>> recoverPendingCompletes(
      AccessTokenProvider getAccessToken) async {
    final pending = await _readPendingComplete();
    if (pending.isEmpty) return const <String>[];

    // Group entries by sessionId so we can report a sid as "recovered"
    // only when all of its per-file entries either re-acked or were
    // dropped as terminal failures (i.e. the sid is no longer holding
    // unfinished business).
    final bySid = <String, Map<FileKind, String>>{};
    for (final entry in pending.entries) {
      final parts = entry.key.split(':');
      if (parts.length != 2) continue;
      final sid = parts[0];
      final kind = _fileKindFromWire(parts[1]);
      if (kind == null) continue;
      (bySid[sid] ??= {})[kind] = entry.value;
    }

    final recovered = <String>[];
    for (final sidEntry in bySid.entries) {
      final sid = sidEntry.key;
      final perKind = sidEntry.value;
      var anyStillPending = false;

      for (final k in _kFileKinds) {
        final submissionId = perKind[k];
        if (submissionId == null) continue; // not part of this sid's pending set

        final taskId = _taskId(sid, k);
        TaskRecord? record;
        try {
          record = await FileDownloader().database.recordForId(taskId);
        } catch (e) {
          debugPrint(
              '[HttpUploadService] recordForId($taskId) threw: $e');
          anyStillPending = true;
          continue;
        }
        if (record == null) {
          // No tracked task — PUT never happened or its record was lost.
          // Drop the marker; a user-driven retry triggers fresh /init.
          await _clearPendingComplete(sid, k);
          continue;
        }
        if (record.status == TaskStatus.failed ||
            record.status == TaskStatus.canceled ||
            record.status == TaskStatus.notFound) {
          await _clearPendingComplete(sid, k);
          try {
            await FileDownloader().database.deleteRecordWithId(taskId);
          } catch (_) {}
          continue;
        }
        if (record.status != TaskStatus.complete) {
          anyStillPending = true;
          continue;
        }

        try {
          final sizeBytes = await _fileLengthForRecord(record);
          await _postComplete(
            submissionId: submissionId,
            kind: k,
            sizeBytes: sizeBytes,
            durationSec: null,
            accessToken: await getAccessToken(),
          );
          await _clearPendingComplete(sid, k);
          debugPrint(
              '[HttpUploadService] recovered /complete?file=${k.wireName} for $sid');
        } catch (e) {
          debugPrint(
              '[HttpUploadService] /complete recovery for $taskId failed: $e');
          anyStillPending = true;
        }
      }

      if (!anyStillPending) recovered.add(sid);
    }
    return recovered;
  }

  Future<int> _fileLengthForRecord(TaskRecord record) async {
    try {
      final task = record.task;
      final p = await task.filePath();
      final file = File(p);
      if (await file.exists()) return await file.length();
    } catch (e) {
      debugPrint('[HttpUploadService] file size lookup failed: $e');
    }
    return 0;
  }
}
