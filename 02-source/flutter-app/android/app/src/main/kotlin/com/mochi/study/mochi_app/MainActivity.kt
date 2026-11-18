package com.mochi.study.mochi_app

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "mochi/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appInfo" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                        result.success(mapOf("version" to info.versionName, "build" to code.toString()))
                    }
                    "openSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("settings_unavailable", e.message, null)
                        }
                    }
                    "channelEnabled" -> {
                        result.success(isChannelEnabled(call.argument<String>("channelId")))
                    }
                    "openChannelSettings" -> {
                        try {
                            openChannelSettings(call.argument<String>("channelId"))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("settings_unavailable", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** A channel can be switched off on its own while the app-level toggle stays on. */
    private fun isChannelEnabled(channelId: String?): Boolean {
        if (channelId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = getSystemService(NotificationManager::class.java) ?: return true
        val channel = manager.getNotificationChannel(channelId) ?: return true
        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun openChannelSettings(channelId: String?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channelId != null) {
            startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, channelId))
            return
        }
        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
    }
}
