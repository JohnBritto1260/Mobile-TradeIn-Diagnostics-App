# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Battery and diagnostic related classes
-keep class trade_In.Internal_Data.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serialization support
-keepattributes *Annotation*,InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class trade_In.Internal_Data.**$$serializer { *; }
-keepclassmembers class trade_In.Internal_Data.** {
    *** Companion;
}
-keepclasseswithmembers class trade_In.Internal_Data.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep battery related classes
-keep class android.os.BatteryManager { *; }
-keep class android.content.Intent { *; }
-keep class android.content.IntentFilter { *; }

# Keep audio related classes
-keep class android.media.AudioManager { *; }
-keep class android.media.AudioRecord { *; }
-keep class android.media.AudioTrack { *; }

# Keep sensor related classes
-keep class android.hardware.Sensor { *; }
-keep class android.hardware.SensorManager { *; }
-keep class android.os.Vibrator { *; }

# Keep device info related classes
-keep class android.provider.Settings { *; }
-keep class android.os.Build { *; }

# Keep method channel related classes
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.BinaryMessenger { *; }

# Keep permission handler related classes
-keep class com.baseflow.permissionhandler.** { *; }

# Keep vibration related classes
-keep class io.flutter.plugins.vibration.** { *; }

# Keep device info plus related classes
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Keep battery plus related classes
-keep class dev.fluttercommunity.plus.battery.** { *; }

# Optimize and remove unused code
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Keep generic signatures for reflection
-keepattributes Signature

# Keep inline classes
-keepclassmembers class * extends kotlin.Metadata {
    public <init>();
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Google Play Core missing classes - suppress warnings
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
