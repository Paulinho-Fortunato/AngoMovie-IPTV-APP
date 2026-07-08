// lib/services/external_player_service.dart
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../models/channel.dart';

class ExternalPlayerService {
  
  /// Tenta abrir o stream de vídeo diretamente no VLC Player para Android
  static Future<bool> playInVlc(Channel channel) async {
    if (!Platform.isAndroid) return false;

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: Uri.encodeFull(channel.streamUrl),
        type: 'video/*',
        package: 'org.videolan.vlc', // Pacote oficial do VLC no Android
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        arguments: <String, dynamic>{
          'title': channel.name,
        },
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false; // Retorna falso se o VLC não estiver instalado
    }
  }

  /// Tenta abrir o stream de vídeo diretamente no MX Player para Android
  static Future<bool> playInMxPlayer(Channel channel) async {
    if (!Platform.isAndroid) return false;

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: Uri.encodeFull(channel.streamUrl),
        type: 'video/*',
        package: 'com.mxtech.videoplayer.ad', // Pacote oficial do MX Player (Free)
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        arguments: <String, dynamic>{
          'title': channel.name,
        },
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false; // Retorna falso se o MX Player não estiver instalado
    }
  }
}
