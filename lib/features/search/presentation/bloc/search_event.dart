import 'package:tclub/features/search/presentation/bloc/search_filters.dart';

abstract class SearchEvent {
  const SearchEvent();
}

/// Inicializar a busca — recebe blockedIds do BlockProvider.
class SearchInitialized extends SearchEvent {
  final String myUid;
  final Set<String> blockedIds;

  const SearchInitialized({
    required this.myUid,
    this.blockedIds = const {},
  });
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);
}

class SearchTypeChanged extends SearchEvent {
  final SearchType searchType;
  const SearchTypeChanged(this.searchType);
}

class SearchLocationFilterApplied extends SearchEvent {
  final String? estadoSigla;
  final String? cidadeNome;
  final String? bairro;

  const SearchLocationFilterApplied({
    this.estadoSigla,
    this.cidadeNome,
    this.bairro,
  });
}

class SearchProximityActivated extends SearchEvent {
  final double latitude;
  final double longitude;
  final double radiusKm;

  const SearchProximityActivated({
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });
}

class SearchRadiusChanged extends SearchEvent {
  final double radiusKm;
  const SearchRadiusChanged(this.radiusKm);
}

class SearchFiltersCleared extends SearchEvent {
  const SearchFiltersCleared();
}

class SearchNextPageRequested extends SearchEvent {
  const SearchNextPageRequested();
}

class SearchRefreshRequested extends SearchEvent {
  const SearchRefreshRequested();
}

/// Disparado pela UI quando o BlockProvider notifica mudança nos IDs bloqueados.
/// Atualiza o set interno do BLoC e re-emite o estado filtrando os resultados
/// que já estão em memória — sem novo fetch ao Firebase.
class SearchBlockedIdsUpdated extends SearchEvent {
  final Set<String> blockedIds;
  const SearchBlockedIdsUpdated(this.blockedIds);
}

