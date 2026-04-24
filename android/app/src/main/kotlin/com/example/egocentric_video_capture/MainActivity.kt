package com.example.egocentric_video_capture

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the camera capture handler plugin
        flutterEngine.plugins.add(CameraCaptureHandler())
    }

    override fun onDestroy() {
        super.onDestroy()

        // Cleanup camera resources
        flutterEngine?.plugins?.get(CameraCaptureHandler::class.java)?.let { plugin ->
            (plugin as? CameraCaptureHandler)?.cleanup()
        }
    }
}
