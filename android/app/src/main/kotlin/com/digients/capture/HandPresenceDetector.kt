package com.digients.capture

import android.content.Context
import android.media.Image
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.framework.image.MediaImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native MediaPipe HandLandmarker wrapper for the V2 hand-presence layer.
 *
 * Frames are pushed in via [submitFrame] from the existing capture pipeline.
 * We throttle internally so heavy inference only runs at [targetFps]; arrival
 * rate from the camera is irrelevant. Inference runs on its own single-thread
 * executor so the camera/AR threads are never blocked.
 *
 * Detection summaries are emitted to the Flutter side over an [EventChannel]
 * named `hand_presence/events`. This class is the channel's stream handler.
 */
class HandPresenceDetector(private val context: Context) : EventChannel.StreamHandler {

    @Volatile var targetFps: Double = 10.0
        private set

    private var landmarker: HandLandmarker? = null
    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "hand-presence-inference").apply { isDaemon = true }
    }

    private val inFlight = AtomicBoolean(false)
    @Volatile private var lastInferAtNanos: Long = 0L

    /**
     * Load the MediaPipe model on the inference thread. Safe to call
     * before the EventChannel has a listener — the model just sits idle.
     */
    fun loadModel() {
        executor.submit {
            try {
                // Resolve the bundled flutter asset key. FlutterLoader maps
                // logical asset paths ("assets/models/hand_landmarker.task")
                // to the on-disk path inside the APK assets directory.
                val key = FlutterLoader().getLookupKeyForAsset(
                    "assets/models/hand_landmarker.task"
                )
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath(key)
                    .build()
                val options = HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(RunningMode.IMAGE)
                    .setNumHands(2)
                    .setMinHandDetectionConfidence(0.5f)
                    .setMinHandPresenceConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .build()
                landmarker = HandLandmarker.createFromOptions(context, options)
                Log.i(TAG, "HandLandmarker loaded from asset $key")
            } catch (t: Throwable) {
                Log.e(TAG, "HandLandmarker load failed; detector disabled", t)
            }
        }
    }

    fun setTargetFps(fps: Double) {
        targetFps = fps.coerceIn(1.0, 30.0)
    }

    /**
     * Hand the current camera frame to the detector. The caller transfers
     * ownership of [image] — we are responsible for closing it. If we are
     * throttling or another inference is in flight, we close immediately.
     */
    fun submitFrame(image: Image, timestampMs: Long) {
        val now = System.nanoTime()
        val intervalNs = (1_000_000_000.0 / targetFps).toLong()

        if (landmarker == null) {
            image.close(); return
        }
        if (inFlight.get()) {
            image.close(); return
        }
        if (now - lastInferAtNanos < intervalNs) {
            image.close(); return
        }
        if (!inFlight.compareAndSet(false, true)) {
            image.close(); return
        }
        lastInferAtNanos = now

        executor.submit {
            try {
                val mpImage: MPImage = MediaImageBuilder(image).build()
                val result = landmarker?.detect(mpImage)
                if (result != null) emitResult(result, timestampMs)
            } catch (t: Throwable) {
                Log.e(TAG, "detect() failed", t)
                emitError(timestampMs)
            } finally {
                try { image.close() } catch (_: Throwable) {}
                inFlight.set(false)
            }
        }
    }

    private fun emitResult(result: HandLandmarkerResult, timestampMs: Long) {
        val sink = eventSink ?: return
        val handednessList = result.handednesses()
        val landmarksList = result.landmarks()
        val n = minOf(handednessList.size, landmarksList.size)
        val hands = ArrayList<Map<String, Any>>(n)

        for (i in 0 until n) {
            val cats = handednessList[i]
            if (cats.isEmpty()) continue
            val top = cats[0]
            val landmarks = landmarksList[i]
            if (landmarks.isEmpty()) continue

            var minX = 1f; var minY = 1f; var maxX = 0f; var maxY = 0f
            for (p in landmarks) {
                if (p.x() < minX) minX = p.x()
                if (p.x() > maxX) maxX = p.x()
                if (p.y() < minY) minY = p.y()
                if (p.y() > maxY) maxY = p.y()
            }
            val cx = (minX + maxX) * 0.5f
            val cy = (minY + maxY) * 0.5f

            // MediaPipe returns anatomical handedness for rear cameras (which
            // we always use here per spec §3.3). Pass through verbatim.
            val isLeft = top.categoryName().equals("Left", ignoreCase = true)

            hands.add(mapOf(
                "isLeftHand" to isLeft,
                "score" to top.score().toDouble(),
                "bboxCenterX" to cx.toDouble(),
                "bboxCenterY" to cy.toDouble(),
            ))
        }

        val event = mapOf<String, Any>(
            "type" to "tick",
            "timestampMs" to timestampMs,
            "hands" to hands,
        )
        mainHandler.post { sink.success(event) }
    }

    private fun emitError(timestampMs: Long) {
        val sink = eventSink ?: return
        val event = mapOf<String, Any>(
            "type" to "tick",
            "timestampMs" to timestampMs,
            "hands" to emptyList<Any>(),
            "detectorError" to true,
        )
        mainHandler.post { sink.success(event) }
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun shutdown() {
        try { landmarker?.close() } catch (_: Throwable) {}
        landmarker = null
        executor.shutdown()
    }

    companion object {
        private const val TAG = "HandPresenceDetector"
    }
}
