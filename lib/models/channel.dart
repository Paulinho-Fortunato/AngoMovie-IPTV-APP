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

  // Campo de Favoritos para Alta Performance no IPTV
  @HiveField(7)
  bool isFavorite;

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.logoUrl,
    required this.groupTitle,
    this.tvgId,
    required this.isHttpStream,
    this.isFavorite = false, // Falso por padrão
  });

  /// Converte uma entrada parseada do arquivo M3U em um Canal mapeado
  factory Channel.fromM3uEntry(Map<String, String> entry) {
    final url = entry['url']?.trim() ?? '';
    
    // Tratamento rigoroso contra strings vazias de tvg-id para evitar colisão de dados
    final rawTvgId = entry['tvg-id']?.trim();
    final hasValidTvgId = rawTvgId != null && rawTvgId.isNotEmpty;
    
    // Se o tvg-id for inválido/vazio, gera um hash seguro e absoluto baseado na URL e no Nome
    final fallbackId = '${(entry['name'] ?? '').hashCode.abs()}_${url.hashCode.abs()}';
    final id = hasValidTvgId ? rawTvgId : fallbackId;

    return Channel(
      id: id,
      name: entry['tvg-name']?.trim() ?? entry['name']?.trim() ?? 'Canal Desconhecido',
      streamUrl: url,
      logoUrl: entry['tvg-logo']?.trim() ?? '',
      groupTitle: entry['group-title']?.trim() ?? 'Geral',
      tvgId: hasValidTvgId ? rawTvgId : null,
      isHttpStream: url.toLowerCase().startsWith('http://'),
      isFavorite: false,
    );
  }

  /// Método utilitário para criar cópias mutáveis do estado do modelo
  Channel copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? logoUrl,
    String? groupTitle,
    String? tvgId,
    bool? isHttpStream,
    bool? isFavorite,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      groupTitle: groupTitle ?? this.groupTitle,
      tvgId: tvgId ?? this.tvgId,
      isHttpStream: isHttpStream ?? this.isHttpStream,
      isFavorite: isFavorite ?? this.isFavorite,
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
        'isFavorite': isFavorite,
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        streamUrl: json['streamUrl'] ?? json['stream_url'] ?? '',
        logoUrl: json['logoUrl'] ?? json['logo_url'] ?? '',
        groupTitle: json['groupTitle'] ?? json['group_title'] ?? '',
        tvgId: json['tvgId'] ?? json['tvg_id'],
        isHttpStream: json['isHttpStream'] ?? json['is_http'] ?? false,
        isFavorite: json['isFavorite'] ?? json['is_favorite'] ?? false,
      );
}
