import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'device_id_service.dart';

// Client surface for the M-Upload-Lite pipeline (digients-api v1/submissions).
//
// The real flow is three-legged:
//   1. POST /v1/submissions/init with {session_id, device_uuid, device_model,
//      content_type} -> returns a pre-signed S3 PUT URL (15min TTL).
//   2. PUT the tar.gz body to that URL directly. AWS S3 verifies the SigV4
//      signature; the App never sees the AWS credentials.
//   3. POST /v1/submissions/<id>/complete with {size_bytes, duration_sec} to
//      flip the submission status uploading -> queued.
//
// UI code talks only to UploadService, so we can swap Mock <-> Http via
// --dart-define=UPLOAD_BACKEND=mock|http exactly like AuthService.
//
// Each call returns a [Stream<UploadProgress>] so the UI can render a
// progress bar without polling. The stream terminates with done() or
// addError() — listeners derive uploading / uploaded / failed from
// onData / onDone / onError respectively.

// Where in the multi-stage upload pipeline a given progress event was
// emitted. `uploading` is the only phase that carries a meaningful byte
// fraction; `finalizing` is a no-percent sentinel telling the controller
// the PUT is done and we're now waiting on the backend /complete round-
// trip (which can take 1-3s — token refresh + cross-region D1 update).
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
// links) — by the time `complete` fires, the 15-minute access token captured
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
}

// In-memory fake. Walks 0% -> 100% across `_durationMs` and either completes
// or fails depending on `_failureRate`. Used by Jason to drive UX iteration
// in the simulator/device before the real Http implementation is wired.
//
// Tunable via constructor args so we can dial up failures while testing the
// retry path without touching the call site.
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
    // If we're going to fail, fail somewhere between 20% and 80% — that's the
    // realistic window for a network blip mid-upload.
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
}

// Real backend implementation. Three-legged flow against digients-api:
//   1. POST /v1/submissions/init with session/device metadata, get back a
//      pre-signed PUT URL (TTL ~15min) and the matching submission id.
//   2. HTTP PUT the tar.gz body to S3 directly via the pre-signed URL.
//      Body is streamed off disk via dio — URLSession applies backpressure
//      so memory stays bounded even for multi-GB takes (a prior http.dart
//      StreamedRequest implementation OOM-crashed on 3.5 GB uploads because
//      its sink was unbounded and the file was read into RAM at disk speed).
//      Progress events come from dio's onSendProgress, which fires as bytes
//      are actually consumed by the underlying HttpClient — reflecting real
//      network throughput, not disk-read speed.
//   3. POST /v1/submissions/<id>/complete with final size + duration to
//      flip the submission status uploading -> queued on the backend.
//
// Known gap: the access token is captured at call-time and used for both
// /init and /complete. If the token expires mid-upload (>15 min), /complete
// will 401 and the take ends up in `failed`. Retrying re-fetches a fresh
// token via AuthController, so this self-heals on retry. Proper mid-flight
// refresh is a fast-follow.
class HttpUploadService implements UploadService {
  final String baseUrl;
  final DeviceIdService _deviceId;
  final http.Client _client;
  // `_dio` and `_uploadTimeout` were the dio path before Phase B swapped
  // `_putToS3` onto background_downloader. Kept around (with the dep) until
  // Phase D verifies the new path holds and removes both at once — per the
  // conservative-change discipline in .claude/plan/6e15-plan-background-upload.md.
  // ignore: unused_field
  final Dio _dio;
  final Duration _controlTimeout;
  // ignore: unused_field
  final Duration _uploadTimeout;

  HttpUploadService({
    required this.baseUrl,
    required DeviceIdService deviceId,
    http.Client? client,
    Dio? dio,
    Duration controlTimeout = const Duration(seconds: 30),
    // 2h is generous on purpose: a 3.5 GB take at 5 Mbps real upload finishes
    // in ~93 min. Multi-part upload (planned) will replace this with per-part
    // timeouts an order of magnitude smaller.
    Duration uploadTimeout = const Duration(hours: 2),
  })  : _deviceId = deviceId,
        _client = client ?? http.Client(),
        _dio = dio ?? Dio(),
        _controlTimeout = controlTimeout,
        _uploadTimeout = uploadTimeout;

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

      // Leg 1: init — server issues pre-signed PUT URL + submission row.
      // Pull a fresh access token immediately before each control-plane call
      // so an in-flight refresh (long PUT, long backoff) doesn't 401.
      final init = await _postInit(
        sessionId: sessionId,
        deviceUuid: deviceUuid,
        deviceModel: deviceModel,
        accessToken: await getAccessToken(),
      );

      // Server-side dedup: if this (user, session) already finished, the
      // server returns 409 with `already_uploaded: true`. Skip PUT + complete
      // and synthesize a 100% progress event so the UI flips straight to
      // "uploaded". The persisted session list in UploadController then keeps
      // this state across App restarts.
      if (init['already_uploaded'] == true) {
        controller.add(UploadProgress(
          fraction: 1.0,
          bytesSent: fileLength,
          bytesTotal: fileLength,
        ));
        await controller.close();
        return;
      }

      final uploadUrl = init['upload_url'] as String;
      final submissionId = init['submission_id'] as String;

      // Leg 2: PUT to S3 with byte-level progress. The pre-signed URL embeds
      // its own auth (SigV4), so the access token never reaches AWS.
      await _putToS3(
        controller: controller,
        sessionId: sessionId,
        uploadUrl: uploadUrl,
        file: file,
        fileLength: fileLength,
      );

      // Signal the controller that the byte stream finished and we're now
      // waiting on the backend round-trip. The /complete call below can
      // take 1-3s (token refresh + cross-region D1 UPDATE), and that
      // window used to look like a "stuck at 100%" hang in the UI.
      if (!controller.isClosed) {
        controller.add(UploadProgress(
          fraction: 1.0,
          bytesSent: fileLength,
          bytesTotal: fileLength,
          phase: UploadPhase.finalizing,
        ));
      }

      // Leg 3: complete — flip status uploading -> queued. Re-fetch the
      // token here in case the PUT ran long enough for the original to
      // have expired.
      await _postComplete(
        submissionId: submissionId,
        sizeBytes: fileLength,
        durationSec: durationSec,
        accessToken: await getAccessToken(),
      );

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
          }),
        )
        .timeout(_controlTimeout);
    if (res.statusCode == 200 || res.statusCode == 409) {
      // 200 = fresh init; 409 = server-side dedup hit (body carries
      // `already_uploaded: true`). Both bodies are JSON.
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _httpException(res, fallbackCode: 'init_failed');
  }

  Future<void> _putToS3({
    required StreamController<UploadProgress> controller,
    required String sessionId,
    required String uploadUrl,
    required File file,
    required int fileLength,
  }) async {
    // Hand the PUT off to iOS background URLSession via the
    // background_downloader plugin (`nsurlsessiond` daemon). Unlike dio's
    // default URLSession, nsurlsessiond outlives the app process: lock
    // screen, app switch, jetsam kill — the upload keeps going until iOS
    // either delivers it or cancels (e.g., user force-quits, 7-day TTL).
    // Phase A spike (commit fba0f17) validated lock-screen survival on
    // iOS 26.4 with a 1.6 GB take; event log confirmed nsurlsessiond
    // continued the transfer across multiple paused/hidden/resumed cycles.
    //
    // background_downloader emits TaskStatusUpdate + TaskProgressUpdate on
    // a global broadcast stream. We filter by taskId == sessionId, bridge
    // progress events back into the local `controller` (so the rest of
    // _run / UploadController doesn't know the transport changed), and use
    // a Completer to convert the async "complete" event into a synchronous
    // return from this function.
    //
    // _uploadTimeout / _controlTimeout from dio path no longer apply —
    // background_downloader has its own 7-day default TTL which is far
    // more than enough for any single take. Per-part timeouts will come
    // back with multipart upload in Tier 3.
    final completer = Completer<void>();
    final sub = FileDownloader().updates.listen((update) {
      if (update.task.taskId != sessionId) return;
      if (update is TaskProgressUpdate) {
        if (controller.isClosed) return;
        final fraction = update.progress.clamp(0.0, 1.0);
        controller.add(UploadProgress(
          fraction: fraction,
          bytesSent: (fraction * fileLength).round(),
          bytesTotal: fileLength,
        ));
      } else if (update is TaskStatusUpdate) {
        if (completer.isCompleted) return;
        switch (update.status) {
          case TaskStatus.complete:
            completer.complete();
            break;
          case TaskStatus.failed:
            completer.completeError(UploadException(
              update.exception?.description ?? 'Upload task failed',
              code: 'put_failed',
            ));
            break;
          case TaskStatus.canceled:
            completer.completeError(UploadException(
              'Upload canceled',
              code: 'put_canceled',
            ));
            break;
          case TaskStatus.notFound:
            completer.completeError(UploadException(
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
    try {
      final task = UploadTask.fromFile(
        file: file,
        taskId: sessionId,
        url: uploadUrl,
        httpRequestMethod: 'PUT',
        // `post: 'binary'` puts the raw file body as the HTTP body (vs
        // multipart/form-data which is the default). S3 presigned PUT
        // expects raw bytes.
        post: 'binary',
        headers: const {'Content-Type': 'application/gzip'},
        updates: Updates.statusAndProgress,
      );
      final enqueued = await FileDownloader().enqueue(task);
      if (!enqueued) {
        throw UploadException(
          'FileDownloader.enqueue returned false (taskId=$sessionId)',
          code: 'enqueue_failed',
        );
      }
      await completer.future;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _postComplete({
    required String submissionId,
    required int sizeBytes,
    required double durationSec,
    required String accessToken,
  }) async {
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
          }),
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
}
