// lib/features/search/di/search_injection.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/features/search/data/datasources/search_remote_datasource.dart';
import 'package:tclub/features/search/data/repositories/search_repository.dart';
import 'package:tclub/features/search/domain/repositories/i_search_repository.dart';
import 'package:tclub/features/search/domain/usercases/fetch_parties_by_proximity_usecase.dart';
import 'package:tclub/features/search/domain/usercases/fetch_parties_usecase.dart';
import 'package:tclub/features/search/domain/usercases/fetch_users_by_proximity_usecase.dart';
import 'package:tclub/features/search/domain/usercases/fetch_users_usecase.dart';
import 'package:tclub/features/search/presentation/bloc/search_bloc.dart';
import 'package:tclub/core/services/cache_service.dart';

/// Injeção de dependências do módulo de busca.
///
/// Responsabilidade: Montar e conectar todas as dependências da feature search.
/// Centraliza a criação dos objetos seguindo o princípio DI.
///
/// Pode ser substituído por um container de DI (get_it, injectable, etc.)
/// sem afetar o restante do código — basta trocar as implementações aqui.
class SearchInjection {
  SearchInjection._();

  // ══════════════════════════════════════════════════════════════════════════
  //  INSTÂNCIAS SINGLETON (compartilhadas enquanto o módulo estiver ativo)
  // ══════════════════════════════════════════════════════════════════════════

  static SearchRemoteDataSource? _remoteDataSource;
  static ISearchRepository? _repository;

  /// Data source de busca remota (Firebase + cache).
  ///
  /// Singleton para reutilizar o cache entre diferentes instâncias do BLoC.
  static SearchRemoteDataSource get remoteDataSource {
    _remoteDataSource ??= SearchRemoteDataSource(
      database: FirebaseDatabase.instance,
      cache: CacheService.instance,
    );
    return _remoteDataSource!;
  }

  /// Repositório de busca.
  ///
  /// Singleton pela mesma razão do data source.
  static ISearchRepository get repository {
    _repository ??= SearchRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
    return _repository!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CRIAÇÃO DO BLOC (nova instância por tela)
  // ══════════════════════════════════════════════════════════════════════════

  /// Cria uma nova instância do [SearchBloc] com todas as dependências injetadas.
  ///
  /// O BLoC não é singleton — cada tela de busca tem sua própria instância,
  /// mas compartilha o repositório (e portanto o cache) via singleton.
  static SearchBloc createBloc() {
    final repo = repository;

    return SearchBloc(
      fetchUsers: FetchUsersUseCase(repo),
      fetchUsersByProximity: FetchUsersByProximityUseCase(repo),
      fetchParties: FetchPartiesUseCase(repo),
      fetchPartiesByProximity: FetchPartiesByProximityUseCase(repo),
      repository: repo,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIMPEZA (use ao fazer logout ou ao desmontar o módulo)
  // ══════════════════════════════════════════════════════════════════════════

  /// Descarta as instâncias singleton.
  ///
  /// Chame ao fazer logout para garantir que dados do usuário anterior
  /// não vazem para o próximo usuário.
  static void dispose() {
    _remoteDataSource?.invalidateUsersCache();
    _remoteDataSource?.invalidatePartiesCache();
    _remoteDataSource = null;
    _repository = null;
  }
}

