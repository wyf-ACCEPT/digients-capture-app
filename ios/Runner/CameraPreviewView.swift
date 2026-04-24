import Flutter
import UIKit
import AVFoundation

final class PreviewContainerView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    init(session: AVCaptureSession?) {
        super.init(frame: .zero)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.session = session
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

final class CameraPreviewView: NSObject, FlutterPlatformView {
    private let containerView: PreviewContainerView

    init(session: AVCaptureSession?) {
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
        return CameraPreviewView(session: cameraHandler?.captureSession)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
