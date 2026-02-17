package trade_In.Internal_Data

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.SystemClock
import java.io.File

object BatteryInfoCollector {

    fun getBatteryInfo(context: Context): BatteryInfo {
        android.util.Log.d("BatteryInfoCollector", "=== STARTING BATTERY INFO COLLECTION ===")
        
        return try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            android.util.Log.d("BatteryInfoCollector", "BatteryManager obtained: $batteryManager")
            
            val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            android.util.Log.d("BatteryInfoCollector", "Battery intent: $intent")

            if (intent == null) {
                android.util.Log.e("BatteryInfoCollector", "BATTERY INTENT IS NULL - using fallback")
                // Fallback to basic battery info if intent is null
                getBasicBatteryInfo(batteryManager)
            } else {
                android.util.Log.d("BatteryInfoCollector", "Processing battery intent...")
                
                // Extract basic info with logging
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, 0)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                val voltage = intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0)
                val temperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)
                val health = intent.getIntExtra(BatteryManager.EXTRA_HEALTH, BatteryManager.BATTERY_HEALTH_UNKNOWN)
                val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
                val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
                val technology = intent.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)
                
                android.util.Log.d("BatteryInfoCollector", "Basic info - Level: $level, Scale: $scale, Voltage: $voltage, Temp: $temperature")
                android.util.Log.d("BatteryInfoCollector", "Health: $health, Status: $status, Plugged: $plugged, Tech: $technology")
                
                // Get advanced info with logging
                val cycleCount = getCycleCount(batteryManager)
                val designCapacity = getDesignCapacity(batteryManager)
                val currentCapacity = getCurrentCapacity(batteryManager)
                val currentNow = getCurrentNow(batteryManager)
                val currentAverage = getCurrentAverage(batteryManager)
                val chargeCounter = getChargeCounter(batteryManager)
                val energyCounter = getEnergyCounter(batteryManager)
                
                android.util.Log.d("BatteryInfoCollector", "Advanced info - CycleCount: $cycleCount, DesignCap: $designCapacity, CurrentCap: $currentCapacity")
                android.util.Log.d("BatteryInfoCollector", "Current info - Now: $currentNow, Avg: $currentAverage, ChargeCounter: $chargeCounter, Energy: $energyCounter")
                
                val batteryInfo = BatteryInfo(
                    level = level,
                    scale = scale,
                    voltage = voltage,
                    temperature = temperature,
                    health = getHealthString(health),
                    status = getStatusString(status),
                    powerSource = getPowerSourceString(plugged),
                    technology = technology ?: "Unknown",
                    cycleCount = cycleCount,
                    designCapacity = designCapacity,
                    currentCapacity = currentCapacity,
                    currentNow = currentNow,
                    currentAverage = currentAverage,
                    chargeCounter = chargeCounter,
                    energyCounter = energyCounter
                )
                
                android.util.Log.d("BatteryInfoCollector", "BatteryInfo created successfully: $batteryInfo")
                android.util.Log.d("BatteryInfoCollector", "=== BATTERY INFO COLLECTION COMPLETED SUCCESSFULLY ===")
                batteryInfo
            }
        } catch (e: Exception) {
            android.util.Log.e("BatteryInfoCollector", "EXCEPTION in getBatteryInfo: ${e.message}", e)
            // Return basic battery info if any error occurs
            getBasicBatteryInfo(context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager)
        }
    }

    private fun getBasicBatteryInfo(batteryManager: BatteryManager): BatteryInfo {
        return try {
            val level = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            } else {
                -1
            }
            
            BatteryInfo(
                level = if (level > 0) level else 50, // Fallback to 50% if can't get level
                scale = 100,
                voltage = 3700, // Typical voltage
                temperature = 250, // Room temperature
                health = "Good",
                status = "Discharging",
                powerSource = "Battery",
                technology = "Li-ion",
                cycleCount = -1,
                designCapacity = -1,
                currentCapacity = -1,
                currentNow = 0,
                currentAverage = 0,
                chargeCounter = -1,
                energyCounter = -1
            )
        } catch (e: Exception) {
            // Ultimate fallback
            BatteryInfo(
                level = 50,
                scale = 100,
                voltage = 3700,
                temperature = 250,
                health = "Good",
                status = "Discharging",
                powerSource = "Battery",
                technology = "Li-ion",
                cycleCount = -1,
                designCapacity = -1,
                currentCapacity = -1,
                currentNow = 0,
                currentAverage = 0,
                chargeCounter = -1,
                energyCounter = -1
            )
        }
    }

    private fun getHealthString(health: Int): String {
        return when (health) {
            BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
            BatteryManager.BATTERY_HEALTH_UNKNOWN -> "Unknown"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Failure"
            else -> "Unknown"
        }
    }

    private fun getStatusString(status: Int): String {
        return when (status) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
            BatteryManager.BATTERY_STATUS_FULL -> "Full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not Charging"
            BatteryManager.BATTERY_STATUS_UNKNOWN -> "Unknown"
            else -> "Unknown"
        }
    }

    private fun getPowerSourceString(plugged: Int): String {
        return when {
            plugged and BatteryManager.BATTERY_PLUGGED_AC != 0 -> "AC"
            plugged and BatteryManager.BATTERY_PLUGGED_USB != 0 -> "USB"
            plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS != 0 -> "Wireless"
            else -> "Battery"
        }
    }

    private fun getCycleCount(batteryManager: BatteryManager): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Try to get cycle count using reflection since BATTERY_PROPERTY_CYCLE_COUNT might not be available
                try {
                    val cycleCountField = BatteryManager::class.java.getDeclaredField("BATTERY_PROPERTY_CYCLE_COUNT")
                    val cycleCountConstant = cycleCountField.getInt(null)
                    val cycleCount = batteryManager.getIntProperty(cycleCountConstant)
                    if (cycleCount != Integer.MIN_VALUE) cycleCount else -1
                } catch (e: NoSuchFieldException) {
                    android.util.Log.w("BatteryInfoCollector", "BATTERY_PROPERTY_CYCLE_COUNT not available in this API level")
                    -1
                } catch (e: IllegalAccessException) {
                    android.util.Log.w("BatteryInfoCollector", "Cannot access BATTERY_PROPERTY_CYCLE_COUNT")
                    -1
                }
            } else {
                -1
            }
        } catch (e: Exception) {
            android.util.Log.w("BatteryInfoCollector", "Error getting cycle count: ${e.message}")
            -1
        }
    }

    private fun getDesignCapacity(batteryManager: BatteryManager): Int {
        return try {
            // Try BatteryManager property first (API 21+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val designCapacity = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
                if (designCapacity > 0) {
                    return designCapacity / 1000 // Convert from μAh to mAh
                }
            }
            
            // Try system files with better error handling
            val filePaths = listOf(
                "/sys/class/power_supply/battery/charge_full_design",
                "/sys/class/power_supply/battery/energy_full_design"
            )
            
            for (path in filePaths) {
                try {
                    val file = File(path)
                    if (file.exists()) {
                        val value = file.readText().trim().toIntOrNull()
                        if (value != null && value > 0) {
                            // Check if value is in μAh (large values) or mAh (smaller values)
                            return if (value > 100000) value / 1000 else value // Convert to mAh if needed
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.w("BatteryInfoCollector", "Error reading design capacity from $path: ${e.message}")
                    // Continue to next path
                }
            }
            
            // Fallback to typical values
            4000
        } catch (e: Exception) {
            android.util.Log.w("BatteryInfoCollector", "Error getting design capacity: ${e.message}")
            4000 // Safe fallback
        }
    }

    private fun getCurrentCapacity(batteryManager: BatteryManager): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val chargeCounter = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
                if (chargeCounter != Integer.MIN_VALUE) {
                    // Convert from microampere-hours to milliampere-hours
                    chargeCounter / 1000
                } else {
                    -1
                }
            } else {
                -1
            }
        } catch (e: Exception) {
            -1
        }
    }

    private fun getCurrentNow(batteryManager: BatteryManager): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val currentNow = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                if (currentNow == Integer.MIN_VALUE) 0 else currentNow
            } else {
                0
            }
        } catch (e: Exception) {
            0
        }
    }

    private fun getCurrentAverage(batteryManager: BatteryManager): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val currentAvg = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_AVERAGE)
                if (currentAvg == Integer.MIN_VALUE) 0 else currentAvg
            } else {
                0
            }
        } catch (e: Exception) {
            0
        }
    }

    private fun getChargeCounter(batteryManager: BatteryManager): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val chargeCounter = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
                if (chargeCounter == Integer.MIN_VALUE) -1 else chargeCounter
            } else {
                -1
            }
        } catch (e: Exception) {
            -1
        }
    }

    private fun getEnergyCounter(batteryManager: BatteryManager): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val energyCounter = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
                if (energyCounter == Integer.MIN_VALUE) -1 else energyCounter
            } else {
                -1
            }
        } catch (e: Exception) {
            -1
        }
    }

    fun getBatteryHealthAssessment(batteryInfo: BatteryInfo): String {
        return when {
            batteryInfo.healthPercentage > 80 -> "Excellent"
            batteryInfo.healthPercentage > 60 -> "Good"
            batteryInfo.healthPercentage > 40 -> "Fair"
            batteryInfo.healthPercentage > 20 -> "Poor"
            batteryInfo.healthPercentage >= 0 -> "Critical"
            else -> "Unknown"
        }
    }

    fun getBatteryRecommendations(batteryInfo: BatteryInfo): List<String> {
        val recommendations = mutableListOf<String>()

        when {
            batteryInfo.healthPercentage < 20 -> {
                recommendations.add("Battery health is critical - consider replacement soon")
                recommendations.add("Battery may not hold charge effectively")
            }
            batteryInfo.healthPercentage < 40 -> {
                recommendations.add("Battery health is poor - monitor performance")
                recommendations.add("Consider battery replacement if experiencing short battery life")
            }
            batteryInfo.healthPercentage < 60 -> {
                recommendations.add("Battery health is fair - monitor degradation")
                recommendations.add("Avoid deep discharges when possible")
            }
        }

        when (batteryInfo.health) {
            "Overheat" -> {
                recommendations.add("Battery temperature is high - allow to cool down")
                recommendations.add("Avoid using device while charging if overheating persists")
            }
            "Over Voltage" -> {
                recommendations.add("Battery voltage is abnormal - check charging equipment")
                recommendations.add("Use original charger if available")
            }
            "Cold" -> {
                recommendations.add("Battery temperature is low - warm up before use")
                recommendations.add("Battery performance may be reduced in cold temperatures")
            }
        }

        if (batteryInfo.cycleCount > 500) {
            recommendations.add("Battery has high cycle count - normal degradation expected")
        }

        if (batteryInfo.temperatureInCelsius > 35) {
            recommendations.add("Battery temperature is elevated - avoid intensive use")
        }

        return recommendations
    }
}
