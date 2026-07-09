# ==============================================================================
# AngoMovie IPTV - ProGuard Rules (Otimizado para VLC e Gradle 8.x+)
# ==============================================================================

# 1. Preservar o Flutter Engine e suas Views de Plataforma Nativas
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# 2. MANTER MÉTODOS NATIVOS JNI INTACTOS (CRUCIAL PARA O DECODIFICADOR VLC C++)
# Impede que o compilador R8 quebre a ponte entre o Java e os binários .so do VLC
-keepclasseswithmembernames class * {
    native <methods>;
}

# 3. PROTEGER INTEGRAMENTE O MOTOR VLC (Evita "A carregar transmissão..." infinito)
-keep class org.videolan.** { *; }
-keep interface org.videolan.** { *; }
-keep class de.mrmousse.flutter_vlc_player.** { *; }
-keep interface de.mrmousse.flutter_vlc_player.** { *; }

-dontwarn org.videolan.**
-dontwarn de.mrmousse.flutter_vlc_player.**

# Se estiver usando interfaces de plataforma de vídeo adicionais
-keep class io.flutter.plugins.videoplayer.** { *; }

# 4. Preservar o ExoPlayer (Fallback de segurança)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# 5. Preservar Banco de Dados Local (Hive)
-keep class com.hive.** { *; }
-keep class io.hive.** { *; }
-dontwarn com.hive.**

# 6. Preservar dependências essenciais do Kotlin e AndroidX
-keep class kotlin.** { *; }
-keep class androidx.** { *; }
-dontwarn kotlin.**
-dontwarn androidx.**

# 7. Otimização de logs em modo Release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# 8. Ponto de Entrada da Aplicação
-keep class com.angomovie.angomovie_iptv.MainActivity { *; }
