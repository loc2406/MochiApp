package com.mochi.study.mochi_app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "mochi/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "appInfo") {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("version" to info.versionName, "build" to code.toString()))
                } else if (call.method == "openSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("settings_unavailable", e.message, null)
                    }
                } else result.notImplemented()
            }
    }
}
