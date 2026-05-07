import AVFoundation
import Flutter
import UIKit

/// Live preview view backed by the AVCaptureSession on the recording handler.
/// Replaces the v1.1 ARSCNView path (we no longer use ARKit under v1.2).
final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        backgroundColor = .black
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        if let conn = previewLayer.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class CameraPreviewView: NSObject, FlutterPlatformView {
    private let containerView: PreviewContainerView

    init(session: AVCaptureSession) {
        containerView = PreviewContainerView(session: session)
        super.init()
    }

    func view() -> UIView { return containerView }
}

final class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private weak var cameraHandler: CameraCaptureHandler?

    init(cameraHandler: CameraCaptureHandler) {
        self.cameraHandler = cameraHandler
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let session = cameraHandler?.captureSession ?? AVCaptureSession()
        return CameraPreviewView(session: session)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
