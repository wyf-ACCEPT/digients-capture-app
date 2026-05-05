import Foundation
import ARKit
import AVFoundation
import CoreMotion
import Flutter
import UIKit
import VideoToolbox
import simd

class CameraCaptureHandler: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel

    // Hand-presence detector (V2 addendum). Set by AppDelegate after load. We
    // tap ARSession.didUpdate at the same place we feed the encoder; the
    // detector throttles to its own cadence and runs on its own queue.
    weak var handDetector: HandPresenceDetector?

    // ARKit owns the camera (per RECORDING_DATA_STRUCTURE_V1.1.md). The ARSession
    // is exposed so CameraPreviewView can attach an ARSCNView to it.
    let arSession = ARSession()
    private var configuration: ARWorldTrackingConfiguration?
    private var selectedVideoFormat: ARConfiguration.VideoFormat?
    // Captured at format-selection time so the encoder, metadata, and HUD all
    // agree on dimensions even when ARKit picks a non-1080p format.
    private var captureWidth: Int = 1920
    private var captureHeight: Int = 1080
    private var captureFps: Int = 30
    // 30 fps is the spec target. ARKit on most devices runs at 60 fps; we drop
    // every other frame in that case. Computed from captureFps at start time.
    private var frameDropModulus: Int = 1
    private var arFrameCounter: Int = 0

    // Asset writer pipeline — fed from ARFrame.capturedImage
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Recording state
    private var isRecording = false
    private var recordingStartTimestamp: TimeInterval?
    private var unixEpochOffset: TimeInterval = 0
    private var outputDirectory: String?
    private var sessionId: String?
    private var frameCounter = 0
    private var framesFileHandle: FileHandle?
    private var posesFileHandle: FileHandle?
    private var motionFileHandle: FileHandle?

    // IMU (motion.jsonl). Spec §7: target 100 Hz on iOS via CMMotionManager.
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let motionRateHz: Double = 100.0
    // CMDeviceMotion.userAcceleration is reported in units of g; convert to m/s²
    // before writing (spec mandates accel_units = "m/s^2").
    private let gToMetersPerSecondSquared: Double = 9.80665

    // Cached lens info, populated on first ARFrame so it reflects the active video format.
    private var cachedLensType: String = "wide"
    private var cachedHorizontalFOVDeg: Double = 78.0

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        motionQueue.name = "digients.motionQueue"
        motionQueue.qualityOfService = .userInitiated
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "digients_app/camera", binaryMessenger: registrar.messenger())
        let instance = CameraCaptureHandler(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeCamera":
            initializeCamera(result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "getCameraInfo":
            getCameraInfo(result: result)
        case "getDeviceInfo":
            getDeviceInfo(result: result)
        case "startRecording":
            if let args = call.arguments as? [String: Any] {
                startRecording(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            }
        case "stopRecording":
            stopRecording(result: result)
        case "getAvailableCameras":
            getAvailableCameras(result: result)
        case "switchCamera":
            // ARKit picks the lens via ARConfiguration.VideoFormat; runtime switching
            // would require re-running the session with a different config. Not used in v3.
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permissions

    private func requestPermissions(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { result(granted) }
        }
    }

    // MARK: - Initialization

    private func initializeCamera(result: @escaping FlutterResult) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            result(FlutterError(code: "NO_PERMISSION", message: "Camera permission not granted", details: nil))
            return
        }
        guard ARWorldTrackingConfiguration.isSupported else {
            result(FlutterError(code: "ARKIT_UNSUPPORTED", message: "ARKit world tracking not supported on this device", details: nil))
            return
        }

        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = []
        cfg.isAutoFocusEnabled = false
        cfg.frameSemantics = []
        if let format = selectBestVideoFormat() {
            cfg.videoFormat = format
            selectedVideoFormat = format
            cachedLensType = lensType(for: format)
            cachedHorizontalFOVDeg = approximateFOV(for: format)
            captureWidth = Int(format.imageResolution.width)
            captureHeight = Int(format.imageResolution.height)
            captureFps = Int(format.framesPerSecond)
            // Keep recorded video close to the spec's 30 fps target. If the
            // hardware reports 60 fps, drop every other frame; if 30 fps, no drop.
            frameDropModulus = max(1, Int((Double(captureFps) / 30.0).rounded()))
        }
        configuration = cfg

        // Capture an offset converting CACurrentMediaTime() (ARFrame.timestamp) to
        // wall-clock seconds. Spec §3 requires session_clock_origin = "unix_epoch".
        unixEpochOffset = Date().timeIntervalSince1970 - CACurrentMediaTime()

        arSession.delegate = self
        arSession.run(cfg, options: [.resetTracking, .removeExistingAnchors])

        result(true)
    }

    private func selectBestVideoFormat() -> ARConfiguration.VideoFormat? {
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        // ARKit on Pro models typically offers 1920×1440 @ 60 fps, 1920×1080 @ 60 fps,
        // and 1280×720 — 30 fps is rarely available. Take any 1920×1080 and prefer
        // ultra-wide; otherwise pick the smallest format whose pixel area is ≥ 1080p,
        // and fall back to whatever's available.
        let exact1080 = formats.filter {
            Int($0.imageResolution.width) == 1920 && Int($0.imageResolution.height) == 1080
        }
        if let pick = exact1080.max(by: { approximateFOV(for: $0) < approximateFOV(for: $1) }) {
            return pick
        }
        let above1080 = formats.filter {
            $0.imageResolution.width * $0.imageResolution.height >= 1920 * 1080
        }
        if let pick = above1080.min(by: { $0.imageResolution.width * $0.imageResolution.height < $1.imageResolution.width * $1.imageResolution.height }) {
            return pick
        }
        return formats.first
    }

    private func lensType(for format: ARConfiguration.VideoFormat) -> String {
        if #available(iOS 16.0, *) {
            switch format.captureDeviceType {
            case .builtInUltraWideCamera: return "ultrawide"
            case .builtInTelephotoCamera: return "telephoto"
            case .builtInWideAngleCamera: return "wide"
            default: return "wide"
            }
        }
        return "wide"
    }

    private func approximateFOV(for format: ARConfiguration.VideoFormat) -> Double {
        if #available(iOS 16.0, *) {
            switch format.captureDeviceType {
            case .builtInUltraWideCamera: return 120.0
            case .builtInTelephotoCamera: return 48.0
            case .builtInWideAngleCamera: return 78.0
            default: return 78.0
            }
        }
        return 78.0
    }

    // MARK: - Info getters

    private func getCameraInfo(result: @escaping FlutterResult) {
        // Report the post-decimation fps (target 30) — that's what we actually
        // write to disk and what metadata.video.framerate / pose.rate_hz reflect.
        let fps = 30.0
        let cameraInfo: [String: Any] = [
            "lensId": "arkit:\(cachedLensType)",
            "lensType": cachedLensType,
            "physicalFocalLengthMm": NSNull(),
            "sensorPhysicalSizeMm": NSNull(),
            "sensorPixelArraySize": NSNull(),
            "horizontalFovDeg": cachedHorizontalFOVDeg,
            "videoStabilizationEnabled": false,
            "opticalStabilizationEnabled": false,
            // v1.1 additions — consumed by record_screen.dart to build metadata.json.
            "intrinsicsSource": "per_frame",
            "poseSource": "arkit",
            "poseRateHz": fps,
            "poseFrameOrigin": "arkit_session",
            "poseCoordinateConvention": "right_handed_y_up_neg_z_forward",
            "poseTransformKind": "camera_to_world",
            "motionRateHz": 100.0,
            "motionGyroUnits": "rad/s",
            "motionAccelUnits": "m/s^2",
            "motionAccelIncludesGravity": false,
            "motionFrame": "device_body",
        ]
        result(cameraInfo)
    }

    private func getDeviceInfo(result: @escaping FlutterResult) {
        let device = UIDevice.current
        let deviceInfo: [String: Any] = [
            "os": "ios",
            "osVersion": device.systemVersion,
            "manufacturer": "Apple",
            "model": device.model,
            "modelIdentifier": deviceModelIdentifier(),
            "hasArkit": ARWorldTrackingConfiguration.isSupported,
            "hasArcore": false,
        ]
        result(deviceInfo)
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    // MARK: - Recording lifecycle

    private func startRecording(args: [String: Any], result: @escaping FlutterResult) {
        guard let sessionId = args["sessionId"] as? String,
              let outputDirectory = args["outputDirectory"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing sessionId or outputDirectory", details: nil))
            return
        }
        guard !isRecording else {
            result(FlutterError(code: "ALREADY_RECORDING", message: "Already recording", details: nil))
            return
        }

        self.sessionId = sessionId
        self.outputDirectory = outputDirectory

        do {
            try setupAssetWriter(outputDirectory: outputDirectory)
            try setupJsonlFiles(outputDirectory: outputDirectory)
            try setupMotionFile(outputDirectory: outputDirectory)
            isRecording = true
            frameCounter = 0
            arFrameCounter = 0
            recordingStartTimestamp = nil
            startMotionUpdates()
            result(true)
        } catch {
            result(FlutterError(code: "START_FAILED", message: "Failed to start recording: \(error.localizedDescription)", details: nil))
        }
    }

    private func setupAssetWriter(outputDirectory: String) throws {
        let videoURL = URL(fileURLWithPath: "\(outputDirectory)/video.mp4")
        if FileManager.default.fileExists(atPath: videoURL.path) {
            try? FileManager.default.removeItem(at: videoURL)
        }

        assetWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        guard let writer = assetWriter else { throw CameraError.assetWriterCreationFailed }

        // Encode at the actual ARKit format dimensions. Hard-coding 1920×1080
        // when ARKit hands a different size makes every append silently fail.
        // Also pin profile + keyframe interval — without these the HEVC encoder
        // defaults can leave the writer in a state where finishWriting fails to
        // finalize the moov atom, producing a 38 MB mdat with no index.
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: captureWidth,
            AVVideoHeightKey: captureHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 15_000_000,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel as String,
            ],
            // BT.709 since the spec asks for it in metadata.color_space.
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        // ARKit's frame.capturedImage is 4:2:0 bi-planar FullRange (NV12 0-255).
        // Stating that explicitly here so the encoder knows what format to
        // expect — without it, the adaptor's defaults can mismatch the actual
        // buffers, and the writer silently transitions to .failed.
        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: captureWidth,
            kCVPixelBufferHeightKey as String: captureHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )

        guard writer.canAdd(input) else { throw CameraError.cannotAddAssetWriterInput }
        writer.add(input)
        guard writer.startWriting() else { throw CameraError.cannotStartWriting }

        assetWriterInput = input
        pixelBufferAdaptor = adaptor
    }

    private func setupJsonlFiles(outputDirectory: String) throws {
        let framesURL = URL(fileURLWithPath: "\(outputDirectory)/frames.jsonl")
        let posesURL = URL(fileURLWithPath: "\(outputDirectory)/poses.jsonl")
        FileManager.default.createFile(atPath: framesURL.path, contents: nil, attributes: nil)
        FileManager.default.createFile(atPath: posesURL.path, contents: nil, attributes: nil)
        framesFileHandle = try FileHandle(forWritingTo: framesURL)
        posesFileHandle = try FileHandle(forWritingTo: posesURL)
    }

    private func setupMotionFile(outputDirectory: String) throws {
        let motionURL = URL(fileURLWithPath: "\(outputDirectory)/motion.jsonl")
        FileManager.default.createFile(atPath: motionURL.path, contents: nil, attributes: nil)
        motionFileHandle = try FileHandle(forWritingTo: motionURL)
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        // 100 Hz per spec §7. CMDeviceMotion fuses gyro + accelerometer + magnetometer
        // and reports bias-corrected rotation rate plus gravity-removed userAcceleration.
        motionManager.deviceMotionUpdateInterval = 1.0 / motionRateHz
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let self = self, self.isRecording, let m = motion else { return }
            self.writeMotionLine(motion: m)
        }
    }

    private func stopMotionUpdates() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    private func writeMotionLine(motion: CMDeviceMotion) {
        let timestampNs = Int64((motion.timestamp + unixEpochOffset) * 1_000_000_000)
        let payload: [String: Any] = [
            "timestamp_ns": timestampNs,
            "gyro": [motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z],
            "accel": [
                motion.userAcceleration.x * gToMetersPerSecondSquared,
                motion.userAcceleration.y * gToMetersPerSecondSquared,
                motion.userAcceleration.z * gToMetersPerSecondSquared,
            ],
        ]
        writeJsonLine(payload, to: motionFileHandle)
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard isRecording else {
            result(FlutterError(code: "NOT_RECORDING", message: "Not currently recording", details: nil))
            return
        }
        isRecording = false
        stopMotionUpdates()

        assetWriterInput?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            // Surface writer failure modes so the next bug is debuggable from
            // device logs instead of from a corrupt MP4 after the fact.
            let writerStatus = self?.assetWriter?.status ?? .unknown
            let writerError = self?.assetWriter?.error
            if writerStatus != .completed {
                NSLog("[CameraCaptureHandler] AVAssetWriter did not complete: status=\(writerStatus.rawValue) error=\(String(describing: writerError))")
            }

            DispatchQueue.main.async {
                self?.framesFileHandle?.closeFile()
                self?.framesFileHandle = nil
                self?.posesFileHandle?.closeFile()
                self?.posesFileHandle = nil
                self?.motionFileHandle?.closeFile()
                self?.motionFileHandle = nil

                let frames = self?.frameCounter ?? 0
                // After decimation we target 30 fps; report duration accordingly so
                // metadata.duration_sec stays consistent with metadata.video.framerate.
                let effectiveFps = 30.0
                let durationSec = Int(Double(frames) / effectiveFps)
                let recordingData: [String: Any] = [
                    "directoryPath": self?.outputDirectory ?? "",
                    "durationSeconds": durationSec,
                    "frameCount": frames,
                    "captureWidth": self?.captureWidth ?? 1920,
                    "captureHeight": self?.captureHeight ?? 1080,
                    "captureFps": Int(effectiveFps),
                    "writerStatus": writerStatus.rawValue,
                    "writerError": writerError?.localizedDescription as Any,
                ]
                result(recordingData)
            }
        }
    }

    private func getAvailableCameras(result: @escaping FlutterResult) {
        // ARKit selects the camera implicitly via the chosen ARConfiguration.VideoFormat.
        // Surface the active selection so the Flutter side has a stable identifier to display.
        result(["arkit:\(cachedLensType)"])
    }
}

extension CameraCaptureHandler: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update cached lens info on the live ARFrame the first time we see one,
        // so getCameraInfo reflects the actual selected format.
        if recordingStartTimestamp == nil {
            cachedHorizontalFOVDeg = liveHorizontalFOVDegrees(from: frame.camera.intrinsics,
                                                              imageWidth: Double(frame.camera.imageResolution.width))
        }

        // Feed the hand-presence detector regardless of recording state — the
        // border + audio cues are useful while the user is composing the shot.
        // The detector throttles internally and runs on its own queue.
        if let detector = handDetector {
            let timestampMs = Int64((frame.timestamp + unixEpochOffset) * 1000)
            detector.submitFrame(frame.capturedImage, timestampMs: timestampMs)
        }

        guard isRecording, let writer = assetWriter, let input = assetWriterInput, let adaptor = pixelBufferAdaptor else { return }

        // Decimate to 30 fps. ARKit on iPhone Pro typically streams at 60 fps;
        // we keep every Nth frame to honor the spec's 30 fps target. Increment
        // arFrameCounter on every callback so the modulus stays even.
        let myArIdx = arFrameCounter
        arFrameCounter += 1
        if frameDropModulus > 1 && (myArIdx % frameDropModulus) != 0 {
            return
        }

        if recordingStartTimestamp == nil {
            recordingStartTimestamp = frame.timestamp
            // Use timescale 600 — the standard MP4 video timescale, divisible by
            // common frame rates (24, 25, 30, 60). Mixing different timescales
            // between startSession and append can wedge finalization on some iOS
            // versions, leaving moov unwritten despite mdat being intact.
            writer.startSession(atSourceTime: CMTime(value: 0, timescale: 600))
        }
        let elapsed = frame.timestamp - (recordingStartTimestamp ?? frame.timestamp)
        let presentationTime = CMTime(seconds: elapsed, preferredTimescale: 600)

        guard input.isReadyForMoreMediaData else { return }
        let pixelBuffer = frame.capturedImage
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            // Append failed — usually means writer.status == .failed (encoder
            // refused the buffer format/dimensions). Log once with details so
            // the failure is debuggable; subsequent failures stay quiet.
            if writer.status == .failed {
                NSLog("[CameraCaptureHandler] adaptor.append failed at frame \(frameCounter): \(String(describing: writer.error))")
            }
            return
        }

        let timestampNs = Int64((frame.timestamp + unixEpochOffset) * 1_000_000_000)
        writeFramesLine(frame: frame, frameIdx: frameCounter, timestampNs: timestampNs)
        writePosesLine(frame: frame, frameIdx: frameCounter, timestampNs: timestampNs)
        frameCounter += 1
    }

    private func liveHorizontalFOVDegrees(from intrinsics: simd_float3x3, imageWidth: Double) -> Double {
        let fx = Double(intrinsics.columns.0[0])
        guard fx > 0 else { return cachedHorizontalFOVDeg }
        return 2.0 * atan(imageWidth / (2.0 * fx)) * 180.0 / .pi
    }

    private func writeFramesLine(frame: ARFrame, frameIdx: Int, timestampNs: Int64) {
        // Per spec §6.1: simd_float3x3 is column-major with columns
        //   col0 = (fx, 0, 0), col1 = (0, fy, 0), col2 = (cx, cy, 1)
        // Assemble row-major [[fx,0,cx],[0,fy,cy],[0,0,1]].
        let m = frame.camera.intrinsics
        let matrix: [[Double]] = [
            [Double(m.columns.0[0]), Double(m.columns.1[0]), Double(m.columns.2[0])],
            [Double(m.columns.0[1]), Double(m.columns.1[1]), Double(m.columns.2[1])],
            [Double(m.columns.0[2]), Double(m.columns.1[2]), Double(m.columns.2[2])],
        ]
        let payload: [String: Any] = [
            "frame_idx": frameIdx,
            "timestamp_ns": timestampNs,
            "intrinsic_matrix": matrix,
            "lens_id": "arkit:\(cachedLensType)",
        ]
        writeJsonLine(payload, to: framesFileHandle)
    }

    private func writePosesLine(frame: ARFrame, frameIdx: Int, timestampNs: Int64) {
        // simd_float4x4 is column-major; spec §5 requires row-major output.
        let t = frame.camera.transform
        let rows: [[Double]] = (0..<4).map { r in
            (0..<4).map { c in Double(t[c][r]) }
        }
        var trackingState = "normal"
        var trackingReason: String? = nil
        switch frame.camera.trackingState {
        case .normal:
            trackingState = "normal"
        case .notAvailable:
            trackingState = "not_available"
        case .limited(let reason):
            trackingState = "limited"
            switch reason {
            case .initializing: trackingReason = "initialization"
            case .excessiveMotion: trackingReason = "excessive_motion"
            case .insufficientFeatures: trackingReason = "insufficient_features"
            case .relocalizing: trackingReason = "relocalizing"
            @unknown default: trackingReason = "unknown"
            }
        }
        var payload: [String: Any] = [
            "frame_idx": frameIdx,
            "timestamp_ns": timestampNs,
            "transform": rows,
            "tracking_state": trackingState,
        ]
        if let reason = trackingReason {
            payload["tracking_state_reason"] = reason
        }
        writeJsonLine(payload, to: posesFileHandle)
    }

    private func writeJsonLine(_ obj: Any, to handle: FileHandle?) {
        guard let handle = handle else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else { return }
        let line = (str + "\n").data(using: .utf8) ?? Data()
        handle.write(line)
    }
}

enum CameraError: Error {
    case assetWriterCreationFailed
    case cannotAddAssetWriterInput
    case cannotStartWriting
}
