import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hand_presence_controller.dart';
import 'hand_presence_state.dart';

/// Bridges the native MediaPipe detector to a [HandPresenceController].
///
/// The native side (iOS: HandPresenceDetector.swift, Android:
/// HandPresenceDetector.kt) emits one event per detector tick over an
/// [EventChannel]. Each event carries the per-hand list and a timestamp;
/// this service unpacks it and pushes a tick into the controller, which
/// runs the smoothing + state machine.
class HandPresenceDetectorService extends ChangeNotifier {
  HandPresenceDetectorService({required this.controller});

  final HandPresenceController controller;

  /// Total ticks received from the native detector since [start] was called.
  int get ticksReceived => _ticksReceived;
  /// Highest hand count seen on a single tick — useful diagnostic to confirm
  /// MediaPipe is finding hands at all (independent of the smoothing layer).
  int get maxHandsSeen => _maxHandsSeen;
  /// Best (highest) score seen on any detection so far.
  double get maxScoreSeen => _maxScoreSeen;
  /// Highest raw hand count returned directly by MediaPipe (before our
  /// filtering). Useful for telling apart "MediaPipe found nothing" vs.
  /// "MediaPipe found something but our filter rejected it".
  int get maxRawHandCount => _maxRawHandCount;
  /// Whether the most recent event reported the model as loaded.
  bool get lastModelLoaded => _lastModelLoaded;

  static const _events = EventChannel('hand_presence/events');
  static const _control = MethodChannel('hand_presence/control');

  StreamSubscription<dynamic>? _sub;

  void start() {
    _sub?.cancel();
    _sub = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('[HandPresence] event stream error: $error');
        }
      },
    );
  }

  /// Cancel the event subscription so no further ticks reach the
  /// controller. Used between takes on the vol-btn-ctrl flow so per-hand
  /// voice cues don't fire while the popup is up or the screen is armed.
  /// Re-callable: pair with [start] to resume.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> setTargetFps(double fps) async {
    try {
      await _control.invokeMethod<void>('setTargetFps', fps);
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[HandPresence] setTargetFps failed: $e');
    }
  }

  int _ticksReceived = 0;
  int _maxHandsSeen = 0;
  double _maxScoreSeen = 0.0;
  int _maxRawHandCount = 0;
  bool _lastModelLoaded = false;

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final timestampMs = (raw['timestampMs'] as num?)?.toInt();
    if (timestampMs == null) return;

    final handsRaw = raw['hands'];
    final hands = <HandDetection>[];
    if (handsRaw is List) {
      for (final h in handsRaw) {
        if (h is! Map) continue;
        final isLeft = h['isLeftHand'] as bool? ?? false;
        final score = (h['score'] as num?)?.toDouble() ?? 0.0;
        final cx = (h['bboxCenterX'] as num?)?.toDouble() ?? 0.5;
        final cy = (h['bboxCenterY'] as num?)?.toDouble() ?? 0.5;
        hands.add(HandDetection(
          isLeftHand: isLeft,
          score: score,
          bboxCenterX: cx,
          bboxCenterY: cy,
        ));
      }
    }

    _ticksReceived++;
    if (hands.length > _maxHandsSeen) _maxHandsSeen = hands.length;
    for (final h in hands) {
      if (h.score > _maxScoreSeen) _maxScoreSeen = h.score;
    }
    final rawCount = (raw['rawHandCount'] as num?)?.toInt() ?? 0;
    if (rawCount > _maxRawHandCount) _maxRawHandCount = rawCount;
    _lastModelLoaded = (raw['modelLoaded'] as bool?) ?? _lastModelLoaded;
    if (kDebugMode && (_ticksReceived <= 5 || _ticksReceived % 30 == 0)) {
      debugPrint(
          '[HandPresence] tick $_ticksReceived: ${hands.length} hand(s)'
          '${hands.isNotEmpty ? " [${hands.map((h) => "${h.isLeftHand ? "L" : "R"}@${h.score.toStringAsFixed(2)}").join(",")}]" : ""}'
          ' | controller.state=${controller.state}');
    }
    controller.onDetectorTick(hands: hands, timestampMs: timestampMs);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
