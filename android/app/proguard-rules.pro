# ==============================================================================
# AngoMovie IPTV - ProGuard Rules
# ==============================================================================

# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Keep ExoPlayer (se houver alguma dependência interna)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ------------------------------------------------------------------------------
# REGRAS CRUCIAL: Flutter VLC Player & LibVLC (Evita tela preta no APK Release)
# ------------------------------------------------------------------------------
-keep class org.videolan.libvlc.** { *; }
-keep class de.mrmousse.flutter_vlc_player.** { *; }
-dontwarn org.videolan.libvlc.**
-dontwarn de.mrmousse.flutter_vlc_player.**

# Se estiver usando o pacote atualizado flutter_vlc_player_platform_interface
-keep class io.flutter.plugins.videoplayer.** { *; }
# ------------------------------------------------------------------------------

# Keep Hive (Banco de dados local)
-keep class com.hive.** { *; }
-keep class io.hive.** { *; }

# Keep Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Keep AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Remove debug logs in release (Otimização de tamanho e performance)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep app entry points
-keep class com.angomovie.angomovie_iptv.MainActivity { *; }
