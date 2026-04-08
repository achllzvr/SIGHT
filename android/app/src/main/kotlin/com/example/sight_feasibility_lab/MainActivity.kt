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
	private val backgroundChannelName = "com.example.sight_feasibility_lab/background_service"
	private var overlayView: View? = null
	private var floatingBubbleView: View? = null
	private var floatingBubbleTitleView: TextView? = null
	private var floatingBubbleSubtitleView: TextView? = null
	private var windowManager: WindowManager? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"showCriticalOverlay" -> result.success(showCriticalOverlay())
				"hideCriticalOverlay" -> result.success(hideCriticalOverlay())
				"isCriticalOverlayShowing" -> result.success(overlayView != null)
				"openOverlaySettings" -> result.success(openOverlaySettings())
				else -> result.notImplemented()
			}
		}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backgroundChannelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"startForegroundService" -> result.success(startForegroundService())
				"stopForegroundService" -> result.success(stopForegroundService())
				"canDrawOverlays" -> result.success(canDrawOverlays())
				"openOverlaySettings" -> result.success(openOverlaySettings())
				"showFloatingBubble" -> result.success(showFloatingBubble())
				"hideFloatingBubble" -> result.success(hideFloatingBubble())
				"updateFloatingBubble" -> {
					val title = call.argument<String>("title") ?: "0 blinks"
					val subtitle = call.argument<String>("subtitle") ?: "-- • Recovering"
					result.success(updateFloatingBubble(title, subtitle))
				}
				"updateNotification" -> {
					val title = call.argument<String>("title") ?: "SIGHT Monitoring"
					val message = call.argument<String>("message") ?: "Monitoring active"
					result.success(updateForegroundNotification(title, message))
				}
				"hasForegroundServicePermission" -> result.success(hasForegroundServicePermission())
				"requestForegroundServicePermission" -> result.success(true) // Handled via activity permissions
				"configureBackgroundModes" -> result.success(true) // iOS only, return success
				else -> result.notImplemented()
			}
		}
	}

	private fun canDrawOverlays(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			Settings.canDrawOverlays(this)
		} else {
			true
		}
	}

	private fun startForegroundService(): Boolean {
		return try {
			val intent = Intent(this, MonitoringForegroundService::class.java).apply {
				action = MonitoringForegroundService.ACTION_START
				putExtra("title", "SIGHT Eye Monitoring")
				putExtra("message", "Monitoring active")
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				startForegroundService(intent)
			} else {
				@Suppress("DEPRECATION")
				startService(intent)
			}
			true
		} catch (e: Exception) {
			android.util.Log.e("MainActivity", "Failed to start foreground service: ${e.message}")
			false
		}
	}

	private fun stopForegroundService(): Boolean {
		return try {
			val intent = Intent(this, MonitoringForegroundService::class.java).apply {
				action = MonitoringForegroundService.ACTION_STOP
			}
			stopService(intent)
			true
		} catch (e: Exception) {
			android.util.Log.e("MainActivity", "Failed to stop foreground service: ${e.message}")
			false
		}
	}

	private fun updateForegroundNotification(title: String, message: String): Boolean {
		return try {
			val intent = Intent(this, MonitoringForegroundService::class.java).apply {
				action = MonitoringForegroundService.ACTION_UPDATE
				putExtra("title", title)
				putExtra("message", message)
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				startForegroundService(intent)
			} else {
				@Suppress("DEPRECATION")
				startService(intent)
			}
			true
		} catch (e: Exception) {
			android.util.Log.e("MainActivity", "Failed to update foreground notification: ${e.message}")
			false
		}
	}

	private fun hasForegroundServicePermission(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			// Android 12+ requires FOREGROUND_SERVICE permission
			val permission = "android.permission.FOREGROUND_SERVICE"
			checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED
		} else {
			true
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

	private fun openOverlaySettings(): Boolean {
		return try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
				val intent = Intent(
					Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
					Uri.parse("package:$packageName")
				).apply {
					addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				}
				startActivity(intent)
				true
			} else {
				false
			}
		} catch (_: Exception) {
			false
		}
	}

	private fun showFloatingBubble(): Boolean {
		if (floatingBubbleView != null) {
			return true
		}

		if (!canDrawOverlays()) {
			return false
		}

		val manager = windowManager ?: (getSystemService(Context.WINDOW_SERVICE) as WindowManager).also { windowManager = it }

		val container = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			setPadding(28, 22, 28, 22)
			setBackgroundColor(Color.parseColor("#D9F6E6"))
			gravity = Gravity.CENTER
			elevation = 18f
		}

		val title = TextView(this).apply {
			text = "0 blinks"
			textSize = 15f
			setTextColor(Color.parseColor("#111111"))
			setTypeface(typeface, android.graphics.Typeface.BOLD)
			gravity = Gravity.CENTER
		}

		val subtitle = TextView(this).apply {
			text = "-- • Recovering"
			textSize = 12f
			setTextColor(Color.parseColor("#333333"))
			gravity = Gravity.CENTER
			setPadding(0, 6, 0, 0)
		}

		container.addView(title)
		container.addView(subtitle)

		container.setOnClickListener {
			val intent = packageManager.getLaunchIntentForPackage(packageName)
			intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
			startActivity(intent)
		}

		val paramsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
		} else {
			@Suppress("DEPRECATION")
			WindowManager.LayoutParams.TYPE_PHONE
		}

		val params = WindowManager.LayoutParams(
			WindowManager.LayoutParams.WRAP_CONTENT,
			WindowManager.LayoutParams.WRAP_CONTENT,
			paramsType,
			WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
			PixelFormat.TRANSLUCENT
		).apply {
			gravity = Gravity.TOP or Gravity.END
			x = 32
			y = 180
		}

		return try {
			manager.addView(container, params)
			floatingBubbleView = container
			floatingBubbleTitleView = title
			floatingBubbleSubtitleView = subtitle
			true
		} catch (_: Exception) {
			false
		}
	}

	private fun updateFloatingBubble(title: String, subtitle: String): Boolean {
		if (floatingBubbleView == null) {
			if (!showFloatingBubble()) {
				return false
			}
		}

		floatingBubbleTitleView?.text = title
		floatingBubbleSubtitleView?.text = subtitle
		return true
	}

	private fun hideFloatingBubble(): Boolean {
		val view = floatingBubbleView ?: return true
		return try {
			windowManager?.removeViewImmediate(view)
			floatingBubbleView = null
			floatingBubbleTitleView = null
			floatingBubbleSubtitleView = null
			true
		} catch (_: Exception) {
			floatingBubbleView = null
			floatingBubbleTitleView = null
			floatingBubbleSubtitleView = null
			true
		}
	}
}
