package kz.kishonization.capture

import android.util.Log
import android.os.SystemClock
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kz.kishonization.capture.AudioStreamHandler


/** CapturePlugin */
class CapturePlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private val audioStreamHandler = AudioStreamHandler()
  private val TAG = "Capture"

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    val messenger = flutterPluginBinding.binaryMessenger
    methodChannel = MethodChannel(messenger, "capture_method_channel")
    eventChannel = EventChannel(messenger, audioStreamHandler.eventChannelName)

    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(audioStreamHandler)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "init" -> {
        // For now, we do nothing to init on android
        result.success(true)
      }
      "getSampleRate" -> {
        result.success(audioStreamHandler.actualSampleRate.toDouble())
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }
}
