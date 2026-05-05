package com.digients.capture

import android.view.KeyEvent
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

    // Volume-button presses are forwarded to Flutter via this channel
    // (Android-only). flutter_volume_controller's settings-observer path
    // doesn't catch every stream the OS routes vol+/vol- through on every
    // device — intercepting the actual KeyEvents in dispatchKeyEvent is
    // the reliable fallback.
    private var volButtonChannel: EventChannel? = null
    private var volButtonSink: EventChannel.EventSink? = null

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

        // Volume-button event channel. The Dart side enables it from the
        // armed/recording phases of the record screen and ignores events
        // outside those phases.
        volButtonChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "digients_app/vol_button",
        ).also { ch ->
            ch.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volButtonSink = events
                }
                override fun onCancel(arguments: Any?) { volButtonSink = null }
            })
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Intercept Vol+/Vol- so the system's media-volume HUD doesn't
        // pop up while the user is wearing the phone. Forward a single
        // event per ACTION_DOWN to Flutter, suppress repeats, and consume
        // the event so Android doesn't also adjust volume.
        if (event.action == KeyEvent.ACTION_DOWN &&
            event.repeatCount == 0 &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            val sink = volButtonSink
            if (sink != null) {
                sink.success(if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down")
                return true
            }
        }
        // Suppress the system handling for ACTION_UP too while the channel
        // is active, otherwise Android still beeps + ticks volume on
        // release. When no listener is attached we let the OS handle the
        // event normally.
        if (volButtonSink != null &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        handDetector?.shutdown()
        handDetector = null
        handEventChannel = null
        handControlChannel = null
        volButtonChannel = null
        volButtonSink = null
        super.onDestroy()
    }
}
