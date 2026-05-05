package com.digients.capture

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Strong references kept on the activity to ensure detector + channels
    // survive past configureFlutterEngine. Flutter's EventChannel/MethodChannel
    // wrappers do not always retain their handlers indirectly.
    private var handDetector: HandPresenceDetector? = null
    private var handEventChannel: EventChannel? = null
    private var handControlChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val cameraHandler = CameraCaptureHandler()
        flutterEngine.plugins.add(cameraHandler)

        // Hand-presence detection (V2 addendum). Detector is constructed up
        // front and kept alive for the engine's lifetime; the camera handler
        // pushes frames into it whenever the AR session is delivering them.
        val detector = HandPresenceDetector(applicationContext)
        detector.loadModel()
        handDetector = detector
        cameraHandler.handDetector = detector

        handEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hand_presence/events"
        ).also { it.setStreamHandler(detector) }

        handControlChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hand_presence/control"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setTargetFps" -> {
                        val fps = call.arguments as? Double
                        if (fps != null) {
                            detector.setTargetFps(fps)
                            result.success(true)
                        } else {
                            result.error("bad_args", "expected Double", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        handDetector?.shutdown()
        handDetector = null
        handEventChannel = null
        handControlChannel = null
        super.onDestroy()
    }
}
