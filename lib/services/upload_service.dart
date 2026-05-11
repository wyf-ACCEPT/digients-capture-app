import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

class UploadProgress {
  final double fraction;
  final int bytesSent;
  final int bytesTotal;

  const UploadProgress({
    required this.fraction,
    required this.bytesSent,
    required this.bytesTotal,
  });

  @override
  String toString() =>
      'UploadProgress(${(fraction * 100).toStringAsFixed(1)}%, $bytesSent/$bytesTotal)';
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
//      Body is streamed off disk, not loaded into memory, so a 3 GB take
//      doesn't OOM the App. Progress events are emitted as bytes flow into
//      the request sink — the network rate IS the progress rate.
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
  final Duration _controlTimeout;
  final Duration _uploadTimeout;

  HttpUploadService({
    required this.baseUrl,
    required DeviceIdService deviceId,
    http.Client? client,
    Duration controlTimeout = const Duration(seconds: 30),
    Duration uploadTimeout = const Duration(minutes: 30),
  })  : _deviceId = deviceId,
        _client = client ?? http.Client(),
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
    if (res.statusCode != 200) {
      throw _httpException(res, fallbackCode: 'init_failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> _putToS3({
    required StreamController<UploadProgress> controller,
    required String uploadUrl,
    required File file,
    required int fileLength,
  }) async {
    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers['Content-Type'] = 'application/gzip';
    request.contentLength = fileLength;

    // Drain the file into the request sink in the background. The http client
    // pumps the sink as the upload progresses, providing natural backpressure.
    // Progress events fire as each chunk hits the sink, which approximates
    // network rate closely enough for a moving progress bar.
    var sent = 0;
    final pump = () async {
      try {
        await for (final chunk in file.openRead()) {
          if (controller.isClosed) break;
          request.sink.add(chunk);
          sent += chunk.length;
          if (!controller.isClosed) {
            controller.add(UploadProgress(
              fraction: fileLength == 0 ? 0 : sent / fileLength,
              bytesSent: sent,
              bytesTotal: fileLength,
            ));
          }
        }
      } catch (e) {
        request.sink.addError(e);
      } finally {
        await request.sink.close();
      }
    }();

    final response =
        await _client.send(request).timeout(_uploadTimeout);
    await pump; // ensure file stream completed (or failed)
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw UploadException(
        'S3 PUT ${response.statusCode}: ${body.isEmpty ? '(empty)' : body}',
        code: 'put_${response.statusCode}',
      );
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
