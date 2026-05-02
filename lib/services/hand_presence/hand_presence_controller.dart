import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'hand_presence_state.dart';

/// Smooths raw MediaPipe detections into a debounced presence state.
///
/// Two pieces of filtering, applied in order on every detector tick:
///   1. Per-hand sliding-window hysteresis (§3.2): a fixed-size circular
///      buffer per hand. `absent → present` requires `count ≥ enterThreshold`;
///      `present → absent` requires `count ≤ exitThreshold`. In between, the
///      previous flag is held — this is what survives single-frame dropouts.
///   2. Composite-state revert-debounce (§4.1): a candidate transition must
///      be confirmed by the next detector tick, otherwise it is cancelled.
///      Catches the rare bounce that hysteresis still lets through.
///
/// Transitions are emitted on the [transitions] stream and `notifyListeners`
/// is called whenever the committed [state] changes.
class HandPresenceController extends ChangeNotifier {
  HandPresenceController({
    this.windowSize = 6,
    this.enterThreshold = 3,
    this.exitThreshold = 1,
    this.warmupTicks = 3,
    this.minScore = 0.6,
    this.maxOutsideMargin = 0.05,
  })  : assert(windowSize > 0),
        assert(enterThreshold > exitThreshold),
        assert(enterThreshold <= windowSize);

  final int windowSize;
  final int enterThreshold;
  final int exitThreshold;
  final int warmupTicks;
  final double minScore;
  final double maxOutsideMargin;

  final ListQueue<int> _leftWindow = ListQueue<int>();
  final ListQueue<int> _rightWindow = ListQueue<int>();

  bool _leftPresent = false;
  bool _rightPresent = false;

  HandPresenceState _committedState = HandPresenceState.none;
  HandPresenceState get state => _committedState;

  HandPresenceState? _pendingState;

  int _tickCount = 0;
  int get tickCount => _tickCount;
  bool get isWarmedUp => _tickCount >= warmupTicks;

  final StreamController<HandPresenceTransition> _transitions =
      StreamController<HandPresenceTransition>.broadcast();
  Stream<HandPresenceTransition> get transitions => _transitions.stream;

  /// Reset windows and warm-up. Used on backgrounding, camera reconfiguration,
  /// or when the detector restarts (§6.6).
  void reset() {
    _leftWindow.clear();
    _rightWindow.clear();
    _leftPresent = false;
    _rightPresent = false;
    _pendingState = null;
    _tickCount = 0;
    if (_committedState != HandPresenceState.none) {
      _committedState = HandPresenceState.none;
      notifyListeners();
    }
  }

  /// Feed one detector tick. `hands` may contain 0, 1, or 2 detections.
  void onDetectorTick({
    required List<HandDetection> hands,
    required int timestampMs,
  }) {
    _tickCount++;

    bool leftDetected = false;
    bool rightDetected = false;

    // Track which handedness has the highest-confidence in-frame detection,
    // in case MediaPipe returns two of the same handedness (§8: two-left-hands
    // case). We keep the canonical one and drop duplicates.
    double bestLeftScore = -1;
    double bestRightScore = -1;
    for (final hand in hands) {
      if (hand.score < minScore) continue;
      if (_isCenterOutside(hand.bboxCenterX, hand.bboxCenterY)) continue;
      if (hand.isLeftHand) {
        if (hand.score > bestLeftScore) {
          bestLeftScore = hand.score;
          leftDetected = true;
        }
      } else {
        if (hand.score > bestRightScore) {
          bestRightScore = hand.score;
          rightDetected = true;
        }
      }
    }

    _push(_leftWindow, leftDetected ? 1 : 0);
    _push(_rightWindow, rightDetected ? 1 : 0);

    _leftPresent = _updatePresence(_leftPresent, _leftWindow);
    _rightPresent = _updatePresence(_rightPresent, _rightWindow);

    final raw = _composeState(_leftPresent, _rightPresent);

    if (_tickCount < warmupTicks) return;

    _evaluateTransition(raw, timestampMs);
  }

  bool _isCenterOutside(double cx, double cy) {
    return cx < -maxOutsideMargin ||
        cx > 1.0 + maxOutsideMargin ||
        cy < -maxOutsideMargin ||
        cy > 1.0 + maxOutsideMargin;
  }

  void _push(ListQueue<int> q, int value) {
    q.addLast(value);
    while (q.length > windowSize) {
      q.removeFirst();
    }
  }

  bool _updatePresence(bool current, ListQueue<int> window) {
    final count = window.fold<int>(0, (a, b) => a + b);
    if (count >= enterThreshold) return true;
    if (count <= exitThreshold) return false;
    return current;
  }

  HandPresenceState _composeState(bool left, bool right) {
    if (left && right) return HandPresenceState.both;
    if (left) return HandPresenceState.leftOnly;
    if (right) return HandPresenceState.rightOnly;
    return HandPresenceState.none;
  }

  void _evaluateTransition(HandPresenceState raw, int timestampMs) {
    if (_pendingState == null) {
      if (raw == _committedState) return;
      _pendingState = raw;
      return;
    }

    final pending = _pendingState!;

    if (raw == pending) {
      // Confirmed by a subsequent tick — commit.
      final from = _committedState;
      _committedState = raw;
      _pendingState = null;
      _transitions.add(HandPresenceTransition(
        from: from,
        to: raw,
        timestampMs: timestampMs,
      ));
      notifyListeners();
      return;
    }

    if (raw == _committedState) {
      // Reverted before confirmation — drop pending.
      _pendingState = null;
      return;
    }

    // Bounced to a third state — replace pending and wait again.
    _pendingState = raw;
  }

  @override
  void dispose() {
    _transitions.close();
    super.dispose();
  }
}
