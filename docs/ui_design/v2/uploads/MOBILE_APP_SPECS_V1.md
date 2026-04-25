# Egocentric Video Capture App — Specification

## 1. Project Goal

Build a cross-platform smartphone app (iOS + Android) that records egocentric RGB video from the widest-FOV rear camera and produces a standardized recording package consumable by a downstream HaWoR + depth estimation pipeline. The app must capture camera intrinsics whenever the OS exposes them, and must produce output that is self-describing enough for the pipeline to route correctly without user intervention.

The captured recording package will eventually be uploaded to Cloudflare R2 and processed on a remote GPU instance. For v1, storing recordings locally on the device and exposing them via a share sheet / file export is sufficient.

## 2. Tech Stack

- **Framework:** Flutter (stable channel, Dart 3.x).
- **UI:** Minimal — a single capture screen with record/stop, a recording list, and an export/share button. No design polish required.
- **Native code:**
  - iOS: Swift, AVFoundation for capture, `AVCaptureConnection` for per-frame intrinsics.
  - Android: Kotlin, Camera2 API (not CameraX — CameraX abstracts away intrinsics access).
- **Bridging:** Flutter platform channels for all native camera logic. The Dart side owns UI and file I/O; the native side owns capture, encoding, and intrinsics extraction.
- **Video encoding:** Hardware HEVC encoder on both platforms.
- **Dependencies:** Keep to a minimum. Do not use `camera` plugin — it does not expose intrinsics. Write a custom platform channel.

## 3. Functional Requirements

### 3.1 Camera selection

On both platforms, at session start the app must enumerate rear-facing cameras and select the one with the widest horizontal field of view.

**iOS:**
- Prefer `AVCaptureDevice.DeviceType.builtInUltraWideCamera` if available.
- Fall back to `builtInWideAngleCamera` if ultrawide is not present.
- Do not use `builtInDualCamera` or `builtInTripleCamera` virtual devices — they auto-switch between physical lenses, which changes intrinsics mid-frame.

**Android:**
- Enumerate all cameras via `CameraManager.cameraIdList`.
- Filter for `LENS_FACING_BACK`.
- Compute horizontal FOV per camera: `2 * atan(sensorWidth / (2 * focalLength))` using `SENSOR_INFO_PHYSICAL_SIZE` and the smallest value in `LENS_INFO_AVAILABLE_FOCAL_LENGTHS`.
- Select the camera with the widest computed FOV.
- Skip logical multi-cameras (those where `REQUEST_AVAILABLE_CAPABILITIES` contains `LOGICAL_MULTI_CAMERA`) for the same reason as iOS.

### 3.2 Capture settings

- **Resolution:** 1920×1080 (1080p). Fall back to the highest available resolution at or below this.
- **Framerate:** 30 fps. If the device/lens combination cannot sustain 30 fps at 1080p, fall back to 24 fps and record the actual framerate in metadata.
- **Video stabilization:** MUST be disabled on both platforms. Stabilization invalidates the intrinsic matrix.
  - iOS: `AVCaptureConnection.preferredVideoStabilizationMode = .off`.
  - Android: Disable `CONTROL_VIDEO_STABILIZATION_MODE` and `LENS_OPTICAL_STABILIZATION_MODE`.
- **Autofocus:** Enabled (continuous). Lock AE/AWB is not required for v1.
- **Color space:** BT.709, 8-bit. Do not use HDR capture modes.
- **Codec:** HEVC (H.265). Use the hardware encoder.
- **Bitrate:** 15 Mbps target. This preserves enough detail for downstream depth estimation and SLAM while keeping files around 112 MB per minute. Validate against 12 Mbps during testing so the team has headroom to reduce file size further if needed.
- **Container:** MP4.
- **Audio:** MUST NOT be captured. Do not configure an audio input on the capture session. Do not request microphone permissions. Rationale: egocentric recordings pick up ambient conversations and bystander voices that create privacy concerns, and the pipeline has no use for the audio track. Stripping audio at the source is simpler than stripping it downstream.

### 3.3 Per-frame intrinsics capture

**iOS (reliable):**
- Before starting capture, call `connection.isCameraIntrinsicMatrixDeliverySupported` — it should always be true for video outputs on modern iOS.
- Set `connection.isCameraIntrinsicMatrixDeliveryEnabled = true`.
- In the `AVCaptureVideoDataOutputSampleBufferDelegate` callback, read the intrinsic matrix from each sample buffer via:
  ```swift
  CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, ...)
  ```
- Record the matrix per frame with the sample buffer's presentation timestamp.

**Android (best effort):**
- Query `CameraCharacteristics.LENS_INTRINSIC_CALIBRATION`. If non-null, use it as the static intrinsic matrix for the entire recording (Android does not expose per-frame updates on most devices at API level < 35; for API 35+, use `CaptureResult.LENS_INTRINSICS_SAMPLES` if available).
- If `LENS_INTRINSIC_CALIBRATION` is null, compute approximate intrinsics from:
  - `LENS_FOCAL_LENGTH` (from `CaptureResult`, in mm)
  - `SENSOR_INFO_PHYSICAL_SIZE` (mm)
  - `SENSOR_INFO_ACTIVE_ARRAY_SIZE` (pixels)
  - Formula: `fx = fy = (focal_length_mm / sensor_width_mm) * image_width_px`; `cx = image_width_px / 2`; `cy = image_height_px / 2`.
- Record whether the intrinsics are "calibrated" (from `LENS_INTRINSIC_CALIBRATION`) or "derived" (computed from focal length + sensor size) in metadata.
- Also record `LENS_DISTORTION` coefficients if non-null.

### 3.4 Intrinsics reliability flagging

The app must set a boolean `reliable` flag in the metadata indicating whether the captured intrinsics should be trusted by the pipeline. The flag is `true` if and only if:
- iOS: per-frame intrinsic delivery was successfully enabled AND video stabilization was off for the entire recording.
- Android: `LENS_INTRINSIC_CALIBRATION` returned non-null AND the hardware level is `FULL` or `LEVEL_3` AND video/optical stabilization was off.

For all other cases (including Android LEGACY/LIMITED devices, or iOS sessions where stabilization was somehow enabled), the flag is `false`. The downstream pipeline uses this flag to decide whether to trust the intrinsics or fall back to an intrinsics-free depth model.

### 3.5 Output package

Each recording produces a directory with the structure defined in **Section 5 (Shared Data Contract)**. This is the critical interface with the post-processing pipeline — follow it exactly.

### 3.6 Storage & export

- Save recordings to the app's documents directory (iOS) or external files directory (Android).
- Provide a recording list UI that shows session ID, timestamp, duration, and file size.
- Provide an "export" button per recording that:
  - Tars the recording directory into a single `.tar.gz`.
  - Opens the native share sheet so the user can AirDrop / save to Files / upload to cloud.
- Provide a "delete" button per recording.
- No cloud upload in v1 — this will be added later when R2 integration is built.

## 4. Platform-Specific Implementation Notes

### 4.1 iOS

- Minimum deployment target: iOS 15.0.
- Request camera permission in Info.plist with clear usage description. Do NOT request `NSMicrophoneUsageDescription` — audio is intentionally not captured.
- Use `AVCaptureVideoDataOutput` + `AVAssetWriter` rather than `AVCaptureMovieFileOutput`, because the latter doesn't give per-frame access needed for intrinsics logging.
- Configure the `AVCaptureSession` with only a video input. Do not add any `AVCaptureDeviceInput` for `AVMediaType.audio`.
- Configure `AVAssetWriter` with only a single `AVAssetWriterInput` for video. Do not add an audio input. The resulting MP4 will have a single video track.
- Encode with `AVAssetWriterInput` configured for HEVC:
  ```
  AVVideoCodecKey: .hevc
  AVVideoCompressionPropertiesKey: {
    AVVideoAverageBitRateKey: 15_000_000
  }
  ```
- Write intrinsics to `frames.jsonl` on a background queue to avoid blocking the capture pipeline.

### 4.2 Android

- Minimum SDK: 26 (Android 8.0). Target SDK: latest stable.
- Request `CAMERA` permission at runtime. Do NOT declare or request `RECORD_AUDIO` — audio is intentionally not captured.
- Use Camera2 API directly.
- Use `MediaCodec` + `MediaMuxer` for HEVC encoding. Configure MediaCodec with:
  ```
  MIME type: video/hevc
  Bitrate: 15_000_000
  IFrameInterval: 1
  ColorFormat: COLOR_FormatSurface
  ```
- Configure `MediaMuxer` with a single video track. Do not add an audio track.
- Use a `Surface`-backed capture session feeding the `MediaCodec` input surface — avoids YUV copies.
- Query `LENS_INTRINSIC_CALIBRATION` once at session start, not per-frame (to minimize overhead).
- Handle the case where the device reports `INFO_SUPPORTED_HARDWARE_LEVEL == LEGACY` by falling back to derived intrinsics and marking `reliable = false`.

## 5. Shared Data Contract (IDENTICAL IN BOTH SPECS)

This section defines the output format of the app and the input format of the post-processing pipeline. Both sides must conform exactly.

### 5.1 Directory structure

Each recording is a directory named `recording_<session_id>/` where `<session_id>` is a UUID v4. The directory contains:

```
recording_<session_id>/
├── metadata.json       # Session-level metadata (required)
├── video.mp4           # HEVC-encoded RGB stream (required)
└── frames.jsonl        # Per-frame intrinsics, one JSON object per line (required on iOS, optional on Android)
```

When exported for transfer, the directory is packed as `recording_<session_id>.tar.gz`.

### 5.2 `metadata.json` schema

```json
{
  "schema_version": "1.0",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "captured_at_utc": "2026-04-24T14:32:11.123Z",
  "app_version": "1.0.0",

  "device": {
    "os": "ios",
    "os_version": "17.4.1",
    "manufacturer": "Apple",
    "model": "iPhone 15 Pro",
    "model_identifier": "iPhone16,1"
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
    "notes": "Per-frame intrinsics captured via AVCaptureConnection. Stabilization off."
  },

  "capture_platform": {
    "flutter_version": "3.24.0",
    "native_sdk_version": "iOS 17.4 SDK"
  }
}
```

**Field definitions:**

- `schema_version` (string, required): Must be `"1.0"` for this spec.
- `session_id` (string, required): UUID v4.
- `captured_at_utc` (string, required): ISO 8601 UTC timestamp of recording start.
- `device.os` (string, required): Either `"ios"` or `"android"`. The pipeline uses this for routing.
- `camera.lens_type` (string, required): One of `"ultrawide"`, `"wide"`, `"telephoto"`, `"unknown"`.
- `camera.horizontal_fov_deg` (float, required): Computed horizontal FOV in degrees.
- `video.framerate` (float, required): Actual recorded framerate, not nominal.
- `video.frame_count` (int, required): Exact number of frames in the MP4. Must equal the number of lines in `frames.jsonl` if present.
- `video.has_audio_track` (bool, required): Must be `false`. The app does not capture audio; this field is an explicit assertion that the MP4 contains only a video track.
- `intrinsics.source` (string, required): One of:
  - `"per_frame"` — full per-frame intrinsics in `frames.jsonl`. iOS case.
  - `"static"` — single intrinsic matrix in `static_matrix` field, no `frames.jsonl`. Android calibrated case.
  - `"estimated_fallback"` — derived from focal length + sensor size, no calibration. Android fallback case.
  - `"none"` — no intrinsics available.
- `intrinsics.per_frame_file` (string | null): Filename, present iff `source == "per_frame"`.
- `intrinsics.static_matrix` (3×3 array | null): Row-major intrinsic matrix in pixels, present iff `source ∈ {"static", "estimated_fallback"}`.
- `intrinsics.distortion_model` (string | null): `"brown_conrady"` or `"kannala_brandt"` or `null`.
- `intrinsics.distortion_coeffs` (array | null): `[k1, k2, p1, p2, k3]` for `brown_conrady`, or empty/null if unknown.
- `intrinsics.reliable` (bool, required): Pipeline routing flag. See Section 3.4 for the definition.

### 5.3 `frames.jsonl` schema

One JSON object per line, one line per video frame, in frame order. Frame indices are 0-based and must match the video's frame order exactly.

```jsonl
{"frame_idx": 0, "timestamp_ns": 1714147931123000000, "intrinsic_matrix": [[1520.3, 0.0, 960.1], [0.0, 1520.3, 540.2], [0.0, 0.0, 1.0]], "lens_id": "com.apple.avfoundation.avcapturedevice.built-in_video:5"}
{"frame_idx": 1, "timestamp_ns": 1714147931156333000, "intrinsic_matrix": [[1520.3, 0.0, 960.1], [0.0, 1520.3, 540.2], [0.0, 0.0, 1.0]], "lens_id": "com.apple.avfoundation.avcapturedevice.built-in_video:5"}
```

**Field definitions:**

- `frame_idx` (int, required): 0-based frame index in the video.
- `timestamp_ns` (int, required): Presentation timestamp in nanoseconds since Unix epoch (iOS: derived from `CMSampleBufferGetPresentationTimeStamp` + session start). Monotonic, increasing.
- `intrinsic_matrix` (3×3 array, required): Row-major intrinsic matrix in pixels at the recorded video resolution.
- `lens_id` (string, optional): Identifier of the physical lens. On iOS, this is useful for detecting mid-recording lens switches (should not happen if virtual cameras are avoided, but worth logging).

### 5.4 Invariants

- `frames.jsonl` is present if and only if `intrinsics.source == "per_frame"`.
- If `frames.jsonl` is present, its line count equals `video.frame_count`.
- `intrinsic_matrix` entries are in pixel units scaled to the recorded video resolution (`video.width` × `video.height`), not to the sensor resolution.
- The first frame of `video.mp4` corresponds to `frame_idx: 0` in `frames.jsonl`.
- All timestamps are monotonically increasing.
- `video.mp4` contains exactly one track of type video and zero tracks of type audio. `video.has_audio_track` must be `false`.

## 6. Testing Requirements

- **Unit tests** (Dart): metadata serialization/deserialization, schema validation.
- **Native tests** (Swift + Kotlin): intrinsics parsing, camera selection logic, HEVC encoder configuration.
- **Integration test:** Record a 10-second clip on a physical device, verify the output package against the schema using a validator script, verify `frame_count` matches `frames.jsonl` line count, verify the MP4 is playable in VLC, verify via `ffprobe` that the MP4 contains exactly one video track and zero audio tracks.
- **Bitrate sweep:** Record the same scene at 12 Mbps, 15 Mbps, and 20 Mbps. Share these with the pipeline team so they can validate that depth estimation and SLAM quality are not degraded at the chosen default. If all three look equivalent downstream, consider dropping the default to 12 Mbps in a later release.
- **Device matrix:**
  - iOS: iPhone 12 or later (must test on a device with ultrawide lens).
  - Android: one Pixel device (good Camera2 compliance), one Samsung device (fragmented OEM), one budget device (LEGACY hardware level fallback path).

## 7. Deliverables

1. Flutter project source in a git repository.
2. Build instructions for iOS (Xcode project) and Android (Gradle).
3. A schema validator script (Python, one file, standalone) that takes a recording directory and validates it against the schema in Section 5. This is used by the pipeline team for acceptance testing.
4. A sample recording (10 sec, both iOS and Android) committed to the repo under `samples/` for the pipeline team to develop against.
5. Documentation covering: how to enable developer signing for iOS builds, how to enumerate rear cameras on an unknown Android device, known device-specific quirks encountered during testing.

## 8. Non-Goals for v1

- No cloud upload. Export to share sheet only.
- No live preview of hand detection or depth — the app is capture-only.
- No authentication or user accounts.
- No video playback in-app beyond a thumbnail. Users can play exported MP4s in any video player.
- No compression level or resolution controls in the UI. Settings are fixed per this spec.
