package com.rvbhati.player

import android.app.PictureInPictureParams
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val PIP_CHANNEL = "com.rvbhati.player/pip"
    private val EQ_CHANNEL = "com.rvbhati.player/equalizer"
    private val UPDATER_CHANNEL = "com.rvbhati.player/updater"
    private val THUMB_CHANNEL = "com.rvbhati.player/thumbnail"
    private val SHARE_CHANNEL = "com.rvbhati.player/share"
    private val MEDIA_CHANNEL = "com.rvbhati.player/media_manager"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var currentSessionId: Int = 0
    private var isEqEnabled: Boolean = true
    private var currentBands = shortArrayOf(0, 0, 0, 0, 0)
    private var currentBass: Short = 0
    private var currentVirtualizer: Short = 0

    private fun releaseAudioEffects() {
        try {
            if (currentSessionId > 0) {
                val intent = Intent(AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION).apply {
                    putExtra(AudioEffect.EXTRA_AUDIO_SESSION, currentSessionId)
                    putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                }
                sendBroadcast(intent)
            }
            equalizer?.release()
            bassBoost?.release()
            virtualizer?.release()
        } catch (ignored: Exception) {}
        equalizer = null
        bassBoost = null
        virtualizer = null
    }

    private fun applyBands() {
        val eq = equalizer ?: return
        try {
            val numBands = eq.numberOfBands.toInt()
            val range = eq.bandLevelRange ?: shortArrayOf(-1500, 1500)
            for (i in 0 until minOf(numBands, currentBands.size)) {
                val clamped = currentBands[i].coerceIn(range[0], range[1])
                eq.setBandLevel(i.toShort(), clamped)
            }
        } catch (ignored: Exception) {}
    }

    private fun initAudioEffects(sessionId: Int) {
        if (equalizer != null && currentSessionId == sessionId && sessionId != 0) {
            return
        }
        releaseAudioEffects()
        currentSessionId = sessionId

        try {
            if (sessionId > 0) {
                val openIntent = Intent(AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION).apply {
                    putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                    putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                    putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                }
                sendBroadcast(openIntent)
            }
        } catch (ignored: Exception) {}

        try {
            equalizer = Equalizer(1000, sessionId).apply {
                enabled = isEqEnabled
            }
            applyBands()
        } catch (ignored: Exception) {
            if (sessionId != 0) {
                try {
                    equalizer = Equalizer(1000, 0).apply {
                        enabled = isEqEnabled
                    }
                    applyBands()
                } catch (ignored2: Exception) {}
            }
        }

        try {
            bassBoost = BassBoost(1000, sessionId).apply {
                enabled = isEqEnabled
                if (strengthSupported) {
                    setStrength(currentBass)
                }
            }
        } catch (ignored: Exception) {
            if (sessionId != 0) {
                try {
                    bassBoost = BassBoost(1000, 0).apply {
                        enabled = isEqEnabled
                        if (strengthSupported) {
                            setStrength(currentBass)
                        }
                    }
                } catch (ignored2: Exception) {}
            }
        }

        try {
            virtualizer = Virtualizer(1000, sessionId).apply {
                enabled = isEqEnabled
                if (strengthSupported) {
                    setStrength(currentVirtualizer)
                }
            }
        } catch (ignored: Exception) {
            if (sessionId != 0) {
                try {
                    virtualizer = Virtualizer(1000, 0).apply {
                        enabled = isEqEnabled
                        if (strengthSupported) {
                            setStrength(currentVirtualizer)
                        }
                    }
                } catch (ignored2: Exception) {}
            }
        }
    }

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
            val sessionIdArg = call.argument<Int>("sessionId")
            if (sessionIdArg != null && sessionIdArg > 0 && sessionIdArg != currentSessionId) {
                initAudioEffects(sessionIdArg)
            } else if (equalizer == null) {
                initAudioEffects(sessionIdArg ?: currentSessionId)
            }

            try {
                when (call.method) {
                    "setAudioSession" -> {
                        val newSessionId = call.argument<Int>("sessionId") ?: 0
                        initAudioEffects(newSessionId)
                        result.success(true)
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        isEqEnabled = enabled
                        equalizer?.enabled = enabled
                        bassBoost?.enabled = enabled
                        virtualizer?.enabled = enabled
                        result.success(true)
                    }
                    "setBandLevel" -> {
                        val band = call.argument<Int>("band") ?: 0
                        val level = call.argument<Int>("level")?.toShort() ?: 0
                        if (band >= 0 && band < currentBands.size) {
                            currentBands[band] = level
                        }
                        equalizer?.let { eq ->
                            val range = eq.bandLevelRange ?: shortArrayOf(-1500, 1500)
                            val clamped = level.coerceIn(range[0], range[1])
                            if (band < eq.numberOfBands.toInt()) {
                                eq.setBandLevel(band.toShort(), clamped)
                            }
                        }
                        result.success(true)
                    }
                    "setBassBoost" -> {
                        val strength = call.argument<Int>("strength")?.toShort() ?: 0
                        currentBass = strength.coerceIn(0, 1000)
                        bassBoost?.let { bb ->
                            if (bb.strengthSupported) {
                                bb.setStrength(currentBass)
                            }
                        }
                        result.success(true)
                    }
                    "setVirtualizer" -> {
                        val strength = call.argument<Int>("strength")?.toShort() ?: 0
                        currentVirtualizer = strength.coerceIn(0, 1000)
                        virtualizer?.let { virt ->
                            if (virt.strengthSupported) {
                                virt.setStrength(currentVirtualizer)
                            }
                        }
                        result.success(true)
                    }
                    "openSystemEqualizer" -> {
                        try {
                            val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                                putExtra(AudioEffect.EXTRA_AUDIO_SESSION, currentSessionId)
                                putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                                putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.success(false)
                        }
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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            try {
                                val manageIntent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(manageIntent)
                            } catch (ignored: Exception) {}
                        }
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

        // Native Video Thumbnail Extractor (Frame at 1s / 0s)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THUMB_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVideoThumbnail") {
                val path = call.argument<String>("path")
                val timeUs = (call.argument<Number>("timeUs"))?.toLong() ?: 1000000L
                if (path == null) {
                    result.error("INVALID_PATH", "Path is null", null)
                    return@setMethodCallHandler
                }
                Thread {
                    var retriever: MediaMetadataRetriever? = null
                    try {
                        retriever = MediaMetadataRetriever()
                        retriever.setDataSource(path)
                        var bitmap = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        if (bitmap == null) {
                            bitmap = retriever.getFrameAtTime(0L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        }
                        if (bitmap == null) {
                            bitmap = retriever.frameAtTime
                        }
                        if (bitmap != null) {
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
                            val bytes = stream.toByteArray()
                            runOnUiThread { result.success(bytes) }
                        } else {
                            runOnUiThread { result.success(null) }
                        }
                    } catch (e: Exception) {
                        runOnUiThread { result.success(null) }
                    } finally {
                        try {
                            retriever?.release()
                        } catch (ignored: Exception) {}
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }

        // Native Video / File Sharing (Intent.ACTION_SEND + FileProvider)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareFile") {
                val path = call.argument<String>("path")
                val title = call.argument<String>("title") ?: "Share Video"
                if (path == null) {
                    result.error("INVALID_PATH", "Path is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File not found: $path", null)
                        return@setMethodCallHandler
                    }
                    val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
                    } else {
                        Uri.fromFile(file)
                    }
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "video/*"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, file.name)
                        putExtra(Intent.EXTRA_TEXT, file.name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    val chooser = Intent.createChooser(intent, title)
                    chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Native Media Deletion & Metadata Extraction
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "deleteMedia" -> {
                    val path = call.argument<String>("path")
                    val id = call.argument<String>("id")
                    if (path == null) {
                        result.error("INVALID_PATH", "Path is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        var deleted = false
                        if (file.exists() && file.delete()) {
                            deleted = true
                            try {
                                MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                            } catch (ignored: Exception) {}
                        }
                        if (!deleted) {
                            try {
                                val contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                                var count = 0
                                if (id != null && id.isNotEmpty()) {
                                    val selection = "${MediaStore.Video.Media._ID} = ?"
                                    count = contentResolver.delete(contentUri, selection, arrayOf(id))
                                }
                                if (count <= 0 && path.isNotEmpty()) {
                                    val selection = "${MediaStore.Video.Media.DATA} = ?"
                                    count = contentResolver.delete(contentUri, selection, arrayOf(path))
                                }
                                deleted = count > 0
                            } catch (ignored: Exception) {}
                        }
                        result.success(deleted)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null && path.isNotEmpty()) {
                        try {
                            MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getVideoInfo" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_PATH", "Path is null", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        var retriever: MediaMetadataRetriever? = null
                        try {
                            retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            val widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                            val heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                            val rotStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                            val bitrateStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                            val mimeStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                            val w = widthStr?.toIntOrNull() ?: 0
                            val h = heightStr?.toIntOrNull() ?: 0
                            val rot = rotStr?.toIntOrNull() ?: 0
                            val br = bitrateStr?.toIntOrNull() ?: 0
                            val info = mapOf(
                                "width" to w,
                                "height" to h,
                                "rotation" to rot,
                                "bitrate" to br,
                                "mimeType" to (mimeStr ?: "")
                            )
                            runOnUiThread { result.success(info) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(null) }
                        } finally {
                            try { retriever?.release() } catch (ignored: Exception) {}
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        releaseAudioEffects()
        super.onDestroy()
    }
}

