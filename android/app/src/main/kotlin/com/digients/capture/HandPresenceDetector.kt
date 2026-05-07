package com.digients.capture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.FlutterInjector
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream
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
                // Resolve the bundled flutter asset key. Use the singleton
                // FlutterLoader from FlutterInjector — instantiating a new
                // FlutterLoader() leaves it uninitialized (NPE on
                // flutterAssetsDir). The injector returns the loader the
                // engine started up with.
                val key = FlutterInjector.instance().flutterLoader()
                    .getLookupKeyForAsset("assets/models/hand_landmarker.task")
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath(key)
                    .build()
                val options = HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(RunningMode.IMAGE)
                    .setNumHands(2)
                    // Lowered from 0.5 → 0.2 (matching iOS) so MediaPipe
                    // emits more raw detections; the controller layer's
                    // minScore + spatial-handedness + bbox-proximity
                    // guards then filter the actual decisions. Helps
                    // false-negative behavior reported on the 13 Pro Max
                    // ultrawide periphery; small effect on the OnePlus 5
                    // wide where confidence rarely dips this low.
                    .setMinHandDetectionConfidence(0.2f)
                    .setMinHandPresenceConfidence(0.2f)
                    .setMinTrackingConfidence(0.2f)
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
                // MediaPipe's IMAGE-mode HandLandmarker requires an RGBA
                // bitmap; raw YUV_420_888 from Camera2 ImageReader fails
                // with "Android media image must use RGBA_8888 config".
                // Convert here on the inference thread (not the camera
                // thread) so we don't slow down frame delivery.
                val bitmap = yuvImageToBitmap(image)
                if (bitmap == null) {
                    emitError(timestampMs)
                    return@submit
                }
                val mpImage: MPImage = BitmapImageBuilder(bitmap).build()
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

    /// Convert a Camera2 YUV_420_888 [Image] into an ARGB_8888 [Bitmap]
    /// via NV21 → JPEG → Bitmap. Heavy compared to a RenderScript
    /// intrinsic, but RenderScript is deprecated and the JPEG path works
    /// uniformly across vendors. At 10 fps × 640×480 the conversion
    /// runs comfortably within budget on the v1.1 reference device.
    ///
    /// Returns null on any failure (caller emits a detector_failure event).
    private fun yuvImageToBitmap(image: Image): Bitmap? {
        return try {
            val width = image.width
            val height = image.height
            val yPlane = image.planes[0]
            val uPlane = image.planes[1]
            val vPlane = image.planes[2]

            val ySize = width * height
            val uvSize = ySize / 2
            val nv21 = ByteArray(ySize + uvSize)

            // Copy Y plane respecting row stride.
            val yRowStride = yPlane.rowStride
            val yPixelStride = yPlane.pixelStride
            val yBuf = yPlane.buffer
            if (yPixelStride == 1 && yRowStride == width) {
                yBuf.get(nv21, 0, ySize)
            } else {
                var dst = 0
                val rowBuf = ByteArray(yRowStride)
                for (row in 0 until height) {
                    yBuf.position(row * yRowStride)
                    yBuf.get(rowBuf, 0, minOf(yRowStride, yBuf.remaining() + (yBuf.position() - yBuf.position())))
                    var col = 0
                    var src = 0
                    while (col < width) {
                        nv21[dst + col] = rowBuf[src]
                        src += yPixelStride
                        col++
                    }
                    dst += width
                }
            }

            // Interleave V then U into NV21 layout (VUVUVU…).
            val vRowStride = vPlane.rowStride
            val vPixelStride = vPlane.pixelStride
            val uRowStride = uPlane.rowStride
            val uPixelStride = uPlane.pixelStride
            val vBuf = vPlane.buffer
            val uBuf = uPlane.buffer
            val chromaWidth = width / 2
            val chromaHeight = height / 2
            var dst = ySize
            for (row in 0 until chromaHeight) {
                for (col in 0 until chromaWidth) {
                    val vIdx = row * vRowStride + col * vPixelStride
                    val uIdx = row * uRowStride + col * uPixelStride
                    nv21[dst++] = vBuf.get(vIdx)
                    nv21[dst++] = uBuf.get(uIdx)
                }
            }

            val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
            val baos = ByteArrayOutputStream(ySize)
            yuvImage.compressToJpeg(Rect(0, 0, width, height), 80, baos)
            val bytes = baos.toByteArray()
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (t: Throwable) {
            Log.w(TAG, "yuvImageToBitmap failed", t)
            null
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
