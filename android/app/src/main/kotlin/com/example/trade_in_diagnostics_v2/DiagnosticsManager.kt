package trade_In.Internal_Data

import android.content.Context
import android.provider.Settings

object DiagnosticsManager {

    fun getDeviceInfo(context: Context): Map<String, Any> {
        val deviceId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val model = android.os.Build.MODEL
        val manufacturer = android.os.Build.MANUFACTURER
        val osVersion = android.os.Build.VERSION.RELEASE
        // Use Device Name (user-set name) for "Product" since marketing name is not available via system properties
        var product = Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
        if (product == null) {
            product = Settings.Secure.getString(context.contentResolver, "bluetooth_name")
        }
        if (product == null) {
             product = android.os.Build.MODEL // Fallback to model if no name found
        }

        var serial = "Unknown"
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                try {
                    // Requires Manifest.permission.READ_PHONE_STATE
                    if (context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                         serial = android.os.Build.getSerial()
                    } else {
                         serial = "Permission Denied"
                    }
                } catch (e: SecurityException) {
                    serial = "Permission Denied" 
                }
            } else {
                serial = android.os.Build.SERIAL
            }
        } catch (e: Exception) {
            serial = "Unknown"
        }

        return mapOf(
            "deviceId" to deviceId,
            "manufacturer" to manufacturer,
            "model" to model,
            "osVersion" to osVersion,
            "product" to product,
            "serial" to serial
        )
    }

    fun runDiagnostics(context: Context): Map<String, Any> {
        val speakerWorking = AudioTests.testSpeaker(context)
        val micWorking = AudioTests.testMicrophone()
        val vibrationWorking = SensorTests.testVibration(context)

        return mapOf(
            "speakerWorking" to speakerWorking,
            "microphoneWorking" to micWorking,
            "vibrationWorking" to vibrationWorking
        )
    }

    /**
     * Attempts to retrieve the device marketing name (e.g., "Galaxy S22", "Galaxy Z Flip5")
     * Falls back to Build.MODEL if marketing name is not available
     */
    private fun getMarketingName(): String {
        return try {
            // Try multiple system properties in order of preference
            val propertyKeys = listOf(
                "ro.product.marketname",
                "ro.product.model.name",
                "ro.config.marketing_name",
                "ro.product.vendor.marketname",
                "ro.product.odm.marketname",
                "ro.product.system.marketname",
                "ro.product.model",
                "ro.product.vendor.model",
                "ro.product.name"
            )
            
            var marketingName: String? = null
            for (key in propertyKeys) {
                val value = getSystemProperty(key)
                android.util.Log.d("DiagnosticsManager", "Property $key = $value")
                if (!value.isNullOrBlank() && value != android.os.Build.MODEL) {
                    marketingName = value
                    android.util.Log.d("DiagnosticsManager", "Using marketing name from $key: $value")
                    break
                }
            }
            
            marketingName ?: android.os.Build.MODEL.also {
                android.util.Log.d("DiagnosticsManager", "Falling back to Build.MODEL: $it")
            }
        } catch (e: Exception) {
            android.util.Log.e("DiagnosticsManager", "Error getting marketing name", e)
            android.os.Build.MODEL
        }
    }

    /**
     * Reads a system property using reflection
     */
    private fun getSystemProperty(key: String): String? {
        return try {
            val systemProperties = Class.forName("android.os.SystemProperties")
            val getMethod = systemProperties.getMethod("get", String::class.java)
            val value = getMethod.invoke(null, key) as? String
            if (value.isNullOrBlank()) null else value
        } catch (e: Exception) {
            null
        }
    }
}
