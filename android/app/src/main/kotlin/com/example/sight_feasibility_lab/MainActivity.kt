package com.example.sight_feasibility_lab

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val overlayChannelName = "com.example.sight_feasibility_lab/critical_overlay"
	private var overlayView: View? = null
	private var windowManager: WindowManager? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"showCriticalOverlay" -> result.success(showCriticalOverlay())
				"hideCriticalOverlay" -> result.success(hideCriticalOverlay())
				"isCriticalOverlayShowing" -> result.success(overlayView != null)
				else -> result.notImplemented()
			}
		}
	}

	private fun showCriticalOverlay(): Boolean {
		if (overlayView != null) {
			return true
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
			return false
		}

		val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
		windowManager = manager

		val layout = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			gravity = Gravity.CENTER
			setPadding(48, 96, 48, 96)
			setBackgroundColor(Color.parseColor("#F2000000"))
		}

		val title = TextView(this).apply {
			text = "Critical Limit Reached. Device Locked."
			setTextColor(Color.WHITE)
			textSize = 28f
			gravity = Gravity.CENTER
		}

		val subtitle = TextView(this).apply {
			text = "Open SIGHT to complete guardian override."
			setTextColor(Color.parseColor("#CCFFFFFF"))
			textSize = 16f
			gravity = Gravity.CENTER
			setPadding(0, 24, 0, 48)
		}

		val button = Button(this).apply {
			text = "Open SIGHT"
			textSize = 18f
			setOnClickListener {
				hideCriticalOverlay()
				val intent = packageManager.getLaunchIntentForPackage(packageName)
				intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
				startActivity(intent)
			}
		}

		layout.addView(title)
		layout.addView(subtitle)
		layout.addView(button)

		val paramsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
		} else {
			@Suppress("DEPRECATION")
			WindowManager.LayoutParams.TYPE_PHONE
		}

		val params = WindowManager.LayoutParams(
			WindowManager.LayoutParams.MATCH_PARENT,
			WindowManager.LayoutParams.MATCH_PARENT,
			paramsType,
			WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
			PixelFormat.TRANSLUCENT
		).apply {
			gravity = Gravity.TOP or Gravity.START
		}

		manager.addView(layout, params)
		overlayView = layout
		return true
	}

	private fun hideCriticalOverlay(): Boolean {
		val view = overlayView ?: return true
		return try {
			windowManager?.removeViewImmediate(view)
			overlayView = null
			true
		} catch (_: Exception) {
			overlayView = null
			true
		}
	}
}
