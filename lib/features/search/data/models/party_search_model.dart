// lib/features/search/data/models/party_search_model.dart

import 'package:tabuapp/features/search/domain/entities/party_search.dart';


/// Model que representa uma festa nos resultados de busca.
///
/// Responsabilidade: Conversão entre dados externos (Firebase) e entidade de domínio.
class PartySearchModel extends PartySearchEntity {
  const PartySearchModel({
    required super.id,
    required super.nome,
    super.descricao,
    required super.dataInicio,
    required super.dataFim,
    super.local,
    super.bairro,
    super.cidade,
    super.estado,
    super.bannerUrl,
    required super.creatorId,
    required super.creatorName,
    required super.interessados,
    required super.confirmados,
    required super.commentCount,
    super.latitude,
    super.longitude,
  });

  /// Cria um modelo a partir de dados do Firebase.
  ///
  /// [id]: ID da festa (vem da chave do Map)
  /// [json]: Map com os dados do Firebase
  factory PartySearchModel.fromFirebase(String id, Map<String, dynamic> json) {
    // ── Timestamps ────────────────────────────────────────────────────────
    final dataInicio = json['data_inicio'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['data_inicio'] as int)
        : DateTime.now();

    final dataFim = json['data_fim'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['data_fim'] as int)
        : dataInicio.add(const Duration(hours: 6));

    // ── CORREÇÃO: Firebase grava 'city'/'state', não 'cidade'/'estado' ────
    // Fallback legado para festas antigas que possam ter gravado em português.
    final cidade = json['city']   as String?
                ?? json['cidade'] as String?;
    final estado = json['state']  as String?
                ?? json['estado'] as String?;

    // ── Bairro: campo explícito ou extração do local (espelha PartyModel) ─
    String? bairro = json['bairro'] as String?;
    final localStr = json['local'] as String?;
    if ((bairro == null || bairro.isEmpty) && localStr != null) {
      bairro = _extractBairroFromLocal(localStr);
    }
    if (bairro != null && bairro.isEmpty) bairro = null;

    // ── CORREÇÃO: contadores são inteiros (gerenciados pela CF), não Maps ─
    // Festas antigas podem ainda ter Maps — suportamos os dois formatos.
    final interessadosRaw = json['interessados'];
    final confirmadosRaw  = json['confirmados'];
    final comentariosRaw  = json['comentarios'];

    final interessados = interessadosRaw is int
        ? interessadosRaw
        : interessadosRaw is Map ? interessadosRaw.length : 0;

    final confirmados = confirmadosRaw is int
        ? confirmadosRaw
        : confirmadosRaw is Map ? confirmadosRaw.length : 0;

    // CORREÇÃO: comment_count já existe como inteiro no nó raiz da festa.
    // Fallback para Map de comentários serve apenas para festas legadas.
    final commentCount = json['comment_count'] as int?
        ?? (comentariosRaw is Map ? comentariosRaw.length : 0);

    return PartySearchModel(
      id: id,
      nome: json['nome'] as String? ?? json['name'] as String? ?? '',
      descricao: json['descricao'] as String?,
      dataInicio: dataInicio,
      dataFim: dataFim,
      local: localStr,
      bairro: bairro,
      cidade: cidade,
      estado: estado,
      bannerUrl: json['banner_url'] as String?,
      creatorId: json['creator_id'] as String?
               ?? json['creator_uid'] as String?
               ?? '',
      creatorName: json['creator_name'] as String? ?? '',
      interessados: interessados,
      confirmados:  confirmados,
      commentCount: commentCount,
      latitude:  (json['latitude']  as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Extrai o bairro de uma string local no formato "Bairro, Cidade - UF".
  /// Espelha PartyModel._extractBairroFromLocal para consistência.
  static String? _extractBairroFromLocal(String local) {
    final parts = local.split(', ');
    if (parts.length < 2) return null;
    if (!parts.last.contains(' - ')) return null;
    final extracted = parts.sublist(0, parts.length - 1).join(', ').trim();
    return extracted.isNotEmpty ? extracted : null;
  }

  /// Converte o modelo para JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'data_inicio': dataInicio.millisecondsSinceEpoch,
      'data_fim': dataFim.millisecondsSinceEpoch,
      'local': local,
      'bairro': bairro,
      'city': cidade,
      'state': estado,
      'banner_url': bannerUrl,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'interessados': interessados,
      'confirmados': confirmados,
      'comment_count': commentCount,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Cria um modelo a partir de JSON serializado (ex: cache local).
  factory PartySearchModel.fromJson(Map<String, dynamic> json) {
    final dataInicio =
        DateTime.fromMillisecondsSinceEpoch(json['data_inicio'] as int);
    final dataFim =
        DateTime.fromMillisecondsSinceEpoch(json['data_fim'] as int);

    // Suporta tanto 'city'/'state' (novo) quanto 'cidade'/'estado' (legado)
    final cidade = json['city']   as String?
                ?? json['cidade'] as String?;
    final estado = json['state']  as String?
                ?? json['estado'] as String?;

    return PartySearchModel(
      id: json['id'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      dataInicio: dataInicio,
      dataFim: dataFim,
      local: json['local'] as String?,
      bairro: json['bairro'] as String?,
      cidade: cidade,
      estado: estado,
      bannerUrl: json['banner_url'] as String?,
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String,
      interessados: json['interessados'] as int? ?? 0,
      confirmados:  json['confirmados']  as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      latitude:  (json['latitude']  as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Converte para a entidade de domínio.
  PartySearchEntity toEntity() => this;

  /// Cria uma cópia com valores modificados.
  PartySearchModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? local,
    String? bairro,
    String? cidade,
    String? estado,
    String? bannerUrl,
    String? creatorId,
    String? creatorName,
    int? interessados,
    int? confirmados,
    int? commentCount,
    double? latitude,
    double? longitude,
  }) {
    return PartySearchModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      local: local ?? this.local,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      estado: estado ?? this.estado,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      interessados: interessados ?? this.interessados,
      confirmados: confirmados ?? this.confirmados,
      commentCount: commentCount ?? this.commentCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}