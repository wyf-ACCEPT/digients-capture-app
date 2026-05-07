import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../l10n/l10n.dart';
import '../../l10n/localized_fixtures.dart';
import '../../state/hand_presence_settings_controller.dart';
import '../../state/locale_controller.dart';
import '../../services/hand_presence/hand_presence_state.dart';
import '../../theme/text_styles.dart';
import '../../services/camera_service.dart';
import '../../services/compression_queue.dart';
import '../../services/recording_manager.dart';
import '../../services/hand_presence/hand_presence_controller.dart';
import '../../services/hand_presence/hand_presence_detector_service.dart';
import '../../services/hand_presence/hand_audio_player.dart';
import '../../models/recording.dart';
import '../../fixtures/data.dart';
import '../../widgets/hand_presence_border.dart';
import '../../widgets/mount_overlay.dart';
import '../../widgets/submission_success_overlay.dart';
import '../../services/volume_button_service.dart';

class RecordScreen extends StatefulWidget {
  final String taskId;
  const RecordScreen({super.key, required this.taskId});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

/// Lifecycle phases for the record-screen state machine.
///
/// `mounting`  — mount-instructions overlay is up; nothing else runs.
/// `armed`     — camera live, waiting for a vol-button press to start.
/// `starting`  — vol-button pressed; the pre-start voice cue is playing
///               and a 3-second countdown follows. Recording hasn't
///               actually started yet — gives the user time to position
///               their hands. Vol button is ignored during this phase.
/// `recording` — capture in progress; vol-button press will stop.
/// `submitted` — capture stopped, success popup is up. The next vol-button
///               press dismisses the popup and rearms (or starts the next
///               take immediately, see [_onVolButtonPress]).
enum _Phase { mounting, armed, starting, recording, submitted }

class _RecordScreenState extends State<RecordScreen> {
  final CameraService _cameraService = CameraService();
  final RecordingManager _recordingManager = RecordingManager();
  final HandPresenceController _handPresence = HandPresenceController();
  late final HandPresenceDetectorService _handDetector =
      HandPresenceDetectorService(controller: _handPresence);
  late final HandAudioPlayer _handAudio = HandAudioPlayer(
    transitions: _handPresence.transitions,
    sideTransitions: _handPresence.sideTransitions,
  );
  final VolumeButtonService _volumeButtons = VolumeButtonService();
  StreamSubscription<void>? _volSub;
  Timer? _popupAutoDismissTimer;

  bool _isInitialized = false;
  bool _expanded = false;
  _Phase _phase = _Phase.mounting;
  // Take counter — increments on every successful submission so the user
  // sees "Take 1", "Take 2"… for back-to-back captures of the same task.
  int _takeNumber = 0;
  int _lastSubmissionPoints = 0;

  // Pre-start sequence state. The vol-button press transitions to
  // _Phase.starting, plays the pre-start voice, then runs a 3-second
  // visible countdown. Both the voice future and the countdown timer
  // need to be cancelable on close-button / unmount so we don't kick off
  // recording after the user has bailed.
  static const Duration _preStartCountdown = Duration(seconds: 3);
  Timer? _preStartCountdownTimer;
  int? _startingSecondsRemaining;

  String? _sessionId;
  DateTime? _startTime;
  String? _outputDirectory;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _errorMessage;
  Map<String, dynamic>? _cameraInfo;
  Map<String, dynamic>? _deviceInfo;

  bool get _showMountOverlay => _phase == _Phase.mounting;
  bool get _showSuccessPopup => _phase == _Phase.submitted;
  bool get _isRecording => _phase == _Phase.recording;

  // Device-orientation overlay rotation. The app is locked to portrait at the
  // OS level (Info.plist) so MediaQuery.orientation never flips; we read the
  // accelerometer instead and rotate the HUD overlays in place. Tracked as an
  // unbounded double so AnimatedRotation always takes the shortest arc.
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _hudTurns = 0.0;
  LocaleController? _localeController;

  @override
  void initState() {
    super.initState();
    // The phone is head-mounted while recording — disable auto-lock for the
    // lifetime of this screen. Released in dispose() so other screens behave
    // normally.
    WakelockPlus.enable();
    _bootstrap();
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(_onAccel);
    final localeController =
        Provider.of<LocaleController>(context, listen: false);
    _localeController = localeController;
    localeController.addListener(_onLocaleChanged);
    unawaited(
        _handAudio.setVoiceLanguageCode(localeController.locale.languageCode));
    unawaited(_handAudio.initialize());
    // Detector is started in _start() — not here — so per-hand voice cues
    // don't fire during the mount-instructions overlay (~6 s before
    // recording actually begins).
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker?.cancel();
    _popupAutoDismissTimer?.cancel();
    _preStartCountdownTimer?.cancel();
    _volSub?.cancel();
    _localeController?.removeListener(_onLocaleChanged);
    _volumeButtons.dispose();
    _handDetector.dispose();
    _handAudio.dispose();
    _handPresence.dispose();
    _cameraService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // Map gravity to one of four target orientations. Threshold of ~7 m/s² keeps
  // the orientation latched until the device is tilted well past 45° from the
  // current axis, which is enough hysteresis in practice.
  void _onAccel(AccelerometerEvent e) {
    int? targetQuarters;
    if (e.y > 7.0) {
      targetQuarters = 0; // portrait normal
    } else if (e.x < -7.0) {
      targetQuarters = -1; // top edge to right (rotated 90° CW); UI rotates CCW
    } else if (e.y < -7.0) {
      targetQuarters = 2; // upside down
    } else if (e.x > 7.0) {
      targetQuarters = 1; // top edge to left (rotated 90° CCW); UI rotates CW
    }
    if (targetQuarters == null) return;

    final currentQuarters = (_hudTurns * 4).round();
    int delta = targetQuarters - currentQuarters;
    while (delta > 2) {
      delta -= 4;
    }
    while (delta < -2) {
      delta += 4;
    }
    if (delta == 0) return;

    setState(() => _hudTurns += delta * 0.25);
  }

  void _applySettings(HandPresenceSettingsController settings) {
    _handAudio.voiceEnabled = settings.voiceCuesEnabled;
  }

  void _onLocaleChanged() {
    final locale = _localeController?.locale;
    if (locale == null) return;
    unawaited(_handAudio.setVoiceLanguageCode(locale.languageCode));
  }

  void _onTransitionForHaptic(HandPresenceTransition t, bool vibrateOnNone) {
    if (vibrateOnNone && t.to == HandPresenceState.none) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _bootstrap() async {
    final l10n = context.l10n;
    final settings =
        Provider.of<HandPresenceSettingsController>(context, listen: false);
    _applySettings(settings);
    settings.addListener(() => _applySettings(settings));
    _handPresence.transitions.listen((t) {
      _onTransitionForHaptic(t, settings.vibrateOnNoneEnabled);
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _errorMessage = l10n.cameraPermissionRequired);
      return;
    }
    final ok = await _cameraService.initializeCamera();
    if (!ok) {
      setState(() => _errorMessage = l10n.failedToInitializeCamera);
      return;
    }
    final cam = await _cameraService.getCameraInfo();
    final dev = await _cameraService.getDeviceInfo();
    setState(() {
      _isInitialized = true;
      _cameraInfo = cam;
      _deviceInfo = dev;
    });
    // Recording is kicked off by the mount-instructions overlay's
    // onComplete callback (_onMountComplete), not here, so the user
    // first sees the orientation/headmount cues over the live preview.
  }

  void _onMountComplete() {
    if (!mounted) return;
    _enterArmed();
  }

  /// Transition to ARMED. The vol-button service is started lazily here
  /// (not in initState) so it doesn't lock the system volume during the
  /// mount-instructions phase, and the prompt voice plays so the
  /// head-mounted user knows what to do.
  Future<void> _enterArmed() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.armed);
    if (_volSub == null) {
      _volSub = _volumeButtons.onPress.listen((_) => _onVolButtonPress());
      await _volumeButtons.start();
    }
    unawaited(_handAudio.playArmedPrompt());
  }

  /// Single dispatcher for hardware volume-button presses. Behavior is
  /// phase-driven so the same button drives arm-start, recording-stop,
  /// and popup-dismiss-and-restart.
  void _onVolButtonPress() {
    if (!mounted) return;
    switch (_phase) {
      case _Phase.mounting:
        // Ignore — mount overlay is doing its thing. (Service shouldn't be
        // running here anyway, but be defensive.)
        return;
      case _Phase.armed:
        unawaited(_handAudio.stopArmedPrompt());
        _runPreStartSequence();
        return;
      case _Phase.starting:
        // The user already committed; ignore further vol presses until
        // recording actually starts. Stop button is what cancels (via X).
        return;
      case _Phase.recording:
        _stop();
        return;
      case _Phase.submitted:
        // Pressing vol while the popup is up means the user wants to keep
        // capturing — dismiss the popup and run the same pre-start
        // sequence so back-to-back takes get the same prepare-then-record
        // rhythm as the first take.
        _popupAutoDismissTimer?.cancel();
        _popupAutoDismissTimer = null;
        unawaited(_handAudio.stopArmedPrompt());
        _runPreStartSequence();
        return;
    }
  }

  /// Three-step prepare-then-record:
  ///   1. flip phase → starting (HUD shows "place hands in view")
  ///   2. play the pre-start voice cue, await playback
  ///   3. visible 3-second countdown (3 → 2 → 1)
  ///   4. _start() — fires the recording-start chirp and begins capture
  ///
  /// Cancelable via [_cancelPreStartSequence] (called from the X close
  /// button and dispose). If the user has navigated away or the phase
  /// changed by the time any await completes, the sequence aborts cleanly.
  Future<void> _runPreStartSequence() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.starting;
      _startingSecondsRemaining = null;
    });
    try {
      await _handAudio.playPreStartPrompt();
    } catch (_) {
      // Voice playback is supplementary; carry on with the countdown.
    }
    if (!mounted || _phase != _Phase.starting) return;
    setState(() => _startingSecondsRemaining = _preStartCountdown.inSeconds);
    _preStartCountdownTimer?.cancel();
    _preStartCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _phase != _Phase.starting) {
        t.cancel();
        _preStartCountdownTimer = null;
        return;
      }
      final remaining = (_startingSecondsRemaining ?? 0) - 1;
      if (remaining > 0) {
        setState(() => _startingSecondsRemaining = remaining);
        return;
      }
      t.cancel();
      _preStartCountdownTimer = null;
      setState(() => _startingSecondsRemaining = null);
      _start();
    });
  }

  void _cancelPreStartSequence() {
    _preStartCountdownTimer?.cancel();
    _preStartCountdownTimer = null;
    _startingSecondsRemaining = null;
    unawaited(_handAudio.stopPreStartPrompt());
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final sessionId = _recordingManager.generateSessionId();
    final dir = await _recordingManager.createRecordingDirectory(sessionId);
    final ok = await _cameraService.startRecording(sessionId, dir);
    if (!ok) {
      setState(() => _errorMessage = l10n.failedToStartRecording);
      return;
    }
    // Pause the background compressor — we don't want a worker isolate
    // contending with the encoder for CPU during a take. It resumes in
    // _stop() once metadata is saved and the new recording is queued.
    if (mounted) {
      // ignore: use_build_context_synchronously
      Provider.of<CompressionQueue>(context, listen: false).pause();
    }
    // Each take gets a clean smoothing window + warmup; otherwise stale
    // state from the previous take could fire spurious "exit" cues.
    _handPresence.reset();
    _handDetector.start();
    setState(() {
      _phase = _Phase.recording;
      _sessionId = sessionId;
      _outputDirectory = dir;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startTime == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startTime!));
    });
    unawaited(_announceCaptureStart());
  }

  /// The phone is mounted on the user's head when recording starts, so they
  /// can't see the screen change. We play a sci-fi chirp the moment capture
  /// begins, then — once the detector's smoothing window has filled — speak
  /// the current hand-presence state so the user can adjust without looking.
  Future<void> _announceCaptureStart() async {
    try {
      await _handAudio.playRecordingStart();
    } catch (_) {
      // Audio is supplementary; never block recording on a playback failure.
    }
    if (!mounted) return;
    try {
      final firstState = await _handPresence.firstStateReady;
      if (!mounted) return;
      await _handAudio.playStateAnnouncement(firstState);
    } catch (_) {
      // Controller may be reset (e.g. backgrounded) before first state lands.
    }
  }

  Future<void> _stop() async {
    // Snapshot phase so callbacks during the async stop don't double-fire.
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();

    // Pause the detector immediately so per-hand voice cues can't fire over
    // the stop chirp / popup while the user is still wearing the phone.
    unawaited(_handDetector.stop());

    // Play the stop chirp before we tear capture down — gives the user an
    // immediate "stop" signal even while file-writing finishes.
    unawaited(_handAudio.playRecordingStop());

    final result = await _cameraService.stopRecording();
    if (!mounted) return;
    if (result == null || _sessionId == null) {
      // Nothing was actually recorded — drop straight back to armed.
      // Resume the compressor since we paused it on _start(); without
      // this, an aborted take would leave the queue indefinitely paused.
      Provider.of<CompressionQueue>(context, listen: false).resume();
      _enterArmed();
      return;
    }

    final capturedAt = _startTime ?? DateTime.now();
    final fileSize =
        await _recordingManager.calculateRecordingSize(_sessionId!);
    final durationSec =
        (result['durationSeconds'] as int?) ?? _elapsed.inSeconds;
    final frameCount = (result['frameCount'] as int?) ?? 0;
    final measuredMotionRateHz =
        (result['motionRateHzMeasured'] as num?)?.toDouble();
    // Pull actual encoded dimensions from native; iOS may pick 1920×1440 etc.
    final capW = (result['captureWidth'] as int?) ?? 1920;
    final capH = (result['captureHeight'] as int?) ?? 1080;
    final capFps = (result['captureFps'] as num?)?.toDouble() ?? 30.0;

    final task = findTask(widget.taskId);
    final recording = Recording(
      sessionId: _sessionId!,
      capturedAt: capturedAt,
      directoryPath: result['directoryPath'] ?? _outputDirectory ?? '',
      durationSeconds: durationSec,
      fileSizeMB: fileSize,
      categoryId: task?.categoryId,
      taskId: task?.id,
    );
    await _recordingManager.saveRecording(recording);
    await _recordingManager.saveMetadata(
        _sessionId!,
        _buildMetadata(
          sessionId: _sessionId!,
          capturedAt: capturedAt,
          durationSeconds: durationSec,
          frameCount: frameCount,
          measuredMotionRateHz: measuredMotionRateHz,
          videoWidth: capW,
          videoHeight: capH,
          videoFps: capFps,
        ));

    if (!mounted) return;
    final pts = task?.rewardPoints ?? 0;
    final completedSessionId = _sessionId!;
    setState(() {
      _phase = _Phase.submitted;
      _takeNumber += 1;
      _lastSubmissionPoints = pts;
      _sessionId = null;
      _outputDirectory = null;
      _startTime = null;
      _elapsed = Duration.zero;
    });
    // Generate the first-frame thumbnail synchronously so the submissions
    // list always has something to show — and so it lands on disk before
    // the post-compression cleanup deletes video.mp4. ~100 ms.
    unawaited(_recordingManager.ensureThumbnail(completedSessionId));
    // Hand the just-finished take off to the background compressor and
    // resume the queue. The user keeps recording back-to-back takes; the
    // queue serializes them so we never run two builds at once.
    final queue = Provider.of<CompressionQueue>(context, listen: false);
    queue.enqueue(completedSessionId);
    queue.resume();
    unawaited(_handAudio.playSubmissionSuccess());

    // Auto-dismiss the popup and rearm after a short hold. Press-vol or tap
    // (handled by the overlay widget) can also cancel this and rearm early.
    _popupAutoDismissTimer?.cancel();
    _popupAutoDismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (_phase != _Phase.submitted) return;
      _enterArmed();
    });
  }

  void _onSuccessPopupTap() {
    if (_phase != _Phase.submitted) return;
    _popupAutoDismissTimer?.cancel();
    _popupAutoDismissTimer = null;
    _enterArmed();
  }

  RecordingMetadata _buildMetadata({
    required String sessionId,
    required DateTime capturedAt,
    required int durationSeconds,
    required int frameCount,
    double? measuredMotionRateHz,
    int videoWidth = 1920,
    int videoHeight = 1080,
    double videoFps = 30,
  }) {
    final cam = _cameraInfo ?? <String, dynamic>{};
    final dev = _deviceInfo ?? <String, dynamic>{};
    final stab = (cam['videoStabilizationEnabled'] as bool?) ?? false;
    final os =
        (dev['os'] as String?) ?? (Platform.isAndroid ? 'android' : 'ios');
    final isAndroid = os == 'android';

    // Intrinsics — v1.2 only accepts source="static". The native side computes
    // a single 3×3 K from the active camera-format calibration data; the
    // distortion model must be "brown_conrady" or "kannala_brandt" or null.
    final matrix = (cam['intrinsicMatrix'] as List?)
        ?.map((row) =>
            (row as List).cast<num>().map((n) => n.toDouble()).toList())
        .toList();
    final coeffs = (cam['distortionCoeffs'] as List?)
        ?.cast<num>()
        .map((n) => n.toDouble())
        .toList();
    final distortionModel = cam['distortionModel'] as String?;
    final intrinsicsReliable =
        matrix != null && !stab; // schema requires bool; default to false-only when no K
    final intrinsicsNotes = (cam['intrinsicsNotes'] as String?) ??
        (isAndroid
            ? 'Static intrinsics from Camera2 LENS_INTRINSIC_CALIBRATION, rescaled to video resolution by a single uniform scalar.'
            : 'Static intrinsics from AVCaptureDevice activeFormat at locked focus.');
    final intrinsics = IntrinsicsInfo(
      source: 'static',
      staticMatrix: matrix,
      distortionModel: distortionModel,
      distortionCoeffs: coeffs,
      reliable: intrinsicsReliable,
      notes: intrinsicsNotes,
    );

    // Motion — v1.2 requires recorded=true. We assume the IMU writer is
    // running; if for some reason it isn't, the bundle will fail the
    // pipeline's validator and we'll see it server-side rather than
    // silently shipping a degraded capture.
    final advertisedMotionRate = (cam['motionRateHz'] as num?)?.toDouble();
    final motionInfo = MotionInfo(
      recorded: true,
      rateHz: measuredMotionRateHz != null && measuredMotionRateHz > 0
          ? measuredMotionRateHz
          : advertisedMotionRate,
      gyroUnits: (cam['motionGyroUnits'] as String?) ?? 'rad/s',
      accelUnits: (cam['motionAccelUnits'] as String?) ?? 'm/s^2',
      accelIncludesGravity:
          (cam['motionAccelIncludesGravity'] as bool?) ??
              (isAndroid ? true : false),
      frame: (cam['motionFrame'] as String?) ?? 'device_body',
      notes: isAndroid
          ? 'Android Sensor TYPE_GYROSCOPE + TYPE_ACCELEROMETER at SENSOR_DELAY_FASTEST, ordered queue, one row per gyro event.'
          : 'iOS CMMotionManager.deviceMotion at 100 Hz.',
      // Each must be > 0 if present per the schema; surface only when native
      // hands a positive value (e.g. from a per-model datasheet table).
      noiseDensityGyro:
          _positiveOrNull((cam['imuNoiseDensityGyro'] as num?)?.toDouble()),
      noiseDensityAccel:
          _positiveOrNull((cam['imuNoiseDensityAccel'] as num?)?.toDouble()),
      randomWalkGyro:
          _positiveOrNull((cam['imuRandomWalkGyro'] as num?)?.toDouble()),
      randomWalkAccel:
          _positiveOrNull((cam['imuRandomWalkAccel'] as num?)?.toDouble()),
    );

    // Extrinsics — only emit when the native side actually provides a 4×4.
    // Android Camera2 hands us LENS_POSE_TRANSLATION + LENS_POSE_ROTATION
    // → "platform_api". iOS doesn't expose this; falls back to omitting the
    // block entirely so the offline VIO solves for it.
    ExtrinsicsInfo? extrinsics;
    final tCamImuRaw = cam['tCamImu'] as List?;
    final extrinsicsSource = cam['extrinsicsSource'] as String?;
    if (tCamImuRaw != null && extrinsicsSource != null) {
      final tCamImu = tCamImuRaw
          .map((row) =>
              (row as List).cast<num>().map((n) => n.toDouble()).toList())
          .toList();
      extrinsics = ExtrinsicsInfo(
        tCamImu: tCamImu,
        source: extrinsicsSource,
        timeOffsetSec: (cam['extrinsicsTimeOffsetSec'] as num?)?.toDouble(),
        rotationStddevDeg:
            (cam['extrinsicsRotationStddevDeg'] as num?)?.toDouble(),
        translationStddevM:
            (cam['extrinsicsTranslationStddevM'] as num?)?.toDouble(),
        notes: cam['extrinsicsNotes'] as String?,
      );
    }

    final rollingShutter = (cam['rollingShutterSkewNs'] as num?)?.toInt();
    final deviceClockId = cam['deviceClockId'] as String?;

    return RecordingMetadata(
      schemaVersion: '1.2',
      sessionId: sessionId,
      capturedAtUtc: capturedAt,
      sessionClockOrigin: 'unix_epoch',
      appVersion: '2.2.0',
      device: DeviceInfo(
        os: os,
        osVersion: (dev['osVersion'] as String?) ?? '',
        manufacturer:
            (dev['manufacturer'] as String?) ?? (isAndroid ? '' : 'Apple'),
        model: (dev['model'] as String?) ?? '',
        modelIdentifier: (dev['modelIdentifier'] as String?) ?? '',
      ),
      camera: CameraInfo(
        lensId: (cam['lensId'] as String?) ?? '',
        // Per spec §3 the lens_type is *derived* from the chosen FOV. Native
        // computes it (>=100° → "ultrawide", else "wide") and we just pass
        // through; the schema rejects "telephoto" / "unknown".
        lensType: (cam['lensType'] as String?) ?? 'wide',
        physicalFocalLengthMm:
            (cam['physicalFocalLengthMm'] as num?)?.toDouble(),
        sensorPhysicalSizeMm: (cam['sensorPhysicalSizeMm'] as List?)
            ?.cast<num>()
            .map((n) => n.toDouble())
            .toList(),
        sensorPixelArraySize: (cam['sensorPixelArraySize'] as List?)
            ?.cast<num>()
            .map((n) => n.toInt())
            .toList(),
        horizontalFovDeg: (cam['horizontalFovDeg'] as num?)?.toDouble(),
        videoStabilizationEnabled: stab,
        opticalStabilizationEnabled:
            (cam['opticalStabilizationEnabled'] as bool?) ?? false,
        rollingShutterSkewNs: (rollingShutter != null && rollingShutter >= 0)
            ? rollingShutter
            : null,
      ),
      video: VideoInfo(
        codec: 'hevc',
        container: 'mp4',
        width: videoWidth,
        height: videoHeight,
        framerate: videoFps,
        durationSec: durationSeconds.toDouble(),
        frameCount: frameCount,
        bitrateBps: 15000000,
        colorSpace: 'bt709',
        pixelFormat: 'yuv420p',
        hasAudioTrack: false,
      ),
      intrinsics: intrinsics,
      // Pose block intentionally omitted under v1.2 (spec §4.2 + §10).
      motion: motionInfo,
      extrinsics: extrinsics,
      deviceClockId: deviceClockId,
      capturePlatform: CapturePlatformInfo(
        flutterVersion: '3.41.7',
        nativeSdkVersion: isAndroid ? 'android' : 'ios',
        capturePipelineVersion: '2.2.0',
      ),
    );
  }

  static double? _positiveOrNull(double? v) =>
      (v != null && v > 0) ? v : null;

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Wrap any overlay so it auto-rotates with the device. Each wrapped
  /// element rotates around its own center (so its position on screen
  /// is preserved) — same pattern the recording pill / stop button /
  /// close button already use.
  Widget _rotated(Widget child) => AnimatedRotation(
        turns: _hudTurns,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: child,
      );

  // Slide offset for the recording pill, in units of the pill's own size.
  // After the pill rotates 90° around its center, it would extend upward into
  // the Dynamic Island's footprint. We push it ~1.5 pill-heights along the
  // device's Y axis (toward the bottom of the device frame) so it lands beside
  // the Dynamic Island in the user's landscape view. |sin(2π·turns)| is 1 at
  // any landscape quarter-turn and 0 at portrait / upside-down, so the slide
  // animates back to zero whenever the device is upright.
  Offset _pillSlideOffset(double turns) {
    final amount = math.sin(2 * math.pi * turns).abs();
    return Offset(0, amount * 1.5);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isInitialized)
            Positioned.fill(
              child: Platform.isIOS
                  ? const UiKitView(
                      viewType: 'digients_app/camera_preview',
                      creationParamsCodec: StandardMessageCodec(),
                    )
                  : const AndroidView(
                      viewType: 'digients_app/camera_preview',
                      creationParamsCodec: StandardMessageCodec(),
                    ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 0.2),
                    radius: 1.2,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
            ),
          ),
          // TEMP debug overlay — top-left corner shows detector pipeline stats.
          // Hidden during the mount overlay so it doesn't compete with the
          // orient-and-mount instructions.
          if (_isRecording)
            Positioned(
              top: 60,
              left: 16,
              child: _rotated(
                AnimatedBuilder(
                  animation: Listenable.merge([_handPresence, _handDetector]),
                  builder: (_, __) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Text(
                      'ticks=${_handDetector.ticksReceived} '
                      'rawH=${_handDetector.maxRawHandCount} '
                      'okH=${_handDetector.maxHandsSeen}\n'
                      'maxS=${_handDetector.maxScoreSeen.toStringAsFixed(2)} '
                      'modelLoaded=${_handDetector.lastModelLoaded}\n'
                      'state=${_handPresence.state.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Colored border tracking the composite hand-presence state.
          // Only meaningful while actually recording — during armed/submitted
          // the detector is paused and the state would just sit at NONE/red.
          if (_isRecording)
            Consumer<HandPresenceSettingsController>(
              builder: (_, settings, __) {
                if (!settings.borderEnabled) {
                  return const SizedBox.shrink();
                }
                return Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _handPresence,
                    builder: (_, __) =>
                        HandPresenceBorder(state: _handPresence.state),
                  ),
                );
              },
            ),
          if (_isRecording)
            Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Center(
                // In landscape the pill rotates 90° around its own center, then
                // shifts along the device's long axis (vertical in device frame)
                // so it lands beside the Dynamic Island instead of on top of it.
                // Sign of the slide is chosen so the pill ends up "below" the
                // Dynamic Island in the user's landscape view, regardless of
                // whether the device was rotated CW or CCW.
                child: AnimatedSlide(
                  offset: _pillSlideOffset(_hudTurns),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: AnimatedRotation(
                    turns: _hudTurns,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: _RecordingPill(elapsed: _format(_elapsed)),
                    ),
                  ),
                ),
              ),
            ),
          if (_isRecording && _expanded)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: _rotated(
                _ExpandedHud(
                  taskTitle:
                      findTask(widget.taskId)?.localizedTitle(l10n) ?? '',
                  lensType: (_cameraInfo?['lensType'] as String?) ?? 'wide',
                ),
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              left: 20,
              right: 20,
              top: 200,
              child: _rotated(
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0F0F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF453A)),
                  ),
                  child: Text(_errorMessage!,
                      style: DCText.inter(
                          size: 14,
                          weight: FontWeight.w500,
                          color: const Color(0xFFFF453A))),
                ),
              ),
            ),
          // On-screen primary button — phase-aware fallback for users who
          // can't reach the volume buttons (handheld testing, accessibility).
          // Tapping it does the same thing a vol-button press does.
          if (_phase == _Phase.armed || _phase == _Phase.recording)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: AnimatedRotation(
                  turns: _hudTurns,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _onVolButtonPress,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: _isRecording
                                ? Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF453A),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  )
                                : Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF14C9A8),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isRecording ? l10n.tapToStop : l10n.tapToStart,
                        style: DCText.mono(
                            size: 11,
                            weight: FontWeight.w500,
                            color: Colors.white70,
                            letterSpacing: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isInitialized && _showMountOverlay && _errorMessage == null)
            Positioned.fill(
              child: MountInstructionsOverlay(
                onComplete: _onMountComplete,
                turns: _hudTurns,
              ),
            ),
          if (_phase == _Phase.armed && _errorMessage == null)
            Positioned.fill(child: _rotated(const _ArmedPrompt())),
          if (_phase == _Phase.starting && _errorMessage == null)
            Positioned.fill(
              child: _rotated(
                _PreStartOverlay(
                  secondsRemaining: _startingSecondsRemaining,
                ),
              ),
            ),
          // Top-right close button — always available so the user can leave
          // the screen, since the vol-button flow has no other terminal
          // state. Stops capture cleanly first if recording.
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: AnimatedRotation(
                turns: _hudTurns,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _onCloseButtonPressed,
                ),
              ),
            ),
          ),
          if (_showSuccessPopup)
            Positioned.fill(
              child: SubmissionSuccessOverlay(
                points: _lastSubmissionPoints,
                takeNumber: _takeNumber,
                onDismiss: _onSuccessPopupTap,
                turns: _hudTurns,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onCloseButtonPressed() async {
    // If we're mid-recording, stop the camera so the file isn't left
    // open. We deliberately do NOT save metadata — exiting is "cancel
    // this take", matching the prior behavior of this button.
    if (_phase == _Phase.recording) {
      try {
        await _cameraService.stopRecording();
      } catch (_) {}
    }
    // Cancel the pre-start voice + countdown if the user bails between
    // press and start.
    _cancelPreStartSequence();
    // The queue may have been paused if a recording was in flight; make
    // sure the background compressor is unblocked before we leave.
    if (mounted) {
      Provider.of<CompressionQueue>(context, listen: false).resume();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// Visible counterpart to the pre-start voice cue + 3-second countdown.
/// While the voice is still playing, [secondsRemaining] is null and we
/// show "PLACE HANDS IN VIEW". Once the countdown begins, we render the
/// remaining seconds as a large digit. The voice cue itself runs
/// independently from [HandAudioPlayer.playPreStartPrompt].
class _PreStartOverlay extends StatelessWidget {
  final int? secondsRemaining;
  const _PreStartOverlay({required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final showDigit = secondsRemaining != null;
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF14C9A8).withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PLACE HANDS IN VIEW',
                style: DCText.mono(
                  size: 11,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              if (showDigit)
                Text(
                  '$secondsRemaining',
                  style: DCText.mono(
                    size: 64,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                )
              else
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: const Color(0xFF14C9A8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered hands-free prompt shown while the screen is ARMED. The phone
/// is on the user's head; this is a fallback for sighted/handheld testing.
/// The actual cue is the `armed_prompt.wav` voice played from
/// [HandAudioPlayer.playArmedPrompt].
class _ArmedPrompt extends StatefulWidget {
  const _ArmedPrompt();

  @override
  State<_ArmedPrompt> createState() => _ArmedPromptState();
}

class _ArmedPromptState extends State<_ArmedPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF14C9A8)
                    .withValues(alpha: 0.4 + 0.4 * _ctl.value),
                width: 1.5,
              ),
            ),
            child: Text(
              context.l10n.pressVolumeButtonToStart,
              style: DCText.mono(
                size: 12,
                weight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingPill extends StatefulWidget {
  final String elapsed;
  const _RecordingPill({required this.elapsed});

  @override
  State<_RecordingPill> createState() => _RecordingPillState();
}

class _RecordingPillState extends State<_RecordingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color.lerp(const Color(0xFFFF453A),
                    const Color(0xFF7A0000), _ctl.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.elapsed,
            style: DCText.mono(
                size: 16,
                weight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.32),
          ),
        ],
      ),
    );
  }
}

class _ExpandedHud extends StatelessWidget {
  final String taskTitle;
  final String lensType;
  const _ExpandedHud({required this.taskTitle, required this.lensType});

  @override
  Widget build(BuildContext context) {
    // Display the chosen lens type uppercased ("ULTRAWIDE" / "WIDE"). Per
    // v1.2 spec §3 these are the only two values the schema accepts.
    final lensLabel = lensType.toUpperCase();
    final stats = [
      const ['FPS', '30'],
      const ['CODEC', 'HEVC'],
      ['LENS', lensLabel],
      const ['BITRATE', '15 Mb/s'],
      const ['STAB', 'OFF'],
      const ['SCHEMA', '1.2'],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(taskTitle,
              style: DCText.inter(
                  size: 13, weight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: stats.map((s) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s[0],
                      style: DCText.mono(
                          size: 9,
                          weight: FontWeight.w500,
                          color: Colors.white60,
                          letterSpacing: 1.3)),
                  const SizedBox(height: 2),
                  Text(
                    s[1],
                    style: DCText.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: (s[0] == 'LENS' && s[1] == 'ULTRAWIDE')
                          ? const Color(0xFF14C9A8)
                          : Colors.white,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
