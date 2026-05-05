# RECORDING_DATA_STRUCTURE_V1.2

This is the **simplified** contract between the **mobile capture app
(Flutter, iOS+Android)** and the **post-processing pipeline**. It supersedes
[v1.1](RECORDING_DATA_STRUCTURE_V1.1.md). The `schema_version` bumps to `"1.2"`.
Backwards compatibility: the validator still accepts `"1.0"` and `"1.1"`
captures unchanged; new captures should target `"1.2"`.

The big idea: **one path only**. No ARKit. No ARCore. No per-frame
intrinsics. The mobile app picks the **widest available lens** on the device,
streams its raw video at fixed (static) intrinsics, and streams raw IMU at
≥100 Hz. Pose reconstruction happens entirely offline in the post-processing
pipeline — today via monocular visual SLAM (DROID-SLAM, inside HaWoR); the
IMU stream is captured now so a future offline-VIO stage can consume it
without re-recording the dataset. This eliminates the entire pose-source
decision tree on the mobile side and the corresponding routing /
`poses.jsonl` handling on the pipeline side.

---

## 1. What changed vs. v1.1

| Change | Why |
|---|---|
| **Removed** ARKit / ARCore pose path. `pose.source` ∈ `{"arkit","arcore","none"}` is **rejected** by the v1.2 validator. | Two device-OS APIs, three routing branches, two more file formats — all to defer the same SLAM problem to the cloud anyway. Drop them all. |
| **Removed** `poses.jsonl`. Forbidden in v1.2 bundles. | Direct consequence of the above. |
| **Removed** `frames.jsonl`. Forbidden in v1.2 bundles. | Per-frame intrinsics are an ARKit feature; with a single wide lens at fixed focus, the intrinsic matrix doesn't change. |
| **Removed** `intrinsics.source ∈ {"per_frame","estimated_fallback","none"}`. Only `"static"` is accepted. | Same reason. |
| **Required** `camera.lens_type` ∈ `{"ultrawide","wide"}`. Telephoto / unknown rejected. | The pipeline expects the widest lens for ego-motion coverage; recording with a telephoto defeats the point. |
| **Required** `motion.recorded == true` and `motion.jsonl` present and non-empty. | IMU is the sole pose-quality signal. Not optional anymore. |
| **Removed** `device.has_arkit`, `device.has_arcore` (still tolerated but no longer required or read by the pipeline). | Vestigial. |
| **Removed** `pose.source = "imu_raw"` is the **only** accepted value (or omit the `pose` block entirely). | Single path. |
| **Added** `extrinsics` block with `T_cam_imu` (4×4 IMU-body → camera-optical transform). | Without this, no VIO can fuse IMU and visual measurements correctly. |
| **Added** `camera.rolling_shutter_skew_ns`. | VIO must model rolling-shutter line-time to avoid pose error during fast motion. |
| **Added** IMU noise model fields under `motion` (`noise_density_gyro`, `noise_density_accel`, `random_walk_gyro`, `random_walk_accel`). | Required for sound IMU↔vision weighting in VIO factor graphs. |
| **Added** optional per-row `gravity` and `attitude_quaternion` columns in `motion.jsonl`. | Platform-fused gravity/attitude give the offline VIO an absolute roll/pitch prior, killing drift modes that vision alone cannot remove. |
| **Added** optional `device_clock_id` at the metadata top level. | Disambiguates `CLOCK_BOOTTIME` vs. `CLOCK_MONOTONIC` etc.; prevents a class of cross-stream timing bugs. |

Everything else from v1.1 still applies: HEVC 1920×1080 30 fps no-audio
video, finalized MP4 (`moov` present), one shared monotonic clock for all
files, UUID v4 session id, tar-gzipped on transfer.

---

## 2. Directory layout

```
recording_<sid>/                    # <sid> = UUID v4 (unchanged)
├── metadata.json                   # session-level (REQUIRED)
├── video.mp4                       # HEVC, finalized (REQUIRED)
└── motion.jsonl                    # raw IMU stream (REQUIRED)
```

Three files. No `frames.jsonl`. No `poses.jsonl`. Both are **forbidden** —
their presence will cause the v1.2 validator to reject the bundle.

When transferred, packed as `recording_<sid>.tar.gz`.

The two timestamped files (`video.mp4` per-frame PTS, `motion.jsonl` per
sample) MUST share the same monotonic clock. Either Unix-epoch nanoseconds
or session-start nanoseconds — pick one and document it in
`metadata.session_clock_origin`.

---

## 3. Lens selection — what the mobile app must do

The capture app MUST enumerate every back-facing **physical** camera the
platform exposes, query each for its horizontal field of view, and select
the one with the **largest** horizontal FOV. The `lens_type` label is
**derived** from the chosen camera's FOV, not used to pick it:

```
selected = argmax over physical_back_cameras of horizontal_fov_deg(cam)
lens_type = "ultrawide" if horizontal_fov_deg(selected) >= 100.0 else "wide"
```

This works correctly across all device shapes:
- **Single-camera phones** (e.g. iPhone 16e — wide-only): the only candidate
  wins; `lens_type = "wide"`. No bug, no fallback gymnastics.
- **Phones with ultrawide + wide** (most modern iPhones, Pixels, Galaxies):
  ultrawide has the larger FOV; `lens_type = "ultrawide"`.
- **Phones with multiple "wide" lenses at different FOVs** (some Android OEMs):
  the widest is selected even though both might be labeled `wide` by the
  platform — using the actual FOV value avoids tying the choice to vendor
  taxonomy.

The schema accepts only `lens_type ∈ {"ultrawide", "wide"}`. If the only
available rear lens has FOV below ~60° (telephoto-only — extremely rare),
the writer SHOULD refuse to record a v1.2 bundle rather than emit a
mis-labeled one.

### 3.1 iOS

```swift
import AVFoundation

func pickWidestPhysicalRearLens() -> AVCaptureDevice? {
    // Only PHYSICAL device types — no logical / virtual / fused cameras.
    // Add new physical types here as Apple introduces them.
    let physicalTypes: [AVCaptureDevice.DeviceType] = [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
        // .builtInTelephotoCamera is intentionally omitted — narrow FOV is
        // unsuitable for ego-motion. If you add it, only as a last resort
        // when nothing else exists.
    ]
    let session = AVCaptureDevice.DiscoverySession(
        deviceTypes: physicalTypes,
        mediaType: .video,
        position: .back
    )
    // Pick by actual FOV, not by deviceType ordering.
    return session.devices
        .map { ($0, horizontalFovDeg(of: $0)) }
        .max(by: { $0.1 < $1.1 })?
        .0
}

func horizontalFovDeg(of device: AVCaptureDevice) -> Double {
    // activeFormat.videoFieldOfView is the diagonal FOV in degrees; convert
    // to horizontal using the active format's aspect ratio.
    let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    let aspect = Double(dims.width) / Double(dims.height)
    let diagFov = Double(device.activeFormat.videoFieldOfView)
    let diagRad = diagFov * .pi / 180
    let halfDiag = tan(diagRad / 2)
    let halfHoriz = halfDiag * aspect / sqrt(aspect * aspect + 1)
    return 2 * atan(halfHoriz) * 180 / .pi
}

let device = pickWidestPhysicalRearLens()!
let hFov = horizontalFovDeg(of: device)
let lensType = (hFov >= 100.0) ? "ultrawide" : "wide"
```

### 3.2 Android (Camera2)

```kotlin
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

data class Candidate(val id: String, val hFovDeg: Double)

fun pickWidestPhysicalRearLens(cm: CameraManager): Candidate {
    val candidates = cm.cameraIdList.mapNotNull { id ->
        val c = cm.getCameraCharacteristics(id)
        if (c.get(CameraCharacteristics.LENS_FACING) != CameraCharacteristics.LENS_FACING_BACK)
            return@mapNotNull null
        // Skip logical multi-cameras — they auto-switch sub-lenses mid-session
        // and break the static-intrinsics contract.
        val caps = c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)?.toList().orEmpty()
        if (CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA in caps)
            return@mapNotNull null
        val fov = horizontalFovDeg(c) ?: return@mapNotNull null
        Candidate(id, fov)
    }
    return candidates.maxByOrNull { it.hFovDeg }
        ?: error("No suitable physical rear camera found")
}

fun horizontalFovDeg(c: CameraCharacteristics): Double? {
    val focals = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS) ?: return null
    val focalMm = focals.min()                                    // shortest focal = widest FOV
    val sensor = c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return null
    return Math.toDegrees(2 * Math.atan((sensor.width / (2 * focalMm)).toDouble()))
}

val pick = pickWidestPhysicalRearLens(cm)
val lensType = if (pick.hFovDeg >= 100.0) "ultrawide" else "wide"
```

### 3.3 Lock the selected lens for the entire session

Multi-camera devices may attempt to swap lenses mid-recording; the
static-intrinsics contract relies on this **not** happening. On both
platforms that means avoiding logical / virtual / fused camera identifiers:

- **iOS**: do NOT pass `builtInDualWideCamera`, `builtInTripleCamera`,
  `builtInDualCamera`, or use `AVCaptureMultiCamSession`. The
  `physicalTypes` allow-list in §3.1 already filters these out.
- **Android**: skip any camera id whose `REQUEST_AVAILABLE_CAPABILITIES`
  includes `LOGICAL_MULTI_CAMERA` (the §3.2 code does this). Lock zoom:
  `request.set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)`. Lock focus to a
  fixed value (or to the value in effect at session start) so the
  intrinsic matrix doesn't drift.

The pipeline assumes one set of intrinsics for the entire recording. A
mid-session lens switch silently breaks this and is hard to detect after
the fact.

### 3.4 Computing `horizontal_fov_deg` for the metadata

Use the same formula on both platforms so `metadata.camera.horizontal_fov_deg`
matches what the schema validator implies from the intrinsic matrix `K`:

```
horizontal_fov_deg = 2 * atan( sensor_width_mm / (2 * focal_length_mm) ) * 180 / π
```

`metadata.camera.physical_focal_length_mm = focal_length_mm`,
`metadata.camera.sensor_physical_size_mm = [sensor_width_mm, sensor_height_mm]`,
`metadata.camera.horizontal_fov_deg` is the value above. The pipeline's
sanity check (`python -m pipeline.sanity`) cross-checks the implied FOV
from `K` and `video.width` against `horizontal_fov_deg` to within 10 %
(see §7).

---

## 4. `metadata.json` — full v1.2 schema

```json
{
  "schema_version": "1.2",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "captured_at_utc": "2026-05-05T14:32:11.123Z",
  "session_clock_origin": "unix_epoch",
  "app_version": "2.2.0",

  "device": {
    "os": "android",
    "os_version": "15",
    "manufacturer": "Xiaomi",
    "model": "24115RA8EC",
    "model_identifier": "Xiaomi_24115RA8EC"
  },

  "camera": {
    "lens_id": "0",
    "lens_type": "ultrawide",
    "physical_focal_length_mm": 1.55,
    "sensor_physical_size_mm": [7.6, 5.7],
    "sensor_pixel_array_size": [4096, 3072],
    "horizontal_fov_deg": 120.0,
    "video_stabilization_enabled": false,
    "optical_stabilization_enabled": false,
    "rolling_shutter_skew_ns": 16000000
  },

  "video": {
    "codec": "hevc",
    "container": "mp4",
    "width": 1920,
    "height": 1080,
    "framerate": 30.0,
    "duration_sec": 587.0,
    "frame_count": 17633,
    "bitrate_bps": 15000000,
    "color_space": "bt709",
    "pixel_format": "yuv420p",
    "has_audio_track": false
  },

  "intrinsics": {
    "source": "static",
    "static_matrix": [[1357.89, 0.0, 960.0],
                      [0.0,    1357.89, 540.0],
                      [0.0,    0.0,    1.0]],
    "distortion_model": "brown_conrady",
    "distortion_coeffs": [-0.18, 0.04, 0.0, 0.0, 0.0],
    "reliable": true,
    "notes": "Static intrinsics from CameraCharacteristics + Brown-Conrady from LENS_DISTORTION."
  },

  "motion": {
    "recorded": true,
    "rate_hz": 200,
    "gyro_units": "rad/s",
    "accel_units": "m/s^2",
    "accel_includes_gravity": true,
    "frame": "device_body",
    "noise_density_gyro": 1.7e-4,
    "noise_density_accel": 2.0e-3,
    "random_walk_gyro": 2.0e-5,
    "random_walk_accel": 3.0e-3,
    "notes": "Sensor.TYPE_GYROSCOPE + TYPE_ACCELEROMETER at SENSOR_DELAY_FASTEST. Noise from BMI260 datasheet."
  },

  "extrinsics": {
    "T_cam_imu": [
      [ 1.0,  0.0,  0.0,  0.012],
      [ 0.0,  1.0,  0.0, -0.003],
      [ 0.0,  0.0,  1.0,  0.041],
      [ 0.0,  0.0,  0.0,  1.0  ]
    ],
    "source": "platform_api",
    "time_offset_sec": 0.005,
    "rotation_stddev_deg": 0.5,
    "translation_stddev_m": 0.002,
    "notes": "Android: CameraCharacteristics.LENS_POSE_TRANSLATION + LENS_POSE_ROTATION."
  },

  "device_clock_id": "CLOCK_BOOTTIME",

  "capture_platform": {
    "flutter_version": "3.41.7",
    "native_sdk_version": "android",
    "capture_pipeline_version": "2.2.0"
  }
}
```

### 4.1 Field requirements (v1.2-specific)

| Field | Requirement |
|---|---|
| `schema_version` | MUST be `"1.2"`. |
| `camera.lens_type` | MUST be `"ultrawide"` (preferred) or `"wide"` (fallback). `telephoto` and `unknown` are rejected. |
| `intrinsics.source` | MUST be `"static"`. The other v1.0/v1.1 values are rejected. |
| `intrinsics.static_matrix` | REQUIRED 3×3 row-major `[[fx,0,cx],[0,fy,cy],[0,0,1]]`. The implied horizontal FOV from `K` and `video.width` MUST agree with `camera.horizontal_fov_deg` to within 10 %. |
| `intrinsics.distortion_model` | REQUIRED for ultrawide, RECOMMENDED for wide. `"brown_conrady"` (preferred) or `"kannala_brandt"`. |
| `intrinsics.distortion_coeffs` | REQUIRED when `distortion_model` is set. Brown-Conrady: `[k1, k2, p1, p2, k3]`. Kannala-Brandt: `[k1, k2, k3, k4]`. |
| `motion.recorded` | MUST be `true`. (Not optional anymore.) |
| `motion.rate_hz` | MUST be ≥ 100. Target 200. |
| `pose` block | OPTIONAL. If present, `pose.source` MUST be `"imu_raw"`. (Better: omit the block entirely.) |
| `device.has_arkit`, `device.has_arcore` | OPTIONAL. The pipeline ignores them. |
| `extrinsics.T_cam_imu` | RECOMMENDED for any capture intended for downstream VIO. 4×4 row-major homogeneous matrix mapping IMU body frame → camera optical frame. Bottom row MUST be `[0, 0, 0, 1]`. See §4.5. |
| `extrinsics.source` | REQUIRED when the `extrinsics` block is present. One of `{"platform_api", "model_calibration_table", "factory", "online_estimated"}`. |
| `extrinsics.time_offset_sec` | OPTIONAL. Camera-IMU temporal offset (`camera_pts_ns − imu_ts_ns`). May be left null; the offline VIO can estimate it online. |
| `camera.rolling_shutter_skew_ns` | RECOMMENDED. Top-to-bottom rolling-shutter readout time, in nanoseconds. Android: `SENSOR_INFO_ROLLING_SHUTTER_SKEW`. iOS: hardcode per `device.model_identifier`. See §4.6. |
| `motion.noise_density_gyro` / `noise_density_accel` | RECOMMENDED. Continuous-time noise densities (rad/s/√Hz, m/s²/√Hz). From the IMU datasheet (or factory calibration). |
| `motion.random_walk_gyro` / `random_walk_accel` | RECOMMENDED. Bias random-walk densities (rad/s²/√Hz, m/s³/√Hz). |
| `device_clock_id` | OPTIONAL but RECOMMENDED. e.g. `"CLOCK_BOOTTIME"`, `"CLOCK_MONOTONIC"`, `"mach_absolute_time"`. Disambiguates which monotonic clock the `timestamp_ns` fields are sourced from. |

### 4.2 Removed fields

These fields from v1.1 are no longer used by the pipeline and SHOULD be omitted:

- `pose.frame_origin`, `pose.coordinate_convention`, `pose.transform_kind`,
  `pose.tracking_state_field`, `pose.rate_hz` — all ARKit/ARCore-specific.

They are tolerated (the validator still has `extra="allow"`) but contribute nothing.

### 4.3 VIO-prep fields — why they exist

The fields below (`extrinsics`, `camera.rolling_shutter_skew_ns`,
`motion.noise_density_*`, optional per-row `gravity` in `motion.jsonl`) are
not consumed by the post-processing pipeline today (the current SLAM is
monocular — DROID-SLAM inside HaWoR — and uses none of them). They are
included in v1.2 because:

1. They are **impossible to recover** from a stored bundle. Re-recording a
   30-minute session because we forgot to log a 4×4 calibration matrix is
   pointless waste.
2. They are essentially **free to capture** at session start (one platform
   API call) or hardcode (datasheet values).
3. They are **prerequisites for accurate offline VIO**, which is the
   stated next step. Capturing them now means the existing dataset doesn't
   need to be re-collected when the VIO stage lands.

If the platform doesn't expose a value (e.g. iOS doesn't publish
`T_cam_imu` cleanly), leave the field null and document the source —
calibration tables can be applied post-hoc as long as `device.model_identifier`
is recorded precisely.

### 4.4 Camera-IMU extrinsics (`extrinsics` block)

```json
"extrinsics": {
  "T_cam_imu": [[r00, r01, r02, tx],
                [r10, r11, r12, ty],
                [r20, r21, r22, tz],
                [0.0, 0.0, 0.0, 1.0]],
  "source": "platform_api",
  "time_offset_sec": 0.005,
  "rotation_stddev_deg": 0.5,
  "translation_stddev_m": 0.002,
  "notes": "..."
}
```

**`T_cam_imu`** is the rigid transform that maps a point expressed in the
**IMU body frame** into the **camera optical frame** (z forward, x right,
y down — OpenCV convention; the pipeline converts internally if your
platform uses a different camera frame). It is the single most important
piece of data for VIO — without it, IMU integration cannot be aligned with
visual measurements.

**Where to get it:**

- **Android (Camera2)**: free and platform-supported.
  ```kotlin
  val c = cm.getCameraCharacteristics(cameraId)
  val tVec = c.get(CameraCharacteristics.LENS_POSE_TRANSLATION)!!  // 3 floats, meters
  val rVec = c.get(CameraCharacteristics.LENS_POSE_ROTATION)!!     // 4 floats (qx,qy,qz,qw)
                                                                    // OR 3 floats (Rodrigues)
                                                                    // depending on LENS_POSE_REFERENCE
  // Compose into a 4x4 matrix, store under extrinsics.T_cam_imu, set source = "platform_api".
  ```
  The reference frame depends on `LENS_POSE_REFERENCE` (typically
  `LENS_POSE_REFERENCE_PRIMARY_CAMERA` or `LENS_POSE_REFERENCE_GYROSCOPE`).
  Document which reference was used in `extrinsics.notes`.

- **iOS**: Apple does **not** expose this directly. Two practical options:
  - **Per-model calibration table**: maintain a static lookup keyed on
    `device.model_identifier` (e.g. `"iPhone16,1"`). Apple's mechanical
    tolerances are tight enough that one calibration per model is good to
    ~1° rotation / few mm translation. Set `extrinsics.source =
    "model_calibration_table"`. Recording `model_identifier` precisely is
    therefore essential.
  - **Online estimation**: leave `extrinsics` null and let the offline
    VIO solver estimate the extrinsics jointly with the trajectory.
    Slower-converging and noisier, but works without per-model data.

**`time_offset_sec`** captures any fixed offset between camera and IMU
clocks (`camera_pts_ns − imu_ts_ns`). On Android both are typically
`CLOCK_BOOTTIME` and the offset is ~0; iOS occasionally has small
end-to-end pipeline lag. Leave null if unknown — the offline VIO will
estimate it.

### 4.5 Rolling-shutter readout time

```json
"camera": { ..., "rolling_shutter_skew_ns": 16000000 }
```

Phone cameras are rolling-shutter: each row of a frame is captured at a
slightly different time. During fast motion (which is exactly what
egocentric hand recordings contain), this introduces apparent geometric
distortion that VIO must model. The skew value is the time between the
first and last row of a frame.

- **Android**: `CameraCharacteristics.SENSOR_INFO_ROLLING_SHUTTER_SKEW`
  returns nanoseconds directly.
- **iOS**: not exposed via `AVFoundation`. Hardcode per `model_identifier`
  (representative values: ~10–25 ms for modern iPhones).

If the value is unknown, leave the field null. The VIO will fall back to a
per-frame instantaneous-capture model.

### 4.6 IMU noise model

```json
"motion": {
  ...,
  "noise_density_gyro": 1.7e-4,    // rad/s/√Hz
  "noise_density_accel": 2.0e-3,   // m/s²/√Hz
  "random_walk_gyro": 2.0e-5,      // rad/s²/√Hz
  "random_walk_accel": 3.0e-3      // m/s³/√Hz
}
```

VIO factor graphs weight IMU vs. visual measurements by their respective
noise. These four scalars control that weighting.

The values come from the **IMU chip datasheet** (or, for higher accuracy,
an Allan-variance calibration of the specific device). Each phone model
ships a known IMU (Bosch BMI260, InvenSense ICM-42688, Apple-fab parts,
etc.); the mobile team typically maintains a per-model lookup. Treat them
as constants — they don't change over a session.

If the values are unknown, leave them null; the offline VIO will fall
back to conservative defaults (which is fine but typically less accurate).

---

## 5. `motion.jsonl` — extended in v1.2 (was v1.1 §7)

One JSON object per IMU sample. Sample rate higher than the video framerate
(typical: 100 Hz minimum, 200 Hz preferred). Lines NOT aligned with frame
indices (different rate); aligned only via `timestamp_ns`.

```jsonl
{"timestamp_ns":1714147931120000000,"gyro":[0.012,-0.034,0.005],"accel":[-0.211,9.812,-0.044],"gravity":[0.0,9.806,0.0],"attitude_quaternion":[0.000,0.000,0.000,1.000]}
{"timestamp_ns":1714147931130000000,"gyro":[0.014,-0.031,0.006],"accel":[-0.215,9.808,-0.041],"gravity":[0.0,9.806,0.0],"attitude_quaternion":[0.001,0.000,0.000,1.000]}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `timestamp_ns` | int | yes | Same monotonic clock as `video.mp4` PTS. |
| `gyro` | `[gx, gy, gz]` rad/s | yes | Body frame. |
| `accel` | `[ax, ay, az]` m/s² | yes | Body frame. Document `accel_includes_gravity` in metadata. |
| `gravity` | `[gx, gy, gz]` m/s² | **RECOMMENDED for v1.2** | Platform-fused gravity-direction estimate. iOS: `CMDeviceMotion.gravity * 9.81`. Android: `Sensor.TYPE_GRAVITY`. Provides an absolute roll/pitch prior to the offline VIO. ~24 B/row overhead. |
| `attitude_quaternion` | `[qx, qy, qz, qw]` | optional | Platform-fused absolute orientation (world-from-body). iOS: `CMDeviceMotion.attitude.quaternion`. Android: `Sensor.TYPE_ROTATION_VECTOR`. Useful as an initialization prior; not load-bearing. |
| `mag` | `[mx, my, mz]` µT | **RECOMMENDED when available** (was optional in v1.1) | Magnetometer. Constrains yaw drift over long sessions. |
| `temperature_c` | float | optional | IMU die temperature. Helps bias correction over long sessions. |

**Constraints (sanity-script-enforced):**
- Rows MUST be in non-decreasing `timestamp_ns` order. (Sort gyro/accel
  events through a single producer queue before writing — see
  [`docs/bug_fix/2026-05-05_android_writer_fixes.md`](../bug_fix/2026-05-05_android_writer_fixes.md) §P1-2.)
- One row per sample event (no double-emit per gyro+accel pair — see
  bug-fix §P1-3).
- IMU window MUST cover `[video_first_pts, video_last_pts]`, with at most
  ~100 ms of slack at each end (see bug-fix §P1-5).

---

## 6. Coordinate conventions

`gyro` and `accel` are in the device-body frame (the platform's native IMU
frame). The pipeline converts to OpenCV camera convention internally. Don't
try to convert on the device.

There is no `transform` to write anymore (no `poses.jsonl`).

---

## 7. Validation rules summary

The pipeline's `pipeline.schema.validate_recording()` enforces, for v1.2 captures:

1. `schema_version == "1.2"`.
2. `camera.lens_type ∈ {"ultrawide","wide"}`.
3. `intrinsics.source == "static"`, `static_matrix` is a valid 3×3.
4. `frames.jsonl` MUST NOT exist on disk.
5. `poses.jsonl` MUST NOT exist on disk.
6. `motion.recorded == true` and `motion.jsonl` exists and is non-empty.
7. If `pose` block is present, `pose.source == "imu_raw"`.
8. `video.mp4` opens cleanly (PyAV / `ffprobe` without `moov atom not found`).
9. If `extrinsics` block is present, `T_cam_imu` is 4×4 with bottom row `[0, 0, 0, 1]` and `extrinsics.source` is one of the four allowed values.

The implied-FOV / `K` consistency check (FOV from `K` vs `camera.horizontal_fov_deg` within 10 %) is performed by `python -m pipeline.sanity` rather than by the strict schema validator; same as v1.1.

---

## 8. Bundle examples

### 8.1 v1.2 ultrawide capture (typical iPhone with ultrawide lens)

```
recording_<sid>/                    # ~ 60 KB / sec ≈ 0.4% overhead vs. video
├── metadata.json                   # ~1.3 KB
├── video.mp4                       # ~1 MB / sec @ 15 Mbps
└── motion.jsonl                    # ~16 KB / sec @ 200 Hz × ~80 B / row
```

### 8.2 v1.2 wide-lens fallback (Android device with no ultrawide)

```
recording_<sid>/
├── metadata.json                   # camera.lens_type = "wide"
├── video.mp4
└── motion.jsonl
```

Same shape, just a narrower FOV. Pipeline behaviour is identical.

---

## 9. Migration checklist for the Flutter / mobile team

The work to ship v1.2 is mostly **deletion**:

- [ ] Bump `schema_version` to `"1.2"`.
- [ ] **Delete** `poses.jsonl` writer code (ARKit / ARCore session, delegate, file handle, transform serialization).
- [ ] **Delete** `frames.jsonl` writer code (per-frame intrinsics serialization).
- [ ] **Delete** `pose_source` decision-cascade logic.
- [ ] On both platforms, select the widest available rear lens at session start (see §3) and *lock it* (no virtual / multi-camera devices).
- [ ] Set `metadata.camera.lens_type` to `"ultrawide"` or `"wide"`.
- [ ] Populate `metadata.intrinsics.static_matrix` from the platform calibration API:
  - **iOS**: `AVCaptureDevice.activeFormat.formatDescription` → `intrinsicMatrix` (lock focus first; intrinsics are only published for locked cameras with `cameraCalibrationDataDeliverySupported`).
  - **Android**: `CameraCharacteristics.LENS_INTRINSIC_CALIBRATION` rescaled to the **video** resolution (single uniform scalar — see [`docs/bug_fix/2026-05-05_android_writer_fixes.md`](../bug_fix/2026-05-05_android_writer_fixes.md) §P1-1).
- [ ] Populate `metadata.intrinsics.distortion_model` and `distortion_coeffs`. Brown-Conrady is preferred; coefficients all-zero is acceptable only if the lens is genuinely undistorted (rare for ultrawide).
- [ ] Always write `motion.jsonl` at ≥100 Hz, sorted by timestamp, one row per sensor event, bracketed to the video window (see bug-fix doc).
- [ ] **VIO-prep fields (§4.3 — RECOMMENDED for any capture intended for downstream VIO):**
  - [ ] Populate the `extrinsics` block with `T_cam_imu` from
    `CameraCharacteristics.LENS_POSE_*` on Android, or from a per-`model_identifier`
    calibration table on iOS. Set `extrinsics.source` accordingly.
  - [ ] Populate `camera.rolling_shutter_skew_ns` from
    `SENSOR_INFO_ROLLING_SHUTTER_SKEW` on Android, or hardcode per
    `model_identifier` on iOS.
  - [ ] Populate `motion.noise_density_*` and `random_walk_*` from the IMU
    chip datasheet (or a per-model lookup).
  - [ ] Add a `gravity` field to each row of `motion.jsonl` from the
    platform-fused gravity estimate (`CMDeviceMotion.gravity * 9.81` on iOS;
    `Sensor.TYPE_GRAVITY` on Android).
  - [ ] Set `device_clock_id` (e.g. `"CLOCK_BOOTTIME"`).
- [ ] Verify locally: `python -m pipeline.sanity <bundle.tar.gz>` should print `RESULT: PASS` (warnings allowed; no FAILs).

A v1.2 bundle should cost the team a **net reduction** in code and complexity vs. v1.1.

---

## 10. Pipeline-side simplifications enabled by v1.2

Listed for context. The pipeline still consumes v1.0 and v1.1 captures, but
the v1.2-only path is materially simpler:

- No `poses.jsonl` parsing, validation, or alignment-with-frames check.
- No `frames.jsonl` per-frame timestamp track; per-frame timestamps are
  derived as `i / framerate` from the video container.
- No `pose.source` routing branch.
- Depth-model routing (`pipeline.depth_router`) is unchanged; it routes on
  `intrinsics.reliable`, not on pose source.

### 10.1 Honest status of pose reconstruction

As of this revision the post-processing pipeline reconstructs camera poses
via **monocular visual SLAM** (DROID-SLAM, vendored inside HaWoR). It does
**not** consume `motion.jsonl` or any IMU signal — `pipeline.run` calls
`hawor.run(frames, K, depth, fps, timestamps_s)` with no IMU input. The
`motion.jsonl` file is captured under v1.2 because:

1. It costs ~0.4 % of the video bitrate to record (negligible).
2. It is required to be present for the offline-VIO stage that is on the
   roadmap; collecting it now means the existing dataset doesn't need to
   be re-recorded when that stage lands.
3. It is useful for sanity / cross-checking (the sanity script already
   validates IMU rate, monotonicity, gravity magnitude, and IMU-vs-video
   timing alignment — see `pipeline.sanity`).

Practical consequence: switching from v1.1 to v1.2 does **not** change the
quality of pose reconstruction today (the pipeline never used the v1.1
ARKit / ARCore poses either — they were validated and discarded). It just
removes data the pipeline was ignoring. If a future revision adds an
offline-VIO stage that consumes the IMU, AR-capable devices recording
under v1.2 will have lower-quality poses than they could have had under
v1.1 (since Apple/Google's real-time visual-inertial fusion is a
meaningful engineering moat). Whether that loss is acceptable depends on
whether single-pipeline consistency is more valuable than per-device
best-quality poses for the project's use case.

A future minor revision can remove the v1.0/v1.1 code paths once all
captures have migrated.
