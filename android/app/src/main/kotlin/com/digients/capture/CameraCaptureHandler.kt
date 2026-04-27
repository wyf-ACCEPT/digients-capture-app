package com.digients.capture

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.hardware.camera2.params.StreamConfigurationMap
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Range
import android.util.Size
import android.util.SizeF
import android.view.Surface
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import kotlin.math.atan2

class CameraCaptureHandler : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        private const val CHANNEL_NAME = "digients_app/camera"
        private const val TAG = "CameraCaptureHandler"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: android.app.Activity? = null

    // Camera2 API components
    private var cameraManager: CameraManager? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var selectedCameraId: String? = null
    private var cameraCharacteristics: CameraCharacteristics? = null

    // Recording components
    private var mediaCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var encoderSurface: Surface? = null
    private var previewSurface: Surface? = null
    private var isRecording = false
    private var videoTrackIndex = -1
    private var muxerStarted = false
    private var encoderThread: Thread? = null
    private var frameCounter = 0
    private var sessionId: String? = null
    private var outputDirectory: String? = null

    // Background thread
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    // Synchronization
    private val cameraOpenCloseLock = Semaphore(1)

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        cameraManager = context?.getSystemService(Context.CAMERA_SERVICE) as? CameraManager

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "digients_app/camera_preview",
            CameraPreviewFactory(this),
        )
    }

    fun setPreviewSurface(surface: Surface?) {
        previewSurface = surface
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        cleanup()
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    private val permissionListener = PluginRegistry.RequestPermissionsResultListener { requestCode, permissions, grantResults ->
        when (requestCode) {
            CAMERA_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
                true
            }
            else -> false
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeCamera" -> initializeCamera(result)
            "requestPermissions" -> requestPermissions(result)
            "getCameraInfo" -> getCameraInfo(result)
            "getDeviceInfo" -> getDeviceInfo(result)
            "startRecording" -> {
                val args = call.arguments as? Map<String, Any>
                if (args != null) {
                    startRecording(args, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
                }
            }
            "stopRecording" -> stopRecording(result)
            "getAvailableCameras" -> getAvailableCameras(result)
            "switchCamera" -> {
                val args = call.arguments as? Map<String, Any>
                if (args != null) {
                    switchCamera(args, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val activity = this.activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        if (ActivityCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
        } else {
            pendingPermissionResult = result
            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST_CODE)
        }
    }

    private fun initializeCamera(result: MethodChannel.Result) {
        if (!hasCameraPermission()) {
            result.error("NO_PERMISSION", "Camera permission not granted", null)
            return
        }

        try {
            startBackgroundThread()
            val bestCameraId = findBestCamera()
            if (bestCameraId == null) {
                result.error("NO_CAMERA", "No suitable camera found", null)
                return
            }

            selectedCameraId = bestCameraId
            cameraCharacteristics = cameraManager?.getCameraCharacteristics(bestCameraId)

            // Close any leftover session/camera from a previous record-screen visit.
            // Re-opening an already-open camera fails on Camera2 with onError, leaving
            // cameraDevice null and the next startRecording call broken.
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null

            openCamera(bestCameraId, result)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize camera", e)
            result.error("INIT_FAILED", "Failed to initialize camera: ${e.message}", null)
        }
    }

    private fun hasCameraPermission(): Boolean {
        val context = this.context ?: return false
        return ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    private fun findBestCamera(): String? {
        val manager = cameraManager ?: return null

        var bestCameraId: String? = null
        var widestFov = 0.0

        try {
            for (cameraId in manager.cameraIdList) {
                val characteristics = manager.getCameraCharacteristics(cameraId)

                // Only consider back cameras
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing != CameraCharacteristics.LENS_FACING_BACK) continue

                // Skip logical multi-cameras
                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                if (capabilities?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA) == true) {
                    continue
                }

                // Calculate FOV
                val fov = calculateHorizontalFOV(characteristics)
                if (fov > widestFov) {
                    widestFov = fov
                    bestCameraId = cameraId
                }
            }
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Camera access exception", e)
        }

        return bestCameraId
    }

    private fun calculateHorizontalFOV(characteristics: CameraCharacteristics): Double {
        val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return 0.0
        val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS) ?: return 0.0

        if (focalLengths.isEmpty()) return 0.0

        val minFocalLength = focalLengths.minOrNull() ?: return 0.0
        val sensorWidth = sensorSize.width

        return 2.0 * atan2((sensorWidth / 2.0).toDouble(), minFocalLength.toDouble()) * 180.0 / Math.PI
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping background thread", e)
        }
    }

    private fun openCamera(cameraId: String, result: MethodChannel.Result) {
        if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
            result.error("TIMEOUT", "Time out waiting to lock camera opening.", null)
            return
        }

        try {
            if (ActivityCompat.checkSelfPermission(context!!, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                cameraOpenCloseLock.release()
                result.error("NO_PERMISSION", "Camera permission not granted", null)
                return
            }

            // Resolve the Dart future from the callback, not synchronously, so Dart
            // doesn't proceed to startRecording with cameraDevice still null.
            val replied = java.util.concurrent.atomic.AtomicBoolean(false)
            cameraManager?.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    cameraDevice = camera
                    Log.d(TAG, "Camera opened successfully")
                    if (replied.compareAndSet(false, true)) result.success(true)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    Log.w(TAG, "Camera disconnected")
                    if (replied.compareAndSet(false, true)) {
                        result.error("DISCONNECTED", "Camera disconnected", null)
                    }
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    Log.e(TAG, "Camera error: $error")
                    if (replied.compareAndSet(false, true)) {
                        result.error("CAMERA_ERROR", "Camera error: $error", null)
                    }
                }
            }, backgroundHandler)
        } catch (e: CameraAccessException) {
            cameraOpenCloseLock.release()
            result.error("CAMERA_ERROR", "Camera access exception: ${e.message}", null)
        }
    }

    private fun getCameraInfo(result: MethodChannel.Result) {
        val characteristics = cameraCharacteristics
        val cameraId = selectedCameraId

        if (characteristics == null || cameraId == null) {
            result.error("NO_CAMERA", "No camera initialized", null)
            return
        }

        try {
            val lensType = when {
                calculateHorizontalFOV(characteristics) > 100 -> "ultrawide"
                calculateHorizontalFOV(characteristics) > 50 -> "wide"
                else -> "telephoto"
            }

            val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            val pixelArraySize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)

            val intrinsicCalibration = characteristics.get(CameraCharacteristics.LENS_INTRINSIC_CALIBRATION)
            val hwLevel = characteristics.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL) ?: -1
            val hwLevelFull = hwLevel == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL ||
                hwLevel == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3

            // Static intrinsics. Vocabulary follows tools/validate_recording.py:
            //   "static"             — vendor-calibrated via LENS_INTRINSIC_CALIBRATION
            //   "estimated_fallback" — derived from focal length + sensor size
            //   "none"               — neither path produced usable values
            val intrinsicMatrix: List<List<Double>>?
            val intrinsicSource: String
            if (intrinsicCalibration != null && intrinsicCalibration.size >= 5) {
                val fx = intrinsicCalibration[0].toDouble()
                val fy = intrinsicCalibration[1].toDouble()
                val cx = intrinsicCalibration[2].toDouble()
                val cy = intrinsicCalibration[3].toDouble()
                intrinsicMatrix = listOf(
                    listOf(fx, 0.0, cx),
                    listOf(0.0, fy, cy),
                    listOf(0.0, 0.0, 1.0)
                )
                intrinsicSource = "static"
            } else {
                val focal = focalLengths?.minOrNull() ?: 0f
                if (sensorSize != null && pixelArraySize != null && focal > 0f) {
                    val fx = (focal / sensorSize.width * pixelArraySize.width).toDouble()
                    val fy = (focal / sensorSize.height * pixelArraySize.height).toDouble()
                    intrinsicMatrix = listOf(
                        listOf(fx, 0.0, 960.0),
                        listOf(0.0, fy, 540.0),
                        listOf(0.0, 0.0, 1.0)
                    )
                    intrinsicSource = "estimated_fallback"
                } else {
                    intrinsicMatrix = null
                    intrinsicSource = "none"
                }
            }

            val distortionCoeffs = characteristics.get(CameraCharacteristics.LENS_DISTORTION)
                ?.toList()?.map { it.toDouble() }

            val cameraInfo = mapOf(
                "lensId" to cameraId,
                "lensType" to lensType,
                "physicalFocalLengthMm" to focalLengths?.minOrNull(),
                "sensorPhysicalSizeMm" to sensorSize?.let { listOf(it.width, it.height) },
                "sensorPixelArraySize" to pixelArraySize?.let { listOf(it.width, it.height) },
                "horizontalFovDeg" to calculateHorizontalFOV(characteristics),
                "videoStabilizationEnabled" to false,
                "opticalStabilizationEnabled" to false,
                "intrinsicMatrix" to intrinsicMatrix,
                "intrinsicSource" to intrinsicSource,
                "distortionCoeffs" to distortionCoeffs,
                "hardwareLevelFull" to hwLevelFull
            )

            result.success(cameraInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting camera info", e)
            result.error("CAMERA_INFO_ERROR", "Error getting camera info: ${e.message}", null)
        }
    }

    private fun getDeviceInfo(result: MethodChannel.Result) {
        val deviceInfo = mapOf(
            "os" to "android",
            "osVersion" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "modelIdentifier" to "${Build.MANUFACTURER}_${Build.MODEL}"
        )

        result.success(deviceInfo)
    }

    private fun startRecording(args: Map<String, Any>, result: MethodChannel.Result) {
        if (isRecording) {
            result.error("ALREADY_RECORDING", "Already recording", null)
            return
        }

        val sessionId = args["sessionId"] as? String
        val outputDirectory = args["outputDirectory"] as? String

        if (sessionId == null || outputDirectory == null) {
            result.error("INVALID_ARGUMENTS", "Missing sessionId or outputDirectory", null)
            return
        }

        // The TextureView (CameraPreviewView) mounts asynchronously after Flutter
        // renders the AndroidView, so previewSurface may still be null when Dart
        // calls startRecording immediately after setState. Camera2 sessions are
        // immutable — if we configure now without the preview surface, recording
        // works but the preview stays black forever. Run the wait on backgroundHandler
        // so the platform thread (and Dart's await) isn't blocked.
        val mainHandler = Handler(android.os.Looper.getMainLooper())
        backgroundHandler?.post {
            val deadline = System.currentTimeMillis() + 800L
            while (previewSurface == null && System.currentTimeMillis() < deadline) {
                try {
                    Thread.sleep(20)
                } catch (e: InterruptedException) {
                    break
                }
            }
            if (previewSurface == null) {
                Log.w(TAG, "Preview surface not ready after 800ms; recording without live preview")
            }

            try {
                this@CameraCaptureHandler.sessionId = sessionId
                this@CameraCaptureHandler.outputDirectory = outputDirectory
                setupMediaCodec(outputDirectory)
                // Note: Android records static intrinsics in metadata.json (per spec).
                // No per-frame frames.jsonl — that's iOS-only via CMSampleBuffer attachments.
                isRecording = true
                frameCounter = 0
                startEncoderDrain()
                createCaptureSession()
                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start recording", e)
                mainHandler.post {
                    result.error("START_FAILED", "Failed to start recording: ${e.message}", null)
                }
            }
        }
    }

    // Drains MediaCodec's output buffers and writes them to MediaMuxer.
    // Without this, encoded frames have nowhere to go: the encoder back-pressures
    // the camera (causing preview to stall), and video.mp4 stays empty.
    private fun startEncoderDrain() {
        videoTrackIndex = -1
        muxerStarted = false
        encoderThread = Thread({
            val codec = mediaCodec ?: return@Thread
            val muxer = mediaMuxer ?: return@Thread
            val bufferInfo = MediaCodec.BufferInfo()
            try {
                while (true) {
                    val index = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
                    when {
                        index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            // No buffer ready yet — keep polling.
                        }
                        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (muxerStarted) {
                                Log.e(TAG, "Output format changed twice; dropping")
                                continue
                            }
                            videoTrackIndex = muxer.addTrack(codec.outputFormat)
                            muxer.start()
                            muxerStarted = true
                        }
                        index >= 0 -> {
                            val buffer = codec.getOutputBuffer(index)
                            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                                // Codec config (CSD) is already in MediaFormat; skip writing.
                                bufferInfo.size = 0
                            }
                            if (buffer != null && bufferInfo.size > 0 && muxerStarted) {
                                buffer.position(bufferInfo.offset)
                                buffer.limit(bufferInfo.offset + bufferInfo.size)
                                muxer.writeSampleData(videoTrackIndex, buffer, bufferInfo)
                            }
                            codec.releaseOutputBuffer(index, false)
                            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                return@Thread
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Encoder drain failed", e)
            }
        }, "encoder-drain").also { it.start() }
    }

    private fun setupMediaCodec(outputDirectory: String) {
        val videoFile = File(outputDirectory, "video.mp4")

        // Setup MediaMuxer
        mediaMuxer = MediaMuxer(videoFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        // Setup MediaCodec
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_HEVC, 1920, 1080).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 15_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_HEVC).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoderSurface = createInputSurface()
            start()
        }
    }

    private fun createCaptureSession() {
        val camera = cameraDevice ?: throw RuntimeException("Camera not available")
        val surface = encoderSurface ?: throw RuntimeException("Encoder surface not available")

        // Include the preview surface if a CameraPreviewView has handed one over.
        // Camera2 sessions are immutable, so any surface added here is fixed for the
        // session lifetime; preview attached after recording starts is unsupported.
        val preview = previewSurface
        val surfaces = if (preview != null) listOf(surface, preview) else listOf(surface)

        camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session
                startRepeatingRequest(session, surface, preview)
            }

            override fun onConfigureFailed(session: CameraCaptureSession) {
                Log.e(TAG, "Failed to configure capture session")
            }
        }, backgroundHandler)
    }

    private fun startRepeatingRequest(
        session: CameraCaptureSession,
        encoder: Surface,
        preview: Surface?,
    ) {
        val cameraId = selectedCameraId ?: return
        val characteristics = cameraCharacteristics ?: return

        val requestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)?.apply {
            addTarget(encoder)
            preview?.let { addTarget(it) }

            // Disable video stabilization
            set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
            set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_OFF)

            // Set continuous autofocus
            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)

            // Set frame rate
            val fpsRange = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                ?.find { it.contains(30) } ?: Range(30, 30)
            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange)
        }

        requestBuilder?.let { builder ->
            session.setRepeatingRequest(builder.build(), object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                    if (isRecording) {
                        frameCounter++
                    }
                }
            }, backgroundHandler)
        }
    }


    private fun stopRecording(result: MethodChannel.Result) {
        if (!isRecording) {
            result.error("NOT_RECORDING", "Not currently recording", null)
            return
        }

        try {
            isRecording = false

            // Stop the camera from sending more frames into the encoder input.
            captureSession?.stopRepeating()
            captureSession?.close()
            captureSession = null

            // Tell the encoder no more input is coming, then wait for the drain
            // thread to flush remaining frames and emit BUFFER_FLAG_END_OF_STREAM.
            try {
                mediaCodec?.signalEndOfInputStream()
            } catch (e: Exception) {
                Log.e(TAG, "signalEndOfInputStream failed", e)
            }
            encoderThread?.join(2_000L)
            encoderThread = null

            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null

            encoderSurface?.release()
            encoderSurface = null

            if (muxerStarted) {
                mediaMuxer?.stop()
            }
            mediaMuxer?.release()
            mediaMuxer = null
            muxerStarted = false
            videoTrackIndex = -1

            val recordingData = mapOf(
                "directoryPath" to (outputDirectory ?: ""),
                "durationSeconds" to (frameCounter / 30),
                "frameCount" to frameCounter
            )

            result.success(recordingData)

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
            result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null)
        }
    }

    private fun getAvailableCameras(result: MethodChannel.Result) {
        val manager = cameraManager
        if (manager == null) {
            result.success(emptyList<String>())
            return
        }

        try {
            val cameras = manager.cameraIdList.filter { cameraId ->
                val characteristics = manager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                facing == CameraCharacteristics.LENS_FACING_BACK
            }
            result.success(cameras)
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Error getting available cameras", e)
            result.error("CAMERA_ERROR", "Error getting available cameras: ${e.message}", null)
        }
    }

    private fun switchCamera(args: Map<String, Any>, result: MethodChannel.Result) {
        val cameraId = args["cameraId"] as? String
        if (cameraId == null) {
            result.error("INVALID_ARGUMENTS", "Missing cameraId", null)
            return
        }

        if (isRecording) {
            result.error("RECORDING", "Cannot switch camera while recording", null)
            return
        }

        // Implementation would switch to the specified camera
        // For now, just return success
        result.success(true)
    }

    fun cleanup() {
        if (isRecording) {
            isRecording = false
        }

        captureSession?.close()
        cameraDevice?.close()
        stopBackgroundThread()

        mediaCodec?.release()
        mediaMuxer?.release()
        encoderSurface?.release()
    }
}