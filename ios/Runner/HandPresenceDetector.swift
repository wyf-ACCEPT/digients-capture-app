import Foundation
import Flutter
import AVFoundation
import CoreImage
import UIKit
import MediaPipeTasksVision

/// Wraps MediaPipe HandLandmarker on iOS and forwards detection summaries
/// to the Dart side over a Flutter EventChannel.
///
/// Frame source is not owned here — the existing `CameraCaptureHandler` taps
/// `ARSession.didUpdate` and calls `submitFrame(_:timestampMs:)` on this
/// detector. We throttle internally so the heavy `detect` call only runs at
/// `targetFPS` regardless of how fast frames arrive.
class HandPresenceDetector: NSObject, FlutterStreamHandler {

    /// Default detector cadence (§6.3 of the addendum).
    private(set) var targetFPS: Double = 10.0

    private var landmarker: HandLandmarker?
    private var eventSink: FlutterEventSink?

    private let processingQueue = DispatchQueue(
        label: "com.digients.capture.handpresence",
        qos: .userInitiated
    )

    /// Reused across frames — CIContext creation is expensive so we keep one.
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
    ])

    /// Last time we ran inference (in seconds, monotonic). Used for throttling.
    private var lastProcessedAt: TimeInterval = 0
    /// Set when a frame is in flight; we drop newer frames until it returns.
    private var inFlight = false

    private var modelPath: String?

    // Debug counters — surfaced via NSLog every N submissions so we can see
    // pipeline progress in `flutter run` output.
    private var submitsTotal = 0
    private var submitsRan = 0
    private var emits = 0

    override init() {
        super.init()
    }

    /// Resolve the bundled MediaPipe model and warm up the landmarker.
    /// Called from main thread after Flutter engine is up. Heavy work runs on
    /// the processing queue so app launch is not blocked.
    func loadModel() {
        guard let key = (FlutterDartProject.lookupKey(forAsset: "assets/models/hand_landmarker.task") as String?),
              let path = Bundle.main.path(forResource: key, ofType: nil) else {
            NSLog("[HandPresence] hand_landmarker.task not found in bundle; detector disabled")
            return
        }
        self.modelPath = path

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let options = HandLandmarkerOptions()
                options.baseOptions.modelAssetPath = path
                options.runningMode = .image
                options.numHands = 2
                // Loosened during bring-up so we can see whether MediaPipe is
                // detecting anything at all. Tighten back to 0.5 once the
                // pipeline is confirmed working end-to-end.
                options.minHandDetectionConfidence = 0.2
                options.minHandPresenceConfidence = 0.2
                options.minTrackingConfidence = 0.2
                self.landmarker = try HandLandmarker(options: options)
                NSLog("[HandPresence] model loaded from \(path)")
            } catch {
                NSLog("[HandPresence] failed to load model: \(error)")
            }
        }
    }

    /// Update detector cadence (§6.5 low-end fallback).
    func setTargetFPS(_ fps: Double) {
        processingQueue.async { [weak self] in
            self?.targetFPS = max(1.0, min(30.0, fps))
        }
    }

    /// Called from `ARSessionDelegate.didUpdate` on the AR session's queue.
    /// We hop to our own queue and only process if (a) enough time has
    /// elapsed since the last inference and (b) no other frame is in flight.
    func submitFrame(_ pixelBuffer: CVPixelBuffer, timestampMs: Int64) {
        let now = CACurrentMediaTime()
        let interval = 1.0 / max(targetFPS, 1.0)

        submitsTotal += 1

        // Quick reject — avoid heavy work on dropped frames.
        if inFlight { return }
        if now - lastProcessedAt < interval { return }

        // ARKit's `frame.capturedImage` is YUV (NV12 / 420 BiPlanar). MediaPipe's
        // MPImage(pixelBuffer:) only accepts BGRA-style pixel formats, and the
        // underlying IOSurface is recycled by ARKit between frames — so we
        // snapshot to a UIImage on the camera thread before doing anything
        // async. Orientation `.right` tells MediaPipe to treat the captured
        // image as needing a 90° CW correction (rear camera on iPhone in
        // portrait — sensor rows run along the device's vertical axis).
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)

        inFlight = true
        lastProcessedAt = now
        submitsRan += 1

        processingQueue.async { [weak self] in
            defer { self?.inFlight = false }
            guard let self = self, let landmarker = self.landmarker else { return }

            do {
                let mpImage = try MPImage(uiImage: uiImage)
                let result = try landmarker.detect(image: mpImage)
                self.emit(result: result, timestampMs: timestampMs)
            } catch {
                NSLog("[HandPresence] detect() failed: \(error)")
                self.lastDetectError = "\(error)"
                self.emitError(timestampMs: timestampMs)
            }
        }
    }

    /// Stringified last-detect error, for surfacing in the debug overlay.
    var lastDetectError: String?

    private func emit(result: HandLandmarkerResult, timestampMs: Int64) {
        emits += 1
        if emits <= 3 || emits % 30 == 0 {
            NSLog("[HandPresence] emit#\(emits) handedness=\(result.handedness.count) landmarks=\(result.landmarks.count) sink=\(eventSink != nil)")
        }
        guard let sink = self.eventSink else { return }

        // Build the per-hand summary the Dart side expects: handedness +
        // score + bbox center derived from landmark extents.
        var hands: [[String: Any]] = []
        let count = min(result.handedness.count, result.landmarks.count)
        for i in 0..<count {
            guard let topCategory = result.handedness[i].first else { continue }
            let landmarks = result.landmarks[i]
            if landmarks.isEmpty { continue }

            var minX: Float = 1.0
            var minY: Float = 1.0
            var maxX: Float = 0.0
            var maxY: Float = 0.0
            for p in landmarks {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            let cx = (minX + maxX) * 0.5
            let cy = (minY + maxY) * 0.5

            // MediaPipe's handedness category for a *rear-facing* camera is
            // anatomical (the person's actual left/right). Spec §3.3 expects
            // anatomical labels — pass through as-is.
            let isLeft = topCategory.categoryName?.lowercased() == "left"

            hands.append([
                "isLeftHand": isLeft,
                "score": Double(topCategory.score),
                "bboxCenterX": Double(cx),
                "bboxCenterY": Double(cy),
            ])
        }

        let event: [String: Any] = [
            "type": "tick",
            "timestampMs": timestampMs,
            "hands": hands,
            "rawHandCount": result.handedness.count,
            "rawLandmarkCount": result.landmarks.count,
            "modelLoaded": true,
        ]

        DispatchQueue.main.async {
            sink(event)
        }
    }

    private func emitError(timestampMs: Int64) {
        guard let sink = self.eventSink else { return }
        let event: [String: Any] = [
            "type": "tick",
            "timestampMs": timestampMs,
            "hands": [],
            "detectorError": true,
            "modelLoaded": landmarker != nil,
            "errorMsg": lastDetectError ?? "",
        ]
        DispatchQueue.main.async { sink(event) }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
