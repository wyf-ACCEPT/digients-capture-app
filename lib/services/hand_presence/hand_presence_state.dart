/// Composite hand-presence state derived from per-hand presence flags.
///
/// `leftOnly` / `rightOnly` are anatomical (the person's left/right hand),
/// not image-relative. The native bridge is responsible for delivering
/// anatomical handedness; the controller does not flip labels.
enum HandPresenceState { both, leftOnly, rightOnly, none }

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

/// Emitted when the state machine commits a transition (post-debounce).
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
