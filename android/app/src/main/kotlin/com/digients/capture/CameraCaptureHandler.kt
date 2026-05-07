package com.digients.capture

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.TotalCaptureResult
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.ImageReader
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Range
import android.view.Surface
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.atan2
import kotlin.math.tan

/// v1.2 capture pipeline (RECORDING_DATA_STRUCTURE_V1.2.md).
///
/// One path only — pick the widest physical rear lens, encode HEVC at static
/// intrinsics, write raw IMU at SENSOR_DELAY_FASTEST. ARCore is gone:
/// `poses.jsonl` and the SharedCamera path are removed entirely. Pose
/// reconstruction happens offline (DROID-SLAM today, offline VIO next).
///
/// Also addresses the Android writer-side bugs filed in
/// `docs/bug_fix/2026-05-05_android_writer_fixes.md`:
///   • P0-1  distortion_model = "brown_conrady" (not "opencv5").
///   • P1-1  fx == fy via single uniform scalar (no per-axis crop factor).
///   • P1-2  IMU rows in monotonic timestamp order (one row per gyro event).
///   • P1-3  one row per sensor event (gyro is the primary stream).
///   • P1-4  motion.rate_hz = primary-sensor sample rate.
///   • P1-5  IMU stream bracketed to the video window.
///   • P2-1  frame_count read from the finalized MP4 (MediaExtractor).
class CameraCaptureHandler : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        private const val CHANNEL_NAME = "digients_app/camera"
        private const val TAG = "CameraCaptureHandler"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
        // v1.2 keeps the v1 video target unchanged: HEVC 1920×1080 30 fps.
        private const val VIDEO_WIDTH = 1920
        private const val VIDEO_HEIGHT = 1080
        // Slack at each end of the video window when bracketing IMU rows
        // (spec §5 / bug-fix P1-5). 100 ms gives VIO interpolation context
        // without bloating the file.
        private const val IMU_BRACKET_SLACK_NS = 100_000_000L
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: android.app.Activity? = null

    // Hand-presence detector (V2 addendum). Set by MainActivity at engine
    // configuration time.
    var handDetector: HandPresenceDetector? = null

    // Camera2 components.
    private var cameraManager: CameraManager? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var selectedCameraId: String? = null
    private var cameraCharacteristics: CameraCharacteristics? = null

    // Recording components.
    private var mediaCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var encoderSurface: Surface? = null
    private var previewSurface: Surface? = null

    // ImageReader → hand-presence detector. v1.1 piggybacked on ARCore's
    // frame.acquireCameraImage(); under v1.2 we run the detector off this
    // dedicated reader so it gets frames during ARMED (preview-only) and
    // RECORDING alike. STRATEGY_KEEP_ONLY_LATEST is implemented manually:
    // every available image is acquired and the previous one closed, so
    // the detector never lags more than one frame behind real-time.
    private var detectorImageReader: ImageReader? = null
    private val detectorImageReaderLock = Any()
    private var isRecording = false
    private var videoTrackIndex = -1
    private var muxerStarted = false
    private var encoderThread: Thread? = null
    private var frameCounter = 0
    @Volatile private var encodedFrameCount = 0
    private var sessionId: String? = null
    private var outputDirectory: String? = null

    // Wall-clock offset to convert SystemClock.elapsedRealtimeNanos() into
    // Unix-epoch nanoseconds. Captured at session start, applied uniformly
    // to frame timestamps and IMU samples so they share one clock.
    private var unixOffsetNs: Long = 0L

    // motion.jsonl writer.
    private var motionWriter: BufferedWriter? = null

    // IMU window — bracket motion.jsonl writes to ~[firstFrame, lastFrame]
    // per bug-fix P1-5. Volatile because the encoder-callback thread sets
    // these and the IMU thread reads them.
    @Volatile private var firstFramePtsNs: Long = 0L
    @Volatile private var lastFramePtsNs: Long = 0L

    // IMU
    private var sensorManager: SensorManager? = null
    private var gyroSensor: Sensor? = null
    private var accelSensor: Sensor? = null
    private val latestAccel = FloatArray(3)
    @Volatile private var haveAccel = false
    // Gyro is the primary stream — every gyro event produces exactly one row,
    // attaching the most recent accel. Solves P1-3 (no double-emit) and as a
    // side effect P1-2 (gyro events arrive monotonically on a single thread,
    // so written rows are monotonic).
    private var motionRowCount: Long = 0L
    private var firstMotionTsNs: Long = 0L
    private var lastMotionTsNs: Long = 0L

    // Background thread.
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    // Synchronization.
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
        // If the camera device is already open and we're not actively
        // recording, kick off (or restart) the preview-only session so
        // the user sees a live feed before they press the vol button to
        // start. Without this the preview surface stays black under v1.2
        // (ARCore used to drive the camera in v1.1; we now have to do it
        // ourselves).
        if (cameraDevice != null && !isRecording) {
            backgroundHandler?.post { startPreviewSession() }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        cleanup()
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    override fun onDetachedFromActivity() { activity = null }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }

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
                if (args != null) startRecording(args, result)
                else result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            }
            "stopRecording" -> stopRecording(result)
            "getAvailableCameras" -> getAvailableCameras(result)
            "switchCamera" -> result.success(true)
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
            val cameraId = pickWidestPhysicalRearLens()
            if (cameraId == null) {
                result.error("NO_CAMERA", "No suitable physical rear camera found", null)
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

    private fun hasCameraPermission(): Boolean {
        val context = this.context ?: return false
        return ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    /// Pick the back-facing physical camera with the largest horizontal FOV.
    /// Logical / multi-camera devices are skipped — they auto-switch sub-
    /// lenses mid-session and break the static-intrinsics contract.
    private fun pickWidestPhysicalRearLens(): String? {
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
            Log.e(TAG, "Camera access exception while picking lens", e)
        }
        return bestCameraId
    }

    private fun calculateHorizontalFOV(characteristics: CameraCharacteristics): Double {
        val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return 0.0
        val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS) ?: return 0.0
        if (focalLengths.isEmpty()) return 0.0
        // Shortest focal length = widest FOV.
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
            val callback = object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    cameraDevice = camera
                    setupDetectorImageReader()
                    if (replied.compareAndSet(false, true)) result.success(true)
                    // If the platform-view surface is already ready, light
                    // the preview now. Otherwise setPreviewSurface will
                    // kick it off as soon as the surface lands.
                    if (previewSurface != null) {
                        backgroundHandler?.post { startPreviewSession() }
                    }
                }
                override fun onDisconnected(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    if (replied.compareAndSet(false, true)) {
                        result.error("DISCONNECTED", "Camera disconnected", null)
                    }
                }
                override fun onError(camera: CameraDevice, error: Int) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    if (replied.compareAndSet(false, true)) {
                        result.error("CAMERA_ERROR", "Camera error: $error", null)
                    }
                }
            }
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
            // v1.2 spec §3: lens_type is *derived* from the chosen FOV.
            val lensType = if (fov >= 100.0) "ultrawide" else "wide"

            val focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            val pixelArraySize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)

            val intrinsicMatrix = computeStaticIntrinsicMatrix(fov)
            val distortionCoeffs = (characteristics.get(CameraCharacteristics.LENS_DISTORTION)
                ?.toList()?.map { it.toDouble() })
                ?: List(5) { 0.0 }

            // Camera-IMU extrinsics (v1.2 §4.4) — Camera2 publishes the
            // rigid transform from sensor to its pose-reference frame.
            val tCamImu = readTCamImu(characteristics)
            val tCamImuSource = if (tCamImu != null) "platform_api" else null
            // Rolling-shutter skew is exposed per-frame on
            // CaptureResult.SENSOR_ROLLING_SHUTTER_SKEW, not as a
            // characteristic. Leave null for now; we'd need to capture it
            // from the first CaptureResult to surface it here. Schema has
            // it as Optional so null is fine.
            val rollingShutterSkewNs: Long? = null

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
                // P0-1: emit the spec-accepted distortion model name. The
                // OpenCV 5-coefficient layout [k1, k2, p1, p2, k3] *is*
                // Brown-Conrady; only the label changes.
                "distortionModel" to "brown_conrady",
                "distortionCoeffs" to distortionCoeffs,
                "intrinsicsNotes" to
                    "Static intrinsics from horizontal FOV at video resolution; distortion coefficients from CameraCharacteristics.LENS_DISTORTION (zero-filled when not exposed by the device).",
                "motionRateHz" to 200.0,
                "motionGyroUnits" to "rad/s",
                "motionAccelUnits" to "m/s^2",
                "motionAccelIncludesGravity" to true,
                "motionFrame" to "device_body",
                "deviceClockId" to "CLOCK_BOOTTIME",
                "rollingShutterSkewNs" to rollingShutterSkewNs,
                "tCamImu" to tCamImu,
                "extrinsicsSource" to tCamImuSource,
                "extrinsicsNotes" to
                    "Camera2 LENS_POSE_TRANSLATION + LENS_POSE_ROTATION composed into 4x4. Reference frame: see CameraCharacteristics.LENS_POSE_REFERENCE on this model.",
            )
            result.success(cameraInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting camera info", e)
            result.error("CAMERA_INFO_ERROR", "Error getting camera info: ${e.message}", null)
        }
    }

    /// Compute K from the horizontal FOV at the recorded video resolution.
    /// Bug-fix P1-1: a single uniform scalar (not per-axis crop factors), so
    /// fx == fy on devices with square-pixel sensors. The bottom row is
    /// always [0, 0, 1].
    private fun computeStaticIntrinsicMatrix(horizontalFovDeg: Double): List<List<Double>> {
        if (horizontalFovDeg <= 0.0) {
            return listOf(
                listOf(0.0, 0.0, 0.0),
                listOf(0.0, 0.0, 0.0),
                listOf(0.0, 0.0, 1.0),
            )
        }
        val halfRad = horizontalFovDeg * Math.PI / 360.0
        val fx = VIDEO_WIDTH.toDouble() / (2.0 * tan(halfRad))
        val fy = fx
        val cx = VIDEO_WIDTH.toDouble() / 2.0
        val cy = VIDEO_HEIGHT.toDouble() / 2.0
        return listOf(
            listOf(fx, 0.0, cx),
            listOf(0.0, fy, cy),
            listOf(0.0, 0.0, 1.0),
        )
    }

    /// Compose Camera2's LENS_POSE_TRANSLATION (3 floats, meters) +
    /// LENS_POSE_ROTATION (4 floats, qx, qy, qz, qw) into a 4×4 row-major
    /// homogeneous matrix that maps a point in the IMU body frame into the
    /// camera optical frame. Returns null if either field is unavailable.
    private fun readTCamImu(c: CameraCharacteristics): List<List<Double>>? {
        val t = c.get(CameraCharacteristics.LENS_POSE_TRANSLATION) ?: return null
        val r = c.get(CameraCharacteristics.LENS_POSE_ROTATION) ?: return null
        if (t.size < 3 || r.size < 4) return null
        val qx = r[0].toDouble(); val qy = r[1].toDouble()
        val qz = r[2].toDouble(); val qw = r[3].toDouble()
        // Quaternion → rotation matrix (right-handed).
        val xx = qx * qx; val yy = qy * qy; val zz = qz * qz
        val xy = qx * qy; val xz = qx * qz; val yz = qy * qz
        val wx = qw * qx; val wy = qw * qy; val wz = qw * qz
        val r00 = 1.0 - 2.0 * (yy + zz)
        val r01 = 2.0 * (xy - wz)
        val r02 = 2.0 * (xz + wy)
        val r10 = 2.0 * (xy + wz)
        val r11 = 1.0 - 2.0 * (xx + zz)
        val r12 = 2.0 * (yz - wx)
        val r20 = 2.0 * (xz - wy)
        val r21 = 2.0 * (yz + wx)
        val r22 = 1.0 - 2.0 * (xx + yy)
        return listOf(
            listOf(r00, r01, r02, t[0].toDouble()),
            listOf(r10, r11, r12, t[1].toDouble()),
            listOf(r20, r21, r22, t[2].toDouble()),
            listOf(0.0, 0.0, 0.0, 1.0),
        )
    }

    private fun getDeviceInfo(result: MethodChannel.Result) {
        val deviceInfo = mapOf(
            "os" to "android",
            "osVersion" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "modelIdentifier" to "${Build.MANUFACTURER}_${Build.MODEL}",
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
        val mainHandler = Handler(Looper.getMainLooper())
        backgroundHandler?.post {
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
                openMotionWriter(outputDirectory)
                isRecording = true
                frameCounter = 0
                firstFramePtsNs = 0L
                lastFramePtsNs = 0L
                motionRowCount = 0L
                firstMotionTsNs = 0L
                lastMotionTsNs = 0L
                haveAccel = false
                startEncoderDrain()
                // P1-5 prep: register sensors *only* after we know we're
                // recording; bracketing in emitMotionRow then guarantees no
                // rows leak before the first frame or after the last.
                startSensorUpdates()
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

    private fun openMotionWriter(outputDirectory: String) {
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
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_HEVC, VIDEO_WIDTH, VIDEO_HEIGHT).apply {
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

    /// One-time ImageReader setup for the hand-presence detector. The
    /// reader is YUV_420_888 at 640×480 — small enough that MediaPipe's
    /// downsampling to 256×256 is a quick resize, big enough that
    /// landmark / handedness classification still works reliably on
    /// older devices like the OnePlus 5. Three buffers gives us slack
    /// across the 30-fps producer / 10-fps consumer mismatch.
    private fun setupDetectorImageReader() {
        synchronized(detectorImageReaderLock) {
            detectorImageReader?.close()
            val reader = ImageReader.newInstance(640, 480, android.graphics.ImageFormat.YUV_420_888, 3)
            reader.setOnImageAvailableListener({ r ->
                val detector = handDetector
                val image = try { r.acquireLatestImage() } catch (_: Throwable) { null }
                if (image == null) return@setOnImageAvailableListener
                if (detector == null) {
                    image.close()
                    return@setOnImageAvailableListener
                }
                try {
                    val tsMs = image.timestamp / 1_000_000L + (unixOffsetNs / 1_000_000L)
                    // submitFrame takes ownership of the Image and must
                    // close it in all paths (matches the v1.1 ARCore call
                    // site). Don't close here.
                    detector.submitFrame(image, tsMs)
                } catch (t: Throwable) {
                    Log.w(TAG, "detector.submitFrame failed", t)
                    try { image.close() } catch (_: Throwable) {}
                }
            }, backgroundHandler)
            detectorImageReader = reader
        }
    }

    /// Spin up a preview-only CameraCaptureSession (no encoder surface
    /// yet) so the user sees a live feed during ARMED before they press
    /// vol to start recording. Replaced by createCaptureSession() the
    /// moment recording begins. No-op if a preview session is already
    /// alive or if either the camera device or the surface isn't ready.
    private fun startPreviewSession() {
        if (isRecording) return
        val camera = cameraDevice ?: return
        val preview = previewSurface ?: return
        try { captureSession?.close() } catch (_: Throwable) {}
        captureSession = null
        val detectorSurface = detectorImageReader?.surface
        val surfaces = mutableListOf(preview)
        detectorSurface?.let { surfaces.add(it) }
        try {
            camera.createCaptureSession(
                surfaces,
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        if (isRecording) {
                            try { session.close() } catch (_: Throwable) {}
                            return
                        }
                        captureSession = session
                        startPreviewRepeatingRequest(session, preview, detectorSurface)
                    }
                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Preview session configure failed")
                    }
                },
                backgroundHandler,
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to start preview session", e)
        }
    }

    private fun startPreviewRepeatingRequest(
        session: CameraCaptureSession,
        preview: Surface,
        detectorSurface: Surface?,
    ) {
        val device = cameraDevice ?: return
        val characteristics = cameraCharacteristics
        val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
            addTarget(preview)
            detectorSurface?.let { addTarget(it) }
            set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE,
                CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
            set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE,
                CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_OFF)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)
            }
            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            characteristics
                ?.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                ?.find { it.contains(30) }
                ?.let { set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, it) }
        }
        try {
            session.setRepeatingRequest(builder.build(), null, backgroundHandler)
        } catch (e: Throwable) {
            Log.e(TAG, "Preview repeating request failed", e)
        }
    }

    private fun createCaptureSession() {
        val camera = cameraDevice ?: throw RuntimeException("Camera not available")
        val surface = encoderSurface ?: throw RuntimeException("Encoder surface not available")
        val preview = previewSurface
        val detectorSurface = detectorImageReader?.surface
        val surfaces = mutableListOf(surface)
        preview?.let { surfaces.add(it) }
        detectorSurface?.let { surfaces.add(it) }

        // Close any preview-only session that's been driving the live
        // feed during ARMED. Camera2 forbids two concurrent sessions on
        // the same device.
        try { captureSession?.close() } catch (_: Throwable) {}
        captureSession = null

        camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session
                startRepeatingRequest(session, surface, preview, detectorSurface)
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
        detectorSurface: Surface?,
    ) {
        val characteristics = cameraCharacteristics ?: return
        val requestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)?.apply {
            addTarget(encoder)
            preview?.let { addTarget(it) }
            detectorSurface?.let { addTarget(it) }
            set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE,
                CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
            set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE,
                CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_OFF)
            // v1.2 §3.3: lock zoom so the static-intrinsics contract holds.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                set(CaptureRequest.CONTROL_ZOOM_RATIO, 1.0f)
            }
            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            val fpsRange = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                ?.find { it.contains(30) } ?: Range(30, 30)
            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange)
        }
        val captureCallback = object : CameraCaptureSession.CaptureCallback() {
            override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                if (!isRecording) return
                val sensorTimestampNs = result.get(CaptureResult_SENSOR_TIMESTAMP) ?: SystemClock.elapsedRealtimeNanos()
                val unixTsNs = sensorTimestampNs + unixOffsetNs
                if (firstFramePtsNs == 0L) firstFramePtsNs = unixTsNs
                lastFramePtsNs = unixTsNs
                frameCounter++
            }
        }
        requestBuilder?.let { builder ->
            session.setRepeatingRequest(builder.build(), captureCallback, backgroundHandler)
        }
    }

    // -------- IMU (motion.jsonl) — bug-fix P1-2 / P1-3 / P1-4 / P1-5 --------

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    System.arraycopy(event.values, 0, latestAccel, 0, 3)
                    haveAccel = true
                }
                Sensor.TYPE_GYROSCOPE -> {
                    // P1-3: emit one row per *gyro* event, attaching the most
                    // recent accel. Drops the duplicate row the accel callback
                    // would have produced; gyro alone is the primary stream.
                    if (haveAccel) emitMotionRow(event)
                }
            }
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private fun emitMotionRow(event: SensorEvent) {
        if (!isRecording) return
        val writer = motionWriter ?: return

        val tsNs = event.timestamp + unixOffsetNs

        // P1-5: bracket to the video window. Allow ~100 ms of slack on each
        // side for VIO interpolation context.
        val firstPts = firstFramePtsNs
        val lastPts = lastFramePtsNs
        if (firstPts != 0L && tsNs < firstPts - IMU_BRACKET_SLACK_NS) return
        if (lastPts != 0L && tsNs > lastPts + IMU_BRACKET_SLACK_NS) return

        val gx = event.values[0]; val gy = event.values[1]; val gz = event.values[2]
        val ax = latestAccel[0]; val ay = latestAccel[1]; val az = latestAccel[2]

        val sb = StringBuilder(160)
        sb.append('{')
        sb.append("\"timestamp_ns\":").append(tsNs).append(',')
        sb.append("\"gyro\":[").append(gx).append(',').append(gy).append(',').append(gz).append(']')
        sb.append(",\"accel\":[").append(ax).append(',').append(ay).append(',').append(az).append(']')
        sb.append("}\n")
        try {
            writer.write(sb.toString())
        } catch (e: Throwable) {
            Log.e(TAG, "motion.jsonl write failed", e)
            return
        }
        if (firstMotionTsNs == 0L) firstMotionTsNs = tsNs
        lastMotionTsNs = tsNs
        motionRowCount += 1
    }

    private fun startSensorUpdates() {
        val sm = sensorManager ?: return
        val gyro = gyroSensor ?: return
        val accel = accelSensor ?: return
        sm.registerListener(sensorListener, accel, SensorManager.SENSOR_DELAY_FASTEST, backgroundHandler)
        sm.registerListener(sensorListener, gyro, SensorManager.SENSOR_DELAY_FASTEST, backgroundHandler)
    }

    private fun stopSensorUpdates() {
        sensorManager?.unregisterListener(sensorListener)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (!isRecording) {
            result.error("NOT_RECORDING", "Not currently recording", null)
            return
        }
        val mainHandler = Handler(Looper.getMainLooper())
        backgroundHandler?.post {
            try {
                try { captureSession?.stopRepeating() } catch (_: Throwable) {}
                Thread.sleep(200) // drain in-flight callbacks

                isRecording = false
                stopSensorUpdates()

                captureSession?.close()
                captureSession = null

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

                try { motionWriter?.flush(); motionWriter?.close() } catch (_: Throwable) {}
                motionWriter = null

                // Bug-fix P2-1: read frame_count + duration from the
                // *finalized* container rather than the encoder counter,
                // which can drift by 1-6 due to flush ordering. Falls back
                // to encoder counts on failure.
                val (containerFrameCount, containerDurationSec) =
                    readMp4FrameCountAndDuration(outputDirectory)

                val authoritativeFrameCount = containerFrameCount
                    ?: when {
                        encodedFrameCount == 0 -> frameCounter
                        frameCounter == 0 -> encodedFrameCount
                        else -> minOf(frameCounter, encodedFrameCount)
                    }
                val authoritativeDurationSec = containerDurationSec
                    ?: (authoritativeFrameCount / 30)

                // Bug-fix P1-4: motion.rate_hz is the gyro sample rate, not
                // the row rate of the (now-deduplicated) writer. With one row
                // per gyro event, rowCount == sampleCount.
                val measuredMotionRateHz =
                    if (motionRowCount > 1 && lastMotionTsNs > firstMotionTsNs) {
                        (motionRowCount - 1).toDouble() /
                            ((lastMotionTsNs - firstMotionTsNs) / 1_000_000_000.0)
                    } else 0.0

                val recordingData = mapOf(
                    "directoryPath" to (outputDirectory ?: ""),
                    "durationSeconds" to authoritativeDurationSec,
                    "frameCount" to authoritativeFrameCount,
                    "motionRateHzMeasured" to measuredMotionRateHz,
                    "captureCallbackCount" to frameCounter,
                    "muxedFrameCount" to encodedFrameCount,
                )
                mainHandler.post { result.success(recordingData) }
                // Re-arm the preview so the user sees a live feed during
                // the success popup and the next ARMED state.
                if (previewSurface != null && cameraDevice != null) {
                    startPreviewSession()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping recording", e)
                mainHandler.post {
                    result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null)
                }
            }
        }
    }

    /// Bug-fix P2-1: read the authoritative frame count and duration from
    /// the finalized MP4 via MediaMetadataRetriever. The retriever reads
    /// the moov atom that MediaMuxer.stop() just wrote — same source the
    /// pipeline uses. Frame count requires API 28+; on older devices the
    /// caller falls back to the encoder counter.
    private fun readMp4FrameCountAndDuration(outputDirectory: String?): Pair<Int?, Int?> {
        val dir = outputDirectory ?: return Pair(null, null)
        val path = File(dir, "video.mp4").absolutePath
        if (!File(path).exists()) return Pair(null, null)
        val retriever = android.media.MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val durationMs = retriever
                .extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
            val durationSec = durationMs?.let { (it / 1000L).toInt() }
            val frameCount = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                retriever
                    .extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)
                    ?.toIntOrNull()
            } else null
            Pair(frameCount, durationSec)
        } catch (t: Throwable) {
            Log.w(TAG, "MediaMetadataRetriever read failed for $path", t)
            Pair(null, null)
        } finally {
            try { retriever.release() } catch (_: Throwable) {}
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

    fun cleanup() {
        if (isRecording) isRecording = false
        stopSensorUpdates()
        captureSession?.close()
        cameraDevice?.close()
        synchronized(detectorImageReaderLock) {
            try { detectorImageReader?.close() } catch (_: Throwable) {}
            detectorImageReader = null
        }
        stopBackgroundThread()
        mediaCodec?.release()
        mediaMuxer?.release()
        encoderSurface?.release()
    }
}

// `CaptureResult.SENSOR_TIMESTAMP` is a static field; the Kotlin compiler
// occasionally trips up resolving it via the package-level import shadow.
// Re-export it under an unambiguous alias so the call site reads cleanly.
private val CaptureResult_SENSOR_TIMESTAMP =
    android.hardware.camera2.CaptureResult.SENSOR_TIMESTAMP
