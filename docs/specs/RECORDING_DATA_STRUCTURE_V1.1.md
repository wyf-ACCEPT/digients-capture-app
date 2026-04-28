# RECORDING_DATA_STRUCTURE_V1.1

This is the upgraded contract between the **mobile capture app (Flutter, iOS+Android)** and the **post-processing pipeline**. It supersedes the v1.0 schema in `PIPELINE_SPECS_V1.md` §5. The schema bumps to `"1.1"`. Backward compatibility: v1.0 captures still parse — pipeline simply treats them as `pose_source == "none"`.

The big idea: capture **whatever pose-quality signal the device can provide**, in tiers. The pipeline picks the best one available per recording.

---

## 1. What's new vs. v1.0

| Change | Why |
|---|---|
| Added `pose_source` field in `metadata.json` | Tells the pipeline which pose pipeline to run (skip SLAM if ARKit/ARCore is present, run VIO if IMU is present, fall back to monocular SLAM otherwise). |
| Added optional `poses.jsonl` (per-frame 6DOF pose from ARKit / ARCore) | Best-quality path. Apple's ARKit and Google's ARCore both fuse camera + IMU and give cm-accurate poses for free on supported devices. |
| Added optional `motion.jsonl` (raw IMU stream at 100–200 Hz) | Universal fallback. Every smartphone has gyro + accelerometer; capture them always so the pipeline can run offline VIO when ARKit/ARCore isn't available or when their tracking is `limited`/`not_available`. |
| `metadata.json.intrinsics.distortion_coeffs` SHOULD be populated when known | Reduces wide-FOV SLAM drift when ARKit/ARCore aren't supplying poses. |
| **Fix:** `frames.jsonl` `intrinsic_matrix` MUST be strict row-major `[[fx, 0, cx], [0, fy, cy], [0, 0, 1]]` | The current iOS app serializes `simd_float3x3` with an off-by-one padding bug (cx ends up at `K[2][2]`, cy is missing). The pipeline tolerates it today but a clean fix on the writer side is required for v1.1. See §6.1. |
| **Fix:** `video.mp4` MUST be a finalized MP4 with `moov` atom present | Two of the v1.0 sample recordings were missing `moov` (capture session never finalized). The pipeline can recover them via mdat repair, but new captures must finalize properly. Use `+faststart` so `moov` is at the head for streaming-friendly output. |

Everything else from v1.0 §5 still applies: the input is still a directory `recording_<sid>/` (UUID v4), still tar-gzipped on transfer, still HEVC 1920×1080 30 fps with no audio.

---

## 2. Directory layout

```
recording_<sid>/                    # <sid> = UUID v4 (unchanged)
├── metadata.json                   # session-level (REQUIRED, expanded)
├── video.mp4                       # HEVC, finalized (REQUIRED)
├── frames.jsonl                    # per-frame intrinsics + timestamps (REQUIRED iff intrinsics.source == "per_frame")
├── poses.jsonl                     # per-frame ARKit/ARCore pose (REQUIRED iff pose_source ∈ {"arkit","arcore"})
└── motion.jsonl                    # raw IMU stream (RECOMMENDED on all captures, REQUIRED iff pose_source == "imu_raw")
```

When transferred, packed as `recording_<sid>.tar.gz`.

The four files MUST share the same monotonic clock for their `timestamp_ns` fields. Either (a) Unix epoch nanoseconds, or (b) nanoseconds since session start — pick one and document it in `metadata.session_clock_origin`. Mixing them is a defect.

---

## 3. `metadata.json` — full schema

```json
{
  "schema_version": "1.1",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "captured_at_utc": "2026-04-27T14:32:11.123Z",
  "session_clock_origin": "unix_epoch",
  "app_version": "2.1.0",

  "device": {
    "os": "ios",
    "os_version": "17.4.1",
    "manufacturer": "Apple",
    "model": "iPhone 15 Pro",
    "model_identifier": "iPhone16,1",
    "has_arkit": true,
    "has_arcore": false
  },

  "camera": {
    "lens_id": "com.apple.avfoundation.avcapturedevice.built-in_video:5",
    "lens_type": "ultrawide",
    "physical_focal_length_mm": 2.22,
    "sensor_physical_size_mm": [7.6, 5.7],
    "sensor_pixel_array_size": [4032, 3024],
    "horizontal_fov_deg": 120.0,
    "video_stabilization_enabled": false,
    "optical_stabilization_enabled": false
  },

  "video": {
    "codec": "hevc",
    "container": "mp4",
    "width": 1920,
    "height": 1080,
    "framerate": 30.0,
    "duration_sec": 12.5,
    "frame_count": 375,
    "bitrate_bps": 15000000,
    "color_space": "bt709",
    "pixel_format": "yuv420p",
    "has_audio_track": false
  },

  "intrinsics": {
    "source": "per_frame",
    "per_frame_file": "frames.jsonl",
    "static_matrix": null,
    "distortion_model": "brown_conrady",
    "distortion_coeffs": [-0.12, 0.08, 0.0, 0.0, 0.0],
    "reliable": true,
    "notes": "Per-frame intrinsics from ARFrame.camera.intrinsics."
  },

  "pose": {
    "source": "arkit",
    "frame_origin": "arkit_session",
    "coordinate_convention": "right_handed_y_up_neg_z_forward",
    "transform_kind": "camera_to_world",
    "rate_hz": 60,
    "tracking_state_field": "tracking_state",
    "notes": "ARWorldTrackingConfiguration, planeDetection=horizontal, autoFocusEnabled=false."
  },

  "motion": {
    "recorded": true,
    "rate_hz": 100,
    "gyro_units": "rad/s",
    "accel_units": "m/s^2",
    "accel_includes_gravity": true,
    "frame": "device_body",
    "notes": "iOS CMMotionManager.deviceMotion (raw + bias-corrected gyro)."
  },

  "capture_platform": {
    "flutter_version": "3.41.7",
    "native_sdk_version": "iOS 17.4 SDK",
    "capture_pipeline_version": "2.1.0"
  }
}
```

### 3.1 New / changed fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema_version` | string | yes | Must be `"1.1"` for this spec. v1.0 also still accepted by the pipeline. |
| `session_clock_origin` | enum | yes | `"unix_epoch"` or `"session_start"`. Tells consumers what `timestamp_ns` is referenced to. New in v1.1. |
| `device.has_arkit` | bool | yes (iOS) | Set true when `ARWorldTrackingConfiguration.isSupported` reports true. |
| `device.has_arcore` | bool | yes (Android) | Set true when `ArCoreApk.checkAvailability()` returns `SUPPORTED_INSTALLED`. |
| `pose.source` | enum | yes | `"arkit"`, `"arcore"`, `"imu_raw"`, or `"none"`. Routes the pipeline. |
| `pose.frame_origin` | string | yes when source ∈ {arkit, arcore} | What the pose is anchored to. ARKit: `"arkit_session"`. ARCore: `"arcore_session"`. Custom VIO: `"first_video_frame"`. |
| `pose.coordinate_convention` | string | yes when poses.jsonl exists | Currently always `"right_handed_y_up_neg_z_forward"` (ARKit and ARCore agree). Pipeline converts to OpenCV internally. |
| `pose.transform_kind` | enum | yes | `"camera_to_world"` (preferred) or `"world_to_camera"`. ARKit and ARCore both give camera-to-world. |
| `pose.rate_hz` | float | yes | Typical: 60 (ARKit) or 30 (ARCore tied to camera framerate). |
| `motion.recorded` | bool | yes | True iff `motion.jsonl` is present and non-empty. |
| `motion.rate_hz` | float | yes when recorded | Effective sample rate (Hz). |
| `motion.gyro_units` | string | yes when recorded | Always `"rad/s"`. |
| `motion.accel_units` | string | yes when recorded | Always `"m/s^2"`. |
| `motion.accel_includes_gravity` | bool | yes when recorded | iOS `CMMotionManager.deviceMotion.userAcceleration` excludes gravity (false); raw `accelerometerData` includes gravity (true). Android `TYPE_ACCELEROMETER` includes gravity (true). Document the choice; pipeline handles both. |
| `motion.frame` | string | yes when recorded | `"device_body"` is the default. ARKit/ARCore expose IMU in device-body frame. |

---

## 4. `pose_source` decision flow (mobile-side)

Both iOS and Android should follow the same priority cascade per session:

```
1. If platform supports system-level VIO (ARKit on iOS, ARCore on Android):
   - Capture poses → poses.jsonl, set pose.source = "arkit" or "arcore"
   - ALSO capture raw IMU → motion.jsonl (cheap, gives the pipeline a recovery path)
2. Else if device has gyro + accelerometer:
   - Capture raw IMU → motion.jsonl, set pose.source = "imu_raw"
   - DON'T write poses.jsonl
3. Else (very rare in 2026):
   - Set pose.source = "none"
   - Pipeline falls back to monocular SLAM (ATE-gated quality)
```

In all cases `motion.jsonl` SHOULD be captured if the hardware allows. It's a few hundred KB per minute of recording — negligible vs. video — and it's the universal recovery path.

---

## 5. `poses.jsonl` (NEW)

One JSON object per video frame, one line, frame order. Required iff `pose.source ∈ {"arkit", "arcore"}`. Line count MUST equal `video.frame_count` and align 1-to-1 with `frames.jsonl`.

```jsonl
{"frame_idx":0,"timestamp_ns":1714147931123000000,"transform":[[0.999,-0.012,0.044,0.000],[0.013,0.999,-0.018,0.000],[-0.044,0.018,0.998,0.000],[0.000,0.000,0.000,1.000]],"tracking_state":"normal"}
{"frame_idx":1,"timestamp_ns":1714147931156333000,"transform":[[0.998,-0.014,0.061,0.005],[0.015,0.999,-0.019,0.001],[-0.061,0.019,0.998,-0.002],[0.000,0.000,0.000,1.000]],"tracking_state":"normal"}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `frame_idx` | int | yes | 0-based, matches `frames.jsonl[i].frame_idx`. |
| `timestamp_ns` | int | yes | Same clock as `frames.jsonl[i].timestamp_ns`. SHOULD equal it exactly. |
| `transform` | 4×4 array | yes | **Row-major**, camera-to-world by default. Right-handed, +Y up, -Z forward (ARKit/ARCore native). |
| `tracking_state` | enum | yes | `"normal"`, `"limited"`, or `"not_available"`. ARKit `ARCamera.trackingState` and ARCore `Camera.getTrackingState()` map directly. |
| `tracking_state_reason` | string | optional | If `limited`, the reason from the OS (e.g. `"insufficient_features"`, `"excessive_motion"`, `"initialization"`). |

**Drop-out semantics.** When tracking is lost mid-recording, **still write a row per frame** with the last good transform and `tracking_state: "not_available"`. Don't silently skip frames — the pipeline needs the row count to match the video. If the OS gives no transform at all for a frame, write an identity matrix and `not_available` (pipeline will discard it).

---

## 6. `frames.jsonl` (CHANGED — now strictly spec-compliant)

```jsonl
{"frame_idx":0,"timestamp_ns":1714147931123000000,"intrinsic_matrix":[[1520.3,0.0,960.1],[0.0,1520.3,540.2],[0.0,0.0,1.0]],"lens_id":"com.apple.avfoundation.avcapturedevice.built-in_video:5"}
```

Schema is unchanged from v1.0 §5.3. **The fix is on the writer side:** the `intrinsic_matrix` MUST be a 3×3 row-major matrix in the form `[[fx, 0, cx], [0, fy, cy], [0, 0, 1]]`. This is the **standard pinhole intrinsic matrix**.

### 6.1 The iOS `simd_float3x3` serialization bug

The current iOS app appears to serialize the `intrinsic_matrix` from a `simd_float3x3` buffer that includes 4-byte padding per column, reading 9 consecutive floats from a 12-float padded layout. The result looks like `[[fx, 0, 0], [0, 0, fy], [0, 0, cx]]` and **drops cy entirely**. Reproducible across all v1.0 iOS samples. The pipeline auto-recovers (synthesizes `cy = height/2`) but downstream consumers shouldn't rely on the recovery.

**Correct iOS serialization (Swift, ARKit):**

```swift
import ARKit

func intrinsicRows(from frame: ARFrame) -> [[Float]] {
    let m = frame.camera.intrinsics  // simd_float3x3, columns: (fx,0,0), (0,fy,0), (cx,cy,1)
    return [
        [m.columns.0[0], m.columns.1[0], m.columns.2[0]],  // fx, 0,  cx
        [m.columns.0[1], m.columns.1[1], m.columns.2[1]],  //  0, fy, cy
        [m.columns.0[2], m.columns.1[2], m.columns.2[2]],  //  0,  0,  1
    ]
}
```

The validator will reject matrices whose third row isn't `[0, 0, 1]` once the writer is fixed. Until then the pipeline keeps its tolerant parser, but emits a `warnings: ["legacy_ios_simd_intrinsic"]` entry in `results_metadata.json`.

### 6.2 `intrinsics.distortion_coeffs`

Populate this when the platform exposes it. iOS ARKit publishes `lensDistortionLookupTable` (a calibrated lookup, not Brown-Conrady, but you can convert; or use a pre-baked Brown-Conrady profile per `model_identifier`). Android `CameraCharacteristics.LENS_DISTORTION` returns `[k1, k2, k3, p1, p2]` directly.

When unknown, leave it `null` — better than guessing wrong.

### 6.3 The Android sensor-vs-video resolution bug (observed in v1.1 OnePlus 5 sample)

The OnePlus 5 sample (`recording_7bb366c5-...`) ships an `intrinsics.static_matrix` whose **`fx, fy` are in pixels at the full sensor resolution (4672×3512), not at the recorded video resolution (1920×1080)**. The principal point `cx, cy` is correctly set at the video center (960, 540). The result is an internally-inconsistent K that overestimates focal length by ~2.43×, implying a 29° FOV when the metadata correctly reports 65°.

What the writer almost certainly did:

```
fx = focal_mm * (sensor_pixel_array_size[0] / sensor_physical_size_mm[0])  // sensor px/mm
                                                                            // → fx in sensor px
cx = video.width / 2                                                        // already in video px
```

Both lines are individually correct *for their own coordinate system*; the bug is mixing them. The fix is one of:

```
# Option A (preferred): scale fx/fy to video resolution
fx = focal_mm * (sensor_pixel_array_size[0] / sensor_physical_size_mm[0]) \
        * (video.width / sensor_pixel_array_size[0])
fy = focal_mm * (sensor_pixel_array_size[1] / sensor_physical_size_mm[1]) \
        * (video.height / sensor_pixel_array_size[1])

# Option B: derive directly from FOV
fx = video.width  / (2 * tan(camera.horizontal_fov_deg * π / 360))
fy = fx  # if pixels are square
```

**Validation rule for v1.1:** the FOV implied by the static `K` and the video resolution must agree with `camera.horizontal_fov_deg` to within 10%. The pipeline auto-detects and rescales the asymmetric form (only `fx, fy` rescaled, `cx, cy` left at video center) and emits a warning until v1.0/v1.1 captures stop arriving with the bug.

---

## 7. `motion.jsonl` (NEW)

One JSON object per IMU sample. Sample rate higher than the video framerate (typical: 100 Hz, often up to 200 Hz). Lines NOT aligned with frame indices (different rate); aligned only via `timestamp_ns`.

```jsonl
{"timestamp_ns":1714147931120000000,"gyro":[0.012,-0.034,0.005],"accel":[-0.211,9.812,-0.044]}
{"timestamp_ns":1714147931130000000,"gyro":[0.014,-0.031,0.006],"accel":[-0.215,9.808,-0.041]}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `timestamp_ns` | int | yes | Same clock as video frames. **Critical:** offline VIO depends on tight time alignment between IMU and video frames; allow ≤ 5 ms skew. |
| `gyro` | `[gx, gy, gz]` rad/s | yes | Body frame. iOS: `CMDeviceMotion.rotationRate` (bias-corrected) preferred over raw `gyroData`. Android: `Sensor.TYPE_GYROSCOPE`. |
| `accel` | `[ax, ay, az]` m/s² | yes | Body frame. iOS: `CMDeviceMotion.userAcceleration` × g + gravity reconstructed, or use raw `CMAccelerometerData`. Document `accel_includes_gravity` in metadata accordingly. Android: `Sensor.TYPE_ACCELEROMETER`. |
| `mag` | `[mx, my, mz]` µT | optional | Magnetometer if available. Useful for absolute orientation. |
| `temperature_c` | float | optional | IMU die temperature, helps bias correction in long sessions. |

**Sampling guidance:**
- Target 100 Hz minimum. 200 Hz preferred (matches the natural sampling rate of most consumer IMUs and gives the offline VIO better integration accuracy).
- Don't down-sample on-device. Stream raw at the highest available rate; the pipeline can always decimate.
- If using iOS's `CMDeviceMotion`, the typical default is 60 Hz — explicitly bump it to 100 via `motionManager.deviceMotionUpdateInterval = 0.01`.

---

## 8. Coordinate conventions

| | ARKit | ARCore | Pipeline (OpenCV) |
|---|---|---|---|
| X | right | right | right |
| Y | up | up | **down** |
| Z | toward the user (camera looks down -Z) | toward the user (camera looks down -Z) | away from camera (camera looks down +Z) |
| Handedness | right | right | right |
| Origin | first ARFrame | session start | first video frame |

The mobile app **writes the OS-native pose** (camera-to-world, +Y up, -Z forward). The pipeline converts to OpenCV camera convention internally with a fixed similarity transform (flip Y and Z). Don't try to convert on the device — that just spreads bug surface.

For `transform`, write the 4×4 in **row-major** order. JSON shape is `[row0, row1, row2, row3]`, each row is `[col0, col1, col2, col3]`.

---

## 9. Per-platform implementation notes

### 9.1 iOS (Flutter via platform-channel or `arkit_flutter_plugin`)

Required components:
- `ARSession` with `ARWorldTrackingConfiguration` for the pose stream.
- `AVCaptureSession` for video recording (existing).
- `CMMotionManager` for IMU stream.

Sketch (Swift, simplified — Flutter can call this via a method channel):

```swift
import ARKit
import CoreMotion
import AVFoundation

class CaptureSession {
    let arSession = ARSession()
    let motionManager = CMMotionManager()
    var posesFile: FileHandle?
    var motionFile: FileHandle?

    func start(_ recordingDir: URL) {
        // ARKit: publishes ARFrame at framerate (60 Hz typically)
        arSession.delegate = self
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = .horizontal
        cfg.isAutoFocusEnabled = false  // stable intrinsics
        arSession.run(cfg)

        // IMU: 100 Hz device motion
        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let m = motion else { return }
            let rec: [String: Any] = [
                "timestamp_ns": Int(m.timestamp * 1e9),
                "gyro": [m.rotationRate.x, m.rotationRate.y, m.rotationRate.z],
                "accel": [m.userAcceleration.x * 9.81, m.userAcceleration.y * 9.81, m.userAcceleration.z * 9.81],
            ]
            // append JSON to motionFile
        }

        // AVCaptureSession for video.mp4 (existing pipeline) – ensure
        // movieFileOutput uses .mov first then convert with -movflags +faststart,
        // OR use AVAssetWriter with .mp4 and finishWriting() in stop().
    }
}

extension CaptureSession: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Match ARFrame timestamps to video frames via the session clock
        let t = frame.timestamp  // CFTimeInterval
        let m = frame.camera.transform  // simd_float4x4
        let rows: [[Float]] = (0..<4).map { r in (0..<4).map { c in m[c, r] } }
        let trackingState: String = {
            switch frame.camera.trackingState {
            case .normal: return "normal"
            case .limited: return "limited"
            case .notAvailable: return "not_available"
            }
        }()
        let rec: [String: Any] = [
            "frame_idx": currentVideoFrameIdx,
            "timestamp_ns": Int(t * 1e9),
            "transform": rows,
            "tracking_state": trackingState,
        ]
        // append JSON to posesFile
    }
}
```

Notes:
- `simd_float4x4` indexes `[col, row]`, so the transpose is needed for row-major output.
- `frame.camera.intrinsics` is also `simd_float3x3` — see §6.1 for the correct serialization.
- ARKit emits `ARFrame`s at video framerate. If video is recorded separately (AVCaptureSession), align via `frame.capturedImage`'s `CMSampleBuffer` PTS.
- Set `cfg.frameSemantics = []` (no need for personSegmentation etc.).

### 9.2 Android (Flutter via `arcore_flutter_plugin` or platform-channel)

Required components:
- `Session` from ARCore for pose stream (when supported).
- `CameraManager` (Camera2) for video (existing).
- `SensorManager` for raw IMU (always).

Detection:

```kotlin
val availability = ArCoreApk.getInstance().checkAvailability(context)
val poseSource = when {
    availability == Availability.SUPPORTED_INSTALLED -> "arcore"
    hasGyroAndAccel(context) -> "imu_raw"
    else -> "none"
}
```

ARCore pose emission:

```kotlin
val frame = session.update()
val pose = frame.camera.pose  // float[]: tx,ty,tz,qx,qy,qz,qw -> convert to 4x4
val state = when (frame.camera.trackingState) {
    TrackingState.TRACKING -> "normal"
    TrackingState.PAUSED   -> "limited"
    else                   -> "not_available"
}
```

IMU registration:

```kotlin
val gyro = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
val accel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
sensorManager.registerListener(listener, gyro, SensorManager.SENSOR_DELAY_FASTEST)
sensorManager.registerListener(listener, accel, SensorManager.SENSOR_DELAY_FASTEST)
```

`SensorEvent.timestamp` is in nanoseconds since boot — convert to your chosen `session_clock_origin` consistently.

Notes:
- ARCore `frame.camera.imageIntrinsics` and `frame.camera.textureIntrinsics` differ. Use `imageIntrinsics` for what matches the captured image.
- Android `TYPE_ACCELEROMETER` includes gravity (set `motion.accel_includes_gravity = true`). For gravity-removed values, use `TYPE_LINEAR_ACCELERATION` and document that.

### 9.3 Universal raw-IMU path (no ARKit/ARCore)

Use Flutter's `sensors_plus` package:

```dart
import 'package:sensors_plus/sensors_plus.dart';

userAccelerometerEvents.listen((e) { /* write to motion.jsonl */ });
gyroscopeEvents.listen((e) { /* write to motion.jsonl */ });
```

Be aware: `sensors_plus` returns ~50–100 Hz on most devices. For higher rates use a platform channel directly to `SensorManager` / `CMMotionManager`.

---

## 10. Validation rules (additions to v1.0 §5.4)

The pipeline's `pipeline.schema.validate_recording()` adds these checks for v1.1:

- `schema_version` MUST be `"1.0"` or `"1.1"`.
- `pose.source` ∈ `{"arkit", "arcore", "imu_raw", "none"}`.
- If `pose.source == "arkit" or "arcore"`: `poses.jsonl` MUST exist with **exactly `video.frame_count` lines**, frame indices 0..N-1, timestamps strictly increasing.
- If `pose.source == "imu_raw"`: `motion.jsonl` MUST exist and be non-empty; `motion.recorded` MUST be `true`.
- If `motion.recorded == true`: `motion.jsonl` MUST exist; rate-hz consistency check (median Δt within 30% of advertised rate).
- `frames.jsonl` `intrinsic_matrix` rows: third row strictly `[0, 0, 1]`. (Tolerant parser still ships behind a warning until v1.0 captures stop arriving.)
- `video.mp4` MUST be openable by both PyAV and `ffprobe` without `moov atom not found` errors.

---

## 11. Migration / examples

A complete v1.1 iPhone bundle:

```
recording_550e8400-e29b-41d4-a716-446655440000/
├── metadata.json            # 1.4 KB
├── video.mp4                # ~1 MB / sec @ 15 Mbps
├── frames.jsonl             # ~120 B / frame ≈ 14 KB / sec @ 30 fps
├── poses.jsonl              # ~250 B / frame ≈ 30 KB / sec @ 30 fps
└── motion.jsonl             # ~80 B / sample ≈ 16 KB / sec @ 200 Hz
```

Total auxiliary overhead: ~60 KB / sec ≈ **0.4% of the video bitrate**. Negligible.

A v1.1 Android-without-ARCore bundle has no `poses.jsonl`:

```
recording_<sid>/
├── metadata.json            # pose.source = "imu_raw"
├── video.mp4
├── frames.jsonl             # source may be "static" if device camera intrinsics are fixed
└── motion.jsonl             # required, the sole pose-source signal
```

A v1.0 bundle (no `pose.source` field) is treated as `"none"` by the pipeline — backward-compatible.

---

## 12. Quick checklist for the Flutter team

- [ ] Bump `schema_version` to `"1.1"`.
- [ ] Set `device.has_arkit` / `has_arcore` correctly.
- [ ] Always record `motion.jsonl` if the device has IMU (cheap, universal recovery path).
- [ ] If ARKit available → run `ARWorldTrackingConfiguration`, write `poses.jsonl`, `pose.source = "arkit"`.
- [ ] If ARCore available → run ARCore Session, write `poses.jsonl`, `pose.source = "arcore"`.
- [ ] Otherwise set `pose.source = "imu_raw"` (or `"none"` if no IMU).
- [ ] **Fix the `simd_float3x3` serialization bug** in `frames.jsonl` (§6.1).
- [ ] **Fix the sensor-vs-video resolution scaling bug** in `intrinsics.static_matrix` (§6.3) — `fx, fy` must be in pixels at the *video* resolution, not the full sensor resolution.
- [ ] **Finalize MP4** (write `moov`; use `+faststart` so it lives at the head).
- [ ] All four files share one `session_clock_origin`.
- [ ] Populate `intrinsics.distortion_coeffs` when the platform exposes it.
- [ ] Smoke-test by feeding one new bundle to `python -m pipeline.run --input <bundle.tar.gz> --output <out>` — expect a `pose_source: "arkit"` (or whatever) entry in `results_metadata.json`.

When a sample bundle conforming to this spec lands in `data/`, the pipeline can immediately route it through the appropriate path.
