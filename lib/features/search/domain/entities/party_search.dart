// lib/features/search/domain/entities/party_search_entity.dart

/// Entidade que representa uma festa nos resultados de busca.
///
/// Esta é a representação no domínio de uma festa.
/// Contém apenas os dados essenciais para a lógica de busca e exibição.
class PartySearchEntity {
  final String id;
  final String nome;
  final String? descricao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String? local;
  final String? bairro;
  final String? cidade;
  final String? estado;
  final String? bannerUrl;
  final String creatorId;
  final String creatorName;
  final int interessados;
  final int confirmados;
  final int commentCount;
  final double? latitude;
  final double? longitude;

  const PartySearchEntity({
    required this.id,
    required this.nome,
    this.descricao,
    required this.dataInicio,
    required this.dataFim,
    this.local,
    this.bairro,
    this.cidade,
    this.estado,
    this.bannerUrl,
    required this.creatorId,
    required this.creatorName,
    required this.interessados,
    required this.confirmados,
    required this.commentCount,
    this.latitude,
    this.longitude,
  });

  // Retornar true se a festa já terminou
  bool get isExpired {
    return dataFim.isBefore(DateTime.now());
  }

  /// Retorna true se a festa possui local definido
  bool get hasLocal => local != null && local!.isNotEmpty;

  /// Retorna true se possui banner
  bool get hasBanner => bannerUrl != null && bannerUrl!.isNotEmpty;

  /// Retorna true se pode mostrar distância (tem coordenadas)
  bool get canShowDistance => latitude != null && longitude != null;

  /// Retorna a localização completa formatada
  String get formattedLocation {
    final parts =
        [bairro, cidade, estado].where((s) => s != null && s.isNotEmpty);
    return parts.join(', ');
  }
}
