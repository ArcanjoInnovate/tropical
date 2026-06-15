// lib/models/gallery_item_model.dart

class GalleryItem {
  final String id;
  final String userId;
  final String type;      // 'foto' | 'video'
  final String mediaUrl;
  final String? thumbUrl;

  /// URL da capa personalizada definida pelo usuário.
  /// Para vídeos: substitui [thumbUrl] no grid e no player.
  /// Para fotos: não é usado (foto já é a própria capa).
  final String? coverUrl;

  final int? videoDuration;
  final DateTime createdAt;

  const GalleryItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.mediaUrl,
    this.thumbUrl,
    this.coverUrl,
    this.videoDuration,
    required this.createdAt,
  });

  /// URL que deve ser usada como thumbnail no grid e no feed.
  /// Prioridade: coverUrl > thumbUrl > null.
  String? get displayThumb => coverUrl?.isNotEmpty == true ? coverUrl : thumbUrl;

  /// Constrói a partir de um Map com o [id] já embutido no próprio map
  /// (padrão usado pelo GalleryService — o id vem da chave do Firebase).
  factory GalleryItem.fromMap(Map<dynamic, dynamic> map) {
    final id = (map['id'] as String?)?.trim() ?? '';
    return GalleryItem(
      id:            id,
      userId:        (map['user_id'] ?? map['userId'])  as String? ?? '',
      type:          map['type']           as String? ?? 'foto',
      mediaUrl:      map['media_url']      as String? ?? '',
      thumbUrl:      map['thumb_url']      as String?,
      coverUrl:      map['cover_url']      as String?,
      videoDuration: (map['video_duration'] as num?)?.toInt(),
      createdAt:     DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Constrói a partir de uma chave Firebase separada do map de dados.
  /// Use quando o id NÃO está embutido no map (ex: ao ler um nó único).
  factory GalleryItem.fromEntry(String id, Map<dynamic, dynamic> map) {
    return GalleryItem(
      id:            id,
      userId:        map['user_id']        as String? ?? '',
      type:          map['type']           as String? ?? 'foto',
      mediaUrl:      map['media_url']      as String? ?? '',
      thumbUrl:      map['thumb_url']      as String?,
      coverUrl:      map['cover_url']      as String?,
      videoDuration: (map['video_duration'] as num?)?.toInt(),
      createdAt:     DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id':        userId,
      'type':           type,
      'media_url':      mediaUrl,
      if (thumbUrl != null)      'thumb_url':      thumbUrl,
      if (coverUrl != null && coverUrl!.isNotEmpty) 'cover_url': coverUrl,
      if (videoDuration != null) 'video_duration':  videoDuration,
      'created_at':     createdAt.millisecondsSinceEpoch,
    };
  }

  GalleryItem copyWith({String? coverUrl}) {
    return GalleryItem(
      id:            id,
      userId:        userId,
      type:          type,
      mediaUrl:      mediaUrl,
      thumbUrl:      thumbUrl,
      coverUrl:      coverUrl ?? this.coverUrl,
      videoDuration: videoDuration,
      createdAt:     createdAt,
    );
  }
}

