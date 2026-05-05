import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Strong references — these need to outlive `application(_:...)`. The
  // FlutterEventChannel / MethodChannel wrappers do not always retain their
  // handlers indirectly, so the AppDelegate keeps them alive.
  private var handDetector: HandPresenceDetector?
  private var handEventChannel: FlutterEventChannel?
  private var handControlChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger

    let cameraChannel = FlutterMethodChannel(name: "digients_app/camera", binaryMessenger: messenger)
    let cameraHandler = CameraCaptureHandler(channel: cameraChannel)
    cameraChannel.setMethodCallHandler(cameraHandler.handle)

    let previewFactory = CameraPreviewFactory(cameraHandler: cameraHandler)
    registrar(forPlugin: "camera-preview")?.register(previewFactory, withId: "digients_app/camera_preview")

    // Hand-presence detection (V2 addendum). Plugin registration must happen
    // FIRST so flutter_secure_storage and other Swift plugins finish their
    // class initialization before we start touching MediaPipe types.
    GeneratedPluginRegistrant.register(with: self)

    let detector = HandPresenceDetector()
    detector.loadModel()
    self.handDetector = detector
    cameraHandler.handDetector = detector

    let handEvents = FlutterEventChannel(name: "hand_presence/events", binaryMessenger: messenger)
    handEvents.setStreamHandler(detector)
    self.handEventChannel = handEvents

    let handControl = FlutterMethodChannel(name: "hand_presence/control", binaryMessenger: messenger)
    handControl.setMethodCallHandler { [weak detector] call, result in
      switch call.method {
      case "setTargetFps":
        if let fps = call.arguments as? Double {
          detector?.setTargetFPS(fps)
          result(true)
        } else {
          result(FlutterError(code: "bad_args", message: "expected Double", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.handControlChannel = handControl

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
