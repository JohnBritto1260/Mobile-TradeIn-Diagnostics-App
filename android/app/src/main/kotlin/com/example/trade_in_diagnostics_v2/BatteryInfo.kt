package trade_In.Internal_Data

data class BatteryInfo(
    val level: Int = 0,
    val scale: Int = 100,
    val voltage: Int = 0,
    val temperature: Int = 0,
    val health: String = "Unknown",
    val status: String = "Unknown",
    val powerSource: String = "Battery",
    val technology: String = "Unknown",
    val cycleCount: Int = -1,
    val designCapacity: Int = -1,
    val currentCapacity: Int = -1,
    val currentNow: Int = 0,
    val currentAverage: Int = 0,
    val chargeCounter: Int = -1,
    val energyCounter: Int = -1
) {
    val healthPercentage: Int
        get() = if (designCapacity > 0 && currentCapacity > 0) {
            ((currentCapacity * 100) / designCapacity).coerceIn(0, 100)
        } else {
            -1
        }

    val voltageInVolts: Double
        get() = voltage / 1000.0

    val temperatureInCelsius: Double
        get() = temperature / 10.0

    val temperatureInFahrenheit: Double
        get() = (temperatureInCelsius * 9/5) + 32

    val isCharging: Boolean
        get() = status == "Charging" || status == "Full" || powerSource != "Battery"

    val currentInMa: Double
        get() = if (currentNow != 0) currentNow / 1000.0 else 0.0

    val averageCurrentInMa: Double
        get() = if (currentAverage != 0) currentAverage / 1000.0 else 0.0

    val capacityInMah: Int
        get() = if (currentCapacity > 0) currentCapacity else -1

    val designCapacityInMah: Int
        get() = if (designCapacity > 0) designCapacity else -1

    fun toMap(): Map<String, Any> {
        return mapOf(
            "level" to level,
            "scale" to scale,
            "voltage" to voltage,
            "temperature" to temperature,
            "health" to health,
            "status" to status,
            "powerSource" to powerSource,
            "technology" to technology,
            "cycleCount" to cycleCount,
            "designCapacity" to designCapacity,
            "currentCapacity" to currentCapacity,
            "currentNow" to currentNow,
            "currentAverage" to currentAverage,
            "chargeCounter" to chargeCounter,
            "energyCounter" to energyCounter,
            "healthPercentage" to healthPercentage,
            "voltageInVolts" to voltageInVolts,
            "temperatureInCelsius" to temperatureInCelsius,
            "temperatureInFahrenheit" to temperatureInFahrenheit,
            "isCharging" to isCharging,
            "currentInMa" to currentInMa,
            "averageCurrentInMa" to averageCurrentInMa,
            "capacityInMah" to capacityInMah,
            "designCapacityInMah" to designCapacityInMah
        )
    }
}
