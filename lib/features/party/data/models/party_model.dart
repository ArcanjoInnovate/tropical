// lib/models/party_model.dart

class PartyModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final String nome;
  final String descricao;

  /// Endereço do evento. Pode ser nulo quando ainda não confirmado pelo criador.
  final String? local;

  final String? bairro;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String? bannerUrl;
  final int interessados;
  final int confirmados;
  final int commentCount;
  final DateTime createdAt;

  /// 'ativa' | 'arquivada'
  final String status;

  const PartyModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    required this.nome,
    required this.descricao,
    this.local,
    this.bairro,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    required this.dataInicio,
    required this.dataFim,
    this.bannerUrl,
    this.interessados = 0,
    this.confirmados = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.status = 'ativa',
  });

  bool get hasCoords => latitude != null && longitude != null;
  bool get isAtiva => status == 'ativa';
  bool get isArquivada => status == 'arquivada';
  bool get estaVencida => DateTime.now().isAfter(dataFim);
  bool get hasLocal => local != null && local!.trim().isNotEmpty;
  bool get canShowDistance => hasCoords && hasLocal;

  factory PartyModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final localRaw = map['local'] as String?;
    final localStr = (localRaw != null && localRaw.trim().isNotEmpty)
        ? localRaw
        : null;

    // Bairro explícito tem prioridade; se não existir, extrai da string local
    // como fallback para festas criadas antes do campo bairro ser adicionado.
    // Formato esperado do local: "Bairro, Cidade - UF"  ou  "Cidade - UF"
    String? bairro = map['bairro'] as String?;
    if ((bairro == null || bairro.isEmpty) && localStr != null) {
      bairro = _extractBairroFromLocal(localStr);
    }
    if (bairro != null && bairro.isEmpty) bairro = null;

    return PartyModel(
      id: id,
      creatorId: (map['creator_id'] ?? map['creator_uid'] ?? '') as String,
      creatorName: map['creator_name'] as String? ?? '',
      creatorAvatar: map['creator_avatar'] as String?,
      nome: (map['nome'] ?? map['name'] ?? '') as String,
      descricao: map['descricao'] as String? ?? '',
      local: localStr,
      bairro: bairro,
      city: map['city'] as String?,
      state: map['state'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      dataInicio: DateTime.fromMillisecondsSinceEpoch(
          (map['data_inicio'] as num).toInt()),
      dataFim:
          DateTime.fromMillisecondsSinceEpoch((map['data_fim'] as num).toInt()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num).toInt()),
      bannerUrl: map['banner_url'] as String?,
      interessados: (map['interessados'] as num? ?? 0).toInt(),
      confirmados: (map['confirmados'] as num? ?? 0).toInt(),
      commentCount: (map['comment_count'] as num? ?? 0).toInt(),
      status: map['status'] as String? ?? 'ativa',
    );
  }

  /// Extrai o bairro de uma string local no formato "Bairro, Cidade - UF".
  /// Se o local tiver apenas "Cidade - UF" (sem bairro), retorna null.
  static String? _extractBairroFromLocal(String local) {
    // Formato com bairro: "Residencial Buena Vista, Goiânia - GO"
    // Formato sem bairro: "Goiânia - GO"
    // Detecta presença de " - " que indica "Cidade - UF" no último segmento
    final parts = local.split(', ');
    if (parts.length < 2) return null; // só "Cidade - UF", sem bairro

    // O último segmento deve ser "Cidade - UF"
    final last = parts.last;
    if (!last.contains(' - ')) return null;

    // Tudo antes do último segmento é o bairro
    final bairroParts = parts.sublist(0, parts.length - 1);
    final extracted = bairroParts.join(', ').trim();
    return extracted.isNotEmpty ? extracted : null;
  }

  Map<String, dynamic> toMap() => {
        'creator_id': creatorId,
        'creator_uid': creatorId,
        'creator_name': creatorName,
        if (creatorAvatar != null) 'creator_avatar': creatorAvatar,
        'nome': nome,
        'name': nome,
        'descricao': descricao,
        if (hasLocal) 'local': local,
        if (bairro != null) 'bairro': bairro,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'data_inicio': dataInicio.millisecondsSinceEpoch,
        'data_fim': dataFim.millisecondsSinceEpoch,
        if (bannerUrl != null) 'banner_url': bannerUrl,
        'created_at': createdAt.millisecondsSinceEpoch,
        'status': status,
      };

  PartyModel copyWith({String? status, String? local}) => PartyModel(
        id: id,
        creatorId: creatorId,
        creatorName: creatorName,
        creatorAvatar: creatorAvatar,
        nome: nome,
        descricao: descricao,
        local: local ?? this.local,
        bairro: bairro,
        city: city,
        state: state,
        latitude: latitude,
        longitude: longitude,
        dataInicio: dataInicio,
        dataFim: dataFim,
        bannerUrl: bannerUrl,
        interessados: interessados,
        confirmados: confirmados,
        commentCount: commentCount,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}

enum FestaPresenca { nenhuma, interessado, confirmado }

