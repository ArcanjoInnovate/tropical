// lib/features/search/data/repositories/search_repository_impl.dart

import 'package:tclub/features/search/data/datasources/search_remote_datasource.dart';
import 'package:tclub/features/search/domain/entities/paginated_result.dart';
import 'package:tclub/features/search/domain/entities/party_search.dart';
import 'package:tclub/features/search/domain/entities/user_search.dart';
import 'package:tclub/features/search/domain/repositories/i_search_repository.dart';

class SearchRepositoryImpl implements ISearchRepository {
  final SearchRemoteDataSource _remoteDataSource;

  SearchRepositoryImpl({
    required SearchRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  // ══════════════════════════════════════════════════════════════════════════
  //  USUÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<PaginatedResultEntity<UserSearchEntity>> fetchUsers({
    required String myUid,
    required Set<String> followingIds,
    Set<String> blockedIds = const {},   // ← NOVO
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
  }) async {
    try {
      final result = await _remoteDataSource.fetchUsers(
        myUid: myUid,
        followingIds: followingIds,
        blockedIds: blockedIds,           // ← NOVO
        page: page,
        query: query,
        estadoSigla: estadoSigla,
        cidadeNome: cidadeNome,
      );

      return PaginatedResultEntity<UserSearchEntity>(
        items: result.items,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
      );
    } catch (e) {
      throw SearchRepositoryException(
        'Erro ao buscar usuários: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<List<UserSearchEntity>> fetchUsersByProximity({
    required String myUid,
    required Set<String> followingIds,
    Set<String> blockedIds = const {},   // ← NOVO
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    try {
      final result = await _remoteDataSource.fetchUsersByProximity(
        myUid: myUid,
        followingIds: followingIds,
        blockedIds: blockedIds,           // ← NOVO
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        query: query,
      );

      return result.cast<UserSearchEntity>();
    } catch (e) {
      throw SearchRepositoryException(
        'Erro ao buscar usuários por proximidade: $e',
        originalError: e,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FESTAS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<PaginatedResultEntity<PartySearchEntity>> fetchParties({
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  }) async {
    try {
      final result = await _remoteDataSource.fetchParties(
        page: page,
        query: query,
        estadoSigla: estadoSigla,
        cidadeNome: cidadeNome,
        bairro: bairro,
      );

      return PaginatedResultEntity<PartySearchEntity>(
        items: result.items,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
      );
    } catch (e) {
      throw SearchRepositoryException(
        'Erro ao buscar festas: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<List<PartySearchEntity>> fetchPartiesByProximity({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    try {
      final result = await _remoteDataSource.fetchPartiesByProximity(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        query: query,
      );

      return result.cast<PartySearchEntity>();
    } catch (e) {
      throw SearchRepositoryException(
        'Erro ao buscar festas por proximidade: $e',
        originalError: e,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CACHE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void invalidateUsersCache() => _remoteDataSource.invalidateUsersCache();

  @override
  void invalidateUserCache(String myUid) =>
      _remoteDataSource.invalidateUserCache(myUid);

  @override
  void invalidatePartiesCache() => _remoteDataSource.invalidatePartiesCache();
  
  /// 🔥 NOVO: Invalida cache de páginas ao mudar filtros.
  /// 
  /// Chamado pelo BLoC antes de aplicar novos filtros de localização
  /// para garantir que buscas subsequentes busquem dados frescos do Firebase
  /// ao invés de retornar páginas cacheadas com filtros antigos.
  @override
  void invalidateFiltersCache() => _remoteDataSource.invalidateFiltersCache();
}

class SearchRepositoryException implements Exception {
  final String message;
  final Object? originalError;

  const SearchRepositoryException(this.message, {this.originalError});

  @override
  String toString() => 'SearchRepositoryException: $message';
}

