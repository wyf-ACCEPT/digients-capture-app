import 'dart:async';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Listens for hardware volume-button presses on iOS / Android and emits
/// them as opaque "press" events. The vol-button control flow on
/// `feat/vol-btn-ctrl` uses these to arm, start, and stop recording so
/// the user can drive a session entirely with side-buttons while the
/// phone is head-mounted.
///
/// iOS doesn't expose Vol+/Vol- key events to apps directly. The standard
/// trick is to KVO `AVAudioSession.outputVolume` and treat *any* change
/// as a press. Several pieces of noise are filtered out so we don't
/// mistake a system-driven change for a real press:
///
///   • A startup grace window after [start] swallows any chatter from the
///     initial snap-to-locked animation and the audio session activating
///     (otherwise the screen would auto-start recording the moment it
///     entered ARMED).
///   • A second suppression window after every snap-back covers iOS
///     emitting multiple intermediate volume values during its own
///     animation toward [lockedVolume].
///   • A magnitude threshold filters micro-jitters: a true Vol+/Vol-
///     press changes outputVolume by 1/16 ≈ 0.0625, so anything closer
///     to [lockedVolume] than [pressDelta] is ignored.
///
/// Direction (Vol+ vs Vol-) isn't exposed and isn't needed — both
/// arm/start/stop the same way per the feature spec.
class VolumeButtonService {
  VolumeButtonService({
    this.lockedVolume = 0.5,
    this.startupGrace = const Duration(milliseconds: 700),
    this.snapbackGrace = const Duration(milliseconds: 350),
    this.pressDelta = 0.04,
    this.deadband = const Duration(milliseconds: 200),
  });

  /// Mid-range volume the service holds while active. 0.5 leaves headroom
  /// in either direction so a press is always observable.
  final double lockedVolume;

  /// Window swallowed at the very start of [start] — covers the snap-to-
  /// locked animation plus any audio-session noise that lands shortly
  /// after the listener subscribes.
  final Duration startupGrace;

  /// Window swallowed after each snap-back. iOS animates setVolume over
  /// ~200 ms and may emit several intermediate values; we ignore them all
  /// until the animation settles.
  final Duration snapbackGrace;

  /// Minimum absolute deviation from [lockedVolume] before an event is
  /// treated as a press. iOS emits volume in 1/16 ≈ 0.0625 increments so
  /// 0.04 reliably catches presses while filtering sub-step jitter.
  final double pressDelta;

  /// Ignore presses arriving within this window of the previous one — a
  /// belt-and-braces guard for any noise the time-windowed suppression
  /// doesn't catch.
  final Duration deadband;

  StreamSubscription<double>? _sub;
  final StreamController<void> _presses = StreamController<void>.broadcast();
  Stream<void> get onPress => _presses.stream;

  bool _active = false;
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPressAt = DateTime.fromMillisecondsSinceEpoch(0);
  double? _restoreVolume;

  /// Begin listening. Captures the user's current volume so [stop] can
  /// restore it, then locks volume to [lockedVolume] and subscribes to
  /// change events. Idempotent.
  Future<void> start() async {
    if (_active) return;
    _active = true;
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
    } catch (_) {}
    try {
      _restoreVolume = await FlutterVolumeController.getVolume();
    } catch (_) {
      _restoreVolume = null;
    }
    _suppress(startupGrace);
    await _setLocked();
    _sub = FlutterVolumeController.addListener(
      _onVolumeChanged,
      emitOnStart: false,
    );
  }

  /// Stop listening and restore the user's prior volume.
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    await _sub?.cancel();
    _sub = null;
    if (_restoreVolume != null) {
      try {
        await FlutterVolumeController.setVolume(_restoreVolume!);
      } catch (_) {}
    }
    _restoreVolume = null;
    try {
      await FlutterVolumeController.updateShowSystemUI(true);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _presses.close();
  }

  void _onVolumeChanged(double volume) {
    if (!_active) return;
    final now = DateTime.now();
    if (now.isBefore(_suppressUntil)) {
      // Still in a suppression window (startup or snap-back). Don't even
      // re-snap here — the snap that opened this window is still settling.
      return;
    }
    if ((volume - lockedVolume).abs() < pressDelta) {
      // Within the locked midpoint's deadzone — snap back if drifted but
      // don't treat as a press.
      if (volume != lockedVolume) {
        _setLocked();
      }
      return;
    }
    if (now.difference(_lastPressAt) < deadband) {
      // Real press, but too close on the heels of the previous one.
      _setLocked();
      return;
    }
    _lastPressAt = now;
    _presses.add(null);
    _setLocked();
  }

  void _suppress(Duration window) {
    final newUntil = DateTime.now().add(window);
    if (newUntil.isAfter(_suppressUntil)) {
      _suppressUntil = newUntil;
    }
  }

  Future<void> _setLocked() async {
    _suppress(snapbackGrace);
    try {
      await FlutterVolumeController.setVolume(lockedVolume);
    } catch (_) {}
  }
}
