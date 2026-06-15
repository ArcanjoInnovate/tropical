// lib/features/search/domain/usercases/fetch_parties_by_proximity_usecase.dart

import 'package:tclub/features/search/domain/entities/party_search.dart';
import 'package:tclub/features/search/domain/repositories/i_search_repository.dart';

/// Parâmetros para busca de festas por proximidade.
class FetchPartiesByProximityParams {
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String? query;

  const FetchPartiesByProximityParams({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.query,
  });

  /// Valida se os parâmetros são válidos.
  bool get isValid {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        radiusKm > 0;
  }
}

/// Caso de uso: Buscar festas por proximidade geográfica.
///
/// Responsabilidade: Orquestrar a busca de festas próximas geograficamente.
/// Valida coordenadas e raio antes de delegar ao repositório.
/// Retorna lista ordenada por distância (mais próximas primeiro),
/// excluindo festas que já encerraram ([PartySearchEntity.isExpired]).
class FetchPartiesByProximityUseCase {
  final ISearchRepository _repository;

  FetchPartiesByProximityUseCase(this._repository);

  /// Executa a busca por proximidade.
  ///
  /// Lança [ArgumentError] se os parâmetros forem inválidos.
  /// Festas cujo [PartySearchEntity.dataFim] seja anterior ao momento atual
  /// são removidas do resultado — comportamento idêntico ao [FetchPartiesUseCase].
  Future<List<PartySearchEntity>> call(
    FetchPartiesByProximityParams params,
  ) async {
    if (!params.isValid) {
      throw ArgumentError('Parâmetros de proximidade inválidos.');
    }

    if (params.radiusKm > 1000) {
      throw ArgumentError('O raio não pode exceder 1000 km.');
    }

    final all = await _repository.fetchPartiesByProximity(
      latitude: params.latitude,
      longitude: params.longitude,
      radiusKm: params.radiusKm,
      query: params.query,
    );

    // ── FIX: remove festas expiradas, mantendo paridade com FetchPartiesUseCase ──
    return all.where((party) => !party.isExpired).toList();
  }
}

