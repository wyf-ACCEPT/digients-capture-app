package com.digients.capture

import android.content.Context
import android.graphics.SurfaceTexture
import android.view.Surface
import android.view.TextureView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

// SurfaceView would be cheaper but can't compose with Flutter's UI on Android —
// it uses its own SurfaceFlinger window. TextureView renders into the parent
// surface, which is what Flutter's hybrid composition needs.
class CameraPreviewView(
    context: Context,
    private val handler: CameraCaptureHandler,
) : PlatformView, TextureView.SurfaceTextureListener {

    private val textureView = TextureView(context).apply {
        surfaceTextureListener = this@CameraPreviewView
    }

    private var cameraSurface: Surface? = null

    override fun getView() = textureView

    override fun dispose() {
        textureView.surfaceTextureListener = null
        handler.setPreviewSurface(null)
        cameraSurface?.release()
        cameraSurface = null
    }

    override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
        texture.setDefaultBufferSize(1920, 1080)
        val surface = Surface(texture)
        cameraSurface = surface
        handler.setPreviewSurface(surface)
    }

    override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {}

    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        handler.setPreviewSurface(null)
        cameraSurface?.release()
        cameraSurface = null
        return true
    }

    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) {}
}

class CameraPreviewFactory(
    private val handler: CameraCaptureHandler,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CameraPreviewView(context, handler)
    }
}
