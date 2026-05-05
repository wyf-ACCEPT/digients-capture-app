import 'package:flutter_test/flutter_test.dart';

import 'package:digients_app/services/hand_presence/hand_presence_controller.dart';
import 'package:digients_app/services/hand_presence/hand_presence_state.dart';

HandDetection _hand({required bool left, double score = 0.9}) {
  return HandDetection(
    isLeftHand: left,
    score: score,
    bboxCenterX: 0.5,
    bboxCenterY: 0.5,
  );
}

void _feed(
  HandPresenceController c, {
  required bool left,
  required bool right,
  required int t,
}) {
  c.onDetectorTick(
    hands: [
      if (left) _hand(left: true),
      if (right) _hand(left: false),
    ],
    timestampMs: t,
  );
}

/// Runs `pattern` of (left, right) booleans through the controller while
/// recording every committed transition. Awaits microtask pump after the loop
/// so broadcast-stream events have time to land before we cancel.
Future<List<HandPresenceTransition>> _runPattern(
  HandPresenceController c,
  List<List<bool>> pattern, {
  int startMs = 0,
  int stepMs = 100,
}) async {
  final transitions = <HandPresenceTransition>[];
  final sub = c.transitions.listen(transitions.add);
  var t = startMs;
  for (final p in pattern) {
    _feed(c, left: p[0], right: p[1], t: t);
    // Pump microtasks so each broadcast-stream event reaches the listener
    // before the next tick fires.
    await Future<void>.delayed(Duration.zero);
    t += stepMs;
  }
  await sub.cancel();
  return transitions;
}

void main() {
  group('warm-up', () {
    test('no transition fires before warmupTicks', () async {
      final c = HandPresenceController();
      final transitions = await _runPattern(c, List.filled(2, [true, true]));
      expect(transitions, isEmpty);
      expect(c.state, HandPresenceState.none);
      c.dispose();
    });

    test('first NONE→BOTH commit happens after warm-up + 1 confirm tick',
        () async {
      final c = HandPresenceController();
      final transitions = await _runPattern(
        c,
        List.filled(6, [true, true]),
      );
      expect(transitions.length, 1);
      expect(transitions.first.from, HandPresenceState.none);
      expect(transitions.first.to, HandPresenceState.both);
      expect(transitions.first.timestampMs, greaterThanOrEqualTo(300));
      expect(c.state, HandPresenceState.both);
      c.dispose();
    });
  });

  group('hysteresis (single-frame dropouts)', () {
    test('one missed frame in a steady BOTH stream does not flip state',
        () async {
      final c = HandPresenceController();
      await _runPattern(c, List.filled(6, [true, true]));
      expect(c.state, HandPresenceState.both);

      final transitions = await _runPattern(
        c,
        [
          [true, false],
          [true, true],
          [true, true],
          [true, true],
        ],
        startMs: 600,
      );
      expect(transitions, isEmpty);
      expect(c.state, HandPresenceState.both);
      c.dispose();
    });

    test('two missed frames in a row also do not flip', () async {
      final c = HandPresenceController();
      await _runPattern(c, List.filled(6, [true, true]));

      final transitions = await _runPattern(
        c,
        [
          [true, false],
          [true, false],
          [true, true],
          [true, true],
          [true, true],
        ],
        startMs: 600,
      );
      expect(transitions, isEmpty);
      expect(c.state, HandPresenceState.both);
      c.dispose();
    });

    test('sustained right-hand absence flips BOTH → LEFT_ONLY', () async {
      final c = HandPresenceController();
      await _runPattern(c, List.filled(6, [true, true]));

      final transitions = await _runPattern(
        c,
        List.filled(8, [true, false]),
        startMs: 600,
      );
      expect(transitions.length, 1);
      expect(transitions.first.from, HandPresenceState.both);
      expect(transitions.first.to, HandPresenceState.leftOnly);
      expect(c.state, HandPresenceState.leftOnly);
      c.dispose();
    });
  });

  group('low-confidence + out-of-frame filtering', () {
    test('detections with score below minScore are discarded', () async {
      final c = HandPresenceController(minScore: 0.6);
      for (var i = 0; i < 20; i++) {
        c.onDetectorTick(
          hands: const [
            HandDetection(
                isLeftHand: true, score: 0.4, bboxCenterX: 0.5, bboxCenterY: 0.5),
            HandDetection(
                isLeftHand: false, score: 0.4, bboxCenterX: 0.5, bboxCenterY: 0.5),
          ],
          timestampMs: i * 100,
        );
      }
      expect(c.state, HandPresenceState.none);
      c.dispose();
    });

    test('out-of-frame bbox center is discarded', () async {
      final c = HandPresenceController();
      for (var i = 0; i < 20; i++) {
        c.onDetectorTick(
          hands: const [
            HandDetection(
                isLeftHand: true, score: 0.9, bboxCenterX: 1.5, bboxCenterY: 0.5),
          ],
          timestampMs: i * 100,
        );
      }
      expect(c.state, HandPresenceState.none);
      c.dispose();
    });
  });

  group('revert-debounce (§4.1)', () {
    test('a one-tick bounce is cancelled (no commit)', () async {
      // Use windowSize=1 so the controller's hysteresis is effectively
      // disabled: each tick directly drives raw state. This isolates the
      // revert-debounce logic, which is the unit under test here.
      final c = HandPresenceController(
        windowSize: 1,
        enterThreshold: 1,
        exitThreshold: 0,
        warmupTicks: 0,
      );

      // Tick 0: BOTH visible. raw=BOTH. committed=NONE. Set pending=BOTH.
      // Tick 1: nothing visible. raw=NONE = committed. → cancel pending.
      // Tick 2: still nothing visible. nothing pending; raw==committed.
      final transitions = await _runPattern(
        c,
        [
          [true, true],
          [false, false],
          [false, false],
        ],
      );
      expect(transitions, isEmpty);
      expect(c.state, HandPresenceState.none);
      c.dispose();
    });

    test('a two-tick stable change does commit', () async {
      final c = HandPresenceController(
        windowSize: 1,
        enterThreshold: 1,
        exitThreshold: 0,
        warmupTicks: 0,
      );

      final transitions = await _runPattern(
        c,
        [
          [true, true],
          [true, true],
        ],
      );
      expect(transitions.length, 1);
      expect(transitions.first.to, HandPresenceState.both);
      c.dispose();
    });

    test('a third-state bounce replaces the pending candidate', () async {
      final c = HandPresenceController(
        windowSize: 1,
        enterThreshold: 1,
        exitThreshold: 0,
        warmupTicks: 0,
      );

      // T0: pending=BOTH (raw=BOTH, committed=NONE)
      // T1: raw=LEFT_ONLY ≠ pending, ≠ committed → replace pending=LEFT_ONLY
      // T2: raw=LEFT_ONLY == pending → COMMIT NONE→LEFT_ONLY
      final transitions = await _runPattern(
        c,
        [
          [true, true],
          [true, false],
          [true, false],
        ],
      );
      expect(transitions.length, 1);
      expect(transitions.first.to, HandPresenceState.leftOnly);
      c.dispose();
    });
  });

  group('state composition', () {
    test('right-only → BOTH → left-only emits three transitions', () async {
      final c = HandPresenceController();

      // Phase 1: warm up with right only.
      var transitions = await _runPattern(c, List.filled(8, [false, true]));
      expect(transitions.length, 1);
      expect(transitions.last.to, HandPresenceState.rightOnly);

      // Phase 2: add left → BOTH.
      transitions = await _runPattern(
        c,
        List.filled(8, [true, true]),
        startMs: 800,
      );
      expect(transitions.length, 1);
      expect(transitions.last.from, HandPresenceState.rightOnly);
      expect(transitions.last.to, HandPresenceState.both);

      // Phase 3: drop right → LEFT_ONLY.
      transitions = await _runPattern(
        c,
        List.filled(8, [true, false]),
        startMs: 1600,
      );
      expect(transitions.length, 1);
      expect(transitions.last.from, HandPresenceState.both);
      expect(transitions.last.to, HandPresenceState.leftOnly);

      c.dispose();
    });
  });

  group('reset', () {
    test('reset clears windows and returns to NONE warm-up state', () async {
      final c = HandPresenceController();
      await _runPattern(c, List.filled(6, [true, true]));
      expect(c.state, HandPresenceState.both);

      c.reset();
      expect(c.state, HandPresenceState.none);
      expect(c.tickCount, 0);
      expect(c.isWarmedUp, false);

      // After reset, warm-up applies again.
      final transitions = await _runPattern(c, List.filled(2, [true, true]));
      expect(transitions, isEmpty);
      c.dispose();
    });
  });

  group('duplicate-handedness handling (§8 two-left-hands)', () {
    test('two left-hand detections per tick still register as LEFT_ONLY',
        () async {
      final c = HandPresenceController();

      var t = 0;
      for (var i = 0; i < 8; i++) {
        c.onDetectorTick(
          hands: const [
            HandDetection(
                isLeftHand: true,
                score: 0.95,
                bboxCenterX: 0.3,
                bboxCenterY: 0.5),
            HandDetection(
                isLeftHand: true,
                score: 0.85,
                bboxCenterX: 0.7,
                bboxCenterY: 0.5),
          ],
          timestampMs: t,
        );
        await Future<void>.delayed(Duration.zero);
        t += 100;
      }
      expect(c.state, HandPresenceState.leftOnly);
      c.dispose();
    });
  });
}
