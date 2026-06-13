import 'package:tabuapp/features/search/domain/entities/paginated_result.dart';
import 'package:tabuapp/features/search/domain/entities/party_search.dart';
import 'package:tabuapp/features/search/domain/entities/user_search.dart';

/// Interface do repositório de busca.
/// 
/// Define o contrato que a camada de dados deve implementar.
/// A camada de domínio não conhece detalhes de implementação (Firebase, cache, etc).
/// Seguindo o Dependency Inversion Principle (SOLID).
abstract class ISearchRepository {
  /// Busca usuários com paginação e filtros opcionais.
  /// 
  /// Parâmetros:
  /// - [myUid]: UID do usuário atual (para exclusão dos resultados)
  /// - [followingIds]: IDs dos usuários que já sigo (para ordenação)
  /// - [page]: Número da página (0-based)
  /// - [query]: Texto de busca (opcional)
  /// - [estadoSigla]: Filtro por estado (opcional)
  /// - [cidadeNome]: Filtro por cidade (opcional)
  Future<PaginatedResultEntity<UserSearchEntity>> fetchUsers({
    required String myUid,
    required Set<String> followingIds,
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome, 
    required Set<String> blockedIds,
  });

  /// Busca usuários por proximidade geográfica.
  /// 
  /// Não usa paginação pois precisa calcular distância de todos.
  /// Retorna ordenado por distância (mais próximos primeiro).
  /// 
  /// Parâmetros:
  /// - [myUid]: UID do usuário atual
  /// - [followingIds]: IDs dos usuários que já sigo
  /// - [latitude]: Latitude do ponto de referência
  /// - [longitude]: Longitude do ponto de referência
  /// - [radiusKm]: Raio de busca em quilômetros
  /// - [query]: Texto de busca (opcional)
  Future<List<UserSearchEntity>> fetchUsersByProximity({
    required String myUid,
    required Set<String> followingIds,
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query, 
    required Set<String> blockedIds,
  });

  /// Busca festas com paginação e filtros opcionais.
  /// 
  /// Parâmetros:
  /// - [page]: Número da página (0-based)
  /// - [query]: Texto de busca (opcional)
  /// - [estadoSigla]: Filtro por estado (opcional)
  /// - [cidadeNome]: Filtro por cidade (opcional)
  /// - [bairro]: Filtro por bairro (opcional)
  Future<PaginatedResultEntity<PartySearchEntity>> fetchParties({
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  });

  /// Busca festas por proximidade geográfica.
  /// 
  /// Não usa paginação pois precisa calcular distância de todas.
  /// Retorna ordenado por distância (mais próximas primeiro).
  /// 
  /// Parâmetros:
  /// - [latitude]: Latitude do ponto de referência
  /// - [longitude]: Longitude do ponto de referência
  /// - [radiusKm]: Raio de busca em quilômetros
  /// - [query]: Texto de busca (opcional)
  Future<List<PartySearchEntity>> fetchPartiesByProximity({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  });

  /// Invalida todo o cache de usuários.
  void invalidateUsersCache();

  /// Invalida o cache de um usuário específico.
  void invalidateUserCache(String myUid);

  /// Invalida todo o cache de festas.
  void invalidatePartiesCache();
  
  /// 🔥 NOVO: Invalida o cache de páginas com filtros.
  /// 
  /// Deve ser chamado ao aplicar novos filtros de localização
  /// para garantir que os resultados sejam refrescados do Firebase
  /// ao invés de usar páginas cacheadas com filtros antigos.
  void invalidateFiltersCache();
}