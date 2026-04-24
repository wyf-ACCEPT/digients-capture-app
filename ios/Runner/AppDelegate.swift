import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "digients_app/camera", binaryMessenger: controller.binaryMessenger)

    let cameraHandler = CameraCaptureHandler(channel: channel)
    channel.setMethodCallHandler(cameraHandler.handle)

    let previewFactory = CameraPreviewFactory(cameraHandler: cameraHandler)
    registrar(forPlugin: "camera-preview")?.register(previewFactory, withId: "digients_app/camera_preview")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
