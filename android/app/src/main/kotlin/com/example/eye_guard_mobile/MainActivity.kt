package com.example.eye_guard_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.eye_guard_mobile/app_timer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "minimizeApp" -> {
                    minimizeApp()
                    result.success(true)
                }
                "launchMainApp" -> {
                    val blockedPackage = call.argument<String>("blockedPackage")
                    val blockedAppName = call.argument<String>("blockedAppName")
                    launchMainApp(blockedPackage, blockedAppName)
                    result.success(true)
                }
                "getIntentExtras" -> {
                    val extras = mapOf(
                        "route" to intent?.getStringExtra("route"),
                        "blockedPackage" to intent?.getStringExtra("blockedPackage"),
                        "blockedAppName" to intent?.getStringExtra("blockedAppName")
                    )
                    // Hapus extra setelah dibaca agar tidak diproses berulang-ulang
                    intent?.removeExtra("route")
                    intent?.removeExtra("blockedPackage")
                    intent?.removeExtra("blockedAppName")
                    result.success(extras)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // PENTING: Update intent agar intent di MainActivity merujuk pada intent baru
        setIntent(intent)
    }

    private fun minimizeApp() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun launchMainApp(blockedPackage: String?, blockedAppName: String?) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "app_block")
            putExtra("blockedPackage", blockedPackage)
            putExtra("blockedAppName", blockedAppName)
        }
        if (intent != null) {
            startActivity(intent)
        }
    }
}
