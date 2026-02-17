package trade_In.Internal_Data

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log
import io.flutter.plugin.common.EventChannel

class VolumeButtonReceiver(private val events: EventChannel.EventSink?) : BroadcastReceiver() {
    
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action
        Log.d("VolumeButtonReceiver", "Received intent: $action")
        
        when (action) {
            "android.media.VOLUME_CHANGED_ACTION" -> {
                // This broadcast is sent when volume changes
                // We need to determine which button was pressed
                val audioManager = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                val newVolume = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1)
                val oldVolume = intent.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1)
                
                Log.d("VolumeButtonReceiver", "Volume changed: stream=$streamType, old=$oldVolume, new=$newVolume")
                
                // Check for any volume stream type, not just MUSIC
                if (audioManager != null) {
                    if (newVolume > oldVolume) {
                        Log.d("VolumeButtonReceiver", "Volume UP detected")
                        events?.success("VOLUME_UP")
                    } else if (newVolume < oldVolume) {
                        Log.d("VolumeButtonReceiver", "Volume DOWN detected")
                        events?.success("VOLUME_DOWN")
                    }
                }
            }
        }
    }
}
