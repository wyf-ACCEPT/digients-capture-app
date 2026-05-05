# Android Capture App — Writer-Side Fixes for v1.1 Recordings

This document lists writer-side issues found by `python -m pipeline.sanity` on
the three v1.1 Android stress-test recordings shipped on 2026-05-05:

| File | Device | OS | Duration |
|---|---|---|---|
| `kitchen-cut-fruit-single-31bc1d45-…tar.gz` | Xiaomi 24115RA8EC | Android 15 | 22:02 |
| `living-room-pick-powerbank-522e8e70-…tar.gz` | Xiaomi 24115RA8EC | Android 15 | 12:48 |
| `living-room-pick-remote-97631769-…tar.gz` | Xiaomi 24115RA8EC | Android 15 | 09:47 |

All findings here are **Android-only**. iOS-specific issues
(`simd_float3x3` padding bug, MP4 `moov` finalization) are tracked separately
in [`docs/specs/RECORDING_DATA_STRUCTURE_V1.1.md`](../specs/RECORDING_DATA_STRUCTURE_V1.1.md) §6.1 / §1.

Severity legend:
- **P0** — pipeline rejects the recording outright; must fix.
- **P1** — degrades downstream accuracy (intrinsics / VIO) but pipeline still produces output.
- **P2** — cosmetic / metadata mismatch; pipeline tolerates.

---

## P0-1. `intrinsics.distortion_model: "opencv5"` is not in the schema enum

**Symptom.** All three recordings fail strict schema validation with:

```
intrinsics.distortion_model: Input should be 'brown_conrady' or 'kannala_brandt' (got 'opencv5')
```

The pipeline (`pipeline.run`) exits with code 1 on ingest. The sanity script
falls back to lenient mode and proceeds, but the production pipeline does not.

**Root cause.** The Android writer emits the OpenCV 5-coefficient distortion
model as a custom string `"opencv5"`. The
[v1.1 spec §3](../specs/RECORDING_DATA_STRUCTURE_V1.1.md#3-metadatajson--full-schema)
only enumerates `{"brown_conrady", "kannala_brandt"}`. The OpenCV 5-coefficient
model `[k1, k2, p1, p2, k3]` **is exactly Brown-Conrady** with three radial and
two tangential terms — they should be reported as `brown_conrady`.

**Fix.** Change the writer to emit:

```json
"intrinsics": {
  "distortion_model": "brown_conrady",
  "distortion_coeffs": [k1, k2, p1, p2, k3]
}
```

Note: in all three samples the coefficients are `[0, 0, 0, 0, 0]`, so once the
schema accepts the renamed field no other behaviour changes.

---

## P1-1. Asymmetric `fx ≠ fy` in `intrinsics.static_matrix` (Android sensor-vs-video rescale bug, variant)

**Symptom.** All three recordings ship `static_matrix` with:

```
fx = 1357.89   fy = 1018.42        # 25% asymmetric
cx = 960.0     cy = 540.0          # video center, correct
```

The implied horizontal FOV from `fx` (70.5°) matches the metadata
`camera.horizontal_fov_deg` of 70.5° — so `fx` is correct. But the vertical
FOV implied by `fy` is ~55.8° versus the expected ~43.3° for a 16:9 frame at
that horizontal FOV — `fy` is wrong.

**Root cause.** Pixels on this sensor are physically square
(`8.26 / 4096 ≈ 6.19 / 3072 ≈ 2.02 µm`), so `fx` and `fy` *in pixels at any
given resolution* must be equal. The writer is computing them with different
per-axis rescale factors:

```kotlin
// suspected current logic — produces the bug
fx = focal_mm * (sensor_pixel_array_size[0] / sensor_physical_size_mm[0]) *
     (video.width  / sensor_pixel_array_size[0])
fy = focal_mm * (sensor_pixel_array_size[1] / sensor_physical_size_mm[1]) *
     (video.height / sensor_pixel_array_size[1])
```

When the sensor is 4:3 (4096×3072) and the video is 16:9 (1920×1080), the
crop+downsample factor differs per axis (`0.469` for x, `0.352` for y), so
`fx` and `fy` end up unequal. This is conceptually the same family of bug as
the OnePlus 5 issue described in
[v1.1 spec §6.3](../specs/RECORDING_DATA_STRUCTURE_V1.1.md#63-the-android-sensor-vs-video-resolution-bug-observed-in-v11-oneplus-5-sample);
this Xiaomi variant differs only in that the rescale factor is *applied
asymmetrically* instead of being skipped entirely.

**Fix.** Apply a single uniform scalar (Camera2 always crops the sensor to the
video aspect, so x and y crop factors are equal *after* the aspect-matched
crop):

```kotlin
// Option A — derive directly from FOV (preferred; one source of truth)
fx = video.width / (2 * tan(Math.toRadians(camera.horizontal_fov_deg / 2)))
fy = fx                                        // square pixels

// Option B — rescale by a single scalar
val cropScale = video.width.toFloat() / sensor_pixel_array_size[0]
fx = focal_mm * (sensor_pixel_array_size[0] / sensor_physical_size_mm[0]) * cropScale
fy = fx                                        // square pixels
```

The pipeline already auto-rescales asymmetric `K` and emits a warning, but
fixing the writer eliminates that recovery path and gives downstream depth /
SLAM the correct aspect-ratio-corrected intrinsics.

---

## P1-2. Severe `motion.jsonl` timestamp non-monotonicity

**Symptom.**

| Recording | Backwards-going rows | Fraction |
|---|---|---|
| `kitchen-cut-fruit-single` | 166,389 / 526,385 | **31.6 %** |
| `living-room-pick-powerbank` | 144 / 315,343 | 0.046 % |
| `living-room-pick-remote` | 59 / 234,017 | 0.025 % |

The 0.025 % – 0.046 % rate is plausible Android sensor-thread interleaving
(gyro and accel callbacks land on different threads and a downstream consumer
can sort them). The 31.6 % rate is **not** interleaving — it indicates a
write-side race or a buffer being flushed in non-monotonic order.

**Spec impact.** [v1.1 spec §10](../specs/RECORDING_DATA_STRUCTURE_V1.1.md#10-validation-rules-additions-to-v10-54)
implies IMU rows be in time order; offline VIO assumes it. The pipeline can
sort before integration, but losing 1/3 of temporal ordering is a strong
signal that the IMU writer is broken under load.

**Fix.** Serialize all sensor events through a single-producer queue keyed by
`SensorEvent.timestamp` before writing:

```kotlin
// Pseudocode — single ordered queue feeds the file writer
private val imuQueue = PriorityBlockingQueue<ImuRow>(/* compareBy timestamp */)

override fun onSensorChanged(e: SensorEvent) {
    imuQueue.put(toImuRow(e))   // both gyro and accel callbacks call here
}

// Drain thread: pulls in timestamp order, batched flush every ~10 ms
```

Equivalently, batch sensor events for ~50 ms windows, sort, then write.

Until this is fixed in the writer, **flag the kitchen recording's
IMU-derived poses as low-confidence** for downstream evaluation.

---

## P1-3. Mass duplicate timestamps in `motion.jsonl`

**Symptom.** ~50 % of `motion.jsonl` rows in every recording share their
`timestamp_ns` with the previous row but carry slightly different
gyro / accel values (one of the two sensors has updated since the last row).

Example from `living-room-pick-remote`:

```jsonl
{"timestamp_ns":1777973005890130782,"gyro":[0.314,0.363,0.106],"accel":[-9.63,-1.26,4.75]}
{"timestamp_ns":1777973005890130782,"gyro":[0.314,0.363,0.106],"accel":[-8.69,-0.79,3.59]}
```

**Root cause.** The writer fires a row on **every** gyro update **and** every
accel update, copying the most recent value of the other sensor each time.
Each pair of consecutive rows therefore shares the timestamp of whichever
sensor fired second.

**Fix.** Pick one of:

1. **One row per sensor event** (preferred — preserves true sample times):
    each row carries either gyro or accel, the other set to `null`. Update
    the schema; or
2. **One row per primary-stream sample**: emit a row only when the *gyro*
    fires, with the most recent accel value attached. Drop the row that the
    accel callback would have produced.

Option 2 keeps the existing schema and is a one-line change. Either way,
[v1.1 spec §7](../specs/RECORDING_DATA_STRUCTURE_V1.1.md#7-motionjsonl-new) needs
a one-sentence clarification of which is required.

---

## P1-4. `motion.rate_hz` reports event rate, not sample rate

**Symptom.** `living-room-pick-remote` advertises `rate_hz: 199.07` and the
empirical rate matches. But `kitchen-cut-fruit-single` advertises
`rate_hz: 387.10` while the empirical median rate (over unique timestamps) is
**199 Hz** — a 49 % discrepancy.

**Root cause.** When P1-3 (duplicate timestamps) is in effect, the writer is
likely computing `rate_hz` as `total_row_count / span_seconds`, which double-
counts because each true sample produces two rows. `rate_hz` should describe
the underlying *sensor* sample rate.

**Fix.** Report the rate of the primary stream:

```kotlin
val gyroRate = gyroSampleCount.toDouble() / spanSeconds
metadata.motion.rate_hz = gyroRate
```

Fixing P1-3 makes this trivial; the row count *is* the sample count.

---

## P1-5. IMU stream not bracketed to video window

**Symptom.**

| Recording | Video duration | IMU span | Δ |
|---|---|---|---|
| `living-room-pick-remote` | 587.00 s | 587.95 s | +0.95 s |
| `living-room-pick-powerbank` | 768.00 s | 793.03 s | **+25.03 s** |
| `kitchen-cut-fruit-single` | 1322.00 s | 1322.50 s | +0.50 s |

The powerbank recording's IMU stream extends 25 seconds beyond the video.
[v1.1 spec §2](../specs/RECORDING_DATA_STRUCTURE_V1.1.md#2-directory-layout)
says all four files share a single monotonic clock; they should also share
a window — IMU outside the video range is unusable and adds size for nothing.

**Root cause.** The sensor listener is started before `MediaRecorder.start()`
and/or stopped after `MediaRecorder.stop()`. The capture session boundary is
not aligned with the IMU window.

**Fix.** Either:

```kotlin
// Option A — register sensors only between video frame 0 and last frame
mediaRecorder.start()
val videoStartNs = SystemClock.elapsedRealtimeNanos()  // or first frame's PTS
sensorManager.registerListener(...)
// stop:
sensorManager.unregisterListener(...)
val videoEndNs = SystemClock.elapsedRealtimeNanos()
mediaRecorder.stop()
```

or

```kotlin
// Option B — keep the wider listener window but trim motion.jsonl on close
trimMotionFile(motionFile, fromNs = videoStartNs, toNs = videoEndNs + 100_000_000L)
```

Allow up to ~100 ms of slack on each side so VIO has interpolation context at
the boundaries.

---

## P2-1. Container frame count differs from `metadata.video.frame_count` by 1–6

**Symptom.**

| Recording | metadata.frame_count | container frames | Δ |
|---|---|---|---|
| `living-room-pick-remote` | 17,633 | 17,639 | +6 |
| `living-room-pick-powerbank` | 23,068 | 23,069 | +1 |
| `kitchen-cut-fruit-single` | 39,671 | 39,677 | +6 |

The pipeline tolerates this (`pipeline.video.decode_video` uses
`min(decoded, expected)`), so it is not blocking. But it indicates the
metadata is computed before final mux.

**Fix.** Read the frame count from the finalized container *after*
`MediaMuxer.stop()`:

```kotlin
mediaMuxer.stop()
mediaMuxer.release()
val extractor = MediaExtractor().apply { setDataSource(outputFile.path) }
val format = extractor.getTrackFormat(0)
metadata.video.frame_count = format.getInteger(MediaFormat.KEY_FRAME_COUNT)
metadata.video.duration_sec = format.getLong(MediaFormat.KEY_DURATION) / 1e6
extractor.release()
```

---

## Summary checklist for the Flutter / Android team

- [ ] **P0-1**: `intrinsics.distortion_model` → `"brown_conrady"` (not `"opencv5"`).
- [ ] **P1-1**: Compute `fx == fy` from FOV or a single scalar rescale (no asymmetric per-axis crop factor).
- [ ] **P1-2**: Order IMU rows by `timestamp_ns` before writing (priority-queue or batch+sort drain).
- [ ] **P1-3**: One row per sample event — eliminate the gyro/accel double-emit.
- [ ] **P1-4**: `motion.rate_hz` = primary sensor sample rate, not row rate.
- [ ] **P1-5**: Bracket the IMU stream to the video window (or trim on close).
- [ ] **P2-1**: Read final `frame_count` and `duration_sec` from the finalized MP4 after `MediaMuxer.stop()`.

Once these land, re-run `python -m pipeline.sanity <bundle.tar.gz>` and expect
`RESULT: PASS` with at most cosmetic warnings.
