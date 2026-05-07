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
    // Lowered from 0.6 to 0.4 so legitimate hands whose MediaPipe
    // confidence dips into the 0.4–0.55 band on the 13 Pro Max ultrawide
    // (periphery distortion) still register. The spatial-handedness +
    // bbox-proximity guards downstream keep false positives bounded.
    this.minScore = 0.4,
    this.maxOutsideMargin = 0.05,
    this.spatialHandednessMargin = 0.15,
    this.oppositeHandMislabelProximity = 0.18,
    this.oppositeHandMislabelRecency = 2,
  })  : assert(windowSize > 0),
        assert(enterThreshold > exitThreshold),
        assert(enterThreshold <= windowSize);

  final int windowSize;
  final int enterThreshold;
  final int exitThreshold;
  final int warmupTicks;
  final double minScore;
  final double maxOutsideMargin;

  /// MediaPipe occasionally flips its handedness label during fast motion
  /// or partial occlusion — e.g. a real right hand exiting frame may be
  /// briefly classified as left, which then drives a phantom "Left hand
  /// enters / exits the view" cue.
  ///
  /// On the rear-facing head-mounted camera this app uses, the user's
  /// anatomical left hand sits on the left half of the image and the
  /// right hand on the right. We discard detections whose handedness
  /// label contradicts the bbox center's spatial position by more than
  /// this margin: a "left" detection with cx > 0.5 + margin (or "right"
  /// with cx < 0.5 - margin) is dropped rather than registered as the
  /// other hand. Set very high (≥ 0.5) to disable.
  final double spatialHandednessMargin;

  /// A second guard against handedness mislabels that the spatial gate
  /// can't catch — when a right hand occupies the central overlap zone
  /// (cx ∈ [0.35, 0.65]) and gets briefly labeled "left" with the same
  /// bbox, the spatial gate lets it through. This bbox-proximity check
  /// drops such a detection when the *opposite* hand was active at a
  /// nearly-identical bbox in the past few ticks.
  ///
  /// [oppositeHandMislabelProximity] is the max bbox-center delta (image-
  /// normalized) for "same hand". A typical hand bbox spans ~0.2 of the
  /// frame, so 0.18 is roughly "within one hand-width".
  /// [oppositeHandMislabelRecency] is the max gap (in detector ticks) for
  /// the opposite hand to be considered "just seen". 2 ticks ≈ 200 ms at
  /// the default 10 fps — long enough to bridge a single dropped frame
  /// without authorizing arbitrarily-old positions.
  final double oppositeHandMislabelProximity;
  final int oppositeHandMislabelRecency;

  final ListQueue<int> _leftWindow = ListQueue<int>();
  final ListQueue<int> _rightWindow = ListQueue<int>();

  bool _leftPresent = false;
  bool _rightPresent = false;

  // Last bbox center for each handedness, used by the opposite-hand
  // mislabel guard. Initialized to a tick value far enough in the past
  // that the recency check always returns false on the first invocation.
  double? _lastLeftCx;
  double? _lastLeftCy;
  int _lastLeftSeenTick = -1 << 20;
  double? _lastRightCx;
  double? _lastRightCy;
  int _lastRightSeenTick = -1 << 20;

  HandPresenceState _committedState = HandPresenceState.none;
  HandPresenceState get state => _committedState;

  HandPresenceState? _pendingState;

  int _tickCount = 0;
  int get tickCount => _tickCount;
  bool get isWarmedUp => _tickCount >= warmupTicks;

  final StreamController<HandPresenceTransition> _transitions =
      StreamController<HandPresenceTransition>.broadcast();
  Stream<HandPresenceTransition> get transitions => _transitions.stream;

  /// Per-hand enter/exit events, emitted after warmup whenever a single
  /// hand's presence flag flips. Drives finer-grained voice cues
  /// ("Left hand enters the view", etc.) while the composite [transitions]
  /// stream still drives tones, haptics, and the colored border.
  final StreamController<HandSideTransition> _sideTransitions =
      StreamController<HandSideTransition>.broadcast();
  Stream<HandSideTransition> get sideTransitions => _sideTransitions.stream;

  /// Resolves once the smoothing window has filled (i.e. warmup completes)
  /// with the first raw composite state. Used by the recording screen to
  /// announce the initial hand presence even when it stays at NONE — the
  /// transition stream alone doesn't fire in that case.
  ///
  /// Recreated on [reset] so a backgrounded-and-resumed session re-announces.
  Completer<HandPresenceState> _firstStateReady =
      Completer<HandPresenceState>();
  Future<HandPresenceState> get firstStateReady => _firstStateReady.future;

  /// Reset windows and warm-up. Used on backgrounding, camera reconfiguration,
  /// or when the detector restarts (§6.6).
  void reset() {
    _leftWindow.clear();
    _rightWindow.clear();
    _leftPresent = false;
    _rightPresent = false;
    _pendingState = null;
    _tickCount = 0;
    _lastLeftCx = null;
    _lastLeftCy = null;
    _lastLeftSeenTick = -1 << 20;
    _lastRightCx = null;
    _lastRightCy = null;
    _lastRightSeenTick = -1 << 20;
    // Abandon the prior completer (if not yet completed, its future will
    // never resolve — fine, the screen disposes alongside this controller).
    // A fresh completer here means any post-reset listener gets the next
    // first-ready state.
    _firstStateReady = Completer<HandPresenceState>();
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

    // First pass: split detections by handedness after the score / out-of-frame
    // / spatial-half filters. We need to know whether *both* sides are present
    // before the proximity-mislabel filter runs — that filter must only apply
    // when one side is exclusively present this tick (otherwise legitimate
    // both-hands-at-similar-positions captures get suppressed).
    final leftCandidates = <HandDetection>[];
    final rightCandidates = <HandDetection>[];
    for (final hand in hands) {
      if (hand.score < minScore) continue;
      if (_isCenterOutside(hand.bboxCenterX, hand.bboxCenterY)) continue;
      if (_handednessContradictsPosition(hand.isLeftHand, hand.bboxCenterX)) {
        continue;
      }
      if (hand.isLeftHand) {
        leftCandidates.add(hand);
      } else {
        rightCandidates.add(hand);
      }
    }

    // Apply the proximity-mislabel filter only when one side is alone this
    // tick. With both sides represented we trust the labels — they can't both
    // be the same hand.
    if (leftCandidates.isNotEmpty && rightCandidates.isEmpty) {
      leftCandidates.removeWhere(_isLikelyOppositeHandMislabel);
    } else if (rightCandidates.isNotEmpty && leftCandidates.isEmpty) {
      rightCandidates.removeWhere(_isLikelyOppositeHandMislabel);
    }

    // Pick the highest-scoring detection per side (handles MediaPipe returning
    // duplicate handedness — §8: two-left-hands).
    double bestLeftScore = -1;
    double bestRightScore = -1;
    double? bestLeftCx, bestLeftCy;
    double? bestRightCx, bestRightCy;
    for (final hand in leftCandidates) {
      if (hand.score > bestLeftScore) {
        bestLeftScore = hand.score;
        bestLeftCx = hand.bboxCenterX;
        bestLeftCy = hand.bboxCenterY;
        leftDetected = true;
      }
    }
    for (final hand in rightCandidates) {
      if (hand.score > bestRightScore) {
        bestRightScore = hand.score;
        bestRightCx = hand.bboxCenterX;
        bestRightCy = hand.bboxCenterY;
        rightDetected = true;
      }
    }

    // Stash positions for the next tick's opposite-hand mislabel guard.
    if (leftDetected) {
      _lastLeftCx = bestLeftCx;
      _lastLeftCy = bestLeftCy;
      _lastLeftSeenTick = _tickCount;
    }
    if (rightDetected) {
      _lastRightCx = bestRightCx;
      _lastRightCy = bestRightCy;
      _lastRightSeenTick = _tickCount;
    }

    _push(_leftWindow, leftDetected ? 1 : 0);
    _push(_rightWindow, rightDetected ? 1 : 0);

    final wasLeftPresent = _leftPresent;
    final wasRightPresent = _rightPresent;
    _leftPresent = _updatePresence(_leftPresent, _leftWindow);
    _rightPresent = _updatePresence(_rightPresent, _rightWindow);

    final raw = _composeState(_leftPresent, _rightPresent);

    if (_tickCount < warmupTicks) return;

    if (_tickCount == warmupTicks && !_firstStateReady.isCompleted) {
      _firstStateReady.complete(raw);
    }

    // Per-hand events fire only after warmup so the initial composite-state
    // announcement isn't clobbered by enter cues from the warmup ramp-up.
    if (_tickCount > warmupTicks) {
      if (_leftPresent != wasLeftPresent) {
        _sideTransitions.add(HandSideTransition(
          side: HandSide.left,
          entered: _leftPresent,
          timestampMs: timestampMs,
        ));
      }
      if (_rightPresent != wasRightPresent) {
        _sideTransitions.add(HandSideTransition(
          side: HandSide.right,
          entered: _rightPresent,
          timestampMs: timestampMs,
        ));
      }
    }

    _evaluateTransition(raw, timestampMs);
  }

  bool _isCenterOutside(double cx, double cy) {
    return cx < -maxOutsideMargin ||
        cx > 1.0 + maxOutsideMargin ||
        cy < -maxOutsideMargin ||
        cy > 1.0 + maxOutsideMargin;
  }

  bool _handednessContradictsPosition(bool isLeftHand, double cx) {
    if (isLeftHand) {
      return cx > 0.5 + spatialHandednessMargin;
    }
    return cx < 0.5 - spatialHandednessMargin;
  }

  /// Returns true if a detection labeled as one handedness sits at a bbox
  /// center close to where the *opposite* handedness was just seen, AND
  /// this side's hand hasn't been seen for a few ticks. That's the
  /// signature of MediaPipe flipping its handedness label on the same
  /// hand mid-motion (the spatial-half gate alone misses cases where the
  /// hand is in the central overlap zone). When a hand of this label was
  /// seen recently — i.e. both hands are concurrently active or briefly
  /// clasped — we trust the new detection and don't apply the guard.
  bool _isLikelyOppositeHandMislabel(HandDetection hand) {
    final lastSelfTick =
        hand.isLeftHand ? _lastLeftSeenTick : _lastRightSeenTick;
    if (_tickCount - lastSelfTick <= oppositeHandMislabelRecency) {
      return false;
    }
    final lastOppositeTick =
        hand.isLeftHand ? _lastRightSeenTick : _lastLeftSeenTick;
    if (_tickCount - lastOppositeTick > oppositeHandMislabelRecency) {
      return false;
    }
    final oppCx = hand.isLeftHand ? _lastRightCx : _lastLeftCx;
    final oppCy = hand.isLeftHand ? _lastRightCy : _lastLeftCy;
    if (oppCx == null || oppCy == null) return false;
    final dx = (hand.bboxCenterX - oppCx).abs();
    final dy = (hand.bboxCenterY - oppCy).abs();
    return dx < oppositeHandMislabelProximity &&
        dy < oppositeHandMislabelProximity;
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
    _sideTransitions.close();
    super.dispose();
  }
}
