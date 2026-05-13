# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a Flutter-based egocentric video capture application designed for robo foundation model training data collection. The Flutter project files are located at the repository root level.

## Key Commands

### Development Setup
```bash
# Already in the mobile-app root directory
flutter pub get
```

### Building and Running
```bash
# iOS
flutter build ios --debug
flutter build ios --release    # Requires developer account

# Android
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release  # For Play Store

# Run on connected device
flutter run

# Run on specific device
flutter run -d "iPhone 15 Pro"
flutter run -d emulator-5554
```

### Code Quality
```bash
flutter analyze        # Static analysis
flutter test          # Run unit tests
```

### Platform-Specific Setup
```bash
# iOS: Open in Xcode for signing configuration
open ios/Runner.xcworkspace

# Android: Clean Gradle cache if needed
cd android && ./gradlew clean && cd ..
```

### Validation
```bash
# Validate recording packages using Python validator
python tools/validate_recording.py recording_<session_id>/
```

## Architecture Overview

### Platform Channel Architecture
The app uses a **Flutter-to-native bridge** architecture where:
- **Flutter (Dart)**: Handles UI, file I/O, and state management
- **Native iOS (Swift)**: Manages camera capture, HEVC encoding, and per-frame intrinsics via AVFoundation
- **Native Android (Kotlin)**: Manages camera capture, HEVC encoding, and intrinsics via Camera2 API

Communication happens through a single MethodChannel: `'digients_app/camera'`

### Data Flow
1. **Recording Request**: Flutter UI → Platform Channel → Native Camera Handler
2. **Video Capture**: Native AVFoundation/Camera2 → Hardware HEVC Encoder → MP4 file
3. **Intrinsics Capture**:
   - iOS: Per-frame via `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` → `frames.jsonl`
   - Android: Static via `LENS_INTRINSIC_CALIBRATION` or derived fallback → `metadata.json`
4. **Metadata Generation**: Native platform info + camera specs → `metadata.json`
5. **Export**: Dart tar.gz compression → Share sheet

### Critical Implementation Details

#### Camera Selection Logic
- **iOS**: Prefers `builtInUltraWideCamera`, falls back to `builtInWideAngleCamera`. Avoids virtual multi-cameras.
- **Android**: Enumerates all rear cameras, calculates horizontal FOV, selects widest. Skips logical multi-cameras.

#### Video Specifications (Fixed)
- Resolution: 1920×1080 (1080p)
- Framerate: 30fps (24fps fallback)
- Codec: HEVC (H.265) hardware encoding
- Bitrate: 15 Mbps
- **Audio: Intentionally disabled for privacy**
- **Stabilization: Disabled to preserve intrinsics accuracy**

#### Output Schema (Section 5 of MOBILE_APP_SPECS.md)
```
recording_<session_id>/
├── metadata.json       # Complete session metadata
├── video.mp4          # HEVC-encoded video
└── frames.jsonl       # Per-frame intrinsics (iOS only)
```

Schema version is `"1.0"` and must match the validator expectations.

#### Reliability Flagging
The `intrinsics.reliable` boolean indicates whether downstream pipeline should trust the intrinsics:
- **iOS**: `true` when per-frame intrinsics available AND stabilization disabled
- **Android**: `true` when `LENS_INTRINSIC_CALIBRATION` available AND hardware level FULL/LEVEL_3 AND stabilization disabled

## Key Constraints

### Privacy Requirements
- **No audio recording at runtime**: The app does not capture audio. Native code paths do not call any microphone APIs.
- **`NSMicrophoneUsageDescription` in Info.plist is required for App Store Connect upload (error 90683)**: audio-playback dependencies (`just_audio` for voice cues, `audio_session`, etc.) reference `AVAudioSession`, which Apple's static analyzer flags as needing a microphone usage description, even when only used for playback. The declared string honestly states "No audio is captured" so the runtime contract matches actual behavior. Do not remove this key.
- **Local storage only**: No automatic cloud upload in v1

### Platform-Specific Considerations
- **iOS**: Requires iOS 15.0+, `NSCameraUsageDescription` + `NSMicrophoneUsageDescription` (playback-only) in Info.plist, developer signing for device deployment
- **Android**: Requires API 26+, Camera2 API support, handles LEGACY hardware level gracefully

### Schema Compliance
All output must validate against `tools/validate_recording.py`. The validator checks:
- Directory naming (`recording_<uuid>`)
- Required files presence
- Metadata schema compliance
- Frame count consistency
- Intrinsics source validation

## iOS Code Signing (Multi-Developer Coordination)

The Capture App is currently shipped through a **personal Apple Developer account** as a bridge until the **Digients Technologies company account** is approved. This creates a multi-developer signing coordination problem because each developer's `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` are personal and incompatible across machines.

**During the bridge period — keep pbxproj per-developer**:
- Each developer uses their own paid Apple Developer team locally
- Each enables `skip-worktree` on pbxproj so local team/bundle don't enter git history:
  ```bash
  git update-index --skip-worktree ios/Runner.xcodeproj/project.pbxproj
  ```
- **Do NOT commit pbxproj changes that override `DEVELOPMENT_TEAM` or `PRODUCT_BUNDLE_IDENTIFIER` to `main`** — it forces every other developer to manually re-apply their own team after pulling. If your pbxproj diff shows team/bundle changes when you push, you forgot to enable skip-worktree.

**After the company account is approved — commit a shared team to `main`**:
1. On a feature branch, set the production values in pbxproj:
   - `DEVELOPMENT_TEAM = FTTNZLDA35` (Digients Tech Pte. Ltd.)
   - `PRODUCT_BUNDLE_IDENTIFIER = tech.digients.capture`
     - NOTE: this is `tech.` not `com.`. The `com.digients.capture` ID was globally taken on Apple's side (likely a teammate's Xcode auto-sign on their personal team). We use the `.tech` TLD that the company actually owns.
2. PR → merge to `main`
3. Each developer runs:
   ```bash
   git update-index --no-skip-worktree ios/Runner.xcodeproj/project.pbxproj
   git pull
   ```
4. pbxproj becomes a normally-tracked file from then on; the skip-worktree dance is retired

For team size > 20 or App Store release, migrate to `fastlane match` for centralized cert/profile management. Out of scope for the current bridge phase.

## Development Notes

When modifying video settings, update both:
- iOS: `CameraCaptureHandler.swift` → `setupAssetWriter` method
- Android: `CameraCaptureHandler.kt` → `setupMediaCodec` method

The recording format is designed for a downstream HaWoR + depth estimation pipeline that uses `device.os` for routing and `intrinsics.reliable` for depth model selection.