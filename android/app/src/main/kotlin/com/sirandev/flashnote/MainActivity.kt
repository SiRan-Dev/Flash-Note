package com.sirandev.flashnote

import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val fairMemoryReceiver = FairMemoryReceiver()
    private val shareIntentHandler by lazy { ShareIntentHandler(this) }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge-to-edge: let the Flutter UI draw behind the system status and
        // navigation bars, and make those bars transparent so content shows
        // through (immersive full-bleed UI). The status/nav bar icon brightness
        // is then controlled by Flutter (AppBar / SystemUiOverlayStyle).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.navigationBarDividerColor = Color.TRANSPARENT
        }
        applyPredictiveBack()
        fairMemoryReceiver.initialize(this)
        shareIntentHandler.handleIntent(intent)
    }

    /** Applies the predictive-back setting read from SharedPreferences. */
    private fun applyPredictiveBack() {
        val enabled =
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .getBoolean("flutter.predictive_back_enabled", true)
        setPredictiveBackEnabled(enabled)
    }

    /** Enables/disables the Android predictive back gesture at runtime.
     *  ComponentActivity.setEnableOnBackInvokedCallback is available on
     *  androidx.activity 1.8.0+ (Android 13+). Falls back silently otherwise. */
    private fun setPredictiveBackEnabled(enabled: Boolean) {
        try {
            val method =
                javaClass.superclass?.superclass?.getMethod(
                    "setEnableOnBackInvokedCallback",
                    Boolean::class.javaPrimitiveType,
                )
            method?.invoke(this, enabled)
        } catch (_: ReflectiveOperationException) {
            // Runtime toggle not available on this androidx.activity version.
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sirandev.flashnote/updater",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "canRequestPackageInstalls" -> result.success(canRequestPackageInstallsCompat())
                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "APK path is empty.", null)
                    } else {
                        installApk(path, result)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Forward HyperOS fair-memory (TRIM/KILL) broadcasts to Flutter so it can
        // clear image caches and persist any in-progress state.
        val fairMemoryChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.sirandev.flashnote/fairmemory",
            )
        fairMemoryReceiver.onTrim = { notifyType, notifyId, isKill ->
            fairMemoryChannel.invokeMethod(
                "onTrim",
                mapOf(
                    "notifyType" to notifyType,
                    "notifyId" to notifyId,
                    "isKill" to isKill,
                ),
            )
        }

        // Apply predictive-back setting changes from the Flutter settings UI.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sirandev.flashnote/predictiveback",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    setPredictiveBackEnabled(enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        shareIntentHandler.attach(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        shareIntentHandler.handleIntent(intent)
    }

    override fun onDestroy() {
        shareIntentHandler.detach()
        fairMemoryReceiver.dispose(this)
        super.onDestroy()
    }

    private fun canRequestPackageInstallsCompat(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apk = File(path)
        if (!apk.exists()) {
            result.error("APK_NOT_FOUND", "APK file does not exist.", null)
            return
        }

        val uri =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
            } else {
                Uri.fromFile(apk)
            }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        result.success(true)
    }
}
