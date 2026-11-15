package com.mochi.study.mochi_app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.util.Base64
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        receiveSession(intent)
    }
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
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "mochi/live_bridge")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> { result.success(pending); pending = null }
                "openGemini" -> {
                    val launch = packageManager.getLaunchIntentForPackage("com.google.android.apps.bard")
                    if (launch == null) result.error("missing", "Chưa tìm thấy ứng dụng Gemini", null)
                    else {
                        // ADB controller reads only this explicit, non-sensitive launch ticket.
                        File(applicationContext.filesDir, "live_bridge_request.txt").writeText(System.currentTimeMillis().toString())
                        // Also notify via broad intent for immediate pickup
                        val notify = Intent("com.mochi.study.BRIDGE_LAUNCHED").putExtra("ts", System.currentTimeMillis())
                        sendBroadcast(notify)
                        getExternalFilesDir(null)?.let { dir ->
                            File(dir, "live_bridge_request.txt").writeText(System.currentTimeMillis().toString())
                        }
                        startActivity(launch)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSession(intent)
        if (pending != null) channel?.invokeMethod("sessionReady", null)
    }
    private fun receiveSession(intent: Intent?) {
        if (intent == null) return
        try {
            val raw = when {
                intent.action == "com.mochi.study.IMPORT_LIVE_SESSION" -> {
                    val encoded = intent.getStringExtra("session_b64") ?: return
                    if (encoded.length > 180000) return
                    String(Base64.decode(encoded, Base64.NO_WRAP), Charsets.UTF_8)
                }
                intent.action == Intent.ACTION_SEND && intent.type == "text/plain" ->
                    intent.getStringExtra(Intent.EXTRA_TEXT)
                else -> null
            }
            if (raw != null && raw.length <= 100000) pending = raw
        } catch (_: Exception) { /* Invalid imports are ignored, never executed. */ }
    }
}
