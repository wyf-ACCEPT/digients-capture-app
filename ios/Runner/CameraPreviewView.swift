import ARKit
import Flutter
import SceneKit
import UIKit

// ARSCNView auto-renders the ARSession's camera background. We don't add any AR
// content — it's purely a viewfinder bound to the same ARSession that the
// recorder writes from.
final class PreviewContainerView: UIView {
    let arView = ARSCNView()

    init(session: ARSession) {
        super.init(frame: .zero)
        backgroundColor = .black
        arView.session = session
        arView.scene = SCNScene()
        arView.automaticallyUpdatesLighting = false
        arView.autoenablesDefaultLighting = false
        arView.preferredFramesPerSecond = 30
        addSubview(arView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        arView.frame = bounds
    }
}

final class CameraPreviewView: NSObject, FlutterPlatformView {
    private let containerView: PreviewContainerView

    init(session: ARSession) {
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
        let session = cameraHandler?.arSession ?? ARSession()
        return CameraPreviewView(session: session)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
