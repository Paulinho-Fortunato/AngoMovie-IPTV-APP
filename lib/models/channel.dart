import 'package:hive/hive.dart';

part 'channel.g.dart';

@HiveType(typeId: 0)
class Channel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String streamUrl;

  @HiveField(3)
  final String logoUrl;

  @HiveField(4)
  final String groupTitle;

  @HiveField(5)
  final String? tvgId;

  @HiveField(6)
  final bool isHttpStream;

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.logoUrl,
    required this.groupTitle,
    this.tvgId,
    required this.isHttpStream,
  });

  factory Channel.fromM3uEntry(Map<String, String> entry) {
    final url = entry['url'] ?? '';
    return Channel(
      id: entry['tvg-id'] ?? url.hashCode.toString(),
      name: entry['tvg-name'] ?? entry['name'] ?? 'Canal Desconhecido',
      streamUrl: url,
      logoUrl: entry['tvg-logo'] ?? '',
      groupTitle: entry['group-title'] ?? 'Geral',
      tvgId: entry['tvg-id'],
      isHttpStream: url.startsWith('http://'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'logoUrl': logoUrl,
        'groupTitle': groupTitle,
        'tvgId': tvgId,
        'isHttpStream': isHttpStream,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        streamUrl: json['streamUrl'] ?? json['stream_url'] ?? '',
        logoUrl: json['logoUrl'] ?? json['logo_url'] ?? '',
        groupTitle: json['groupTitle'] ?? json['group_title'] ?? '',
        tvgId: json['tvgId'] ?? json['tvg_id'],
        isHttpStream: json['isHttpStream'] ?? json['is_http'] ?? false,
      );
}
