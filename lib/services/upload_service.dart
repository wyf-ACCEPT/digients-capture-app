import 'dart:async';
import 'dart:math';

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

abstract class UploadService {
  // Streams progress events while the upload is in flight; closes normally
  // on success and emits an [UploadException] via addError on failure.
  Stream<UploadProgress> upload({
    required String sessionId,
    required String archivePath,
    required int sizeBytes,
    required double durationSec,
    required String accessToken,
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
    required String accessToken,
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

// Real backend implementation. Stubbed for now — Phase C's first cut is mock-
// only so Jason can iterate on UX. Wire init/PUT/complete once UX is locked.
class HttpUploadService implements UploadService {
  final String baseUrl;

  HttpUploadService({required this.baseUrl});

  @override
  Stream<UploadProgress> upload({
    required String sessionId,
    required String archivePath,
    required int sizeBytes,
    required double durationSec,
    required String accessToken,
  }) {
    final controller = StreamController<UploadProgress>();
    controller.addError(UploadException(
      'HttpUploadService not yet wired (Phase C is mock-only).',
      code: 'not_implemented',
    ));
    controller.close();
    return controller.stream;
  }
}
