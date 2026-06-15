// lib/features/search/presentation/bloc/search_bloc.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tclub/features/search/domain/repositories/i_search_repository.dart';
import 'package:tclub/features/search/domain/usercases/fetch_parties_by_proximity_usecase.dart';
import 'package:tclub/features/search/domain/usercases/fetch_parties_usecase.dart';
import 'package:tclub/features/search/domain/usercases/fetch_users_by_proximity_usecase.dart';
import 'package:tclub/features/search/domain/usercases/fetch_users_usecase.dart';
import 'package:tclub/features/search/presentation/bloc/search_event.dart';
import 'package:tclub/features/search/presentation/bloc/search_filters.dart';
import 'package:tclub/features/search/presentation/bloc/search_pagination.dart';
import 'package:tclub/features/search/presentation/bloc/search_state.dart';

/// BLoC que gerencia o estado da tela de busca.
///
/// Responsabilidades:
/// - Orquestrar use cases de busca
/// - Gerenciar paginação e filtros
/// - Sincronizar IDs bloqueados com BlockProvider
/// - Filtrar resultados em memória quando bloqueios mudam
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final FetchUsersUseCase _fetchUsers;
  final FetchUsersByProximityUseCase _fetchUsersByProximity;
  final FetchPartiesUseCase _fetchParties;
  final FetchPartiesByProximityUseCase _fetchPartiesByProximity;
  final ISearchRepository _repository;

  SearchBloc({
    required FetchUsersUseCase fetchUsers,
    required FetchUsersByProximityUseCase fetchUsersByProximity,
    required FetchPartiesUseCase fetchParties,
    required FetchPartiesByProximityUseCase fetchPartiesByProximity,
    required ISearchRepository repository,
  })  : _fetchUsers = fetchUsers,
        _fetchUsersByProximity = fetchUsersByProximity,
        _fetchParties = fetchParties,
        _fetchPartiesByProximity = fetchPartiesByProximity,
        _repository = repository,
        super(const SearchState()) {
    on<SearchInitialized>(_onInitialized);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchTypeChanged>(_onTypeChanged);
    on<SearchLocationFilterApplied>(_onLocationFilterApplied);
    on<SearchProximityActivated>(_onProximityActivated);
    on<SearchRadiusChanged>(_onRadiusChanged);
    on<SearchFiltersCleared>(_onFiltersCleared);
    on<SearchNextPageRequested>(_onNextPageRequested);
    on<SearchRefreshRequested>(_onRefreshRequested);
    on<SearchBlockedIdsUpdated>(_onBlockedIdsUpdated);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INICIALIZAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _onInitialized(
    SearchInitialized event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      myUid: event.myUid,
      blockedIds: event.blockedIds, // ← snapshot inicial do Provider
      isLoading: true,
      clearError: true,
    ));

    try {
      // Busca inicial de usuários com blockedIds
      await _performSearch(emit);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao carregar dados: $e',
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BLOQUEIOS - SINCRONIZAÇÃO EM TEMPO REAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Atualiza blockedIds quando o BlockProvider notifica mudanças.
  /// RE-FILTRA os resultados que já estão em memória SEM fazer novo fetch.
  void _onBlockedIdsUpdated(
    SearchBlockedIdsUpdated event,
    Emitter<SearchState> emit,
  ) {
    // Se nada mudou, ignora
    if (event.blockedIds.length == state.blockedIds.length &&
        event.blockedIds.containsAll(state.blockedIds)) {
      return;
    }

    print('🔄 SearchBloc: blockedIds updated: ${event.blockedIds.length} IDs');

    // Atualiza o set interno e força re-render via copyWith
    // O getter visibleUsers no SearchState já fará o filtro automaticamente
    emit(state.copyWith(
      blockedIds: event.blockedIds,
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTROS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      filters: state.filters.copyWith(query: event.query),
      pagination: state.pagination.reset(),
      clearError: true,
    ));

    await _performSearch(emit);
  }

  Future<void> _onTypeChanged(
    SearchTypeChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      filters: state.filters.copyWith(searchType: event.searchType),
      pagination: state.pagination.reset(),
      clearError: true,
    ));

    await _performSearch(emit);
  }

  /// 🔥 CORREÇÃO: Removido clearLocation: true para permitir que filtros de 
  /// localização (estado/cidade/bairro) sejam aplicados corretamente.
  /// 
  /// Antes, clearLocation limpava latitude/longitude, causando confusão
  /// no getter isProximityActive que verifica se locationMode == proximity
  /// E latitude/longitude != null.
  Future<void> _onLocationFilterApplied(
    SearchLocationFilterApplied event,
    Emitter<SearchState> emit,
  ) async {
    // Invalida cache de páginas para garantir dados frescos com novos filtros
    _repository.invalidateFiltersCache();
    
    emit(state.copyWith(
      filters: state.filters.copyWith(
        locationMode: LocationMode.filter,
        estadoSigla: event.estadoSigla,
        cidadeNome: event.cidadeNome,
        bairro: event.bairro,
        // 🔥 clearLocation: true REMOVIDO
        // Não precisamos limpar latitude/longitude aqui.
        // LocationMode.filter já indica que usaremos filtros ao invés de GPS.
      ),
      pagination: state.pagination.reset(),
      clearError: true,
    ));

    await _performSearch(emit);
  }

  Future<void> _onProximityActivated(
    SearchProximityActivated event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      filters: state.filters.copyWith(
        locationMode: LocationMode.proximity,
        latitude: event.latitude,
        longitude: event.longitude,
        radiusKm: event.radiusKm,
        clearEstado: true,
        clearCidade: true,
        clearBairro: true,
      ),
      pagination: state.pagination.reset(),
      clearError: true,
    ));

    await _performSearch(emit);
  }

  Future<void> _onRadiusChanged(
    SearchRadiusChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      filters: state.filters.copyWith(radiusKm: event.radiusKm),
      clearError: true,
    ));

    // Debounce: só busca se for proximidade ativa
    if (state.filters.isProximityActive) {
      await _performSearch(emit);
    }
  }

  Future<void> _onFiltersCleared(
    SearchFiltersCleared event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      filters: state.filters.reset(),
      pagination: state.pagination.reset(),
      clearError: true,
    ));

    await _performSearch(emit);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAGINAÇÃO E REFRESH
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _onNextPageRequested(
    SearchNextPageRequested event,
    Emitter<SearchState> emit,
  ) async {
    // Ignora se já está carregando ou não tem mais páginas
    if (state.isLoadingMore || !state.pagination.canLoadMore) return;

    // Apenas paginação normal (não proximidade)
    if (state.filters.isProximityActive) return;

    emit(state.copyWith(
      pagination: state.pagination.startLoadingMore(),
      clearError: true,
    ));

    try {
      if (state.filters.isUsersSearch) {
        await _fetchMoreUsers(emit);
      } else {
        await _fetchMoreParties(emit);
      }
    } catch (e) {
      emit(state.copyWith(
        pagination: state.pagination.copyWith(isLoadingMore: false),
        errorMessage: 'Erro ao carregar mais: $e',
      ));
    }
  }

  /// 🔥 CORREÇÃO CRÍTICA: Ao fazer refresh, MANTÉM blockedIds atuais
  Future<void> _onRefreshRequested(
    SearchRefreshRequested event,
    Emitter<SearchState> emit,
  ) async {
    // NÃO reseta blockedIds — mantém o estado atual do BlockProvider
    emit(state.copyWith(
      pagination: state.pagination.reset(),
      isLoading: true,
      clearError: true,
      // blockedIds: SEM RESET — mantém os IDs atuais!
    ));

    try {
      // Invalida cache do repositório
      if (state.filters.isUsersSearch) {
        _repository.invalidateUserCache(state.myUid);
      } else {
        _repository.invalidatePartiesCache();
      }

      await _performSearch(emit);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao atualizar: $e',
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LÓGICA DE BUSCA
  // ══════════════════════════════════════════════════════════════════════════

  /// Executa busca completa (primeira página) baseada nos filtros atuais.
  /// 🔥 SEMPRE passa blockedIds para os use cases.
  Future<void> _performSearch(Emitter<SearchState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      if (state.filters.isUsersSearch) {
        await _searchUsers(emit);
      } else {
        await _searchParties(emit);
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Erro na busca: $e',
      ));
    }
  }

  /// Busca usuários (primeira página ou proximidade)
  Future<void> _searchUsers(Emitter<SearchState> emit) async {
    if (state.filters.isProximityActive) {
      // Busca por proximidade (sem paginação)
      final users = await _fetchUsersByProximity(FetchUsersByProximityParams(
        myUid: state.myUid,
        followingIds: state.followingIds,
        blockedIds: state.blockedIds, // ← SEMPRE passa blockedIds!
        latitude: state.filters.latitude!,
        longitude: state.filters.longitude!,
        radiusKm: state.filters.radiusKm,
        query: state.filters.query.isNotEmpty ? state.filters.query : null,
      ));

      emit(state.copyWith(
        users: users,
        parties: [],
        isLoading: false,
        pagination: SearchPagination(hasMore: false), // proximidade não pagina
      ));
    } else {
      // Busca paginada normal
      final result = await _fetchUsers(FetchUsersParams(
        myUid: state.myUid,
        followingIds: state.followingIds,
        blockedIds: state.blockedIds, // ← SEMPRE passa blockedIds!
        page: 0,
        query: state.filters.query.isNotEmpty ? state.filters.query : null,
        estadoSigla: state.filters.estadoSigla,
        cidadeNome: state.filters.cidadeNome,
      ));

      emit(state.copyWith(
        users: result.items,
        parties: [],
        isLoading: false,
        pagination: SearchPagination(
          currentPage: result.page,
          pageSize: result.pageSize,
          totalCount: result.totalCount,
          hasMore: result.hasMore,
        ),
      ));
    }
  }

  /// Busca festas (primeira página ou proximidade)
  Future<void> _searchParties(Emitter<SearchState> emit) async {
    if (state.filters.isProximityActive) {
      final parties = await _fetchPartiesByProximity(
        FetchPartiesByProximityParams(
          latitude: state.filters.latitude!,
          longitude: state.filters.longitude!,
          radiusKm: state.filters.radiusKm,
          query: state.filters.query.isNotEmpty ? state.filters.query : null,
        ),
      );

      emit(state.copyWith(
        users: [],
        parties: parties,
        isLoading: false,
        pagination: SearchPagination(hasMore: false),
      ));
    } else {
      final result = await _fetchParties(FetchPartiesParams(
        page: 0,
        query: state.filters.query.isNotEmpty ? state.filters.query : null,
        estadoSigla: state.filters.estadoSigla,
        cidadeNome: state.filters.cidadeNome,
        bairro: state.filters.bairro,
      ));

      emit(state.copyWith(
        users: [],
        parties: result.items,
        isLoading: false,
        pagination: SearchPagination(
          currentPage: result.page,
          pageSize: result.pageSize,
          totalCount: result.totalCount,
          hasMore: result.hasMore,
        ),
      ));
    }
  }

  /// Carrega próxima página de usuários
  Future<void> _fetchMoreUsers(Emitter<SearchState> emit) async {
    final nextPage = state.pagination.nextPage;

    final result = await _fetchUsers(FetchUsersParams(
      myUid: state.myUid,
      followingIds: state.followingIds,
      blockedIds: state.blockedIds, // ← SEMPRE passa blockedIds!
      page: nextPage,
      query: state.filters.query.isNotEmpty ? state.filters.query : null,
      estadoSigla: state.filters.estadoSigla,
      cidadeNome: state.filters.cidadeNome,
    ));

    // Acumula resultados
    emit(state.copyWith(
      users: [...state.users, ...result.items],
      pagination: SearchPagination(
        currentPage: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
        isLoadingMore: false,
      ),
    ));
  }

  /// Carrega próxima página de festas
  Future<void> _fetchMoreParties(Emitter<SearchState> emit) async {
    final nextPage = state.pagination.nextPage;

    final result = await _fetchParties(FetchPartiesParams(
      page: nextPage,
      query: state.filters.query.isNotEmpty ? state.filters.query : null,
      estadoSigla: state.filters.estadoSigla,
      cidadeNome: state.filters.cidadeNome,
      bairro: state.filters.bairro,
    ));

    emit(state.copyWith(
      parties: [...state.parties, ...result.items],
      pagination: SearchPagination(
        currentPage: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore,
        isLoadingMore: false,
      ),
    ));
  }
}

