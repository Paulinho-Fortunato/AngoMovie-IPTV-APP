import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:angomovie_iptv/models/channel.dart';
import 'package:angomovie_iptv/services/local_media_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.angomovie.iptv/local_media');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('favorite toggle sends metadata but never a stream URL', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return true;
    });

    final isFavorite = await LocalMediaStore.toggleFavorite(_channel());

    expect(isFavorite, isTrue);
    expect(receivedCall?.method, 'favorites.toggle');
    final arguments = Map<String, Object?>.from(receivedCall!.arguments as Map);
    expect(arguments['channelId'], 'channel-1');
    expect(arguments.containsKey('streamUrl'), isFalse);
    expect(arguments.containsKey('url'), isFalse);
  });

  test('legacy favorites are imported once without URLs', () async {
    Map<Object?, Object?>? receivedArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedArguments = call.arguments as Map<Object?, Object?>;
      return true;
    });

    await LocalMediaStore.migrateLegacyFavorites(<Channel>[_channel(favorite: true)]);
    await LocalMediaStore.migrateLegacyFavorites(<Channel>[_channel(favorite: true)]);

    expect(receivedArguments?['channels'], hasLength(1));
    final imported = (receivedArguments!['channels'] as List).single as Map;
    expect(imported['channelId'], 'channel-1');
    expect(imported.containsKey('streamUrl'), isFalse);
    expect(imported.containsKey('url'), isFalse);
  });

  test('history response is decoded into typed entries', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'history.record') {
        return <String, Object?>{
          'channelId': 'channel-1',
          'name': 'Canal de teste',
          'logoUrl': '',
          'groupTitle': 'Angola',
          'tvgId': null,
          'lastPlayedAt': 1234,
          'playCount': 2,
        };
      }
      if (call.method == 'history.list') {
        return <Object?>[
          <String, Object?>{
            'channelId': 'channel-1',
            'name': 'Canal de teste',
            'logoUrl': '',
            'groupTitle': 'Angola',
            'tvgId': null,
            'lastPlayedAt': 1234,
            'playCount': 2,
          },
        ];
      }
      return null;
    });

    final recorded = await LocalMediaStore.recordPlayback(_channel());
    final history = await LocalMediaStore.getWatchHistory();

    expect(recorded.playCount, 2);
    expect(history, hasLength(1));
    expect(history.single.channelId, 'channel-1');
    expect(history.single.lastPlayedAt, 1234);
  });
}

Channel _channel({bool favorite = false}) => Channel(
      id: 'channel-1',
      name: 'Canal de teste',
      streamUrl: 'https://stream.example/live.m3u8?token=private',
      logoUrl: '',
      groupTitle: 'Angola',
      tvgId: 'tvg-1',
      isHttpStream: false,
      isFavorite: favorite,
    );
