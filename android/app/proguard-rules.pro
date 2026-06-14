# AngoMovie IPTV - ProGuard Rules
# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Keep video player
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Keep Hive
-keep class com.hive.** { *; }

# Keep Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Keep AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep app entry points
-keep class com.angomovie.angomovie_iptv.MainActivity { *; }
