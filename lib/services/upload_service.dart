import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'device_id_service.dart';

// Client surface for the S3 multipart upload pipeline (Tier 3).
//
// Wire-protocol (since 0.3.0):
//   1. POST /v1/submissions/init with `multipart_capable: true` -> server
//      calls S3 CreateMultipartUpload and returns
//      `{submission_id, multipart: {upload_id, part_size}}`.
//   2. For each part N in [1..ceil(fileLength / part_size)]:
//        a. POST /v1/submissions/<id>/parts/N/url -> presigned UploadPart URL
//        b. PUT the byte range of the archive [offset, offset+size) to that URL
//        c. Capture the ETag from the response and persist locally.
//   3. POST /v1/submissions/<id>/complete with the full ordered parts list
//      -> server calls CompleteMultipartUpload and flips status uploading
//      -> queued.
//
// On cold start, any persisted in-flight upload is reconciled with S3 via
// POST /v1/submissions/<id>/resume (server proxies ListParts). The local
// part-ETag cache is just a hint; S3 is the source of truth.
//
// History: 0.2.x used a single S3 PUT, which limited files to 5 GB, forced
// the full transfer to restart on force-quit, and gave no per-part retry
// granularity. Plan: .claude/plan/6e16-plan-multipart-upload.md.

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
// links) — by the time `/complete` fires, the 15-minute access token captured
// at upload-start may have expired. The callback resolves to a fresh token
// each call, so the implementation can auto-refresh transparently.
typedef AccessTokenProvider = Future<String> Function();

abstract class UploadService {
  // Streams progress events while the upload is in flight; closes normally
  // on success and emits an [UploadException] via addError on failure.
  Stream<UploadProgress> upload({
    required String sessionId,
    required String archivePath,
    required int sizeBytes,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  });

  // Cold-start recovery: walk persisted in-flight multipart uploads, ask
  // the server (which asks S3 ListParts) which parts have actually
  // landed, and either finish (call `/complete`) or leave alone for the
  // user to retry from where they stopped.
  //
  // Returns the sessionIds that were fully recovered to `queued` on the
  // server — caller (UploadController.hydrate) flips their UI to
  // `uploaded`.
  Future<List<String>> recoverPendingCompletes(
      AccessTokenProvider getAccessToken);

  // Full teardown of any in-flight upload for [sessionId]: cancels the
  // active per-part task, calls `/abort` on the server so S3 frees the
  // partial multipart upload (only if `getAccessToken` is supplied —
  // otherwise the S3 bucket lifecycle handles cleanup after 7 days),
  // deletes temp part files on disk, and wipes local persistence. Used
  // when the user deletes the recording. Best-effort throughout — never
  // throws.
  Future<void> cancelInflight(
    String sessionId, {
    AccessTokenProvider? getAccessToken,
  });
}

// In-memory fake. Walks 0% -> 100% across `_durationMs` and either completes
// or fails depending on `_failureRate`. Used to drive UX iteration before
// the real Http implementation is wired.
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
    required String archivePath,
    required int sizeBytes,
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
        bytesSent: (sizeBytes * fraction).round(),
        bytesTotal: sizeBytes,
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
  Future<void> cancelInflight(
    String sessionId, {
    AccessTokenProvider? getAccessToken,
  }) async {}
}

// A completed multipart part — what we need to persist locally to avoid
// re-uploading on retry, and what we hand to `/complete` at the end.
class _CompletedPart {
  final int partNumber;
  final String etag; // including surrounding quotes; verbatim from S3.
  final int size;

  const _CompletedPart({
    required this.partNumber,
    required this.etag,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'part_number': partNumber,
        'etag': etag,
        'size': size,
      };

  static _CompletedPart? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final pn = raw['part_number'];
    final et = raw['etag'];
    final sz = raw['size'];
    if (pn is! int || et is! String || et.isEmpty || sz is! int) {
      return null;
    }
    return _CompletedPart(partNumber: pn, etag: et, size: sz);
  }
}

// Per-session record stored under `_multipartStateKey`. Cache of what we
// know about an in-flight multipart upload — submissionId / uploadId /
// completed parts. Used to skip already-uploaded parts on retry without
// a round-trip, and to drive cold-start recovery.
class _MultipartState {
  final String submissionId;
  final String uploadId;
  final int partSize;
  final int totalSize;
  final String archivePath;
  final List<_CompletedPart> completedParts;

  _MultipartState({
    required this.submissionId,
    required this.uploadId,
    required this.partSize,
    required this.totalSize,
    required this.archivePath,
    required this.completedParts,
  });

  Map<String, dynamic> toJson() => {
        'submission_id': submissionId,
        'upload_id': uploadId,
        'part_size': partSize,
        'total_size': totalSize,
        'archive_path': archivePath,
        'completed_parts':
            completedParts.map((p) => p.toJson()).toList(growable: false),
      };

  static _MultipartState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final submissionId = raw['submission_id'];
    final uploadId = raw['upload_id'];
    final partSize = raw['part_size'];
    final totalSize = raw['total_size'];
    final archivePath = raw['archive_path'];
    final parts = raw['completed_parts'];
    if (submissionId is! String ||
        uploadId is! String ||
        partSize is! int ||
        totalSize is! int ||
        archivePath is! String ||
        parts is! List) {
      return null;
    }
    final decoded = <_CompletedPart>[];
    for (final r in parts) {
      final p = _CompletedPart.fromJson(r);
      if (p != null) decoded.add(p);
    }
    return _MultipartState(
      submissionId: submissionId,
      uploadId: uploadId,
      partSize: partSize,
      totalSize: totalSize,
      archivePath: archivePath,
      completedParts: decoded,
    );
  }
}

// Routing slot for a single in-flight S3 UploadPart PUT. The
// `HttpUploadService` singleton listener on `FileDownloader().updates`
// keys events by taskId (= `'$sessionId.p$partNumber'`) and dispatches
// to the matching entry's completer / onProgress.
//
// `completer` resolves with the ETag (including surrounding double quotes
// — that's the on-the-wire format S3 returns and the form
// CompleteMultipartUpload requires).
class _ActiveTask {
  final Completer<String> completer;
  final void Function(double fraction) onProgress;
  _ActiveTask({required this.completer, required this.onProgress});
}

class HttpUploadService implements UploadService {
  // Tier 3 multipart-state secure-storage key. Per-session record
  // (see `_MultipartState`) describing what we know about an in-flight
  // multipart upload: which submission, which S3 UploadId, what part size
  // the server picked, and the running list of completed parts (with
  // their ETags).
  static const _multipartStateKey =
      'upload_service.multipart_state_v1';

  // Tier 2 / 0.2.x single-PUT cache key — kept here only so we can wipe
  // it on first boot of a Tier 3 build. Old entries are useless because
  // they reference submissions that were single-PUT mode; the new
  // recovery path needs an UploadId which old entries didn't store.
  static const _legacyPendingCompleteKey =
      'upload_service.pending_complete_v1';

  final String baseUrl;
  final DeviceIdService _deviceId;
  final http.Client _client;
  final Duration _controlTimeout;
  final FlutterSecureStorage _secureStorage;

  // Per-taskId routing for in-flight UploadPart PUTs, plus the single
  // subscription that fans events out to those entries.
  // `FileDownloader().updates` is non-broadcast, so listening more than
  // once crashes with "Bad state". One service-wide listener avoids
  // that and matches the plugin's intended usage pattern.
  final Map<String, _ActiveTask> _activeTasks = {};
  StreamSubscription<TaskUpdate>? _updatesSub;

  // Tracks, per sessionId, which per-part task is currently in flight so
  // `cancelInflight` can cancel the right `taskId`. Cleared as soon as
  // the part resolves (success or failure). Decoupled from `_activeTasks`
  // because that map is keyed by taskId; cancel is given a sessionId.
  final Map<String, String> _currentPartTaskId = {};

  bool _legacyKeyPurged = false;

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

  // Lazy-init the singleton subscription. Idempotent across calls; the
  // first part PUT wires it up and it lives until process death (no
  // dispose path — the service is constructed once at app boot).
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
            // S3 ships the ETag as `etag: "<32-hex>"` (lowercase header
            // key, value includes the surrounding quotes). `background_
            // downloader` lowercases header keys; we hand the value to
            // `/complete` verbatim because CompleteMultipartUpload
            // requires the quotes.
            final etag = update.responseHeaders?['etag'];
            if (etag == null || etag.isEmpty) {
              active.completer.completeError(UploadException(
                'S3 PUT succeeded but ETag header was missing',
                code: 'etag_missing',
              ));
            } else {
              active.completer.complete(etag);
            }
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
            // running / enqueued / paused / waitingToRetry — keep waiting
            break;
        }
      }
    });
  }

  @override
  Stream<UploadProgress> upload({
    required String sessionId,
    required String archivePath,
    required int sizeBytes,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  }) {
    final controller = StreamController<UploadProgress>();
    // ignore: unawaited_futures
    _run(
      controller: controller,
      sessionId: sessionId,
      archivePath: archivePath,
      durationSec: durationSec,
      getAccessToken: getAccessToken,
    );
    return controller.stream;
  }

  Future<void> _run({
    required StreamController<UploadProgress> controller,
    required String sessionId,
    required String archivePath,
    required double durationSec,
    required AccessTokenProvider getAccessToken,
  }) async {
    try {
      await _purgeLegacyKeyOnce();

      final deviceUuid = await _deviceId.getOrCreateUuid();
      final deviceModel = await _deviceId.getDeviceModelLabel();

      final file = File(archivePath);
      if (!await file.exists()) {
        throw UploadException(
          'Archive not found at $archivePath',
          code: 'archive_missing',
        );
      }
      final fileLength = await file.length();

      // Leg 1: init.
      final init = await _postInit(
        sessionId: sessionId,
        deviceUuid: deviceUuid,
        deviceModel: deviceModel,
        accessToken: await getAccessToken(),
      );

      // Server-side dedup: this (user, session) already finished.
      if (init['already_uploaded'] == true) {
        controller.add(UploadProgress(
          fraction: 1.0,
          bytesSent: fileLength,
          bytesTotal: fileLength,
        ));
        await controller.close();
        return;
      }

      final submissionId = init['submission_id'] as String;
      final multipart = init['multipart'];
      if (multipart is! Map ||
          multipart['upload_id'] is! String ||
          multipart['part_size'] is! int) {
        throw UploadException(
          'Server response missing multipart fields',
          code: 'multipart_missing',
        );
      }
      final uploadId = multipart['upload_id'] as String;
      final partSize = multipart['part_size'] as int;

      // Hydrate local state — preserve any previously-completed parts
      // for this sessionId from a prior retry. The submissionId+uploadId
      // pair must match the one we just got from /init; if they don't
      // (server reset / mode flipped), drop the cache and start fresh.
      final cached = await _readState(sessionId);
      final cachedParts = (cached != null &&
              cached.submissionId == submissionId &&
              cached.uploadId == uploadId)
          ? cached.completedParts
          : <_CompletedPart>[];

      // Always reconcile with S3 via /resume — the local cache is a
      // hint, S3 is authoritative. On a fresh upload this is one cheap
      // round-trip that returns an empty list; on a retry it tells us
      // which parts S3 actually has.
      final serverParts = await _postResume(
        submissionId: submissionId,
        accessToken: await getAccessToken(),
      );

      final completed = _mergeParts(cachedParts, serverParts);

      // Persist the merged state before any new PUT, so a force-quit
      // during the first new part doesn't lose the union of
      // cache+server we just computed.
      await _writeState(
        sessionId,
        _MultipartState(
          submissionId: submissionId,
          uploadId: uploadId,
          partSize: partSize,
          totalSize: fileLength,
          archivePath: archivePath,
          completedParts: completed,
        ),
      );

      // Leg 2: per-part PUTs.
      await _putToS3Multipart(
        controller: controller,
        sessionId: sessionId,
        submissionId: submissionId,
        file: file,
        fileLength: fileLength,
        partSize: partSize,
        alreadyCompleted: completed,
        getAccessToken: getAccessToken,
      );

      // Byte stream done; /complete typically takes 1-3 s. Tell the UI
      // so it doesn't look hung at 100 %.
      if (!controller.isClosed) {
        controller.add(UploadProgress(
          fraction: 1.0,
          bytesSent: fileLength,
          bytesTotal: fileLength,
          phase: UploadPhase.finalizing,
        ));
      }

      final finalState = await _readState(sessionId);
      final partsForComplete = finalState?.completedParts ?? completed;

      // Leg 3: complete.
      await _postComplete(
        submissionId: submissionId,
        sizeBytes: fileLength,
        durationSec: durationSec,
        parts: partsForComplete,
        accessToken: await getAccessToken(),
      );

      await _clearState(sessionId);
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
    } finally {
      _currentPartTaskId.remove(sessionId);
    }
  }

  // --- Wire calls ---

  Future<Map<String, dynamic>> _postInit({
    required String sessionId,
    required String deviceUuid,
    required String deviceModel,
    required String accessToken,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v1/submissions/init'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'session_id': sessionId,
            'device_uuid': deviceUuid,
            'device_model': deviceModel,
            'content_type': 'application/gzip',
            'multipart_capable': true,
          }),
        )
        .timeout(_controlTimeout);
    if (res.statusCode == 200 || res.statusCode == 409) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _httpException(res, fallbackCode: 'init_failed');
  }

  Future<String> _postPartUrl({
    required String submissionId,
    required int partNumber,
    required String accessToken,
  }) async {
    final res = await _client
        .post(
          Uri.parse(
              '$baseUrl/v1/submissions/$submissionId/parts/$partNumber/url'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: '{}',
        )
        .timeout(_controlTimeout);
    if (res.statusCode != 200) {
      throw _httpException(res, fallbackCode: 'part_url_failed');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final url = json['url'];
    if (url is! String || url.isEmpty) {
      throw UploadException(
        'Server returned an empty presigned URL for part $partNumber',
        code: 'part_url_empty',
      );
    }
    return url;
  }

  Future<List<_CompletedPart>> _postResume({
    required String submissionId,
    required String accessToken,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v1/submissions/$submissionId/resume'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: '{}',
        )
        .timeout(_controlTimeout);
    if (res.statusCode != 200) {
      throw _httpException(res, fallbackCode: 'resume_failed');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = json['completed_parts'];
    if (parts is! List) return const <_CompletedPart>[];
    final out = <_CompletedPart>[];
    for (final r in parts) {
      final p = _CompletedPart.fromJson(r);
      if (p != null) out.add(p);
    }
    out.sort((a, b) => a.partNumber.compareTo(b.partNumber));
    return out;
  }

  Future<void> _postAbort({
    required String submissionId,
    required String accessToken,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v1/submissions/$submissionId/abort'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: '{}',
        )
        .timeout(_controlTimeout);
    // /abort is idempotent — server returns 204 even on terminal states.
    // Non-204 here is informational only; cancel is best-effort.
    if (res.statusCode != 204) {
      debugPrint(
          '[HttpUploadService] /abort returned ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> _postComplete({
    required String submissionId,
    required int sizeBytes,
    required double durationSec,
    required List<_CompletedPart> parts,
    required String accessToken,
  }) async {
    // Server sorts too, but a defensive sort here keeps the request body
    // self-documenting and avoids relying on map iteration order across
    // recovery vs. in-band paths.
    final sorted = [...parts]..sort((a, b) => a.partNumber.compareTo(b.partNumber));
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v1/submissions/$submissionId/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'size_bytes': sizeBytes,
            'duration_sec': durationSec,
            'parts': sorted.map((p) => p.toJson()).toList(growable: false),
          }),
        )
        .timeout(_controlTimeout);
    if (res.statusCode != 204) {
      throw _httpException(res, fallbackCode: 'complete_failed');
    }
  }

  // --- Multipart upload loop ---

  Future<void> _putToS3Multipart({
    required StreamController<UploadProgress> controller,
    required String sessionId,
    required String submissionId,
    required File file,
    required int fileLength,
    required int partSize,
    required List<_CompletedPart> alreadyCompleted,
    required AccessTokenProvider getAccessToken,
  }) async {
    _ensureUpdatesListener();

    final totalParts = max(1, (fileLength / partSize).ceil());
    final doneByNumber = <int, _CompletedPart>{
      for (final p in alreadyCompleted) p.partNumber: p,
    };
    var processedBytes = doneByNumber.values
        .fold<int>(0, (s, p) => s + p.size)
        .clamp(0, fileLength);

    // Seed the UI with the resume-from progress so users opening the
    // app after a force-quit don't see the bar snap back to 0 % before
    // the first new part lands.
    if (!controller.isClosed && processedBytes > 0) {
      controller.add(UploadProgress(
        fraction: processedBytes / fileLength,
        bytesSent: processedBytes,
        bytesTotal: fileLength,
      ));
    }

    for (var partNum = 1; partNum <= totalParts; partNum++) {
      if (doneByNumber.containsKey(partNum)) continue;

      final offset = (partNum - 1) * partSize;
      final size =
          (partNum == totalParts) ? fileLength - offset : partSize;
      if (size <= 0) continue;

      final partFile = await _splitChunk(file, offset, size, partNum);

      try {
        final url = await _postPartUrl(
          submissionId: submissionId,
          partNumber: partNum,
          accessToken: await getAccessToken(),
        );

        final etag = await _putPartAndWait(
          sessionId: sessionId,
          partNumber: partNum,
          partFile: partFile,
          partSize: size,
          url: url,
          onPartProgress: (frac) {
            if (controller.isClosed) return;
            final bytesInPart = (frac * size).round();
            final totalSent = processedBytes + bytesInPart;
            controller.add(UploadProgress(
              fraction: totalSent / fileLength,
              bytesSent: totalSent,
              bytesTotal: fileLength,
            ));
          },
        );

        final completed = _CompletedPart(
          partNumber: partNum,
          etag: etag,
          size: size,
        );
        doneByNumber[partNum] = completed;
        processedBytes += size;

        await _appendCompletedPart(sessionId, completed);
      } finally {
        try {
          await partFile.delete();
        } catch (_) {}
        _currentPartTaskId.remove(sessionId);
      }
    }

    // Final clamp — emit exactly 100 % for the last part so the pill
    // doesn't sit at 99.9 % during the /complete round-trip.
    if (!controller.isClosed) {
      controller.add(UploadProgress(
        fraction: 1.0,
        bytesSent: fileLength,
        bytesTotal: fileLength,
      ));
    }
  }

  Future<File> _splitChunk(
      File source, int offset, int size, int partNum) async {
    final partPath = '${source.path}.part$partNum';
    final out = File(partPath);
    final sink = out.openWrite();
    try {
      await source.openRead(offset, offset + size).pipe(sink);
    } catch (e) {
      try {
        await out.delete();
      } catch (_) {}
      rethrow;
    }
    return out;
  }

  Future<String> _putPartAndWait({
    required String sessionId,
    required int partNumber,
    required File partFile,
    required int partSize,
    required String url,
    required void Function(double fraction) onPartProgress,
  }) async {
    final taskId = '$sessionId.p$partNumber';

    // After a force-quit, iOS marks the prior background URLSession task
    // as `canceled` and `background_downloader` persists that record. A
    // subsequent enqueue with the same taskId can then re-emit the stale
    // status on the updates stream and resolve the new completer with a
    // spurious `put_canceled`. Wiping the stale record first avoids that.
    try {
      final stale = await FileDownloader().database.recordForId(taskId);
      if (stale != null &&
          (stale.status == TaskStatus.canceled ||
              stale.status == TaskStatus.failed ||
              stale.status == TaskStatus.notFound)) {
        await FileDownloader().database.deleteRecordWithId(taskId);
      }
    } catch (e) {
      debugPrint('[HttpUploadService] stale record purge for $taskId failed: $e');
    }

    final completer = Completer<String>();
    _activeTasks[taskId] = _ActiveTask(
      completer: completer,
      onProgress: onPartProgress,
    );
    _currentPartTaskId[sessionId] = taskId;

    try {
      final task = UploadTask.fromFile(
        file: partFile,
        taskId: taskId,
        url: url,
        httpRequestMethod: 'PUT',
        post: 'binary',
        // No Content-Type header on UploadPart — S3 ignores it for part
        // bodies, and presigned UploadPart URLs are signed without one.
        headers: const {},
        updates: Updates.statusAndProgress,
      );
      final enqueued = await FileDownloader().enqueue(task);
      if (!enqueued) {
        throw UploadException(
          'FileDownloader.enqueue returned false (taskId=$taskId)',
          code: 'enqueue_failed',
        );
      }
      return await completer.future;
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  // --- Recovery + cancel ---

  @override
  Future<List<String>> recoverPendingCompletes(
      AccessTokenProvider getAccessToken) async {
    await _purgeLegacyKeyOnce();

    final all = await _readAllState();
    if (all.isEmpty) return const <String>[];

    final recovered = <String>[];
    for (final entry in all.entries) {
      final sessionId = entry.key;
      final state = entry.value;
      try {
        final serverParts = await _postResume(
          submissionId: state.submissionId,
          accessToken: await getAccessToken(),
        );
        final merged = _mergeParts(state.completedParts, serverParts);
        final totalUploaded =
            merged.fold<int>(0, (s, p) => s + p.size);

        if (totalUploaded >= state.totalSize) {
          // All parts present on S3. Fire /complete.
          await _postComplete(
            submissionId: state.submissionId,
            sizeBytes: state.totalSize,
            durationSec: 0,
            parts: merged,
            accessToken: await getAccessToken(),
          );
          await _clearState(sessionId);
          recovered.add(sessionId);
          debugPrint(
              '[HttpUploadService] recovered /complete for $sessionId (${merged.length} parts)');
        } else {
          // Partial. Persist the merged view so the next user-triggered
          // retry resumes from where the previous run actually stopped,
          // then leave the entry — we don't auto-resume; resume happens
          // when the user (or the controller's retry path) calls upload
          // again with this sessionId.
          await _writeState(
            sessionId,
            _MultipartState(
              submissionId: state.submissionId,
              uploadId: state.uploadId,
              partSize: state.partSize,
              totalSize: state.totalSize,
              archivePath: state.archivePath,
              completedParts: merged,
            ),
          );
        }
      } catch (e) {
        if (e is UploadException &&
            (e.code == 'http_404' || e.code == 'http_410')) {
          // Server doesn't know this submission (or it's been GC'd by
          // the 7-day S3 lifecycle that aborted the multipart upload).
          // Drop the entry — next user retry creates a fresh /init.
          await _clearState(sessionId);
          debugPrint(
              '[HttpUploadService] dropped unknown submission $sessionId (${e.code})');
        } else {
          debugPrint(
              '[HttpUploadService] recovery for $sessionId failed: $e');
          // Leave entry; next hydrate will retry.
        }
      }
    }
    return recovered;
  }

  @override
  Future<void> cancelInflight(
    String sessionId, {
    AccessTokenProvider? getAccessToken,
  }) async {
    final partTaskId = _currentPartTaskId.remove(sessionId);
    if (partTaskId != null) {
      try {
        await FileDownloader().cancelTaskWithId(partTaskId);
      } catch (e) {
        debugPrint(
            '[HttpUploadService] cancelTaskWithId($partTaskId) failed: $e');
      }
    }

    final state = await _readState(sessionId);
    if (state != null) {
      if (getAccessToken != null) {
        try {
          await _postAbort(
            submissionId: state.submissionId,
            accessToken: await getAccessToken(),
          );
        } catch (e) {
          // /abort is best-effort: failure here just means the S3
          // multipart upload sticks around until the 7-day bucket
          // lifecycle rule sweeps it. Bytes won't sit forever.
          debugPrint('[HttpUploadService] /abort failed: $e');
        }
      }
      await _cleanupTempParts(state);
    }
    await _clearState(sessionId);
  }

  // --- Persistence ---

  Future<void> _purgeLegacyKeyOnce() async {
    if (_legacyKeyPurged) return;
    _legacyKeyPurged = true;
    try {
      await _secureStorage.delete(key: _legacyPendingCompleteKey);
    } catch (e) {
      debugPrint('[HttpUploadService] legacy key purge failed: $e');
    }
  }

  Future<Map<String, _MultipartState>> _readAllState() async {
    try {
      final raw = await _secureStorage.read(key: _multipartStateKey);
      if (raw == null || raw.isEmpty) return <String, _MultipartState>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, _MultipartState>{};
      final out = <String, _MultipartState>{};
      decoded.forEach((k, v) {
        if (k is! String) return;
        final s = _MultipartState.fromJson(v);
        if (s != null) out[k] = s;
      });
      return out;
    } catch (e) {
      debugPrint('[HttpUploadService] read multipart state failed: $e');
      return <String, _MultipartState>{};
    }
  }

  Future<void> _writeAllState(Map<String, _MultipartState> map) async {
    try {
      final encoded = jsonEncode(
        map.map((k, v) => MapEntry(k, v.toJson())),
      );
      await _secureStorage.write(key: _multipartStateKey, value: encoded);
    } catch (e) {
      debugPrint('[HttpUploadService] write multipart state failed: $e');
    }
  }

  Future<_MultipartState?> _readState(String sessionId) async {
    final all = await _readAllState();
    return all[sessionId];
  }

  Future<void> _writeState(String sessionId, _MultipartState state) async {
    final all = await _readAllState();
    all[sessionId] = state;
    await _writeAllState(all);
  }

  Future<void> _appendCompletedPart(
      String sessionId, _CompletedPart part) async {
    final all = await _readAllState();
    final existing = all[sessionId];
    if (existing == null) return;
    final merged = _mergeParts(existing.completedParts, [part]);
    all[sessionId] = _MultipartState(
      submissionId: existing.submissionId,
      uploadId: existing.uploadId,
      partSize: existing.partSize,
      totalSize: existing.totalSize,
      archivePath: existing.archivePath,
      completedParts: merged,
    );
    await _writeAllState(all);
  }

  Future<void> _clearState(String sessionId) async {
    final all = await _readAllState();
    if (all.remove(sessionId) != null) {
      await _writeAllState(all);
    }
  }

  // Union of two part lists, keyed by part number. Later occurrences win
  // (so caller order is "less authoritative first, more authoritative
  // second"). S3 ListParts is treated as authoritative over local cache.
  static List<_CompletedPart> _mergeParts(
    List<_CompletedPart> a,
    List<_CompletedPart> b,
  ) {
    final byNumber = <int, _CompletedPart>{
      for (final p in a) p.partNumber: p,
    };
    for (final p in b) {
      byNumber[p.partNumber] = p;
    }
    final out = byNumber.values.toList(growable: false);
    out.sort((x, y) => x.partNumber.compareTo(y.partNumber));
    return out;
  }

  Future<void> _cleanupTempParts(_MultipartState state) async {
    // Delete `<archive>.part<N>` siblings of the archive. We don't know
    // exactly which parts had a temp file (the per-part split deletes
    // its file in the `finally` block of the loop), but a stale temp can
    // linger if the process was killed between split and delete.
    try {
      final archive = File(state.archivePath);
      final dir = archive.parent;
      final stem = archive.uri.pathSegments.last;
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('$stem.part')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[HttpUploadService] temp-part cleanup failed: $e');
    }
  }

  // --- Error mapping ---

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
}
