/// Composite hand-presence state derived from per-hand presence flags.
///
/// `leftOnly` / `rightOnly` are anatomical (the person's left/right hand),
/// not image-relative. The native bridge is responsible for delivering
/// anatomical handedness; the controller does not flip labels.
enum HandPresenceState { both, leftOnly, rightOnly, none }

/// Anatomical side of a single hand.
enum HandSide { left, right }

/// One detection from the native MediaPipe bridge.
class HandDetection {
  final bool isLeftHand;
  final double score;
  final double bboxCenterX;
  final double bboxCenterY;

  const HandDetection({
    required this.isLeftHand,
    required this.score,
    required this.bboxCenterX,
    required this.bboxCenterY,
  });
}

/// Emitted when the state machine commits a composite transition (post-debounce).
class HandPresenceTransition {
  final HandPresenceState from;
  final HandPresenceState to;
  final int timestampMs;

  const HandPresenceTransition({
    required this.from,
    required this.to,
    required this.timestampMs,
  });

  @override
  String toString() =>
      'HandPresenceTransition($from → $to @ ${timestampMs}ms)';
}

/// Emitted when a single hand crosses the per-hand presence threshold (i.e.
/// the hysteresis window confirmed it entered or exited the view).
///
/// Per-hand events fire only after the warmup ticks have completed, so the
/// initial composite-state announcement isn't immediately overshadowed by a
/// pile of "left enter / right enter" events while the buffer fills.
class HandSideTransition {
  final HandSide side;
  final bool entered;
  final int timestampMs;

  const HandSideTransition({
    required this.side,
    required this.entered,
    required this.timestampMs,
  });

  @override
  String toString() =>
      'HandSideTransition(${side.name} ${entered ? 'enter' : 'exit'} @ ${timestampMs}ms)';
}
