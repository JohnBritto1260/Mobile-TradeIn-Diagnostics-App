package trade_In.Internal_Data

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DiagnosticsMethodChannel(private val context: Context) {
    
    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "trade_In.Internal_Data/diagnostics"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "testSpeaker" -> {
                    val speakerWorking = AudioTests.testSpeaker(context)
                    result.success(speakerWorking)
                }
                "testMicrophone" -> {
                    val micWorking = AudioTests.testMicrophone()
                    result.success(micWorking)
                }
                "testVibration" -> {
                    val vibrationWorking = SensorTests.testVibration(context)
                    result.success(vibrationWorking)
                }
                "getDeviceInfo" -> {
                    val deviceInfo = DiagnosticsManager.getDeviceInfo(context)
                    result.success(deviceInfo)
                }
                "getBatteryInfo" -> {
                    android.util.Log.d("DiagnosticsMethodChannel", "=== METHOD CALL: getBatteryInfo ===")
                    try {
                        val batteryInfo = BatteryInfoCollector.getBatteryInfo(context)
                        android.util.Log.d("DiagnosticsMethodChannel", "BatteryInfo obtained, converting to map")
                        val batteryMap = batteryInfo.toMap()
                        android.util.Log.d("DiagnosticsMethodChannel", "BatteryInfo map: $batteryMap")
                        result.success(batteryMap)
                        android.util.Log.d("DiagnosticsMethodChannel", "=== getBatteryInfo COMPLETED SUCCESSFULLY ===")
                    } catch (e: Exception) {
                        android.util.Log.e("DiagnosticsMethodChannel", "EXCEPTION in getBatteryInfo: ${e.message}", e)
                        result.error("BATTERY_ERROR", "Failed to get battery info: ${e.message}", null)
                    }
                }
                "getBatteryHealthAssessment" -> {
                    android.util.Log.d("DiagnosticsMethodChannel", "=== METHOD CALL: getBatteryHealthAssessment ===")
                    try {
                        val batteryInfo = BatteryInfoCollector.getBatteryInfo(context)
                        android.util.Log.d("DiagnosticsMethodChannel", "BatteryInfo obtained for health assessment: $batteryInfo")
                        val assessment = BatteryInfoCollector.getBatteryHealthAssessment(batteryInfo)
                        android.util.Log.d("DiagnosticsMethodChannel", "Health assessment: $assessment")
                        result.success(assessment)
                        android.util.Log.d("DiagnosticsMethodChannel", "=== getBatteryHealthAssessment COMPLETED SUCCESSFULLY ===")
                    } catch (e: Exception) {
                        android.util.Log.e("DiagnosticsMethodChannel", "EXCEPTION in getBatteryHealthAssessment: ${e.message}", e)
                        result.error("BATTERY_ERROR", "Failed to get battery health assessment: ${e.message}", null)
                    }
                }
                "getBatteryRecommendations" -> {
                    android.util.Log.d("DiagnosticsMethodChannel", "=== METHOD CALL: getBatteryRecommendations ===")
                    try {
                        val batteryInfo = BatteryInfoCollector.getBatteryInfo(context)
                        android.util.Log.d("DiagnosticsMethodChannel", "BatteryInfo obtained for recommendations: $batteryInfo")
                        val recommendations = BatteryInfoCollector.getBatteryRecommendations(batteryInfo)
                        android.util.Log.d("DiagnosticsMethodChannel", "Battery recommendations: $recommendations")
                        result.success(recommendations)
                        android.util.Log.d("DiagnosticsMethodChannel", "=== getBatteryRecommendations COMPLETED SUCCESSFULLY ===")
                    } catch (e: Exception) {
                        android.util.Log.e("DiagnosticsMethodChannel", "EXCEPTION in getBatteryRecommendations: ${e.message}", e)
                        result.error("BATTERY_ERROR", "Failed to get battery recommendations: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Configure audio method channel for the new microphone test screen
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "trade_In.Internal_Data/audio"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "testMicrophone" -> {
                    val micWorking = AudioTests.testMicrophone()
                    result.success(micWorking)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Configure audio event channel for real-time amplitude streaming
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "trade_In.Internal_Data/audio_amplitude"
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var amplitudeThread: Thread? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    amplitudeThread = Thread {
                        AudioTests.streamMicrophoneAmplitude { amplitude ->
                            Handler(Looper.getMainLooper()).post {
                                events?.success(amplitude)
                            }
                        }
                    }
                    amplitudeThread?.start()
                }

                override fun onCancel(arguments: Any?) {
                    amplitudeThread?.interrupt()
                    amplitudeThread = null
                }
            }
        )
    }
}
