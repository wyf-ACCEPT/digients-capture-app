import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RecordingState {
  idle,
  recording,
  stopping,
  error,
}

class CameraService {
  static const MethodChannel _channel = MethodChannel('digients_app/camera');

  RecordingState _recordingState = RecordingState.idle;
  String? _currentSessionId;

  RecordingState get recordingState => _recordingState;
  String? get currentSessionId => _currentSessionId;

  final Stream<RecordingState> _stateController = const Stream.empty();
  Stream<RecordingState> get recordingStateStream => _stateController;

  Future<bool> initializeCamera() async {
    try {
      final bool result = await _channel.invokeMethod('initializeCamera');
      return result;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('requestPermissions');
      return result;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCameraInfo() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('getCameraInfo');
      return result?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('Error getting camera info: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('getDeviceInfo');
      return result?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('Error getting device info: $e');
      return null;
    }
  }

  Future<bool> startRecording(String sessionId, String outputDirectory) async {
    if (_recordingState != RecordingState.idle) {
      return false;
    }

    try {
      _recordingState = RecordingState.recording;
      _currentSessionId = sessionId;

      final bool result = await _channel.invokeMethod('startRecording', {
        'sessionId': sessionId,
        'outputDirectory': outputDirectory,
      });

      if (!result) {
        _recordingState = RecordingState.error;
        _currentSessionId = null;
      }

      return result;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _recordingState = RecordingState.error;
      _currentSessionId = null;
      return false;
    }
  }

  Future<Map<String, dynamic>?> stopRecording() async {
    if (_recordingState != RecordingState.recording) {
      return null;
    }

    try {
      _recordingState = RecordingState.stopping;

      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('stopRecording');

      _recordingState = RecordingState.idle;
      _currentSessionId = null;

      return result?.cast<String, dynamic>();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _recordingState = RecordingState.error;
      return null;
    }
  }

  Future<List<String>> getAvailableCameras() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('getAvailableCameras');
      return result?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('Error getting available cameras: $e');
      return [];
    }
  }

  Future<bool> switchCamera(String cameraId) async {
    try {
      final bool result =
          await _channel.invokeMethod('switchCamera', {'cameraId': cameraId});
      return result;
    } catch (e) {
      debugPrint('Error switching camera: $e');
      return false;
    }
  }

  void dispose() {
    if (_recordingState == RecordingState.recording) {
      stopRecording();
    }
  }
}
