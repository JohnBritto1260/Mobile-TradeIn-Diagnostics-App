package trade_In.Internal_Data

import android.content.Context
import android.os.VibrationEffect
import android.os.Vibrator

object SensorTests {

    fun testVibration(context: Context): Boolean {
        return try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (vibrator.hasVibrator()) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    vibrator.vibrate(500)
                }
                true
            } else false
        } catch (e: Exception) {
            false
        }
    }
}
