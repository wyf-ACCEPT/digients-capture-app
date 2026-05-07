import 'dart:convert';

class Recording {
  final String sessionId;
  final DateTime capturedAt;
  final String directoryPath;
  final int? durationSeconds;
  final int? fileSizeMB;
  // Category slug (e.g. "kitchen", "living-room") of the task this clip
  // captured. Used to compose the export filename
  // `<categoryId>-<sessionId>.tar.gz`. Nullable for backward compatibility
  // with recordings persisted before this field was added.
  final String? categoryId;
  final String? taskId;

  const Recording({
    required this.sessionId,
    required this.capturedAt,
    required this.directoryPath,
    this.durationSeconds,
    this.fileSizeMB,
    this.categoryId,
    this.taskId,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'capturedAt': capturedAt.toIso8601String(),
      'directoryPath': directoryPath,
      'durationSeconds': durationSeconds,
      'fileSizeMB': fileSizeMB,
      if (categoryId != null) 'categoryId': categoryId,
      if (taskId != null) 'taskId': taskId,
    };
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      sessionId: json['sessionId'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      directoryPath: json['directoryPath'] as String,
      durationSeconds: json['durationSeconds'] as int?,
      fileSizeMB: json['fileSizeMB'] as int?,
      categoryId: json['categoryId'] as String?,
      taskId: json['taskId'] as String?,
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
  // Per v1.2 spec §3 + schema: only "ultrawide" / "wide" are accepted.
  final String lensType;
  final double? physicalFocalLengthMm;
  final List<double>? sensorPhysicalSizeMm;
  final List<int>? sensorPixelArraySize;
  final double? horizontalFovDeg;
  final bool videoStabilizationEnabled;
  final bool opticalStabilizationEnabled;
  // v1.2: top-to-bottom rolling-shutter readout time, nanoseconds.
  // Android: SENSOR_INFO_ROLLING_SHUTTER_SKEW (free).
  // iOS: not exposed; null unless we add a per-model_identifier table.
  final int? rollingShutterSkewNs;

  const CameraInfo({
    required this.lensId,
    required this.lensType,
    this.physicalFocalLengthMm,
    this.sensorPhysicalSizeMm,
    this.sensorPixelArraySize,
    this.horizontalFovDeg,
    required this.videoStabilizationEnabled,
    required this.opticalStabilizationEnabled,
    this.rollingShutterSkewNs,
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
      // Schema requires this field to be a non-negative int OR absent. Omit
      // when null to keep both branches valid.
      if (rollingShutterSkewNs != null)
        'rolling_shutter_skew_ns': rollingShutterSkewNs,
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
  // Per v1.2 spec only "static" is accepted by the validator. We keep this as
  // a string field rather than an enum so legacy reads (older bundles on disk
  // labeled "per_frame" / "estimated_fallback" / "none") still parse, but
  // every NEW write should set it to "static".
  final String source;
  final List<List<double>>? staticMatrix;
  // Distortion model — must be "brown_conrady" or "kannala_brandt", or null
  // when the lens is genuinely undistorted (rare for ultrawide).
  final String? distortionModel;
  // Brown-Conrady: [k1, k2, p1, p2, k3]. Kannala-Brandt: [k1, k2, k3, k4].
  final List<double>? distortionCoeffs;
  final bool reliable;
  final String notes;

  const IntrinsicsInfo({
    required this.source,
    this.staticMatrix,
    this.distortionModel,
    this.distortionCoeffs,
    required this.reliable,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'static_matrix': staticMatrix,
      // Pydantic validator rejects unknown distortion models; only emit a
      // value we know is valid.
      if (distortionModel != null) 'distortion_model': distortionModel,
      if (distortionCoeffs != null) 'distortion_coeffs': distortionCoeffs,
      'reliable': reliable,
      'notes': notes,
    };
  }
}

/// Legacy pose block. Under v1.2 this should NOT be emitted; we keep the
/// type so older v1.0/v1.1 metadata files can be deserialized for reads.
class PoseInfo {
  final String source;
  final String? notes;

  const PoseInfo({required this.source, this.notes});

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      if (notes != null) 'notes': notes,
    };
  }
}

class MotionInfo {
  // v1.2 requires this to be `true` and a non-empty motion.jsonl on disk.
  final bool recorded;
  final double? rateHz;
  final String? gyroUnits;
  final String? accelUnits;
  final bool? accelIncludesGravity;
  final String? frame;
  final String? notes;
  // v1.2 IMU noise model — continuous-time densities + random-walk densities.
  // All must be > 0 if set; the schema validator rejects 0 or negative. Omit
  // (leave null) if the per-device datasheet values aren't known yet.
  final double? noiseDensityGyro; // rad/s/√Hz
  final double? noiseDensityAccel; // m/s²/√Hz
  final double? randomWalkGyro; // rad/s²/√Hz
  final double? randomWalkAccel; // m/s³/√Hz

  const MotionInfo({
    required this.recorded,
    this.rateHz,
    this.gyroUnits,
    this.accelUnits,
    this.accelIncludesGravity,
    this.frame,
    this.notes,
    this.noiseDensityGyro,
    this.noiseDensityAccel,
    this.randomWalkGyro,
    this.randomWalkAccel,
  });

  Map<String, dynamic> toJson() {
    return {
      'recorded': recorded,
      if (rateHz != null) 'rate_hz': rateHz,
      if (gyroUnits != null) 'gyro_units': gyroUnits,
      if (accelUnits != null) 'accel_units': accelUnits,
      if (accelIncludesGravity != null)
        'accel_includes_gravity': accelIncludesGravity,
      if (frame != null) 'frame': frame,
      if (notes != null) 'notes': notes,
      if (noiseDensityGyro != null) 'noise_density_gyro': noiseDensityGyro,
      if (noiseDensityAccel != null) 'noise_density_accel': noiseDensityAccel,
      if (randomWalkGyro != null) 'random_walk_gyro': randomWalkGyro,
      if (randomWalkAccel != null) 'random_walk_accel': randomWalkAccel,
    };
  }
}

/// Camera-IMU rigid extrinsics. `T_cam_imu` maps a point in the IMU body
/// frame into the camera optical frame. v1.2 RECOMMENDED for any capture
/// intended for downstream VIO; OPTIONAL in the schema for backward compat.
///
/// The validator requires the bottom row to be exactly `[0, 0, 0, 1]`.
class ExtrinsicsInfo {
  final List<List<double>> tCamImu;
  // Must be one of: "platform_api", "model_calibration_table", "factory",
  // "online_estimated". The validator rejects anything else.
  final String source;
  // camera_pts_ns − imu_ts_ns, in seconds. Null when unknown — the offline
  // VIO will estimate it.
  final double? timeOffsetSec;
  final double? rotationStddevDeg;
  final double? translationStddevM;
  final String? notes;

  const ExtrinsicsInfo({
    required this.tCamImu,
    required this.source,
    this.timeOffsetSec,
    this.rotationStddevDeg,
    this.translationStddevM,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'T_cam_imu': tCamImu,
      'source': source,
      if (timeOffsetSec != null) 'time_offset_sec': timeOffsetSec,
      if (rotationStddevDeg != null) 'rotation_stddev_deg': rotationStddevDeg,
      if (translationStddevM != null)
        'translation_stddev_m': translationStddevM,
      if (notes != null) 'notes': notes,
    };
  }
}

class CapturePlatformInfo {
  final String flutterVersion;
  final String nativeSdkVersion;
  final String? capturePipelineVersion;

  const CapturePlatformInfo({
    required this.flutterVersion,
    required this.nativeSdkVersion,
    this.capturePipelineVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'flutter_version': flutterVersion,
      'native_sdk_version': nativeSdkVersion,
      if (capturePipelineVersion != null)
        'capture_pipeline_version': capturePipelineVersion,
    };
  }
}

class RecordingMetadata {
  final String schemaVersion;
  final String sessionId;
  final DateTime capturedAtUtc;
  // Per spec: "unix_epoch" or "session_start". Tells consumers what
  // timestamp_ns is referenced to.
  final String sessionClockOrigin;
  final String appVersion;
  final DeviceInfo device;
  final CameraInfo camera;
  final VideoInfo video;
  final IntrinsicsInfo intrinsics;
  // v1.2: pose block is optional and SHOULD be omitted entirely. Kept for
  // backward-compat reads only; new writes should pass null.
  final PoseInfo? pose;
  final MotionInfo motion;
  final ExtrinsicsInfo? extrinsics;
  // v1.2: explicit clock-id label, e.g. "CLOCK_BOOTTIME", "CLOCK_MONOTONIC",
  // "mach_absolute_time". OPTIONAL but RECOMMENDED.
  final String? deviceClockId;
  final CapturePlatformInfo capturePlatform;

  const RecordingMetadata({
    required this.schemaVersion,
    required this.sessionId,
    required this.capturedAtUtc,
    required this.sessionClockOrigin,
    required this.appVersion,
    required this.device,
    required this.camera,
    required this.video,
    required this.intrinsics,
    this.pose,
    required this.motion,
    this.extrinsics,
    this.deviceClockId,
    required this.capturePlatform,
  });

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'session_id': sessionId,
      'captured_at_utc': capturedAtUtc.toUtc().toIso8601String(),
      'session_clock_origin': sessionClockOrigin,
      'app_version': appVersion,
      'device': device.toJson(),
      'camera': camera.toJson(),
      'video': video.toJson(),
      'intrinsics': intrinsics.toJson(),
      if (pose != null) 'pose': pose!.toJson(),
      'motion': motion.toJson(),
      if (extrinsics != null) 'extrinsics': extrinsics!.toJson(),
      if (deviceClockId != null) 'device_clock_id': deviceClockId,
      'capture_platform': capturePlatform.toJson(),
    };
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
