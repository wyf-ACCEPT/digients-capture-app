import Foundation
import AVFoundation
import Flutter
import UIKit
import CoreMotion

class CameraCaptureHandler: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var isRecording = false
    private var recordingStartTime: CMTime?
    private var outputDirectory: String?
    private var sessionId: String?
    private var frameCounter = 0
    private var framesFileHandle: FileHandle?

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "egocentric_video_capture/camera", binaryMessenger: registrar.messenger())
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
            if let args = call.arguments as? [String: Any] {
                switchCamera(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }

    private func initializeCamera(result: @escaping FlutterResult) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            result(FlutterError(code: "NO_PERMISSION", message: "Camera permission not granted", details: nil))
            return
        }

        do {
            try setupCaptureSession()
            result(true)
        } catch {
            result(FlutterError(code: "INIT_FAILED", message: "Failed to initialize camera: \(error.localizedDescription)", details: nil))
        }
    }

    private func setupCaptureSession() throws {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { throw CameraError.sessionCreationFailed }

        captureSession.sessionPreset = .hd1920x1080

        // Find the best camera (ultrawide preferred, then wide)
        currentDevice = findBestCamera()
        guard let device = currentDevice else { throw CameraError.noCameraFound }

        // Configure device
        try device.lockForConfiguration()

        // Disable video stabilization
        if device.activeFormat.isVideoStabilizationModeSupported(.off) {
            device.activeVideoStabilizationMode = .off
        }

        // Set focus mode
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        // Set frame rate to 30fps
        let targetFrameRate: Double = 30
        let frameRateRange = device.activeFormat.videoSupportedFrameRateRanges.first { range in
            range.minFrameRate <= targetFrameRate && range.maxFrameRate >= targetFrameRate
        }

        if let range = frameRateRange {
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(targetFrameRate))
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(targetFrameRate))
        }

        device.unlockForConfiguration()

        // Create input
        currentInput = try AVCaptureDeviceInput(device: device)
        guard let input = currentInput else { throw CameraError.inputCreationFailed }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.cannotAddInput
        }

        // Create video output
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput else { throw CameraError.outputCreationFailed }

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]

        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            throw CameraError.cannotAddOutput
        }

        // Configure connection for intrinsics
        if let connection = videoOutput.connection(with: .video) {
            connection.preferredVideoStabilizationMode = .off

            if connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
    }

    private func findBestCamera() -> AVCaptureDevice? {
        // Prefer ultrawide camera
        if let ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return ultraWideDevice
        }

        // Fall back to wide camera
        if let wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return wideDevice
        }

        return nil
    }

    private func getCameraInfo(result: @escaping FlutterResult) {
        guard let device = currentDevice else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera initialized", details: nil))
            return
        }

        let lensType: String
        switch device.deviceType {
        case .builtInUltraWideCamera:
            lensType = "ultrawide"
        case .builtInWideAngleCamera:
            lensType = "wide"
        case .builtInTelephotoCamera:
            lensType = "telephoto"
        default:
            lensType = "unknown"
        }

        let fov = calculateHorizontalFOV(device: device)

        let cameraInfo: [String: Any] = [
            "lensId": device.uniqueID,
            "lensType": lensType,
            "physicalFocalLengthMm": nil, // iOS doesn't expose this easily
            "sensorPhysicalSizeMm": nil,  // iOS doesn't expose this
            "sensorPixelArraySize": nil,  // iOS doesn't expose this
            "horizontalFovDeg": fov,
            "videoStabilizationEnabled": false,
            "opticalStabilizationEnabled": false
        ]

        result(cameraInfo)
    }

    private func calculateHorizontalFOV(device: AVCaptureDevice) -> Double {
        // This is an approximation - iOS doesn't provide easy access to exact FOV
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return 120.0
        case .builtInWideAngleCamera:
            return 78.0
        case .builtInTelephotoCamera:
            return 48.0
        default:
            return 78.0
        }
    }

    private func getDeviceInfo(result: @escaping FlutterResult) {
        let device = UIDevice.current

        let deviceInfo: [String: Any] = [
            "os": "ios",
            "osVersion": device.systemVersion,
            "manufacturer": "Apple",
            "model": device.model,
            "modelIdentifier": deviceModelIdentifier()
        ]

        result(deviceInfo)
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }

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
            try setupFramesFile(outputDirectory: outputDirectory)

            isRecording = true
            frameCounter = 0
            recordingStartTime = nil

            captureSession?.startRunning()

            result(true)
        } catch {
            result(FlutterError(code: "START_FAILED", message: "Failed to start recording: \(error.localizedDescription)", details: nil))
        }
    }

    private func setupAssetWriter(outputDirectory: String) throws {
        let videoURL = URL(fileURLWithPath: "\(outputDirectory)/video.mp4")

        assetWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        guard let assetWriter = assetWriter else { throw CameraError.assetWriterCreationFailed }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 15_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
            ]
        ]

        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        guard let assetWriterInput = assetWriterInput else { throw CameraError.assetWriterInputCreationFailed }

        assetWriterInput.expectsMediaDataInRealTime = true

        if assetWriter.canAdd(assetWriterInput) {
            assetWriter.add(assetWriterInput)
        } else {
            throw CameraError.cannotAddAssetWriterInput
        }

        if !assetWriter.startWriting() {
            throw CameraError.cannotStartWriting
        }
    }

    private func setupFramesFile(outputDirectory: String) throws {
        let framesURL = URL(fileURLWithPath: "\(outputDirectory)/frames.jsonl")

        // Create empty file
        FileManager.default.createFile(atPath: framesURL.path, contents: nil, attributes: nil)

        framesFileHandle = try FileHandle(forWritingTo: framesURL)
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard isRecording else {
            result(FlutterError(code: "NOT_RECORDING", message: "Not currently recording", details: nil))
            return
        }

        isRecording = false
        captureSession?.stopRunning()

        assetWriterInput?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                self?.framesFileHandle?.closeFile()
                self?.framesFileHandle = nil

                let recordingData: [String: Any] = [
                    "directoryPath": self?.outputDirectory ?? "",
                    "durationSeconds": self?.frameCounter ?? 0 / 30, // Approximate duration
                    "frameCount": self?.frameCounter ?? 0
                ]

                result(recordingData)
            }
        }
    }

    private func getAvailableCameras(result: @escaping FlutterResult) {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )

        let cameras = discoverySession.devices.map { $0.uniqueID }
        result(cameras)
    }

    private func switchCamera(args: [String: Any], result: @escaping FlutterResult) {
        guard let cameraId = args["cameraId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing cameraId", details: nil))
            return
        }

        guard !isRecording else {
            result(FlutterError(code: "RECORDING", message: "Cannot switch camera while recording", details: nil))
            return
        }

        // Implementation would switch to the specified camera
        // For now, just return success
        result(true)
    }
}

extension CameraCaptureHandler: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }

        // Start asset writer session on first frame
        if recordingStartTime == nil {
            recordingStartTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter?.startSession(atSourceTime: recordingStartTime!)
        }

        // Write video frame
        if assetWriterInput?.isReadyForMoreMediaData == true {
            assetWriterInput?.append(sampleBuffer)
        }

        // Extract intrinsics if available
        if let intrinsicMatrix = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data {
            writeFrameIntrinsics(sampleBuffer: sampleBuffer, intrinsicMatrix: intrinsicMatrix)
        }

        frameCounter += 1
    }

    private func writeFrameIntrinsics(sampleBuffer: CMSampleBuffer, intrinsicMatrix: Data) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampNs = Int64(timestamp.seconds * 1_000_000_000)

        // Convert intrinsic matrix data to array
        let matrixData = intrinsicMatrix.withUnsafeBytes { bytes in
            return Array(bytes.bindMemory(to: Float32.self))
        }

        // Convert to 3x3 matrix
        let matrix: [[Double]] = [
            [Double(matrixData[0]), Double(matrixData[1]), Double(matrixData[2])],
            [Double(matrixData[3]), Double(matrixData[4]), Double(matrixData[5])],
            [Double(matrixData[6]), Double(matrixData[7]), Double(matrixData[8])]
        ]

        let frameData: [String: Any] = [
            "frame_idx": frameCounter,
            "timestamp_ns": timestampNs,
            "intrinsic_matrix": matrix,
            "lens_id": currentDevice?.uniqueID ?? ""
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: frameData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let line = jsonString + "\n"
            framesFileHandle?.write(line.data(using: .utf8) ?? Data())
        }
    }
}

enum CameraError: Error {
    case sessionCreationFailed
    case noCameraFound
    case inputCreationFailed
    case cannotAddInput
    case outputCreationFailed
    case cannotAddOutput
    case assetWriterCreationFailed
    case assetWriterInputCreationFailed
    case cannotAddAssetWriterInput
    case cannotStartWriting
}