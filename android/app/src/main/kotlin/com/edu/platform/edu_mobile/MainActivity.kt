package com.edu.platform.edu_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.edu.platform.edu_mobile/voice_audio"
    private val REQ_RECORD_AUDIO = 4001

    private var mediaRecorder: MediaRecorder? = null
    private var currentRecordFile: File? = null
    private var recordStartTimeMs: Long = 0L
    private var mediaPlayer: MediaPlayer? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermission" -> {
                    if (hasRecordPermission()) {
                        result.success(true)
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            REQ_RECORD_AUDIO
                        )
                        result.success(false)
                    }
                }
                "startRecording" -> {
                    if (!hasRecordPermission()) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            REQ_RECORD_AUDIO
                        )
                        result.error("PERMISSION_DENIED", "Microphone permission requested", null)
                        return@setMethodCallHandler
                    }
                    try {
                        stopAndReleaseRecorder()
                        val outFile = File(cacheDir, "voice_${System.currentTimeMillis()}.m4a")
                        currentRecordFile = outFile

                        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            MediaRecorder(this)
                        } else {
                            @Suppress("DEPRECATION")
                            MediaRecorder()
                        }

                        recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                        recorder.setAudioSamplingRate(16000)
                        recorder.setAudioEncodingBitRate(24000)
                        recorder.setOutputFile(outFile.absolutePath)
                        recorder.prepare()
                        recorder.start()

                        mediaRecorder = recorder
                        recordStartTimeMs = System.currentTimeMillis()
                        result.success(true)
                    } catch (e: Exception) {
                        stopAndReleaseRecorder()
                        result.error("RECORD_START_FAILED", e.message, null)
                    }
                }
                "stopRecording" -> {
                    try {
                        val elapsedMs = (System.currentTimeMillis() - recordStartTimeMs).coerceAtLeast(500L)
                        mediaRecorder?.apply {
                            try {
                                stop()
                            } catch (_: Exception) {}
                            release()
                        }
                        mediaRecorder = null

                        val file = currentRecordFile
                        currentRecordFile = null
                        if (file != null && file.exists() && file.length() > 0) {
                            val bytes = file.readBytes()
                            file.delete()
                            val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                            result.success(
                                mapOf(
                                    "base64" to b64,
                                    "durationMs" to elapsedMs
                                )
                            )
                        } else {
                            result.error("EMPTY_RECORDING", "No audio recorded", null)
                        }
                    } catch (e: Exception) {
                        stopAndReleaseRecorder()
                        result.error("RECORD_STOP_FAILED", e.message, null)
                    }
                }
                "cancelRecording" -> {
                    stopAndReleaseRecorder()
                    currentRecordFile?.delete()
                    currentRecordFile = null
                    result.success(true)
                }
                "playAudio" -> {
                    val b64 = call.argument<String>("base64") ?: ""
                    val msgId = call.argument<String>("id") ?: "msg"
                    if (b64.isEmpty()) {
                        result.error("INVALID_AUDIO", "Audio payload is empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        stopAndReleasePlayer()
                        val bytes = Base64.decode(b64, Base64.DEFAULT)
                        val tempFile = File(cacheDir, "play_${msgId.hashCode()}.m4a")
                        tempFile.writeBytes(bytes)

                        val player = MediaPlayer()
                        player.setDataSource(tempFile.absolutePath)
                        player.setOnCompletionListener {
                            stopAndReleasePlayer()
                            methodChannel?.invokeMethod("onPlaybackComplete", msgId)
                        }
                        player.setOnErrorListener { _, _, _ ->
                            stopAndReleasePlayer()
                            methodChannel?.invokeMethod("onPlaybackComplete", msgId)
                            true
                        }
                        player.prepare()
                        player.start()
                        mediaPlayer = player
                        result.success(true)
                    } catch (e: Exception) {
                        stopAndReleasePlayer()
                        result.error("PLAY_FAILED", e.message, null)
                    }
                }
                "stopAudio" -> {
                    stopAndReleasePlayer()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasRecordPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun stopAndReleaseRecorder() {
        try {
            mediaRecorder?.apply {
                try {
                    stop()
                } catch (_: Exception) {}
                release()
            }
        } catch (_: Exception) {}
        mediaRecorder = null
    }

    private fun stopAndReleasePlayer() {
        try {
            mediaPlayer?.apply {
                try {
                    if (isPlaying) stop()
                } catch (_: Exception) {}
                release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    override fun onDestroy() {
        stopAndReleaseRecorder()
        stopAndReleasePlayer()
        super.onDestroy()
    }
}
