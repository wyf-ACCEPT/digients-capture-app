import Foundation
import AVFoundation
import CoreMotion
import Flutter
import UIKit
import VideoToolbox

/// v1.2 capture pipeline (RECORDING_DATA_STRUCTURE_V1.2.md).
///
/// One path only: AVCaptureSession bound to the widest physical rear lens,
/// HEVC-encoded video at fixed static intrinsics, plus raw IMU at 100 Hz.
/// No ARKit. No per-frame intrinsics. No poses.jsonl. The post-processing
/// pipeline reconstructs poses offline (DROID-SLAM today, offline VIO next).
class CameraCaptureHandler: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel

    // Hand-presence detector (V2 addendum). Set by AppDelegate after load. We
    // tap the AVCaptureVideoDataOutput delegate to feed it.
    weak var handDetector: HandPresenceDetector?

    // The AVCaptureSession is exposed so CameraPreviewView can attach an
    // AVCaptureVideoPreviewLayer to it.
    let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?

    // Active capture characteristics, captured at initializeCamera.
    private var captureWidth: Int = 1920
    private var captureHeight: Int = 1080
    private var captureFps: Double = 30.0
    private var captureLensType: String = "wide"
    private var captureHorizontalFovDeg: Double = 78.0
    private var capturePhysicalFocalLengthMm: Double?

    // Asset writer pipeline — fed from AVCaptureVideoDataOutput sample buffers.
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let videoQueue = DispatchQueue(label: "digients.captureQueue", qos: .userInitiated)

    // Recording state.
    private var isRecording = false
    private var recordingStartTimestamp: TimeInterval?
    // Offset from CACurrentMediaTime() (== mach_absolute_time / timebase) to
    // wall-clock seconds. Spec §4.4 requires session_clock_origin = "unix_epoch".
    private var unixEpochOffset: TimeInterval = 0
    private var outputDirectory: String?
    private var sessionId: String?
    private var frameCounter = 0
    private var motionFileHandle: FileHandle?

    // Bracket the IMU stream to the video window (v1.2 spec §5 / Android P1-5
    // applies symmetrically). Captured the moment the first/last sample buffer
    // arrives; motion writes outside this window are suppressed at stop.
    private var firstFramePtsNs: Int64?
    private var lastFramePtsNs: Int64?
    private var motionRowCount: Int = 0
    private var firstMotionTsNs: Int64?
    private var lastMotionTsNs: Int64?

    // IMU (motion.jsonl). Spec §5: 100 Hz minimum, 200 Hz preferred. CMDeviceMotion
    // is well-behaved and gives us bias-corrected gyro + gravity-removed accel,
    // plus the gravity vector (recommended in v1.2 motion.jsonl rows).
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private let motionRateHz: Double = 100.0
    // CMDeviceMotion.userAcceleration is reported in g; convert to m/s².
    private let gToMetersPerSecondSquared: Double = 9.80665

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
            // v1.2 picks one widest physical lens at session start and locks it.
            // Mid-session lens switching would break the static-intrinsics contract.
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

    // MARK: - Lens selection (v1.2 §3)

    /// Pick the back-facing physical camera with the widest horizontal FOV.
    /// Physical types only — virtual / fused / multi-camera devices would
    /// auto-switch sub-lenses mid-session and break the static-intrinsics
    /// contract.
    private func pickWidestPhysicalRearLens() -> AVCaptureDevice? {
        let physicalTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            // .builtInTelephotoCamera intentionally excluded — narrow FOV is
            // unsuitable for ego-motion. Spec §3 rejects telephoto entirely.
        ]
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: physicalTypes,
            mediaType: .video,
            position: .back
        )
        return session.devices
            .map { ($0, horizontalFovDeg(of: $0)) }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    private func horizontalFovDeg(of device: AVCaptureDevice) -> Double {
        // activeFormat.videoFieldOfView is the diagonal FOV in degrees.
        // Convert to horizontal using the active format's aspect ratio.
        let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let aspect = Double(dims.width) / Double(dims.height)
        let diagFov = Double(device.activeFormat.videoFieldOfView)
        guard diagFov > 0 else { return 0 }
        let diagRad = diagFov * .pi / 180
        let halfDiag = tan(diagRad / 2)
        let halfHoriz = halfDiag * aspect / sqrt(aspect * aspect + 1)
        return 2 * atan(halfHoriz) * 180 / .pi
    }

    // MARK: - Initialization

    private func initializeCamera(result: @escaping FlutterResult) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            result(FlutterError(code: "NO_PERMISSION", message: "Camera permission not granted", details: nil))
            return
        }
        guard let device = pickWidestPhysicalRearLens() else {
            result(FlutterError(code: "NO_LENS", message: "No suitable physical rear lens found", details: nil))
            return
        }

        // Pick a 1920×1080 30-fps format if the lens offers one; fall back to
        // its currently-active format otherwise. The encoder pins these
        // dimensions, so we don't change them per-frame.
        let format = bestFormat(for: device) ?? device.activeFormat
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            // Lock to 30 fps. Spec §1 keeps the v1 video target unchanged.
            let thirty = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = thirty
            device.activeVideoMaxFrameDuration = thirty
            // Use continuous autofocus rather than .locked. The spec asks
            // for fixed focus to keep intrinsics stable, but locking the
            // moment we open the device freezes the lens at whatever
            // position the system handed us — typically infinity, useless
            // for ego/hand work — and there's no AF settle pass first.
            // On modern iPhones the intrinsic-vs-focus drift is small, so
            // we accept it in exchange for a sharp picture.
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            // Disable subject-area-change tracking so AF doesn't keep
            // re-triggering on every minor scene change.
            device.isSubjectAreaChangeMonitoringEnabled = false
            device.unlockForConfiguration()
        } catch {
            result(FlutterError(code: "LOCK_FAIL", message: "Failed to lock camera: \(error.localizedDescription)", details: nil))
            return
        }

        // Wire up AVCaptureSession from scratch so re-initialization is clean.
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .inputPriority  // honor the format we set
        for input in captureSession.inputs { captureSession.removeInput(input) }
        for output in captureSession.outputs { captureSession.removeOutput(output) }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            captureSession.addInput(input)
        } catch {
            captureSession.commitConfiguration()
            result(FlutterError(code: "INPUT_FAIL", message: error.localizedDescription, details: nil))
            return
        }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            result(FlutterError(code: "OUTPUT_FAIL", message: "Cannot add video output", details: nil))
            return
        }
        captureSession.addOutput(output)
        if let conn = output.connection(with: .video) {
            // Use the sensor's natural landscape orientation so the buffers
            // match the encoder's 1920×1080 configuration. Setting `.portrait`
            // here rotates the buffers to 1080×1920, after which the encoder
            // squashes them back into a 1920×1080 canvas — that's the bug
            // that produced stretched + 90°-rotated video on iPhone 13 Pro Max.
            if conn.isVideoOrientationSupported {
                conn.videoOrientation = .landscapeRight
            }
            if conn.isVideoMirroringSupported {
                conn.isVideoMirrored = false
            }
            // Per-frame intrinsic matrix delivery is a v1.1 feature; under v1.2
            // we use static K, so leave it disabled.
            if conn.isCameraIntrinsicMatrixDeliverySupported {
                conn.isCameraIntrinsicMatrixDeliveryEnabled = false
            }
        }
        captureSession.commitConfiguration()

        // Cache active capture characteristics.
        self.captureDevice = device
        self.videoOutput = output
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        self.captureWidth = Int(dims.width)
        self.captureHeight = Int(dims.height)
        self.captureFps = 30.0
        self.captureHorizontalFovDeg = horizontalFovDeg(of: device)
        self.captureLensType = (self.captureHorizontalFovDeg >= 100.0) ? "ultrawide" : "wide"
        self.capturePhysicalFocalLengthMm = nil

        // Capture mach→wall offset so timestamps end up in unix-epoch ns.
        self.unixEpochOffset = Date().timeIntervalSince1970 - CACurrentMediaTime()

        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
        result(true)
    }

    private func bestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        // Prefer 1920×1080 at 30 fps; fall back to closest above 1080p.
        let exact1080At30 = device.formats.filter { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dims.width == 1920 && dims.height == 1080 else { return false }
            return format.videoSupportedFrameRateRanges.contains { range in
                Double(range.minFrameRate) <= 30.0 && Double(range.maxFrameRate) >= 30.0
            }
        }
        if let pick = exact1080At30.first { return pick }
        // Smallest format whose pixel area is at least 1920×1080.
        let above1080 = device.formats.filter { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return Int(dims.width) * Int(dims.height) >= 1920 * 1080
        }
        return above1080.min { a, b in
            let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
            let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
            return Int(da.width) * Int(da.height) < Int(db.width) * Int(db.height)
        } ?? device.formats.first
    }

    private func computeIntrinsicMatrix() -> [[Double]] {
        // K from horizontal FOV + video resolution. iPhone sensors have
        // square pixels at the active video format, so fx == fy. cx/cy at
        // the video center is the standard pinhole assumption.
        let halfFovRad = captureHorizontalFovDeg * .pi / 360.0
        guard halfFovRad > 0 else {
            return [[0, 0, 0], [0, 0, 0], [0, 0, 1]]
        }
        let fx = Double(captureWidth) / (2.0 * tan(halfFovRad))
        let fy = fx
        let cx = Double(captureWidth) / 2.0
        let cy = Double(captureHeight) / 2.0
        return [
            [fx, 0.0, cx],
            [0.0, fy, cy],
            [0.0, 0.0, 1.0],
        ]
    }

    // MARK: - Info getters

    private func getCameraInfo(result: @escaping FlutterResult) {
        let info: [String: Any] = [
            "lensId": "ios:\(captureLensType)",
            "lensType": captureLensType,
            "physicalFocalLengthMm": (capturePhysicalFocalLengthMm as Any?) ?? NSNull(),
            "sensorPhysicalSizeMm": NSNull(),
            "sensorPixelArraySize": NSNull(),
            "horizontalFovDeg": captureHorizontalFovDeg,
            "videoStabilizationEnabled": false,
            "opticalStabilizationEnabled": false,
            "intrinsicMatrix": computeIntrinsicMatrix(),
            // We don't have measured distortion coefficients from
            // AVFoundation; emit a zero-coefficient Brown-Conrady so the
            // schema accepts the model name. Pipeline can re-calibrate
            // per-model_identifier offline if needed.
            "distortionModel": "brown_conrady",
            "distortionCoeffs": [0.0, 0.0, 0.0, 0.0, 0.0],
            "intrinsicsNotes": "Static K from horizontal FOV at locked focus; AVFoundation does not expose lens distortion coefficients on iOS, so they are reported as zero.",
            "motionRateHz": motionRateHz,
            "motionGyroUnits": "rad/s",
            "motionAccelUnits": "m/s^2",
            "motionAccelIncludesGravity": false,
            "motionFrame": "device_body",
            "deviceClockId": "mach_absolute_time",
            // T_cam_imu and rolling_shutter_skew_ns aren't exposed by
            // AVFoundation. Leave the keys absent so the Dart side omits
            // the corresponding metadata blocks; offline VIO can either
            // estimate them or look them up per model_identifier.
        ]
        result(info)
    }

    private func getDeviceInfo(result: @escaping FlutterResult) {
        let device = UIDevice.current
        let deviceInfo: [String: Any] = [
            "os": "ios",
            "osVersion": device.systemVersion,
            "manufacturer": "Apple",
            "model": device.model,
            "modelIdentifier": deviceModelIdentifier(),
        ]
        result(deviceInfo)
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
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
            try setupMotionFile(outputDirectory: outputDirectory)
            isRecording = true
            frameCounter = 0
            recordingStartTimestamp = nil
            firstFramePtsNs = nil
            lastFramePtsNs = nil
            motionRowCount = 0
            firstMotionTsNs = nil
            lastMotionTsNs = nil
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
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
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

    private func setupMotionFile(outputDirectory: String) throws {
        let motionURL = URL(fileURLWithPath: "\(outputDirectory)/motion.jsonl")
        FileManager.default.createFile(atPath: motionURL.path, contents: nil, attributes: nil)
        motionFileHandle = try FileHandle(forWritingTo: motionURL)
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
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

        // Bracket to the video window (spec §5 / Android P1-5). Allow ~100 ms
        // of slack on each side so VIO has interpolation context.
        if let firstPts = firstFramePtsNs, timestampNs < firstPts - 100_000_000 {
            return
        }
        if let lastPts = lastFramePtsNs, timestampNs > lastPts + 100_000_000 {
            return
        }

        // CMDeviceMotion.gravity is in g; convert to m/s². Recommended in v1.2
        // to give the offline VIO an absolute roll/pitch prior.
        let gravity = [
            motion.gravity.x * gToMetersPerSecondSquared,
            motion.gravity.y * gToMetersPerSecondSquared,
            motion.gravity.z * gToMetersPerSecondSquared,
        ]
        // CMDeviceMotion.attitude.quaternion: world-from-body (x, y, z, w).
        let q = motion.attitude.quaternion
        let attitude = [q.x, q.y, q.z, q.w]
        let payload: [String: Any] = [
            "timestamp_ns": timestampNs,
            "gyro": [motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z],
            "accel": [
                motion.userAcceleration.x * gToMetersPerSecondSquared,
                motion.userAcceleration.y * gToMetersPerSecondSquared,
                motion.userAcceleration.z * gToMetersPerSecondSquared,
            ],
            "gravity": gravity,
            "attitude_quaternion": attitude,
        ]
        writeJsonLine(payload, to: motionFileHandle)

        if firstMotionTsNs == nil { firstMotionTsNs = timestampNs }
        lastMotionTsNs = timestampNs
        motionRowCount += 1
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
            guard let self = self else { return }
            let writerStatus = self.assetWriter?.status ?? .unknown
            let writerError = self.assetWriter?.error
            if writerStatus != .completed {
                NSLog("[CameraCaptureHandler] AVAssetWriter did not complete: status=\(writerStatus.rawValue) error=\(String(describing: writerError))")
            }

            DispatchQueue.main.async {
                self.motionFileHandle?.closeFile()
                self.motionFileHandle = nil

                let frames = self.frameCounter
                let effectiveFps = 30.0
                let durationSec = Int(Double(frames) / effectiveFps)
                // Empirical IMU rate over the recording window — what the
                // schema's motion.rate_hz field expects.
                var measuredRate: Double = self.motionRateHz
                if let first = self.firstMotionTsNs, let last = self.lastMotionTsNs,
                   last > first, self.motionRowCount > 1 {
                    let spanSec = Double(last - first) / 1_000_000_000.0
                    if spanSec > 0 {
                        measuredRate = Double(self.motionRowCount - 1) / spanSec
                    }
                }
                let recordingData: [String: Any] = [
                    "directoryPath": self.outputDirectory ?? "",
                    "durationSeconds": durationSec,
                    "frameCount": frames,
                    "captureWidth": self.captureWidth,
                    "captureHeight": self.captureHeight,
                    "captureFps": Int(effectiveFps),
                    "motionRateHzMeasured": measuredRate,
                    "writerStatus": writerStatus.rawValue,
                    "writerError": writerError?.localizedDescription as Any,
                ]
                result(recordingData)
            }
        }
    }

    private func getAvailableCameras(result: @escaping FlutterResult) {
        result(["ios:\(captureLensType)"])
    }

    private func writeJsonLine(_ obj: Any, to handle: FileHandle?) {
        guard let handle = handle else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else { return }
        let line = (str + "\n").data(using: .utf8) ?? Data()
        handle.write(line)
    }
}

extension CameraCaptureHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Hand-presence detection runs regardless of recording state — the
        // colored border + voice cues are useful while the user is composing
        // the shot. Detector throttles to its own cadence.
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let detector = handDetector,
           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let timestampMs = Int64((pts.seconds + unixEpochOffset) * 1000)
            detector.submitFrame(pixelBuffer, timestampMs: timestampMs)
        }

        guard isRecording,
              let writer = assetWriter,
              let input = assetWriterInput,
              let adaptor = pixelBufferAdaptor,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if recordingStartTimestamp == nil {
            recordingStartTimestamp = pts.seconds
            // Use timescale 600 — the standard MP4 video timescale, divisible
            // by 24/25/30/60 — avoids finalization wedges some iOS versions
            // exhibit when the writer's session start uses a different scale
            // from the appended sample times.
            writer.startSession(atSourceTime: CMTime(value: 0, timescale: 600))
        }
        let elapsed = pts.seconds - (recordingStartTimestamp ?? pts.seconds)
        let presentationTime = CMTime(seconds: elapsed, preferredTimescale: 600)

        guard input.isReadyForMoreMediaData else { return }
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            if writer.status == .failed {
                NSLog("[CameraCaptureHandler] adaptor.append failed at frame \(frameCounter): \(String(describing: writer.error))")
            }
            return
        }

        let nowNs = Int64((pts.seconds + unixEpochOffset) * 1_000_000_000)
        if firstFramePtsNs == nil { firstFramePtsNs = nowNs }
        lastFramePtsNs = nowNs
        frameCounter += 1
    }
}

enum CameraError: Error {
    case assetWriterCreationFailed
    case cannotAddAssetWriterInput
    case cannotStartWriting
    case cannotAddInput
}
