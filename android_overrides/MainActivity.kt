package com.rvbhati.player

import android.app.PictureInPictureParams
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
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
                    } catch (ignored: Exception) {}
                    try {
                        bassBoost = BassBoost(0, sessionId).apply { enabled = true }
                    } catch (ignored: Exception) {}
                    try {
                        virtualizer = Virtualizer(0, sessionId).apply { enabled = true }
                    } catch (ignored: Exception) {}
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
}
