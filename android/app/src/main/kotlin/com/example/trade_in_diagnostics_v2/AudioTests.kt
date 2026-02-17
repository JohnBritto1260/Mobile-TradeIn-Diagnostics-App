package trade_In.Internal_Data

import android.content.Context
import android.media.*
import android.os.*
import kotlin.math.abs
import kotlin.math.max

object AudioTests {

    fun testSpeaker(context: Context): Boolean {
        var player: MediaPlayer? = null
        var success = false

        return try {
            // Create a simple tone using MediaPlayer
            player = MediaPlayer.create(context, android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            
            if (player == null) {
                // Try with a different system sound
                player = MediaPlayer.create(context, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
            }
            
            if (player == null) {
                // Try with a click sound
                player = MediaPlayer.create(context, android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            }
            
            if (player != null) {
                // Set volume to maximum
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                val originalVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC), 0)
                
                player.setOnCompletionListener {
                    // Restore original volume
                    audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, originalVolume, 0)
                    success = true
                }
                
                player.setOnErrorListener { _, _, _ ->
                    // Restore original volume
                    audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, originalVolume, 0)
                    success = false
                    true
                }
                
                player.start()
                
                // Wait for playback to complete (max 3 seconds)
                var waitTime = 0
                while (player.isPlaying && waitTime < 3000) {
                    Thread.sleep(100)
                    waitTime += 100
                }
                
                // Restore original volume if not already done
                audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, originalVolume, 0)
                
                success = player.isPlaying || waitTime < 3000
            } else {
                success = false
            }
            
            success
        } catch (e: Exception) {
            e.printStackTrace()
            false
        } finally {
            try {
                player?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun testMicrophone(): Boolean {
        var recorder: AudioRecord? = null

        return try {
            val sampleRate = 44100
            val bufferSize = max(
                AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                ), 4096
            )

            recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            if (recorder.state == AudioRecord.STATE_UNINITIALIZED) return false

            val buffer = ShortArray(bufferSize)
            recorder.startRecording()

            val start = System.currentTimeMillis()
            val duration = 5000L
            val amplitudes = mutableListOf<Double>()

            while (System.currentTimeMillis() - start < duration) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read > 0) {
                    val amp = buffer.take(read).map { abs(it.toInt()) }.average()
                    amplitudes.add(amp)
                }
            }

            recorder.stop()

            val avg = amplitudes.average()
            val maxAmp = amplitudes.maxOrNull() ?: 0.0
            val activeRatio = amplitudes.count { it > 600 } / amplitudes.size.toDouble()

            avg > 500 && maxAmp > 1000 && activeRatio > 0.25
        } catch (e: Exception) {
            e.printStackTrace()
            false
        } finally {
            try {
                recorder?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun streamMicrophoneAmplitude(callback: (Double) -> Unit) {
        var recorder: AudioRecord? = null
        try {
            val sampleRate = 44100
            val bufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(2048)

            recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            if (recorder.state == AudioRecord.STATE_UNINITIALIZED) {
                callback(-1.0)
                return
            }

            val buffer = ShortArray(bufferSize)
            recorder.startRecording()
            val start = System.currentTimeMillis()
            val duration = 5000L

            while (System.currentTimeMillis() - start < duration) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read > 0) {
                    val amplitude = buffer.take(read).map { abs(it.toInt()) }.average()
                    callback(amplitude)
                }
                Thread.sleep(50) // Send amplitude data every 50ms for smooth waveform
            }

            recorder.stop()
        } catch (e: Exception) {
            e.printStackTrace()
            callback(-1.0)
        } finally {
            try {
                recorder?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
