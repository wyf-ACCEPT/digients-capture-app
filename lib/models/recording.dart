import 'dart:convert';

class Recording {
  final String sessionId;
  final DateTime capturedAt;
  final String directoryPath;
  final int? durationSeconds;
  final int? fileSizeMB;

  const Recording({
    required this.sessionId,
    required this.capturedAt,
    required this.directoryPath,
    this.durationSeconds,
    this.fileSizeMB,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'capturedAt': capturedAt.toIso8601String(),
      'directoryPath': directoryPath,
      'durationSeconds': durationSeconds,
      'fileSizeMB': fileSizeMB,
    };
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      sessionId: json['sessionId'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      directoryPath: json['directoryPath'] as String,
      durationSeconds: json['durationSeconds'] as int?,
      fileSizeMB: json['fileSizeMB'] as int?,
    );
  }
}

class DeviceInfo {
  final String os;
  final String osVersion;
  final String manufacturer;
  final String model;
  final String modelIdentifier;

  const DeviceInfo({
    required this.os,
    required this.osVersion,
    required this.manufacturer,
    required this.model,
    required this.modelIdentifier,
  });

  Map<String, dynamic> toJson() {
    return {
      'os': os,
      'os_version': osVersion,
      'manufacturer': manufacturer,
      'model': model,
      'model_identifier': modelIdentifier,
    };
  }
}

class CameraInfo {
  final String lensId;
  final String lensType;
  final double? physicalFocalLengthMm;
  final List<double>? sensorPhysicalSizeMm;
  final List<int>? sensorPixelArraySize;
  final double? horizontalFovDeg;
  final bool videoStabilizationEnabled;
  final bool opticalStabilizationEnabled;

  const CameraInfo({
    required this.lensId,
    required this.lensType,
    this.physicalFocalLengthMm,
    this.sensorPhysicalSizeMm,
    this.sensorPixelArraySize,
    this.horizontalFovDeg,
    required this.videoStabilizationEnabled,
    required this.opticalStabilizationEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'lens_id': lensId,
      'lens_type': lensType,
      'physical_focal_length_mm': physicalFocalLengthMm,
      'sensor_physical_size_mm': sensorPhysicalSizeMm,
      'sensor_pixel_array_size': sensorPixelArraySize,
      'horizontal_fov_deg': horizontalFovDeg,
      'video_stabilization_enabled': videoStabilizationEnabled,
      'optical_stabilization_enabled': opticalStabilizationEnabled,
    };
  }
}

class VideoInfo {
  final String codec;
  final String container;
  final int width;
  final int height;
  final double framerate;
  final double durationSec;
  final int frameCount;
  final int bitrateBps;
  final String colorSpace;
  final String pixelFormat;
  final bool hasAudioTrack;

  const VideoInfo({
    required this.codec,
    required this.container,
    required this.width,
    required this.height,
    required this.framerate,
    required this.durationSec,
    required this.frameCount,
    required this.bitrateBps,
    required this.colorSpace,
    required this.pixelFormat,
    required this.hasAudioTrack,
  });

  Map<String, dynamic> toJson() {
    return {
      'codec': codec,
      'container': container,
      'width': width,
      'height': height,
      'framerate': framerate,
      'duration_sec': durationSec,
      'frame_count': frameCount,
      'bitrate_bps': bitrateBps,
      'color_space': colorSpace,
      'pixel_format': pixelFormat,
      'has_audio_track': hasAudioTrack,
    };
  }
}

class IntrinsicsInfo {
  final String source;
  final String? perFrameFile;
  final List<List<double>>? staticMatrix;
  final String? distortionModel;
  final List<double>? distortionCoeffs;
  final bool reliable;
  final String notes;

  const IntrinsicsInfo({
    required this.source,
    this.perFrameFile,
    this.staticMatrix,
    this.distortionModel,
    this.distortionCoeffs,
    required this.reliable,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'per_frame_file': perFrameFile,
      'static_matrix': staticMatrix,
      'distortion_model': distortionModel,
      'distortion_coeffs': distortionCoeffs,
      'reliable': reliable,
      'notes': notes,
    };
  }
}

class CapturePlatformInfo {
  final String flutterVersion;
  final String nativeSdkVersion;

  const CapturePlatformInfo({
    required this.flutterVersion,
    required this.nativeSdkVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'flutter_version': flutterVersion,
      'native_sdk_version': nativeSdkVersion,
    };
  }
}

class RecordingMetadata {
  final String schemaVersion;
  final String sessionId;
  final DateTime capturedAtUtc;
  final String appVersion;
  final DeviceInfo device;
  final CameraInfo camera;
  final VideoInfo video;
  final IntrinsicsInfo intrinsics;
  final CapturePlatformInfo capturePlatform;

  const RecordingMetadata({
    required this.schemaVersion,
    required this.sessionId,
    required this.capturedAtUtc,
    required this.appVersion,
    required this.device,
    required this.camera,
    required this.video,
    required this.intrinsics,
    required this.capturePlatform,
  });

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'session_id': sessionId,
      'captured_at_utc': capturedAtUtc.toUtc().toIso8601String(),
      'app_version': appVersion,
      'device': device.toJson(),
      'camera': camera.toJson(),
      'video': video.toJson(),
      'intrinsics': intrinsics.toJson(),
      'capture_platform': capturePlatform.toJson(),
    };
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class FrameIntrinsics {
  final int frameIdx;
  final int timestampNs;
  final List<List<double>> intrinsicMatrix;
  final String? lensId;

  const FrameIntrinsics({
    required this.frameIdx,
    required this.timestampNs,
    required this.intrinsicMatrix,
    this.lensId,
  });

  Map<String, dynamic> toJson() {
    return {
      'frame_idx': frameIdx,
      'timestamp_ns': timestampNs,
      'intrinsic_matrix': intrinsicMatrix,
      if (lensId != null) 'lens_id': lensId,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }
}