import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  final Dio _dio;
  final Duration _controlTimeout;
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
    required String uploadUrl,
    required File file,
    required int fileLength,
  }) async {
    // dio consumes `file.openRead()` as a Stream<List<int>> and pumps it into
    // the underlying HttpClient with proper backpressure — the stream is only
    // pulled as fast as URLSession can transmit, so memory stays bounded
    // regardless of file size. Content-Length must be supplied explicitly
    // because the stream has no inherent length; S3 also requires it on PUT.
    try {
      final response = await _dio.put<String>(
        uploadUrl,
        data: file.openRead(),
        options: Options(
          contentType: 'application/gzip',
          headers: {
            Headers.contentLengthHeader: fileLength,
          },
          responseType: ResponseType.plain,
          sendTimeout: _uploadTimeout,
          receiveTimeout: _controlTimeout,
          // Inspect status ourselves so we can produce a uniform
          // UploadException shape instead of catching DioException for !=2xx.
          validateStatus: (_) => true,
        ),
        onSendProgress: (sent, total) {
          if (controller.isClosed) return;
          // dio reports `total` from Content-Length; fall back to fileLength
          // for safety.
          final reportedTotal = total > 0 ? total : fileLength;
          controller.add(UploadProgress(
            fraction:
                reportedTotal == 0 ? 0 : sent / reportedTotal,
            bytesSent: sent,
            bytesTotal: reportedTotal,
          ));
        },
      );

      if (response.statusCode != 200) {
        final body = response.data ?? '';
        throw UploadException(
          'S3 PUT ${response.statusCode}: ${body.isEmpty ? '(empty)' : body}',
          code: 'put_${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      // Network-layer failures (timeout, connection lost, TLS, etc.) never
      // reach the validateStatus path above.
      final code = switch (e.type) {
        DioExceptionType.sendTimeout => 'upload_send_timeout',
        DioExceptionType.receiveTimeout => 'upload_recv_timeout',
        DioExceptionType.connectionTimeout => 'upload_connect_timeout',
        DioExceptionType.connectionError => 'upload_connection_error',
        DioExceptionType.cancel => 'upload_cancelled',
        _ => 'upload_io_error',
      };
      throw UploadException(e.message ?? e.type.toString(), code: code);
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
