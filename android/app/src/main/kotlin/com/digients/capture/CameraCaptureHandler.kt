package com.digients.capture

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.*
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.Log
import android.util.Range
import android.view.Surface
import androidx.core.app.ActivityCompat
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Frame
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.SharedCamera
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.UnavailableException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.util.EnumSet
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.atan2

class CameraCaptureHandler : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        private const val CHANNEL_NAME = "digients_app/camera"
        private const val TAG = "CameraCaptureHandler"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
        // Recorded video dimensions — also the coordinate frame for
        // intrinsics emitted to metadata.json (per spec §6.3, fx/fy/cx/cy
        // must all be in video pixels, not sensor active-array pixels).
        private const val VIDEO_WIDTH = 1920
        private const val VIDEO_HEIGHT = 1080
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: android.app.Activity? = null

    // Hand-presence detector (V2 addendum). Set by MainActivity at engine
    // configuration time. We piggyback on the existing ARCore frame loop:
    // every Nth captureCallback we fetch the YUV image and hand it off.
    var handDetector: HandPresenceDetector? = null

    // Camera2 API components (also used in shared-camera mode with ARCore)
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
    // Authoritative count of frames actually written to the MP4 muxer. Counted
    // in the encoder-drain thread as muxer.writeSampleData runs. Used to detect
    // (and report on) any drift vs frameCounter.
    @Volatile private var encodedFrameCount = 0
    private var sessionId: String? = null
    private var outputDirectory: String? = null

    // ARCore (Shared Camera mode). Null when ARCore unavailable — we fall back
    // to the imu_raw tier per RECORDING_DATA_STRUCTURE_V1.1.md §4.
    private var arSession: Session? = null
    private var sharedCamera: SharedCamera? = null
    private var arEglHelper: ArCoreEglHelper? = null
    private var poseSource: String = "none"
    private val arSetupLatch = Object()

    // Wall-clock offset to convert SystemClock.elapsedRealtimeNanos() into Unix
    // epoch nanoseconds. Captured at session start, applied uniformly to ARCore
    // poses, frame timestamps, and IMU samples so they share one clock.
    private var unixOffsetNs: Long = 0L

    // Per-frame jsonl writers. BufferedWriter is fine — writes happen on
    // backgroundHandler at ~30 Hz.
    private var posesWriter: BufferedWriter? = null
    private var motionWriter: BufferedWriter? = null

    // IMU
    private var sensorManager: SensorManager? = null
    private var gyroSensor: Sensor? = null
    private var accelSensor: Sensor? = null
    private val latestGyro = FloatArray(3)
    private val latestAccel = FloatArray(3)
    private val haveGyro = AtomicBoolean(false)
    private val haveAccel = AtomicBoolean(false)
    private var motionRateHz: Double = 0.0
    private var lastMotionTimestampNs: Long = 0L
    private var motionSampleCount: Long = 0L

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
        sensorManager = context?.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        gyroSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

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

    private val permissionListener = PluginRegistry.RequestPermissionsResultListener { requestCode, _, grantResults ->
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
                @Suppress("UNCHECKED_CAST")
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
                @Suppress("UNCHECKED_CAST")
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

            // Try ARCore first (best tier). Falls back to imu_raw on unsupported
            // devices and to a generic Camera2 path when neither IMU nor ARCore work.
            val arCoreAvailable = tryInitArCore()
            poseSource = when {
                arCoreAvailable -> "arcore"
                gyroSensor != null && accelSensor != null -> "imu_raw"
                else -> "none"
            }

            // Camera selection: ARCore picks its own camera; otherwise pick the
            // widest-FOV rear lens (existing logic — used on the imu_raw fallback).
            val cameraId = if (arCoreAvailable) {
                arSession?.cameraConfig?.cameraId ?: findBestCamera()
            } else {
                findBestCamera()
            }
            if (cameraId == null) {
                result.error("NO_CAMERA", "No suitable camera found", null)
                return
            }

            selectedCameraId = cameraId
            cameraCharacteristics = cameraManager?.getCameraCharacteristics(cameraId)

            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null

            openCamera(cameraId, result)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize camera", e)
            result.error("INIT_FAILED", "Failed to initialize camera: ${e.message}", null)
        }
    }

    private fun tryInitArCore(): Boolean {
        val ctx = context ?: return false
        var availability = try {
            ArCoreApk.getInstance().checkAvailability(ctx)
        } catch (e: Throwable) {
            Log.w(TAG, "ArCoreApk.checkAvailability threw", e)
            return false
        }
        // checkAvailability is async on first call; poll briefly until we get
        // a stable answer rather than instantly bailing on UNKNOWN_CHECKING.
        var pollMs = 0L
        while (availability.isTransient && pollMs < 500) {
            Thread.sleep(100)
            pollMs += 100
            availability = ArCoreApk.getInstance().checkAvailability(ctx)
        }
        Log.i(TAG, "ARCore availability for ${Build.MANUFACTURER}/${Build.MODEL}: $availability")
        when (availability) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED -> Unit
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED,
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD -> {
                val activity = this.activity ?: return false
                val status = try {
                    ArCoreApk.getInstance().requestInstall(activity, true)
                } catch (e: UnavailableException) {
                    Log.w(TAG, "ARCore install request failed", e)
                    return false
                }
                Log.i(TAG, "ARCore requestInstall returned: $status")
                // When the play services prompt has just installed it inline
                // we can keep going; otherwise the next launch will pick it up.
                if (status != ArCoreApk.InstallStatus.INSTALLED) return false
            }
            ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE -> {
                Log.i(TAG, "ARCore: device not on supported-devices list — falling back to imu_raw")
                return false
            }
            else -> {
                Log.i(TAG, "ARCore: availability=$availability — falling back to imu_raw")
                return false
            }
        }

        return try {
            val session = Session(ctx, EnumSet.of(Session.Feature.SHARED_CAMERA))
            // Default config is fine — no plane detection, no light estimation.
            arSession = session
            sharedCamera = session.sharedCamera

            // EGL setup must run on the same thread that later calls session.update().
            // We pin both to backgroundHandler.
            val handler = backgroundHandler ?: error("backgroundHandler not started")
            val helper = ArCoreEglHelper()
            val ready = AtomicBoolean(false)
            val error = AtomicBoolean(false)
            handler.post {
                try {
                    helper.setupOnCurrentThread()
                    session.setCameraTextureName(helper.textureId)
                    ready.set(true)
                } catch (t: Throwable) {
                    Log.e(TAG, "ARCore EGL setup failed", t)
                    error.set(true)
                }
                synchronized(arSetupLatch) { arSetupLatch.notifyAll() }
            }
            synchronized(arSetupLatch) {
                if (!ready.get() && !error.get()) {
                    arSetupLatch.wait(2_000)
                }
            }
            if (error.get() || !ready.get()) {
                helper.release()
                session.close()
                arSession = null
                sharedCamera = null
                return false
            }
            arEglHelper = helper
            true
        } catch (e: Throwable) {
            Log.w(TAG, "ARCore session creation failed; falling back to imu_raw", e)
            arSession?.close()
            arSession = null
            sharedCamera = null
            false
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
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing != CameraCharacteristics.LENS_FACING_BACK) continue

                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                if (capabilities?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA) == true) {
                    continue
                }

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

            val replied = AtomicBoolean(false)
            val rawCallback = object : CameraDevice.StateCallback() {
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
            }
            // In Shared Camera mode, ARCore wraps the device callback so it can
            // observe open/close events that affect its internal pipeline.
            val callback = sharedCamera?.createARDeviceStateCallback(rawCallback, backgroundHandler) ?: rawCallback
            cameraManager?.openCamera(cameraId, callback, backgroundHandler)
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
            val fov = calculateHorizontalFOV(characteristics)
            val lensType = when {
                fov > 100 -> "ultrawide"
                fov > 50 -> "wide"
                else -> "telephoto"
            }

            val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            val pixelArraySize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)

            val intrinsicCalibration = characteristics.get(CameraCharacteristics.LENS_INTRINSIC_CALIBRATION)
            val hwLevel = characteristics.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL) ?: -1
            val hwLevelFull = hwLevel == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL ||
                hwLevel == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3

            // The intrinsic matrix MUST be expressed in *video* pixel coordinates
            // (1920×1080), not the full sensor active-array coordinates. Camera2's
            // LENS_INTRINSIC_CALIBRATION is in sensor pixels, and the focal-length-
            // ÷-sensor-size derivation also lands in sensor pixels. Mixing those
            // with cx/cy at the video center is the §6.3 bug — fx/fy end up
            // overestimated by the sensor-to-video ratio. Scale fx/fy/cx/cy to
            // video pixels so the implied K is internally consistent.
            val intrinsicMatrix: List<List<Double>>?
            val intrinsicSource: String
            val videoW = VIDEO_WIDTH.toDouble()
            val videoH = VIDEO_HEIGHT.toDouble()
            if (intrinsicCalibration != null && intrinsicCalibration.size >= 5 &&
                pixelArraySize != null && pixelArraySize.width > 0 && pixelArraySize.height > 0) {
                val sxW = videoW / pixelArraySize.width
                val syH = videoH / pixelArraySize.height
                val fx = intrinsicCalibration[0].toDouble() * sxW
                val fy = intrinsicCalibration[1].toDouble() * syH
                val cx = intrinsicCalibration[2].toDouble() * sxW
                val cy = intrinsicCalibration[3].toDouble() * syH
                intrinsicMatrix = listOf(
                    listOf(fx, 0.0, cx),
                    listOf(0.0, fy, cy),
                    listOf(0.0, 0.0, 1.0)
                )
                intrinsicSource = "static"
            } else {
                val focal = focalLengths?.minOrNull() ?: 0f
                if (sensorSize != null && focal > 0f) {
                    // Per spec §6.3 Option A simplified:
                    //   fx_video = focal_mm * (video.width / sensor_physical_size_mm[0])
                    val fx = (focal / sensorSize.width * videoW).toDouble()
                    val fy = (focal / sensorSize.height * videoH).toDouble()
                    intrinsicMatrix = listOf(
                        listOf(fx, 0.0, videoW / 2.0),
                        listOf(0.0, fy, videoH / 2.0),
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
                "horizontalFovDeg" to fov,
                "videoStabilizationEnabled" to false,
                "opticalStabilizationEnabled" to false,
                "intrinsicMatrix" to intrinsicMatrix,
                "intrinsicSource" to intrinsicSource,
                "distortionCoeffs" to distortionCoeffs,
                "hardwareLevelFull" to hwLevelFull,
                // v1.1 additions consumed by record_screen.dart to build metadata.json.
                "poseSource" to poseSource,
                "poseRateHz" to 30.0,
                "poseFrameOrigin" to if (poseSource == "arcore") "arcore_session" else null,
                "poseCoordinateConvention" to if (poseSource == "arcore") "right_handed_y_up_neg_z_forward" else null,
                "poseTransformKind" to if (poseSource == "arcore") "camera_to_world" else null,
                "motionRateHz" to 200.0,
                "motionGyroUnits" to "rad/s",
                "motionAccelUnits" to "m/s^2",
                "motionAccelIncludesGravity" to true,
                "motionFrame" to "device_body"
            )

            result.success(cameraInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting camera info", e)
            result.error("CAMERA_INFO_ERROR", "Error getting camera info: ${e.message}", null)
        }
    }

    private fun getDeviceInfo(result: MethodChannel.Result) {
        val ctx = context
        val arCoreAvailable = ctx?.let {
            try {
                ArCoreApk.getInstance().checkAvailability(it) == ArCoreApk.Availability.SUPPORTED_INSTALLED
            } catch (e: Throwable) {
                false
            }
        } ?: false

        val deviceInfo = mapOf(
            "os" to "android",
            "osVersion" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "modelIdentifier" to "${Build.MANUFACTURER}_${Build.MODEL}",
            "hasArkit" to false,
            "hasArcore" to arCoreAvailable
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

        val mainHandler = Handler(android.os.Looper.getMainLooper())
        backgroundHandler?.post {
            // The preview surface lands asynchronously after Flutter mounts the
            // platform view; wait briefly so we don't configure a session without it.
            val deadline = System.currentTimeMillis() + 800L
            while (previewSurface == null && System.currentTimeMillis() < deadline) {
                try { Thread.sleep(20) } catch (_: InterruptedException) { break }
            }
            if (previewSurface == null) {
                Log.w(TAG, "Preview surface not ready after 800ms; recording without live preview")
            }

            try {
                this@CameraCaptureHandler.sessionId = sessionId
                this@CameraCaptureHandler.outputDirectory = outputDirectory
                unixOffsetNs = TimeUnit.MILLISECONDS.toNanos(System.currentTimeMillis()) - SystemClock.elapsedRealtimeNanos()

                setupMediaCodec(outputDirectory)
                openJsonlWriters(outputDirectory)
                isRecording = true
                frameCounter = 0
                lastMotionTimestampNs = 0L
                motionSampleCount = 0L
                haveGyro.set(false)
                haveAccel.set(false)
                startEncoderDrain()
                startSensorUpdates()
                // ARCore's session.resume() must wait until the Camera2 capture
                // session is actually configured (StateCallback.onConfigured) —
                // calling resume earlier means ARCore starts tracking before its
                // shared surfaces are receiving frames. We move the resume into
                // onConfigured below; here we just kick off configuration.
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

    private fun openJsonlWriters(outputDirectory: String) {
        if (poseSource == "arcore") {
            val posesFile = File(outputDirectory, "poses.jsonl")
            posesWriter = BufferedWriter(FileWriter(posesFile, false))
        }
        // motion.jsonl is written whenever we have an IMU at all (the cheap
        // recovery path, per spec §4: "always record motion.jsonl if hardware allows").
        if (gyroSensor != null && accelSensor != null) {
            val motionFile = File(outputDirectory, "motion.jsonl")
            motionWriter = BufferedWriter(FileWriter(motionFile, false))
        }
    }

    private fun startEncoderDrain() {
        videoTrackIndex = -1
        muxerStarted = false
        encodedFrameCount = 0
        encoderThread = Thread({
            val codec = mediaCodec ?: return@Thread
            val muxer = mediaMuxer ?: return@Thread
            val bufferInfo = MediaCodec.BufferInfo()
            try {
                while (true) {
                    val index = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
                    when {
                        index == MediaCodec.INFO_TRY_AGAIN_LATER -> {}
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
                                bufferInfo.size = 0
                            }
                            if (buffer != null && bufferInfo.size > 0 && muxerStarted) {
                                buffer.position(bufferInfo.offset)
                                buffer.limit(bufferInfo.offset + bufferInfo.size)
                                muxer.writeSampleData(videoTrackIndex, buffer, bufferInfo)
                                encodedFrameCount++
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

        mediaMuxer = MediaMuxer(videoFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

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

        val preview = previewSurface
        val appSurfaces = mutableListOf(surface)
        preview?.let { appSurfaces.add(it) }

        // Shared Camera mode: ARCore needs its own surfaces added to the
        // capture session, and it wants to know which surfaces are app-owned.
        val sc = sharedCamera
        val cameraId = selectedCameraId
        val arSurfaces: List<Surface> = sc?.arCoreSurfaces ?: emptyList()
        if (sc != null && cameraId != null) {
            sc.setAppSurfaces(cameraId, appSurfaces)
        }
        val surfaces = appSurfaces + arSurfaces

        val rawSessionCallback = object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session
                // Now (and only now) ARCore can start tracking — its surfaces
                // are part of an active capture session and will receive frames.
                if (arSession != null && poseSource == "arcore") {
                    try {
                        arSession?.resume()
                        Log.i(TAG, "ARCore session resumed")
                    } catch (e: Throwable) {
                        Log.e(TAG, "ARCore session.resume failed; continuing without poses", e)
                        poseSource = if (gyroSensor != null && accelSensor != null) "imu_raw" else "none"
                    }
                }
                startRepeatingRequest(session, surface, preview, arSurfaces)
            }

            override fun onConfigureFailed(session: CameraCaptureSession) {
                Log.e(TAG, "Failed to configure capture session")
            }
        }
        val sessionCallback = sc?.createARSessionStateCallback(rawSessionCallback, backgroundHandler) ?: rawSessionCallback

        camera.createCaptureSession(surfaces, sessionCallback, backgroundHandler)
    }

    private fun startRepeatingRequest(
        session: CameraCaptureSession,
        encoder: Surface,
        preview: Surface?,
        arSurfaces: List<Surface>,
    ) {
        val characteristics = cameraCharacteristics ?: return

        val requestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)?.apply {
            addTarget(encoder)
            preview?.let { addTarget(it) }
            // ARCore-required surfaces must be capture-request targets so ARCore
            // receives every frame in lockstep with the encoder.
            arSurfaces.forEach { addTarget(it) }

            set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
            set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_OFF)
            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)

            val fpsRange = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                ?.find { it.contains(30) } ?: Range(30, 30)
            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange)
        }

        val captureCallback = object : CameraCaptureSession.CaptureCallback() {
            override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                val ar = arSession
                if (ar != null && poseSource == "arcore") {
                    try {
                        // Rebind EGL context for this thread on every call —
                        // cheap, idempotent, and protects against accidental
                        // context drops on some OEM stacks.
                        arEglHelper?.makeCurrent()
                        val frame = ar.update()
                        if (isRecording) {
                            writePoseLine(frame, frameCounter)
                        }
                        // Feed the hand-presence detector regardless of recording
                        // state — the border + audio cues help the user compose
                        // before pressing record. The detector throttles itself.
                        val detector = handDetector
                        if (detector != null) {
                            try {
                                val image = frame.acquireCameraImage()
                                val timestampMs =
                                    (frame.timestamp + unixOffsetNs) / 1_000_000L
                                // Ownership of `image` transfers — submitFrame
                                // calls image.close() in all paths.
                                detector.submitFrame(image, timestampMs)
                            } catch (_: com.google.ar.core.exceptions.NotYetAvailableException) {
                                // Frame not ready yet; just skip this tick.
                            } catch (t: Throwable) {
                                Log.w(TAG, "hand detector frame submit failed", t)
                            }
                        }
                    } catch (t: Throwable) {
                        Log.e(TAG, "ARCore session.update failed for frame $frameCounter", t)
                    }
                }
                if (isRecording) {
                    frameCounter++
                }
            }
        }

        requestBuilder?.let { builder ->
            session.setRepeatingRequest(builder.build(), captureCallback, backgroundHandler)
        }
    }

    private fun writePoseLine(frame: Frame, frameIdx: Int) {
        val writer = posesWriter ?: return
        val camera = frame.camera
        val pose: Pose = camera.pose
        val mat = FloatArray(16)
        // ARCore Pose.toMatrix returns column-major. Spec §5 wants row-major.
        pose.toMatrix(mat, 0)
        val rows = Array(4) { r -> DoubleArray(4) { c -> mat[c * 4 + r].toDouble() } }

        val (state, reason) = when (camera.trackingState) {
            TrackingState.TRACKING -> "normal" to null
            TrackingState.PAUSED -> "limited" to mapTrackingFailureReason(camera.trackingFailureReason)
            TrackingState.STOPPED -> "not_available" to null
            else -> "not_available" to null
        }

        // Frame timestamp is in nanoseconds in the SystemClock.elapsedRealtimeNanos
        // domain on Android; convert via the unix offset captured at start.
        val timestampNs = frame.timestamp + unixOffsetNs

        val sb = StringBuilder(256)
        sb.append('{')
        sb.append("\"frame_idx\":").append(frameIdx).append(',')
        sb.append("\"timestamp_ns\":").append(timestampNs).append(',')
        sb.append("\"transform\":[")
        for (r in 0 until 4) {
            if (r > 0) sb.append(',')
            sb.append('[')
            for (c in 0 until 4) {
                if (c > 0) sb.append(',')
                sb.append(rows[r][c])
            }
            sb.append(']')
        }
        sb.append("],\"tracking_state\":\"").append(state).append('"')
        if (reason != null) {
            sb.append(",\"tracking_state_reason\":\"").append(reason).append('"')
        }
        sb.append("}\n")
        writer.write(sb.toString())
    }

    private fun mapTrackingFailureReason(r: TrackingFailureReason?): String? = when (r) {
        TrackingFailureReason.NONE, null -> null
        TrackingFailureReason.BAD_STATE -> "bad_state"
        TrackingFailureReason.INSUFFICIENT_LIGHT -> "insufficient_light"
        TrackingFailureReason.EXCESSIVE_MOTION -> "excessive_motion"
        TrackingFailureReason.INSUFFICIENT_FEATURES -> "insufficient_features"
        TrackingFailureReason.CAMERA_UNAVAILABLE -> "camera_unavailable"
    }

    // -------- IMU (motion.jsonl) --------

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_GYROSCOPE -> {
                    System.arraycopy(event.values, 0, latestGyro, 0, 3)
                    haveGyro.set(true)
                    if (haveAccel.get()) emitMotionSample(event.timestamp)
                }
                Sensor.TYPE_ACCELEROMETER -> {
                    System.arraycopy(event.values, 0, latestAccel, 0, 3)
                    haveAccel.set(true)
                    if (haveGyro.get()) emitMotionSample(event.timestamp)
                }
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private fun emitMotionSample(sensorTimestampNs: Long) {
        if (!isRecording) return
        val writer = motionWriter ?: return
        val timestampNs = sensorTimestampNs + unixOffsetNs

        val sb = StringBuilder(160)
        sb.append('{')
        sb.append("\"timestamp_ns\":").append(timestampNs).append(',')
        sb.append("\"gyro\":[").append(latestGyro[0]).append(',')
            .append(latestGyro[1]).append(',').append(latestGyro[2]).append(']')
        sb.append(",\"accel\":[").append(latestAccel[0]).append(',')
            .append(latestAccel[1]).append(',').append(latestAccel[2]).append(']')
        sb.append("}\n")
        try {
            writer.write(sb.toString())
        } catch (e: Throwable) {
            Log.e(TAG, "motion.jsonl write failed", e)
            return
        }

        if (lastMotionTimestampNs > 0) {
            val deltaSec = (sensorTimestampNs - lastMotionTimestampNs) / 1_000_000_000.0
            if (deltaSec > 0) {
                val instantaneousHz = 1.0 / deltaSec
                // Running EMA gives us a stable rate to report in metadata.json.
                motionRateHz = if (motionRateHz == 0.0) instantaneousHz
                else 0.95 * motionRateHz + 0.05 * instantaneousHz
            }
        }
        lastMotionTimestampNs = sensorTimestampNs
        motionSampleCount += 1
    }

    private fun startSensorUpdates() {
        val sm = sensorManager ?: return
        val gyro = gyroSensor ?: return
        val accel = accelSensor ?: return
        sm.registerListener(sensorListener, gyro, SensorManager.SENSOR_DELAY_FASTEST, backgroundHandler)
        sm.registerListener(sensorListener, accel, SensorManager.SENSOR_DELAY_FASTEST, backgroundHandler)
    }

    private fun stopSensorUpdates() {
        sensorManager?.unregisterListener(sensorListener)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (!isRecording) {
            result.error("NOT_RECORDING", "Not currently recording", null)
            return
        }
        // Run the whole stop sequence on backgroundHandler so it serializes
        // with the camera capture callbacks (which also run there). This,
        // plus a short drain wait after stopRepeating, lets in-flight
        // onCaptureCompleted callbacks finish writing their pose/jsonl
        // entries before we set isRecording=false. Otherwise the encoder
        // muxes those frames but the callback skips counting them, and
        // metadata.frame_count reads 1 less than the actual MP4.
        val mainHandler = Handler(android.os.Looper.getMainLooper())
        backgroundHandler?.post {
            try {
                // 1. Stop scheduling new captures. In-flight ones still complete.
                try { captureSession?.stopRepeating() } catch (e: Throwable) {
                    Log.w(TAG, "stopRepeating failed", e)
                }

                // 2. Drain barrier: at 30 fps, capture pipeline depth is at most
                // 2-3 frames (~100 ms). Sleep 200 ms — well above that — so any
                // remaining onCaptureCompleted callbacks fire and the corresponding
                // pose/frames jsonl writes complete *before* we tear ARCore down.
                Thread.sleep(200)

                // 3. Past this point no more poses should be written.
                isRecording = false
                stopSensorUpdates()
                try { arSession?.pause() } catch (_: Throwable) {}

                captureSession?.close()
                captureSession = null

                // 4. Tell the encoder no more input is coming, then wait for
                // the drain thread to flush remaining encoded frames into the
                // muxer. encodedFrameCount becomes authoritative once join returns.
                try { mediaCodec?.signalEndOfInputStream() } catch (e: Exception) {
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
                    try { mediaMuxer?.stop() } catch (_: Throwable) {}
                }
                mediaMuxer?.release()
                mediaMuxer = null
                muxerStarted = false
                videoTrackIndex = -1

                try { posesWriter?.flush(); posesWriter?.close() } catch (_: Throwable) {}
                posesWriter = null
                try { motionWriter?.flush(); motionWriter?.close() } catch (_: Throwable) {}
                motionWriter = null

                if (frameCounter != encodedFrameCount) {
                    Log.w(TAG, "frame count drift: callback=$frameCounter muxed=$encodedFrameCount")
                }

                // With the drain barrier, frameCounter (which gates poses.jsonl
                // writes) matches encodedFrameCount in healthy operation. Use the
                // smaller value to guarantee the spec invariant
                //   poses.jsonl line count == video.frame_count == frames in MP4
                // even in edge cases where the two diverge by one. Truncation of
                // any extra MP4 frames is implicit (the decoder will produce N
                // frames; the pipeline iterates by frame_idx 0..N-1).
                val authoritativeFrameCount = when {
                    encodedFrameCount == 0 -> frameCounter
                    frameCounter == 0 -> encodedFrameCount
                    else -> minOf(frameCounter, encodedFrameCount)
                }
                val recordingData = mapOf(
                    "directoryPath" to (outputDirectory ?: ""),
                    "durationSeconds" to (authoritativeFrameCount / 30),
                    "frameCount" to authoritativeFrameCount,
                    "poseSource" to poseSource,
                    "motionRateHzMeasured" to (if (motionSampleCount > 1) motionRateHz else 0.0),
                    "captureCallbackCount" to frameCounter,
                    "muxedFrameCount" to encodedFrameCount,
                )
                mainHandler.post { result.success(recordingData) }
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping recording", e)
                mainHandler.post {
                    result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null)
                }
            }
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
        result.success(true)
    }

    fun cleanup() {
        if (isRecording) {
            isRecording = false
        }
        stopSensorUpdates()

        captureSession?.close()
        cameraDevice?.close()

        try { arSession?.close() } catch (_: Throwable) {}
        arSession = null
        sharedCamera = null
        // EGL helper lives on backgroundHandler — release on that thread before tearing it down.
        backgroundHandler?.post {
            try { arEglHelper?.release() } catch (_: Throwable) {}
            arEglHelper = null
        }

        stopBackgroundThread()

        mediaCodec?.release()
        mediaMuxer?.release()
        encoderSurface?.release()
    }
}
