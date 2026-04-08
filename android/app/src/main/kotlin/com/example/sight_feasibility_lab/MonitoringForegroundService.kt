package com.example.sight_feasibility_lab

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MonitoringForegroundService : Service() {

    companion object {
        const val ACTION_START = "com.example.sight_feasibility_lab.START_MONITORING"
        const val ACTION_STOP = "com.example.sight_feasibility_lab.STOP_MONITORING"
        const val ACTION_UPDATE = "com.example.sight_feasibility_lab.UPDATE_MONITORING"
        const val MONITORING_CHANNEL_ID = "sight_monitoring_channel"
        const val MONITORING_NOTIFICATION_ID = 42069
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        
        val title = intent?.getStringExtra("title") ?: "SIGHT Eye Monitoring"
        val message = intent?.getStringExtra("message") ?: "Monitoring active in background"

        val notification = buildNotification(title, message)

        when (action) {
            ACTION_START, ACTION_UPDATE -> {
                startForeground(MONITORING_NOTIFICATION_ID, notification)
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                MONITORING_CHANNEL_ID,
                "SIGHT Eye Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Continuous eye health monitoring in background"
                enableVibration(false)
                enableLights(false)
                setSound(null, null)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, message: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, MONITORING_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Replace with your app icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
