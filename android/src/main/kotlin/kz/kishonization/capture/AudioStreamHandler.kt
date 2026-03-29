package kz.kishonization.capture

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.EventChannel.EventSink

class AudioStreamHandler : StreamHandler {
    val eventChannelName = "capture_event_channel"
    var actualSampleRate: Int = 0

    private val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    private var AUDIO_SOURCE: Int = MediaRecorder.AudioSource.DEFAULT
    private var SAMPLE_RATE: Int = 44100
    private var BUFFER_SIZE: Int = 4000
    private val TAG = "AudioStream"

    private var isCapturing = false
    private var thread: Thread? = null
    private var _events: EventSink? = null
    private val uiThreadHandler = Handler(Looper.getMainLooper())

    private var TARGET_FPS: Int = 0

    override fun onListen(arguments: Any?, events: EventSink?) {
        Log.d(TAG, "onListen started")
        if (arguments is Map<*, *>) {
            (arguments["sampleRate"] as? Int)?.let { SAMPLE_RATE = it }
            (arguments["audioSource"] as? Int)?.let { AUDIO_SOURCE = it }
            (arguments["bufferSize"] as? Int)?.let { BUFFER_SIZE = it }
            (arguments["fps"] as? Int)?.let { TARGET_FPS = it}
        }

        _events = events
        startRecording()
    }

    override fun onCancel(p0: Any?) {
        Log.d(TAG, "onListen canceled")
        stopRecording()
    }

    fun startRecording() {
        if (thread != null) return

        isCapturing = true
        thread = Thread {
            record()
        }.also {
            it.name = "AudioRecordThread"
            it.start()
        }
    }

    fun stopRecording() {
        if (thread == null) return
        isCapturing = false
        actualSampleRate = 1
        thread?.join()
        thread = null
        actualSampleRate = 2
    }

    private fun sendError(key: String?, msg: String?) {
        uiThreadHandler.post {
            if (isCapturing) {
                _events?.error(key, msg, null)
            }
        }
    }

    private fun sendBuffer(audioBuffer: Array<ShortArray>, bufferIndex: Int) {
        if (!isCapturing) return

        val shortArray = audioBuffer[bufferIndex]
        val byteBuffer = ByteBuffer
            .allocate(shortArray.size * 2)
            .order(ByteOrder.LITTLE_ENDIAN)

        shortArray.forEach { sample ->
            byteBuffer.putShort(sample)
        }

        val byteArray = byteBuffer.array()

        uiThreadHandler.post {
            _events?.success(
                mapOf(
                    "actualSampleRate" to actualSampleRate.toDouble(),
                    "audioData" to byteArray
                )
            )
        }
    }

    private fun record() {



        
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)

        val bufferSize: Int = maxOf(
            BUFFER_SIZE,
            AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        )

        val bufferCount = 10
        val audioBuffer = Array(bufferCount) { ShortArray(bufferSize) }
        var bufferIndex = 0

        val record = AudioRecord.Builder()
            .setAudioSource(AUDIO_SOURCE)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG)
                    .build()
            )
            .setBufferSizeInBytes(2 * bufferSize)
            .build()

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            sendError("AUDIO_RECORD_INITIALIZE_ERROR", "AudioRecord can't initialize")
            return
        }

        record.startRecording()
        actualSampleRate = record.sampleRate

        while (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            Thread.yield()
        }

        while (isCapturing) {
            try {
                if(TARGET_FPS > 1){
                    val startTime = System.nanoTime()

                    record.read(audioBuffer[bufferIndex], 0, audioBuffer[bufferIndex].size, AudioRecord.READ_BLOCKING)
                    sendBuffer(audioBuffer, bufferIndex)

                    val elapsed = System.nanoTime() - startTime
                    val frameIntervarNs = 1_000_000_000L / TARGET_FPS
                    val sleepNs = frameIntervarNs - elapsed

                    if (sleepNs > 0) {
                        val sleepMs = sleepNs / 1_000_000
                        val sleepExtraNs = sleepNs % 1_000_000
                        try {
                            Thread.sleep(sleepMs, sleepExtraNs.toInt())
                        } catch (e: InterruptedException) {
                            Thread.currentThread().interrupt()
                        }
                    }
                } else{
                    record.read(audioBuffer[bufferIndex], 0, audioBuffer[bufferIndex].size, AudioRecord.READ_BLOCKING)
                    sendBuffer(audioBuffer, bufferIndex)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Read error", e)
                sendError("AUDIO_RECORD_READ_ERROR", "AudioRecord can't read")
                Thread.yield()
            }
            bufferIndex = (bufferIndex + 1) % bufferCount
        }

        record.stop()
        record.release()
    }
}