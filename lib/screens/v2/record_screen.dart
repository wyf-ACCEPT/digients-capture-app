import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/text_styles.dart';
import '../../services/camera_service.dart';
import '../../services/recording_manager.dart';
import '../../models/recording.dart';
import '../../fixtures/data.dart';

class RecordScreen extends StatefulWidget {
  final String taskId;
  const RecordScreen({super.key, required this.taskId});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final CameraService _cameraService = CameraService();
  final RecordingManager _recordingManager = RecordingManager();
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
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
  }) {
    final cam = _cameraInfo ?? <String, dynamic>{};
    final dev = _deviceInfo ?? <String, dynamic>{};
    final stab = (cam['videoStabilizationEnabled'] as bool?) ?? false;
    final os = (dev['os'] as String?) ?? (Platform.isAndroid ? 'android' : 'ios');
    final isAndroid = os == 'android';

    final IntrinsicsInfo intrinsics;
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
      // Per CLAUDE.md spec: Android intrinsics are reliable iff calibrated
      // (LENS_INTRINSIC_CALIBRATION available), hardware level is FULL/LEVEL_3,
      // and stabilization is off. The "static" source string here means calibrated.
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
      intrinsics = IntrinsicsInfo(
        source: 'per_frame',
        perFrameFile: 'frames.jsonl',
        reliable: !stab,
        notes: 'Per-frame intrinsics from CMSampleBuffer attachment.',
      );
    }

    return RecordingMetadata(
      schemaVersion: '1.0',
      sessionId: sessionId,
      capturedAtUtc: capturedAt,
      appVersion: '2.0.0',
      device: DeviceInfo(
        os: os,
        osVersion: (dev['osVersion'] as String?) ?? '',
        manufacturer: (dev['manufacturer'] as String?) ?? (isAndroid ? '' : 'Apple'),
        model: (dev['model'] as String?) ?? '',
        modelIdentifier: (dev['modelIdentifier'] as String?) ?? '',
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
        width: 1920,
        height: 1080,
        framerate: 30,
        durationSec: durationSeconds.toDouble(),
        frameCount: frameCount,
        bitrateBps: 15000000,
        colorSpace: 'bt709',
        pixelFormat: 'yuv420p',
        hasAudioTrack: false,
      ),
      intrinsics: intrinsics,
      capturePlatform: CapturePlatformInfo(
        flutterVersion: '3.41.7',
        nativeSdkVersion: isAndroid ? 'android' : 'ios',
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Center(child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: _RecordingPill(elapsed: _format(_elapsed)),
            )),
          ),
          if (_expanded)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: _ExpandedHud(taskTitle: findTask(widget.taskId)?.title ?? ''),
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
            child: Column(
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
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
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
  const _ExpandedHud({required this.taskTitle});

  @override
  Widget build(BuildContext context) {
    final stats = const [
      ['FPS', '30'],
      ['CODEC', 'HEVC'],
      ['LENS', 'Ultrawide'],
      ['BITRATE', '15 Mb/s'],
      ['STAB', 'OFF'],
      ['INTRINSICS', 'LIVE'],
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
                  Text(s[1], style: DCText.mono(size: 13, weight: FontWeight.w600, color: s[1] == 'LIVE' ? const Color(0xFF14C9A8) : Colors.white)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
