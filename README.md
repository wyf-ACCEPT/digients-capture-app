# Digients Capture

A cross-platform Flutter app for capturing egocentric RGB video from smartphone cameras, designed for robo foundation model training data collection. The app captures camera intrinsics, produces standardized recording packages, and ensures compatibility with downstream HaWoR + depth estimation pipelines.

## Features

- **Cross-platform**: iOS and Android support
- **Wide-angle capture**: Automatically selects the widest FOV rear camera (ultrawide preferred)
- **Hardware HEVC encoding**: 1080p @ 30fps with 15 Mbps bitrate
- **Camera intrinsics capture**:
  - iOS: Per-frame intrinsics via AVFoundation
  - Android: Static or derived intrinsics via Camera2 API
- **No audio recording**: Privacy-first approach eliminates ambient conversation capture
- **Standardized output**: Self-describing recording packages with metadata
- **Export functionality**: Tar.gz archives for easy sharing and transfer
- **Video stabilization disabled**: Preserves intrinsic matrix validity

## Technical Specifications

### Video Settings
- **Resolution**: 1920×1080 (1080p)
- **Framerate**: 30 fps (fallback to 24 fps if needed)
- **Codec**: HEVC (H.265) hardware encoding
- **Bitrate**: 15 Mbps target
- **Container**: MP4
- **Audio**: None (intentionally disabled)

### Camera Configuration
- **Stabilization**: Video and optical stabilization disabled
- **Focus**: Continuous autofocus enabled
- **Color Space**: BT.709, 8-bit
- **Camera Selection**: Widest horizontal FOV rear camera

## Project Structure

```
mobile-app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── recording.dart        # Data models for recordings and metadata
│   ├── screens/
│   │   ├── home_screen.dart      # Main navigation
│   │   ├── capture_screen.dart   # Recording interface
│   │   └── recordings_screen.dart # Recording list and export
│   └── services/
│       ├── camera_service.dart   # Platform channel interface
│       └── recording_manager.dart # File management and export
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift          # iOS app delegate
│       ├── CameraCaptureHandler.swift # iOS camera implementation
│       └── Info.plist                # Permissions and config
├── android/
│   └── app/src/main/
│       ├── kotlin/com/example/egocentric_video_capture/
│       │   ├── MainActivity.kt             # Android main activity
│       │   └── CameraCaptureHandler.kt     # Android camera implementation
│       └── AndroidManifest.xml            # Permissions and config
├── tools/
│   └── validate_recording.py     # Python schema validator
└── MOBILE_APP_SPECS.md          # Detailed technical specifications
```

## Output Data Format

Each recording produces a directory with this structure:

```
recording_<session_id>/
├── metadata.json       # Session metadata
├── video.mp4           # HEVC-encoded video stream
└── frames.jsonl        # Per-frame intrinsics (iOS only)
```

### Metadata Schema

The `metadata.json` follows the specification in `MOBILE_APP_SPECS.md` and includes:

- Session information (ID, timestamp, app version)
- Device details (OS, version, model)
- Camera parameters (lens type, FOV, focal length)
- Video properties (codec, resolution, framerate, frame count)
- Intrinsics information (source, reliability, distortion)
- Capture platform details

### Intrinsics Handling

**iOS (Reliable)**:
- Per-frame intrinsics via `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix`
- Written to `frames.jsonl` with frame index and timestamp
- Marked as `reliable: true` when stabilization is disabled

**Android (Best Effort)**:
- Static calibrated intrinsics via `LENS_INTRINSIC_CALIBRATION` (when available)
- Derived intrinsics from focal length + sensor size (fallback)
- Marked as `reliable: true` only for FULL/LEVEL_3 devices with calibrated intrinsics

## Building the App

### Prerequisites

- Flutter 3.24.0+
- Dart 3.5+
- iOS: Xcode 15+, iOS 15.0+ deployment target
- Android: API 26+ (Android 8.0), Target SDK: latest stable

### Setup

1. **Clone and navigate to the project**:
   ```bash
   cd mobile-app
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **iOS Setup**:
   ```bash
   cd ios
   pod install  # If using CocoaPods
   cd ..
   ```

4. **Android Setup**:
   - No additional setup required
   - Gradle will handle dependencies automatically

### Building

**iOS**:
```bash
# Development build
flutter build ios --debug

# Release build (requires developer account)
flutter build ios --release
```

**Android**:
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### Running

**On connected device**:
```bash
flutter run
```

**On iOS Simulator**:
```bash
flutter run -d "iPhone 15 Pro"
```

**On Android Emulator**:
```bash
flutter run -d emulator-5554
```

## iOS Developer Setup

### Signing Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Set your Development Team
4. Update Bundle Identifier if needed
5. Ensure "Automatically manage signing" is enabled

### Camera Permission

The app requires camera permission, configured in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture egocentric video for robo foundation model training data collection. No audio is recorded to protect privacy.</string>
```

## Android Configuration

### Permissions

Configured in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
```

### Camera Hardware

```xml
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

## Testing Device Compatibility

### iOS Devices
- iPhone 12 or later (recommended for ultrawide camera)
- iPad Pro with ultrawide camera
- Any iOS 15.0+ device with rear camera

### Android Devices
**Tested Configurations**:
- Pixel devices (good Camera2 API compliance)
- Samsung Galaxy devices (handle OEM customizations)
- Budget devices (test LEGACY hardware level fallback)

**Camera2 API Requirements**:
- FULL or LEVEL_3 for reliable intrinsics
- LEGACY/LIMITED devices fall back to derived intrinsics

## Camera Selection Algorithm

### iOS
1. Prefer `builtInUltraWideCamera` if available
2. Fall back to `builtInWideAngleCamera`
3. Avoid virtual cameras (`builtInDualCamera`, `builtInTripleCamera`)

### Android
1. Enumerate all rear-facing cameras via `CameraManager`
2. Skip logical multi-cameras (`LOGICAL_MULTI_CAMERA` capability)
3. Calculate horizontal FOV: `2 * atan(sensorWidth / (2 * focalLength))`
4. Select camera with widest computed FOV

## Validation

Use the included Python validator to check recording packages:

```bash
# Validate a recording directory
python tools/validate_recording.py recording_550e8400-e29b-41d4-a716-446655440000/

# The validator checks:
# - Directory structure and naming
# - metadata.json schema compliance
# - File presence and consistency
# - Frame count invariants
# - Intrinsics source validation
```

## Known Device-Specific Quirks

### iOS
- Some older devices may not support HEVC encoding
- iPhone SE (1st gen) lacks ultrawide camera
- Video stabilization settings may persist between sessions on some iOS versions

### Android
- Samsung devices may report different FOV calculations
- Some OEMs disable Camera2 API features
- LEGACY hardware level devices provide estimated intrinsics only
- Pixel devices generally have the most consistent Camera2 API behavior

## Troubleshooting

### Build Issues

**iOS**:
```bash
# Clean build cache
cd ios
rm -rf Pods/
pod install
cd ..
flutter clean
flutter pub get
```

**Android**:
```bash
# Clean Gradle cache
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Runtime Issues

**Permission Denied**:
- Check app permissions in device Settings
- Restart app after granting permissions

**Camera Initialization Failed**:
- Ensure no other camera apps are running
- Restart device if camera is locked by another process

**Recording Fails**:
- Check available storage space
- Ensure camera permission is granted
- Verify device supports HEVC encoding

### Performance Issues

**Frame Drops**:
- Close other apps to free memory
- Reduce recording duration for testing
- Check device thermal state

## File Size Estimates

At 15 Mbps bitrate:
- 1 minute: ~112 MB
- 5 minutes: ~560 MB
- 10 minutes: ~1.1 GB

## Privacy & Data Handling

- **No audio capture**: Eliminates ambient conversation recording
- **Local storage only**: No automatic cloud upload
- **Manual export**: User controls data sharing via share sheet
- **No analytics**: App doesn't collect usage data

## Pipeline Integration

Recording packages are designed for the downstream HaWoR + depth estimation pipeline:

1. **Automatic routing**: `device.os` field enables platform-specific processing
2. **Intrinsics reliability**: `intrinsics.reliable` flag guides depth model selection
3. **Standardized format**: Consistent structure across iOS and Android
4. **Self-describing**: Metadata includes all necessary processing parameters

## Future Enhancements (v2+)

- Cloudflare R2 direct upload
- Real-time preview with hand detection overlay
- Variable quality/bitrate settings
- Background recording support
- Live streaming capabilities

## License

This project is developed for robo foundation model training data collection. Please ensure compliance with local privacy laws and obtain appropriate consent for video recording.

## Support

For technical issues:
1. Check device compatibility above
2. Validate recording packages with `tools/validate_recording.py`
3. Review device-specific quirks section
4. Check Flutter and platform tool versions

## Development Notes

### Adding New Platforms

To support additional platforms (e.g., desktop):
1. Implement platform-specific camera capture in `lib/services/camera_service.dart`
2. Add camera permissions to platform manifest
3. Update device info collection in native code
4. Test intrinsics capture compatibility

### Modifying Video Settings

Key settings are defined in:
- iOS: `CameraCaptureHandler.swift` - `setupAssetWriter` method
- Android: `CameraCaptureHandler.kt` - `setupMediaCodec` method
- Update both platforms consistently to maintain schema compliance

### Schema Changes

If modifying the output schema:
1. Update `MOBILE_APP_SPECS.md` first
2. Modify data models in `lib/models/recording.dart`
3. Update native platform code
4. Update `tools/validate_recording.py` validator
5. Increment schema version in metadata