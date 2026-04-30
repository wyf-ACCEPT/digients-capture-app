# MOBILE_APP_SPECS_V2 — Hand Presence Feedback (Recording HUD Addendum)

> **Scope.** Extends `MOBILE_APP_SPECS_V2.md` §4.4 (Recording modal). Adds real-time hand-presence detection that drives synchronized audio + border-color feedback to guide the data collector during capture. Nothing in the v1 capture pipeline or the v2 data contract changes — this is a pure HUD layer plus a parallel detector pipeline. The recorded video file is **not** affected by detection results.
>
> **Why.** Crowd-sourced data collectors record hand-object interactions in environments where they cannot easily look at the screen (cooking, cleaning, lifting, reaching). They need a hands-free signal when one or both hands leave the frame so they can correct mid-take instead of discovering bad data after the fact.

---

## 1. Goals

1. Tell the user, hands-free, which of their hands are currently in frame: `BOTH`, `LEFT_ONLY`, `RIGHT_ONLY`, `NONE`.
2. Survive realistic detector noise — single dropped frames, motion blur, brief self-occlusion — without flickering between states.
3. Stay within a hard performance budget on sub-1000-RMB Android devices (see §6.5). Capture frame rate must remain 30 fps, untouched.
4. Slot into the existing Recording screen as an additive layer. No restructuring of v2 §4.4.
5. Localize cleanly: audio cues are tones (locale-free) by default; optional TTS announcements respect `lib/l10n/`.

## 2. Detector Choice

**MediaPipe Hand Landmarker (Tasks API)**, native on both platforms, exposed to Flutter via `MethodChannel` + `EventChannel`, mirroring the v1 native intrinsics bridge.

| Option | Verdict | Reason |
|---|---|---|
| **MediaPipe Hand Landmarker** | ✅ Chosen | Cross-platform, hardware-accelerated (GPU/NNAPI), per-hand bbox + handedness + confidence, ~10-15 ms inference on mid-range Android, official iOS/Android SDKs. |
| Apple Vision `VNDetectHumanHandPoseRequest` | ❌ | iOS-only — would require a second Android implementation. Not worth the divergence. |
| HaMeR / WiLoR | ❌ | 3D mesh models, two orders of magnitude too heavy. Wrong tool. |
| Custom YOLO-nano hand detector | ❌ | We'd own the training, data, drift, and handedness head. MediaPipe already solves this. |

We use the **Lite** model variant (`hand_landmarker.task`, ~8 MB). The Full variant is unnecessary — we need presence and handedness, not landmark precision.

## 3. Hand-Presence State Machine

### 3.1 Per-frame detector output

Every detector tick produces, for each detected hand:
- `bbox` (xyxy, normalized)
- `handedness ∈ {Left, Right}`
- `score ∈ [0, 1]`

We discard detections with `score < 0.6`. We discard detections whose bbox center is more than 5% outside the frame (rare, but happens with edge-bleed crops).

### 3.2 Per-hand presence with hysteresis

Maintain a fixed-size circular buffer per hand (`leftWindow`, `rightWindow`), each of size **N = 6 frames**. On every detector tick, push `1` if that hand was detected in this frame, `0` otherwise.

A hand's `present` flag flips with **asymmetric thresholds** to prevent flicker:

| Transition | Condition |
|---|---|
| `absent → present` (enter) | `count(window) ≥ 3` (50% of window) |
| `present → absent` (exit) | `count(window) ≤ 1` (≤16% of window) |
| Between 2 and 3 | **Hold** previous flag (hysteresis band) |

At 10 fps detector rate, N=6 = 600 ms of smoothing. Tunable via a single constant — see §6.5 for low-end fallback.

### 3.3 Composite state

```
both = leftPresent && rightPresent      → BOTH
only L = leftPresent && !rightPresent   → LEFT_ONLY
only R = !leftPresent && rightPresent   → RIGHT_ONLY
neither                                 → NONE
```

`LEFT_ONLY` / `RIGHT_ONLY` refer to the **anatomical** left/right of the person — NOT image-relative left/right. MediaPipe returns anatomical handedness directly when the camera is **rear-facing** (which v2 §4.4 mandates). If a front-camera path is ever added, invert the handedness label at the bridge layer; the state machine consumes anatomical labels only.

### 3.4 Initial state

On Recording screen entry, state is `NONE` until the first detection window fills. The first transition fires only after **at least 3 detector ticks** have completed, to avoid a spurious `NONE → BOTH` chime in the first 300 ms while the buffer warms up.

## 4. Audio Feedback

### 4.1 Trigger rule

Audio fires **only on state transitions**, never on steady-state. The state machine in §3.3 is the single source of truth — if the state didn't change, no audio plays.

Additional debounce: ignore any transition that reverts within 250 ms (the new state must hold for at least one more detector tick after the transition, or the transition is cancelled and no audio plays). This catches cases where hysteresis still lets through a fast bounce.

### 4.2 Tone bank

Bundled as 4 short PCM WAV files in `assets/audio/hand_state/`. All ≤350 ms, normalized to -3 dBFS, mono 44.1 kHz.

| State | File | Spec |
|---|---|---|
| `BOTH` | `both.wav` | 250 ms major-third chime: C5 (523 Hz) + E5 (659 Hz), 50 ms attack, 200 ms decay. Feels "complete." |
| `LEFT_ONLY` | `left_only.wav` | 200 ms single beep at 600 Hz, square-ish envelope. |
| `RIGHT_ONLY` | `right_only.wav` | 200 ms single beep at 900 Hz. Pitch ≠ left so users learn the difference. |
| `NONE` | `none.wav` | 3× 100 ms beeps at 400 Hz, 80 ms gaps. Alarm character — clearly bad. |

Tones are **language-free by design.** No TTS in the default path.

### 4.3 Optional TTS overlay

Settings → Recording feedback → "Spoken cues" toggle (default **OFF**).

When ON, after the tone plays, a TTS phrase from `intl_*.arb` is queued:
- `bothHandsVisible` — "Both hands visible"
- `leftHandOnly` — "Only left hand"
- `rightHandOnly` — "Only right hand"
- `noHandsVisible` — "No hands visible"

Use platform-native TTS (`flutter_tts` or direct `AVSpeechSynthesizer` / `TextToSpeech`). Speech is dropped (not queued) if a new transition occurs before the previous utterance finishes — last-state-wins.

### 4.4 Audio session

- **iOS:** `AVAudioSession` category `.ambient` with `.mixWithOthers` so we don't kill the user's music. Honor the silent switch — set `.duckOthers` only when TTS is on.
- **Android:** `STREAM_NOTIFICATION` for tones, `STREAM_MUSIC` for TTS. Respect Do Not Disturb.

If the device is muted, **the visual feedback in §5 still plays.** Audio is supplementary, not primary.

## 5. Visual Feedback (Border Layer)

### 5.1 Layer placement

A new full-screen widget `HandPresenceBorder` wraps the existing Recording stack:

```
Stack
├─ NativeCameraPreview          // v1, untouched
├─ HandPresenceBorder           // NEW — this addendum
├─ RecordingHUD                 // v2 §4.4 (top pill, stop button, expanded HUD)
```

The border is a stateless `IgnorePointer` widget — it never absorbs touches.

### 5.2 Visual spec

A 6 dp inset border rendered with `CustomPaint`, drawn as a rounded rectangle (24 dp radius) hugging the safe-area inset. Border color is driven by the current state via `tokens.dart`:

| State | Color token | Hex (dark theme) |
|---|---|---|
| `BOTH` | `accent` | `#14C9A8` |
| `LEFT_ONLY` | `warning` | `#FFB800` |
| `RIGHT_ONLY` | `warning` | `#FFB800` |
| `NONE` | `danger` | `#FF453A` |

Both single-hand states share the warning color. The audio cue carries the left/right distinction; doubling up the visual would just clutter the HUD.

### 5.3 Motion

- **Color transition:** 240 ms tween between colors via `AnimatedContainer` / Tween. No sudden jumps.
- **Glow:** 16 dp blur outer glow at 35% opacity in the active color. Pulses subtly in `WARNING` and `NONE` (1.4 s ease-in-out, opacity 0.25 ↔ 0.45) — same cadence as the existing recording dot in v2 §4.4 to feel like one system.
- **`BOTH`:** static glow, no pulse. Calm = good.
- Motion is disabled when `MediaQuery.disableAnimations == true`; border still recolors on transitions, just instantly.

### 5.4 Coexistence with the existing HUD

The top pill (`mm:ss` + red dot) sits **inside** the border. The 80 dp stop button sits inside the border. Nothing in v2 §4.4 needs to move. The border has no opaque fill — only stroke + glow — so the camera preview is fully visible.

## 6. Native Pipeline

### 6.1 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Native (iOS/Android)                                        │
│                                                             │
│  CaptureSession ──▶ Capture frames @ 30 fps (video file)    │
│         │                                                   │
│         └──▶ Frame tap ──▶ Downsample 256×256 ──▶ MediaPipe │
│                                            (10 fps)         │
│                                                 │           │
│                                                 ▼           │
│                                       Detection result      │
└─────────────────────────────────────────────────────────────┘
                                                  │
                              EventChannel        │
                       hand_presence_events       │
                                                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Flutter                                                     │
│  HandPresenceController (Riverpod)                          │
│   ├─ Sliding-window smoothing (§3.2)                        │
│   ├─ State machine (§3.3)                                   │
│   ├─ Transition debounce (§4.1)                             │
│   └─ Emits: AudioCueRequest, BorderState                    │
│                                                             │
│  HandPresenceBorder ◀── BorderState                         │
│  AudioCuePlayer    ◀── AudioCueRequest                      │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Frame tap, not separate session

The MediaPipe input comes from a **non-blocking tap** on the existing capture session's video output:
- **iOS:** `AVCaptureVideoDataOutput` with a dedicated dispatch queue, separate from the file-writing queue. `setSampleBufferDelegate` configured to drop frames if the queue is busy (`alwaysDiscardsLateVideoFrames = true`).
- **Android:** CameraX `ImageAnalysis` use case with `STRATEGY_KEEP_ONLY_LATEST`, alongside the existing `VideoCapture` use case. Same `LifecycleOwner`.

We do **not** open a second camera session. Frames are shared.

### 6.3 Frame rate decoupling

| Pipeline | Rate | Reason |
|---|---|---|
| Capture (video file) | 30 fps | v1 spec, untouched |
| MediaPipe inference | **10 fps** (default) | Presence detection has no use for 30 fps; saves ~67% of detector compute |
| State machine ticks | 10 Hz | One per detector result |
| Border redraw | On state change only | Idle the GPU when nothing moves |

The MediaPipe input frame is downsampled to **256×256** before inference. Hand presence does not need landmark precision.

### 6.4 Threading

- Capture runs on the OS-managed camera thread.
- MediaPipe inference runs on the camera thread's analysis dispatch queue (iOS) or `ImageAnalysis` executor (Android), GPU-delegated where available.
- Smoothing + state machine run on the Flutter UI isolate (microseconds of work per tick — no point spinning a separate isolate).
- Audio playback uses a dedicated `AudioPlayer` instance with preloaded buffers; play call is non-blocking.

### 6.5 Performance budget

Target device: **Tecno Spark 10C** (Helio G36, 4 GB RAM) — the v2 §8 reference device.

| Metric | Budget | Measurement method |
|---|---|---|
| Capture frame rate | 30.0 fps (no drops) | Frame timestamp histogram from v1 logger |
| Additional CPU | ≤ 8% (single core) | `top -p <pid>` during 60 s record |
| Additional RSS | ≤ 80 MB | `dumpsys meminfo` delta vs v2 baseline |
| Detector latency p99 | ≤ 80 ms | EventChannel timestamp at native send vs Dart receive |
| Battery | ≤ 5% additional drain over 30-min record | Battery Historian delta |

**Low-end fallback:** if at app start we detect a chipset on the deny-list (Helio A22 / A25, Snapdragon 4xx pre-2020, Unisoc T606 and below), drop detector to **5 fps** and window size to **N = 4**. Determined via `DeviceInfoPlugin` + a hard-coded match list updated quarterly.

### 6.6 Failure modes

| Failure | Behavior |
|---|---|
| MediaPipe model fails to load at startup | Border stays at `accent` (BOTH-equivalent neutral). Audio disabled for the session. Log telemetry; do not block recording. |
| Detector throws on a single frame | Frame counted as `0` for both hands in the window. Don't crash. |
| Detector queue backs up > 500 ms | Drop oldest, log a `detector_lag` event. The capture pipeline is unaffected. |
| App backgrounded mid-record | Detector pauses; on resume, windows clear; first transition suppressed for the warm-up period (§3.4). |
| Camera reconfiguration (e.g., torch toggle) | State resets to `NONE` and warm-up restarts. |

## 7. Settings (`MOBILE_APP_SPECS_V2.md` §4.9 additions)

Add a new **Recording feedback** section to Settings, between **Uploads** and **Notifications**:

| Row | Default | Notes |
|---|---|---|
| Hand-presence cues (master toggle) | **ON** | Off disables both audio and border. |
| Audio tones | ON | Subordinate to master. |
| Spoken cues (TTS) | OFF | Subordinate to master + audio tones. Uses device locale. |
| Border indicator | ON | Subordinate to master. Required-on for accessibility users who can't hear. |
| Vibrate on `NONE` | OFF | Optional haptic on entering the `NONE` state — single `HapticFeedback.mediumImpact`, never repeats while in state. |

Per the v2 §4.9 principle (capture-quality knobs aren't user-tunable), these are presentation-only toggles — they do not affect what's recorded or what's evaluated server-side.

## 8. Edge Cases

- **Hand at frame edge.** MediaPipe will sometimes detect, sometimes not — exactly the case the hysteresis window is designed for. No special handling.
- **User wearing gloves.** MediaPipe's training set includes gloves; performance degrades but doesn't collapse. We accept the degraded behavior and don't add a glove-specific code path.
- **Two left hands (e.g., a second person enters frame).** MediaPipe returns up to two hands; if both come back labeled `Left`, treat the higher-confidence one as canonical and ignore the second. Log a `multi_person_detected` telemetry event so we can flag affected sessions in review.
- **Hands held very close together / overlapping.** Detector may collapse to one detection. Falls into `LEFT_ONLY` or `RIGHT_ONLY` — acceptable; the user adjusts and gets the `BOTH` chime back.
- **Very dim lighting.** Detector confidence drops below 0.6 and the system reads `NONE`. Correct behavior — bad lighting = bad data; the user should improve lighting.
- **Mirror / reflective surface in frame** (oven door, fridge). May produce phantom hand detections. Hysteresis handles brief flickers; sustained false positives are rare in practice and not worth a special path.

## 9. Telemetry

Append to v1 session JSON a new object:

```json
"hand_presence": {
  "detector": "mediapipe-hand-landmarker-lite-v0.10",
  "detector_fps_target": 10,
  "detector_fps_actual_p50": 9.8,
  "detector_fps_actual_p05": 8.1,
  "window_size": 6,
  "transitions": [
    { "t_ms": 1240, "from": "NONE", "to": "BOTH" },
    { "t_ms": 8430, "from": "BOTH", "to": "LEFT_ONLY" },
    ...
  ],
  "state_durations_ms": {
    "BOTH": 41200,
    "LEFT_ONLY": 3100,
    "RIGHT_ONLY": 800,
    "NONE": 0
  },
  "detector_failures": 0
}
```

Server-side review can use `state_durations_ms.NONE` and the transition density as a coarse quality signal — sessions where the user spent >30% in `NONE` are flagged for closer review.

## 10. Acceptance

The feature is complete when:

1. The Recording modal renders the colored border and plays the correct tone within 700 ms of any genuine state change on the v2 reference device.
2. Single-frame detector dropouts (manually injected via test harness) **do not** trigger any state transition or audio cue.
3. Capture frame rate measured over a 60-second record on the reference device is unchanged from v2 baseline (within ±0.2 fps).
4. The performance metrics in §6.5 are met.
5. Toggling each Settings row in §7 produces the documented behavior with the Recording screen open and live.
6. The session JSON contains a valid `hand_presence` block matching §9.
7. A 30-second recording with deliberate hand exits/entries (left out, right out, both out, both in) shows correct transitions in the telemetry log and no audio repeats during steady states.

## 11. Out of Scope

- Real-time hand pose / landmark visualization in the HUD (deferred — adds clutter and we don't need it for presence).
- Driving auto-pause on `NONE` (we discussed and rejected: the user might intentionally show empty workspace; pausing on `NONE` would create more dropped sessions than it would save).
- Server-side hand-presence verification (V3 quality pipeline, not this layer).
- Cross-frame hand identity tracking (which left hand is the "same" left hand across time). MediaPipe does not provide tracking IDs; the state machine doesn't need them.

## 12. Implementation Order

1. **Native bridge** (iOS + Android): MediaPipe wrapped behind `MethodChannel('hand_presence/control')` and `EventChannel('hand_presence/events')`. Smoke test: log raw detection count to console for 60 s of preview.
2. **Smoothing + state machine** in Dart, with unit tests covering: clean transitions, single-frame dropouts, sustained low-confidence, warm-up period.
3. **Border widget** wired to a Riverpod `StateNotifier`. Visual QA against the design tokens.
4. **Audio bank** + transition trigger. Manual QA on iOS silent switch, Android DnD, low-volume device.
5. **Settings rows** + persistence to the existing `prefs` Hive box.
6. **Telemetry** appended to session JSON.
7. **Reference-device performance pass** against §6.5 budget.
8. **Acceptance run** per §10.
