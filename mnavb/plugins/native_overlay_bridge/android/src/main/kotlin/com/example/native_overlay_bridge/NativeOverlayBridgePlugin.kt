package com.example.native_overlay_bridge

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeOverlayBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    private val channelName = "native_overlay"
    private val notificationChannelId = "voucher_channel"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, channelName)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canDrawOverlays" -> {
                result.success(Settings.canDrawOverlays(appContext))
            }

            "requestOverlayPermission" -> {
                if (!Settings.canDrawOverlays(appContext)) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${appContext.packageName}"),
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    appContext.startActivity(intent)
                }
                result.success(true)
            }

            "openOverlayFromPending" -> {
                if (!Settings.canDrawOverlays(appContext)) {
                    result.success(false)
                    return
                }

                val intent = Intent().apply {
                    setClassName(appContext, "${appContext.packageName}.VoucherOverlayService")
                }
                appContext.startService(intent)
                result.success(true)
            }

            "showNativeConfirmNotification" -> {
                val id = call.argument<Int>("id") ?: 9999
                val message =
                    call.argument<String>("message")
                        ?: "Toca para confirmar categoria y subcategoria"
                showNativeConfirmNotification(id, message)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun showNativeConfirmNotification(id: Int, message: String) {
        val manager =
            appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "Procesamiento de Vouchers",
                NotificationManager.IMPORTANCE_HIGH,
            )
            manager.createNotificationChannel(channel)
        }

        val receiverIntent = Intent().apply {
            setClassName(appContext, "${appContext.packageName}.OverlayNotificationReceiver")
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(appContext, id, receiverIntent, flags)

        val notification =
            NotificationCompat.Builder(appContext, notificationChannelId)
                .setSmallIcon(appContext.applicationInfo.icon)
                .setContentTitle("Confirmar voucher API")
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

        manager.notify(id, notification)
    }
}
