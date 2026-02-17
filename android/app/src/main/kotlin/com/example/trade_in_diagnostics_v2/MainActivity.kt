package trade_In.Internal_Data

import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val POWER_BUTTON_CHANNEL = "trade_In.Internal_Data/power_button"
    private val VOLUME_BUTTON_CHANNEL = "trade_In.Internal_Data/volume_buttons"
    private val AUDIO_CHANNEL = "trade_In.Internal_Data/audio"
    private var powerButtonReceiver: PowerButtonReceiver? = null
    private var volumeButtonReceiver: VolumeButtonReceiver? = null
    private lateinit var diagnosticsMethodChannel: DiagnosticsMethodChannel

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        configureWindowForFullScreen()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Diagnostics method channel (already in your code)
        diagnosticsMethodChannel = DiagnosticsMethodChannel(this)
        diagnosticsMethodChannel.configureFlutterEngine(flutterEngine)

        // Power button event channel (broadcast receiver approach)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_BUTTON_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    powerButtonReceiver = PowerButtonReceiver(events)
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_SCREEN_ON)
                        addAction(Intent.ACTION_SCREEN_OFF)
                        addAction(Intent.ACTION_USER_PRESENT)
                    }
                    registerReceiver(powerButtonReceiver, filter)
                    android.util.Log.d("MainActivity", "Power button receiver registered with intents: SCREEN_ON, SCREEN_OFF, USER_PRESENT")
                }

                override fun onCancel(arguments: Any?) {
                    powerButtonReceiver?.let { unregisterReceiver(it) }
                    powerButtonReceiver = null
                    android.util.Log.d("MainActivity", "Power button receiver unregistered")
                }
            }
        )

        // Volume button event channel (new feature)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_BUTTON_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeButtonReceiver = VolumeButtonReceiver(events)
                    val filter = IntentFilter().apply {
                        addAction("android.media.VOLUME_CHANGED_ACTION")
                    }
                    registerReceiver(volumeButtonReceiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    volumeButtonReceiver?.let { unregisterReceiver(it) }
                    volumeButtonReceiver = null
                }
            }
        )

        // 🔊 Audio test channel for microphone testing + streaming amplitude
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "testMicrophone" -> {
                        Thread {
                            val testResult = AudioTests.testMicrophone()
                            runOnUiThread { result.success(testResult) }
                        }.start()
                    }


                    else -> result.notImplemented()
                }
            }
    }

    private fun configureWindowForFullScreen() {
        window.apply {
            setFlags(
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            )

            attributes = attributes.apply {
                softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            }

            clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
            clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                statusBarColor = android.graphics.Color.TRANSPARENT
                navigationBarColor = android.graphics.Color.TRANSPARENT
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insetsController?.apply {
                    hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                    systemBarsBehavior =
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                decorView.systemUiVisibility = (
                        View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                                or View.SYSTEM_UI_FLAG_FULLSCREEN
                                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        configureWindowForFullScreen()
    }


    override fun onDestroy() {
        super.onDestroy()
        powerButtonReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        powerButtonReceiver = null
        
        volumeButtonReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        volumeButtonReceiver = null
    }
}
