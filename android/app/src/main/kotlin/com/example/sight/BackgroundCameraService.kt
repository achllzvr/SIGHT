package com.example.sight

import android.app.Service
import android.content.Intent
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import java.nio.ByteBuffer

class BackgroundCameraService : Service() {
  companion object {
    private const val TAG = "SIGHT_BgCamera"
    private const val CHANNEL = "com.example.sight/camera_frames"
    private var flutterEngine: FlutterEngine? = null
    private var instance: BackgroundCameraService? = null

    fun setFlutterEngine(engine: FlutterEngine) {
      flutterEngine = engine
    }
  }

  private var cameraManager: CameraManager? = null
  private var cameraId: String? = null
  private var cameraCaptureSession: CameraCaptureSession? = null
  private var cameraDevice: CameraDevice? = null
  private var imageReader: ImageReader? = null
  private var backgroundThread: HandlerThread? = null
  private var backgroundHandler: Handler? = null
  private var isRunning = false

  override fun onCreate() {
    super.onCreate()
    instance = this
    cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
    startBackgroundThread()
    Log.d(TAG, "Service created")
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    Log.d(TAG, "Service started")
    if (!isRunning) {
      startCameraCapture()
    }
    return START_STICKY
  }

  override fun onDestroy() {
    stopCameraCapture()
    stopBackgroundThread()
    instance = null
    super.onDestroy()
    Log.d(TAG, "Service destroyed")
  }

  override fun onBind(intent: Intent?): IBinder? = null

  private fun startBackgroundThread() {
    backgroundThread = HandlerThread("SIGHTCameraBackground").apply {
      start()
      backgroundHandler = Handler(looper)
    }
  }

  private fun stopBackgroundThread() {
    backgroundThread?.quitSafely()
    try {
      backgroundThread?.join()
    } catch (e: InterruptedException) {
      Log.e(TAG, "Background thread interrupted", e)
    }
    backgroundThread = null
    backgroundHandler = null
  }

  private fun startCameraCapture() {
    backgroundHandler?.post {
      try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
          initCameraLollipop()
        }
      } catch (e: Exception) {
        Log.e(TAG, "Failed to start camera capture", e)
      }
    }
  }

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private fun initCameraLollipop() {
    val cameraIdList = cameraManager?.cameraIdList ?: return
    cameraId = cameraIdList.firstOrNull { id ->
      val characteristics = cameraManager?.getCameraCharacteristics(id)
      characteristics?.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
    } ?: cameraIdList.firstOrNull() ?: return

    val characteristics = cameraManager?.getCameraCharacteristics(cameraId!!) ?: return
    val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return
    val outputSizes = map.getOutputSizes(ImageFormat.YUV_420_888)
    val previewSize = outputSizes?.lastOrNull() ?: return

    imageReader = ImageReader.newInstance(previewSize.width, previewSize.height, ImageFormat.YUV_420_888, 2).apply {
      setOnImageAvailableListener({ reader ->
        reader.acquireLatestImage()?.use { image ->
          sendFrameToFlutter(image)
        }
      }, backgroundHandler)
    }

    try {
      cameraManager?.openCamera(cameraId!!, object : CameraDevice.StateCallback() {
        override fun onOpened(device: CameraDevice) {
          cameraDevice = device
          createCaptureSession()
        }

        override fun onDisconnected(device: CameraDevice) {
          device.close()
          cameraDevice = null
        }

        override fun onError(device: CameraDevice, error: Int) {
          device.close()
          cameraDevice = null
          Log.e(TAG, "Camera error: $error")
        }
      }, backgroundHandler)
    } catch (e: SecurityException) {
      Log.e(TAG, "Camera permission denied", e)
    } catch (e: CameraAccessException) {
      Log.e(TAG, "Camera access exception", e)
    }
  }

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private fun createCaptureSession() {
    try {
      val device = cameraDevice ?: return
      val reader = imageReader ?: return
      val previewRequestBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
        addTarget(reader.surface)
      }

      device.createCaptureSession(
        listOf(reader.surface),
        object : CameraCaptureSession.StateCallback() {
          override fun onConfigured(session: CameraCaptureSession) {
            cameraCaptureSession = session
            try {
              session.setRepeatingRequest(previewRequestBuilder.build(), null, backgroundHandler)
              isRunning = true
              Log.d(TAG, "Camera session started")
            } catch (e: CameraAccessException) {
              Log.e(TAG, "Failed to start repeating request", e)
            }
          }

          override fun onConfigureFailed(session: CameraCaptureSession) {
            Log.e(TAG, "Failed to configure capture session")
          }
        },
        backgroundHandler
      )
    } catch (e: CameraAccessException) {
      Log.e(TAG, "Camera access exception", e)
    }
  }

  private fun sendFrameToFlutter(image: Image) {
    try {
      val planes = image.planes
      val ySize = planes[0].buffer.remaining()
      val uvSize = planes[1].buffer.remaining() + planes[2].buffer.remaining()
      val nv21 = ByteArray(ySize + uvSize)

      planes[0].buffer.get(nv21, 0, ySize)
      val uvPixelStride = planes[1].pixelStride
      if (uvPixelStride == 1) {
        planes[1].buffer.get(nv21, ySize, planes[1].buffer.remaining())
        planes[2].buffer.get(nv21, ySize + planes[1].buffer.remaining(), planes[2].buffer.remaining())
      } else {
        val uvBuffer = ByteArray(uvSize)
        planes[1].buffer.get(uvBuffer, 0, planes[1].buffer.remaining())
        planes[2].buffer.get(uvBuffer, planes[1].buffer.remaining(), planes[2].buffer.remaining())
        for (i in uvBuffer.indices step 2) {
          nv21[ySize + i / 2] = uvBuffer[i]
          nv21[ySize + uvSize / 2 + i / 2] = uvBuffer[i + 1]
        }
      }

      flutterEngine?.dartExecutor?.binaryMessenger?.send(
        CHANNEL,
        ByteBuffer.wrap(nv21),
        null
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error sending frame to Flutter", e)
    }
  }

  private fun stopCameraCapture() {
    try {
      cameraCaptureSession?.stopRepeating()
      cameraCaptureSession?.close()
      cameraCaptureSession = null
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping capture session", e)
    }

    try {
      cameraDevice?.close()
      cameraDevice = null
    } catch (e: Exception) {
      Log.e(TAG, "Error closing camera device", e)
    }

    imageReader?.close()
    imageReader = null
    isRunning = false
  }
}
