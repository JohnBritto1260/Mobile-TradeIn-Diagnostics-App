package trade_In.Internal_Data

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.EventChannel

class PowerButtonReceiver(private val events: EventChannel.EventSink?) : BroadcastReceiver() {
    
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action
        Log.d("PowerButtonReceiver", "Received intent: $action")
        
        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.d("PowerButtonReceiver", "Screen OFF detected - Power button pressed (first press)")
                events?.success("SCREEN_OFF")
            }
            Intent.ACTION_SCREEN_ON -> {
                Log.d("PowerButtonReceiver", "Screen ON detected - Power button pressed (second press)")
                events?.success("SCREEN_ON")
            }
            Intent.ACTION_USER_PRESENT -> {
                Log.d("PowerButtonReceiver", "User present (unlock) detected")
                events?.success("USER_PRESENT")
            }
        }
    }
}
