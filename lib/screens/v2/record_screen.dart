import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../state/hand_presence_settings_controller.dart';
import '../../services/hand_presence/hand_presence_state.dart';
import '../../theme/text_styles.dart';
import '../../services/camera_service.dart';
import '../../services/recording_manager.dart';
import '../../services/hand_presence/hand_presence_controller.dart';
import '../../services/hand_presence/hand_presence_detector_service.dart';
import '../../services/hand_presence/hand_audio_player.dart';
import '../../models/recording.dart';
import '../../fixtures/data.dart';
import '../../widgets/hand_presence_border.dart';

class RecordScreen extends StatefulWidget {
  final String taskId;
  const RecordScreen({super.key, required this.taskId});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

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
  bool _isInitialized = false;
  bool _expanded = false;
  String? _sessionId;
  DateTime? _startTime;
  String? _outputDirectory;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _errorMessage;
  Map<String, dynamic>? _cameraInfo;
  Map<String, dynamic>? _deviceInfo;

  // Device-orientation overlay rotation. The app is locked to portrait at the
  // OS level (Info.plist) so MediaQuery.orientation never flips; we read the
  // accelerometer instead and rotate the HUD overlays in place. Tracked as an
  // unbounded double so AnimatedRotation always takes the shortest arc.
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _hudTurns = 0.0;

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
    _handAudio.initialize();
    _handDetector.start();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker?.cancel();
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
    _handAudio.tonesEnabled = settings.tonesEnabled;
    _handAudio.voiceEnabled = settings.voiceEnabled;
  }

  void _onTransitionForHaptic(HandPresenceTransition t, bool vibrateOnNone) {
    if (vibrateOnNone && t.to == HandPresenceState.none) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _bootstrap() async {
    final settings =
        Provider.of<HandPresenceSettingsController>(context, listen: false);
    _applySettings(settings);
    settings.addListener(() => _applySettings(settings));
    _handPresence.transitions.listen((t) {
      _onTransitionForHaptic(t, settings.vibrateOnNone);
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _errorMessage = 'Camera permission required');
      return;
    }
    final ok = await _cameraService.initializeCamera();
    if (!ok) {
      setState(() => _errorMessage = 'Failed to initialize camera');
      return;
    }
    final cam = await _cameraService.getCameraInfo();
    final dev = await _cameraService.getDeviceInfo();
    setState(() {
      _isInitialized = true;
      _cameraInfo = cam;
      _deviceInfo = dev;
    });
    await _start();
  }

  Future<void> _start() async {
    final sessionId = _recordingManager.generateSessionId();
    final dir = await _recordingManager.createRecordingDirectory(sessionId);
    final ok = await _cameraService.startRecording(sessionId, dir);
    if (!ok) {
      setState(() => _errorMessage = 'Failed to start recording');
      return;
    }
    setState(() {
      _sessionId = sessionId;
      _outputDirectory = dir;
      _startTime = DateTime.now();
    });
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
    _ticker?.cancel();
    final result = await _cameraService.stopRecording();
    if (result == null || _sessionId == null) {
      if (mounted) context.pop();
      return;
    }
    final capturedAt = _startTime ?? DateTime.now();
    final fileSize = await _recordingManager.calculateRecordingSize(_sessionId!);
    final durationSec = (result['durationSeconds'] as int?) ?? _elapsed.inSeconds;
    final frameCount = (result['frameCount'] as int?) ?? 0;
    final actualPoseSource = (result['poseSource'] as String?) ??
        (_cameraInfo?['poseSource'] as String?);
    final measuredMotionRateHz = (result['motionRateHzMeasured'] as num?)?.toDouble();
    // Pull actual encoded dimensions from native; iOS may pick 1920×1440 etc.
    final capW = (result['captureWidth'] as int?) ?? 1920;
    final capH = (result['captureHeight'] as int?) ?? 1080;
    final capFps = (result['captureFps'] as num?)?.toDouble() ?? 30.0;

    final recording = Recording(
      sessionId: _sessionId!,
      capturedAt: capturedAt,
      directoryPath: result['directoryPath'] ?? _outputDirectory ?? '',
      durationSeconds: durationSec,
      fileSizeMB: fileSize,
    );
    await _recordingManager.saveRecording(recording);
    await _recordingManager.saveMetadata(_sessionId!, _buildMetadata(
      sessionId: _sessionId!,
      capturedAt: capturedAt,
      durationSeconds: durationSec,
      frameCount: frameCount,
      poseSourceOverride: actualPoseSource,
      measuredMotionRateHz: measuredMotionRateHz,
      videoWidth: capW,
      videoHeight: capH,
      videoFps: capFps,
    ));

    if (!mounted) return;
    final pts = findTask(widget.taskId)?.rewardPoints ?? 0;
    context.go('/success?points=$pts');
  }

  RecordingMetadata _buildMetadata({
    required String sessionId,
    required DateTime capturedAt,
    required int durationSeconds,
    required int frameCount,
    String? poseSourceOverride,
    double? measuredMotionRateHz,
    int videoWidth = 1920,
    int videoHeight = 1080,
    double videoFps = 30,
  }) {
    final cam = _cameraInfo ?? <String, dynamic>{};
    final dev = _deviceInfo ?? <String, dynamic>{};
    final stab = (cam['videoStabilizationEnabled'] as bool?) ?? false;
    final os = (dev['os'] as String?) ?? (Platform.isAndroid ? 'android' : 'ios');
    final isAndroid = os == 'android';

    // Intrinsics
    final IntrinsicsInfo intrinsics;
    final intrinsicsSourceFromNative = cam['intrinsicsSource'] as String?;
    if (isAndroid) {
      final matrix = (cam['intrinsicMatrix'] as List?)
          ?.map((row) => (row as List).cast<num>().map((n) => n.toDouble()).toList())
          .toList();
      final source = (cam['intrinsicSource'] as String?) ?? 'none';
      final hwLevelFull = (cam['hardwareLevelFull'] as bool?) ?? false;
      final coeffs = (cam['distortionCoeffs'] as List?)
          ?.cast<num>()
          .map((n) => n.toDouble())
          .toList();
      final reliable = source == 'static' && hwLevelFull && !stab;
      final notes = switch (source) {
        'static' => 'Static intrinsics from Camera2 LENS_INTRINSIC_CALIBRATION.',
        'estimated_fallback' => 'Static intrinsics derived from focal length and sensor size.',
        _ => 'No intrinsics available from Camera2 characteristics.',
      };
      intrinsics = IntrinsicsInfo(
        source: source,
        staticMatrix: matrix,
        distortionModel: coeffs != null && coeffs.isNotEmpty ? 'opencv5' : null,
        distortionCoeffs: coeffs,
        reliable: reliable,
        notes: notes,
      );
    } else {
      // iOS: per-frame intrinsics from ARFrame.camera.intrinsics, written natively.
      intrinsics = IntrinsicsInfo(
        source: intrinsicsSourceFromNative ?? 'per_frame',
        perFrameFile: 'frames.jsonl',
        reliable: !stab,
        notes: 'Per-frame intrinsics from ARFrame.camera.intrinsics.',
      );
    }

    // Pose
    final poseSource = poseSourceOverride ?? (cam['poseSource'] as String?) ?? 'none';
    final poseInfo = PoseInfo(
      source: poseSource,
      frameOrigin: cam['poseFrameOrigin'] as String?,
      coordinateConvention: cam['poseCoordinateConvention'] as String?,
      transformKind: cam['poseTransformKind'] as String?,
      rateHz: (cam['poseRateHz'] as num?)?.toDouble(),
      trackingStateField: poseSource == 'arkit' || poseSource == 'arcore'
          ? 'tracking_state'
          : null,
      notes: switch (poseSource) {
        'arkit' => 'ARWorldTrackingConfiguration, autoFocusEnabled=false, planeDetection=none.',
        'arcore' => 'ARCore Shared Camera mode. Default config.',
        'imu_raw' => 'No system VIO available; offline VIO consumes motion.jsonl.',
        _ => 'No pose source available.',
      },
    );

    // Motion. Always recorded if we have a usable IMU; the device almost always
    // does. Native side reports actual measured rate at stop time on Android.
    final advertisedMotionRate = (cam['motionRateHz'] as num?)?.toDouble();
    final motionRecorded = advertisedMotionRate != null && advertisedMotionRate > 0;
    final motionInfo = MotionInfo(
      recorded: motionRecorded,
      rateHz: measuredMotionRateHz != null && measuredMotionRateHz > 0
          ? measuredMotionRateHz
          : advertisedMotionRate,
      gyroUnits: motionRecorded ? (cam['motionGyroUnits'] as String?) ?? 'rad/s' : null,
      accelUnits: motionRecorded ? (cam['motionAccelUnits'] as String?) ?? 'm/s^2' : null,
      accelIncludesGravity: motionRecorded
          ? (cam['motionAccelIncludesGravity'] as bool?) ?? (isAndroid ? true : false)
          : null,
      frame: motionRecorded ? (cam['motionFrame'] as String?) ?? 'device_body' : null,
      notes: motionRecorded
          ? (isAndroid
              ? 'Android Sensor TYPE_GYROSCOPE + TYPE_ACCELEROMETER at SENSOR_DELAY_FASTEST.'
              : 'iOS CMMotionManager.deviceMotion at 100 Hz.')
          : null,
    );

    return RecordingMetadata(
      schemaVersion: '1.1',
      sessionId: sessionId,
      capturedAtUtc: capturedAt,
      sessionClockOrigin: 'unix_epoch',
      appVersion: '2.1.0',
      device: DeviceInfo(
        os: os,
        osVersion: (dev['osVersion'] as String?) ?? '',
        manufacturer: (dev['manufacturer'] as String?) ?? (isAndroid ? '' : 'Apple'),
        model: (dev['model'] as String?) ?? '',
        modelIdentifier: (dev['modelIdentifier'] as String?) ?? '',
        hasArkit: dev['hasArkit'] as bool?,
        hasArcore: dev['hasArcore'] as bool?,
      ),
      camera: CameraInfo(
        lensId: (cam['lensId'] as String?) ?? '',
        lensType: (cam['lensType'] as String?) ?? 'unknown',
        physicalFocalLengthMm: (cam['physicalFocalLengthMm'] as num?)?.toDouble(),
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
        opticalStabilizationEnabled: (cam['opticalStabilizationEnabled'] as bool?) ?? false,
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
      pose: poseInfo,
      motion: motionInfo,
      capturePlatform: CapturePlatformInfo(
        flutterVersion: '3.41.7',
        nativeSdkVersion: isAndroid ? 'android' : 'ios',
        capturePipelineVersion: '2.1.0',
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
          // Ticks > 0: native MediaPipe is emitting events.
          // maxH > 0: MediaPipe found at least one hand.
          // state: current smoothed presence state.
          Positioned(
            top: 60,
            left: 16,
            child: AnimatedBuilder(
              animation: Listenable.merge([_handPresence, _handDetector]),
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          if (_expanded)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: _ExpandedHud(
                taskTitle: findTask(widget.taskId)?.title ?? '',
                poseSource: (_cameraInfo?['poseSource'] as String?) ?? 'NONE',
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              left: 20,
              right: 20,
              top: 200,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0F0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF453A)),
                ),
                child: Text(_errorMessage!, style: DCText.inter(size: 14, weight: FontWeight.w500, color: const Color(0xFFFF453A))),
              ),
            ),
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
                      onTap: _stop,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF14C9A8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TAP TO STOP',
                      style: DCText.mono(size: 11, weight: FontWeight.w500, color: Colors.white70, letterSpacing: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                  onPressed: () async {
                    if (_sessionId != null) {
                      await _cameraService.stopRecording();
                    }
                    if (mounted) context.pop();
                  },
                ),
              ),
            ),
          ),
        ],
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

class _RecordingPillState extends State<_RecordingPill> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
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
                color: Color.lerp(const Color(0xFFFF453A), const Color(0xFF7A0000), _ctl.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.elapsed,
            style: DCText.mono(size: 16, weight: FontWeight.w600, color: Colors.white, letterSpacing: -0.32),
          ),
        ],
      ),
    );
  }
}

class _ExpandedHud extends StatelessWidget {
  final String taskTitle;
  final String poseSource;
  const _ExpandedHud({required this.taskTitle, required this.poseSource});

  @override
  Widget build(BuildContext context) {
    final poseLabel = switch (poseSource) {
      'arkit' => 'ARKIT',
      'arcore' => 'ARCORE',
      'imu_raw' => 'IMU',
      _ => 'NONE',
    };
    final stats = [
      const ['FPS', '30'],
      const ['CODEC', 'HEVC'],
      const ['LENS', 'Ultrawide'],
      const ['BITRATE', '15 Mb/s'],
      const ['STAB', 'OFF'],
      ['POSE', poseLabel],
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
          Text(taskTitle, style: DCText.inter(size: 13, weight: FontWeight.w500, color: Colors.white)),
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
                  Text(s[0], style: DCText.mono(size: 9, weight: FontWeight.w500, color: Colors.white60, letterSpacing: 1.3)),
                  const SizedBox(height: 2),
                  Text(
                    s[1],
                    style: DCText.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: (s[0] == 'POSE' && s[1] != 'NONE')
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
