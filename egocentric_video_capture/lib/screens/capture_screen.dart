import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_service.dart';
import '../services/recording_manager.dart';
import '../models/recording.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final RecordingManager _recordingManager = RecordingManager();

  bool _isInitialized = false;
  bool _hasPermission = false;
  RecordingState _recordingState = RecordingState.idle;
  String? _currentSessionId;
  DateTime? _recordingStartTime;
  String? _errorMessage;
  Map<String, dynamic>? _cameraInfo;
  Map<String, dynamic>? _deviceInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _recordingState == RecordingState.recording) {
      _stopRecording();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      // Request permissions first
      final bool permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        setState(() {
          _errorMessage = 'Camera permission is required to use this app';
        });
        return;
      }

      setState(() {
        _hasPermission = true;
      });

      // Initialize camera
      final bool initialized = await _cameraService.initializeCamera();
      if (!initialized) {
        setState(() {
          _errorMessage = 'Failed to initialize camera';
        });
        return;
      }

      // Get camera and device info
      final Map<String, dynamic>? cameraInfo = await _cameraService.getCameraInfo();
      final Map<String, dynamic>? deviceInfo = await _cameraService.getDeviceInfo();

      setState(() {
        _isInitialized = initialized;
        _cameraInfo = cameraInfo;
        _deviceInfo = deviceInfo;
        _recordingState = _cameraService.recordingState;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final PermissionStatus cameraStatus = await Permission.camera.request();
    return cameraStatus.isGranted;
  }

  Future<void> _startRecording() async {
    if (_recordingState != RecordingState.idle || !_isInitialized) {
      return;
    }

    try {
      final String sessionId = _recordingManager.generateSessionId();
      final String outputDirectory = await _recordingManager.createRecordingDirectory(sessionId);

      final bool started = await _cameraService.startRecording(sessionId, outputDirectory);

      if (started) {
        setState(() {
          _currentSessionId = sessionId;
          _recordingState = RecordingState.recording;
          _recordingStartTime = DateTime.now();
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to start recording';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error starting recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_recordingState != RecordingState.recording) {
      return;
    }

    try {
      setState(() {
        _recordingState = RecordingState.stopping;
      });

      final Map<String, dynamic>? result = await _cameraService.stopRecording();

      if (result != null && _currentSessionId != null) {
        final DateTime capturedAt = _recordingStartTime ?? DateTime.now();
        final int? fileSizeMB = await _recordingManager.calculateRecordingSize(_currentSessionId!);

        final Recording recording = Recording(
          sessionId: _currentSessionId!,
          capturedAt: capturedAt,
          directoryPath: result['directoryPath'] ?? '',
          durationSeconds: result['durationSeconds'] as int?,
          fileSizeMB: fileSizeMB,
        );

        await _recordingManager.saveRecording(recording);

        setState(() {
          _recordingState = RecordingState.idle;
          _currentSessionId = null;
          _recordingStartTime = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to stop recording';
          _recordingState = RecordingState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error stopping recording: $e';
        _recordingState = RecordingState.error;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final String minutes = duration.inMinutes.toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Egocentric Video Capture'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow('Camera', _isInitialized ? 'Ready' : 'Not initialized'),
                    _buildStatusRow('Permissions', _hasPermission ? 'Granted' : 'Not granted'),
                    _buildStatusRow('Recording', _getRecordingStateText()),
                    if (_recordingState == RecordingState.recording && _recordingStartTime != null) ...[
                      const SizedBox(height: 8),
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 1)),
                        builder: (context, snapshot) {
                          final Duration elapsed = DateTime.now().difference(_recordingStartTime!);
                          return Text(
                            'Recording time: ${_formatDuration(elapsed)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Camera Info Card
            if (_cameraInfo != null || _deviceInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Camera Info',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_deviceInfo != null) ...[
                        _buildInfoRow('Device', _deviceInfo!['model'] ?? 'Unknown'),
                        _buildInfoRow('OS', '${_deviceInfo!['os']} ${_deviceInfo!['osVersion']}'),
                      ],
                      if (_cameraInfo != null) ...[
                        _buildInfoRow('Lens', _cameraInfo!['lensType'] ?? 'Unknown'),
                        _buildInfoRow('FOV', '${_cameraInfo!['horizontalFovDeg']?.toStringAsFixed(1)}°'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error Message
            if (_errorMessage != null) ...[
              Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Spacer(),

            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isInitialized ? null : _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Initialize'),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: ElevatedButton(
                    onPressed: _getRecordButtonAction(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getRecordButtonColor(),
                      shape: const CircleBorder(),
                    ),
                    child: _getRecordButtonChild(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _hasPermission ? null : _requestPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Permissions'),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getStatusColor(label, value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color? _getStatusColor(String label, String value) {
    if (label == 'Camera' && value == 'Ready') return Colors.green;
    if (label == 'Permissions' && value == 'Granted') return Colors.green;
    if (label == 'Recording' && value == 'Recording') return Colors.red;
    if (value.contains('Not') || value.contains('Error')) return Colors.red;
    return null;
  }

  String _getRecordingStateText() {
    switch (_recordingState) {
      case RecordingState.idle:
        return 'Idle';
      case RecordingState.recording:
        return 'Recording';
      case RecordingState.stopping:
        return 'Stopping';
      case RecordingState.error:
        return 'Error';
    }
  }

  VoidCallback? _getRecordButtonAction() {
    if (!_isInitialized || !_hasPermission) return null;

    switch (_recordingState) {
      case RecordingState.idle:
        return _startRecording;
      case RecordingState.recording:
        return _stopRecording;
      case RecordingState.stopping:
      case RecordingState.error:
        return null;
    }
  }

  Color _getRecordButtonColor() {
    switch (_recordingState) {
      case RecordingState.idle:
        return Colors.red;
      case RecordingState.recording:
        return Colors.red[300]!;
      case RecordingState.stopping:
        return Colors.grey;
      case RecordingState.error:
        return Colors.red[900]!;
    }
  }

  Widget _getRecordButtonChild() {
    switch (_recordingState) {
      case RecordingState.idle:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fiber_manual_record, size: 40, color: Colors.white),
            Text('Record', style: TextStyle(color: Colors.white)),
          ],
        );
      case RecordingState.recording:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop, size: 40, color: Colors.white),
            Text('Stop', style: TextStyle(color: Colors.white)),
          ],
        );
      case RecordingState.stopping:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text('Stopping...', style: TextStyle(color: Colors.white)),
          ],
        );
      case RecordingState.error:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 40, color: Colors.white),
            Text('Error', style: TextStyle(color: Colors.white)),
          ],
        );
    }
  }
}