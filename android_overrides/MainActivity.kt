package com.rvbhati.player

import android.app.PictureInPictureParams
import android.content.Intent
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val PIP_CHANNEL = "com.rvbhati.player/pip"
    private val EQ_CHANNEL = "com.rvbhati.player/equalizer"
    private val UPDATER_CHANNEL = "com.rvbhati.player/updater"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Picture in Picture
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPip") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        val params = PictureInPictureParams.Builder().build()
                        val entered = enterPictureInPictureMode(params)
                        result.success(entered)
                    } catch (e: Exception) {
                        result.error("PIP_ERROR", e.message, null)
                    }
                } else {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }

        // Hardware Equalizer & Audio FX
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EQ_CHANNEL).setMethodCallHandler { call, result ->
            val sessionId = call.argument<Int>("sessionId") ?: 0
            try {
                if (equalizer == null) {
                    try {
                        equalizer = Equalizer(0, sessionId).apply { enabled = true }
                    } catch (_: Exception) {}
                    try {
                        bassBoost = BassBoost(0, sessionId).apply { enabled = true }
                    } catch (_: Exception) {}
                    try {
                        virtualizer = Virtualizer(0, sessionId).apply { enabled = true }
                    } catch (_: Exception) {}
                }

                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        equalizer?.enabled = enabled
                        bassBoost?.enabled = enabled
                        virtualizer?.enabled = enabled
                        result.success(true)
                    }
                    "setBandLevel" -> {
                        val band = call.argument<Int>("band")?.toShort() ?: 0
                        val level = call.argument<Int>("level")?.toShort() ?: 0
                        equalizer?.setBandLevel(band, level)
                        result.success(true)
                    }
                    "setBassBoost" -> {
                        val strength = call.argument<Int>("strength")?.toShort() ?: 0
                        bassBoost?.setStrength(strength)
                        result.success(true)
                    }
                    "setVirtualizer" -> {
                        val strength = call.argument<Int>("strength")?.toShort() ?: 0
                        virtualizer?.setStrength(strength)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(false)
            }
        }

        // In-App APK Installer
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_PATH", "File path is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File not found: $filePath", null)
                        return@setMethodCallHandler
                    }
                    val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
                    } else {
                        Uri.fromFile(file)
                    }
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
