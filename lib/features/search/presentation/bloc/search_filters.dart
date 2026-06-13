// lib/features/search/presentation/bloc/search_filters.dart

/// Enum que representa o tipo de busca ativo.
///
/// Determina qual aba/modo de busca está selecionado na UI.
enum SearchType {
  /// Busca por usuários
  users,

  /// Busca por festas
  parties,
}

/// Enum que representa o modo de localização da busca.
enum LocationMode {
  /// Sem filtro de localização
  none,

  /// Filtro por estado/cidade (dropdown)
  filter,

  /// Filtro por proximidade geográfica (GPS)
  proximity,
}

/// Value object que encapsula todos os filtros de busca.
///
/// Responsabilidade: Centralizar e validar o estado dos filtros.
/// É imutável — use [copyWith] para modificar.
class SearchFilters {
  final SearchType searchType;
  final String query;
  final String? estadoSigla;
  final String? cidadeNome;
  final String? bairro;
  final LocationMode locationMode;
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  const SearchFilters({
    this.searchType = SearchType.users,
    this.query = '',
    this.estadoSigla,
    this.cidadeNome,
    this.bairro,
    this.locationMode = LocationMode.none,
    this.latitude,
    this.longitude,
    this.radiusKm = 10.0,
  });

  /// Retorna true se há algum filtro de localização ou texto ativo.
  bool get hasActiveFilters {
    return query.isNotEmpty ||
        estadoSigla != null ||
        cidadeNome != null ||
        bairro != null ||
        locationMode != LocationMode.none;
  }

  /// Retorna true se o modo de proximidade está ativo e tem coordenadas.
  bool get isProximityActive =>
      locationMode == LocationMode.proximity &&
      latitude != null &&
      longitude != null;

  /// Retorna true se o modo de filtro por estado/cidade está ativo.
  bool get isFilterActive => locationMode == LocationMode.filter;

  /// Retorna true se a busca é de usuários.
  bool get isUsersSearch => searchType == SearchType.users;

  /// Retorna true se a busca é de festas.
  bool get isPartiesSearch => searchType == SearchType.parties;

  /// Cria uma cópia com valores modificados.
  SearchFilters copyWith({
    SearchType? searchType,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
    LocationMode? locationMode,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool clearEstado = false,
    bool clearCidade = false,
    bool clearBairro = false,
    bool clearLocation = false,
  }) {
    return SearchFilters(
      searchType: searchType ?? this.searchType,
      query: query ?? this.query,
      estadoSigla: clearEstado ? null : (estadoSigla ?? this.estadoSigla),
      cidadeNome: clearCidade ? null : (cidadeNome ?? this.cidadeNome),
      bairro: clearBairro ? null : (bairro ?? this.bairro),
      locationMode: locationMode ?? this.locationMode,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }

  /// Reseta todos os filtros para o estado inicial.
  SearchFilters reset() {
    return SearchFilters(searchType: searchType);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilters &&
        other.searchType == searchType &&
        other.query == query &&
        other.estadoSigla == estadoSigla &&
        other.cidadeNome == cidadeNome &&
        other.bairro == bairro &&
        other.locationMode == locationMode &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radiusKm == radiusKm;
  }

  @override
  int get hashCode => Object.hash(
        searchType,
        query,
        estadoSigla,
        cidadeNome,
        bairro,
        locationMode,
        latitude,
        longitude,
        radiusKm,
      );
}