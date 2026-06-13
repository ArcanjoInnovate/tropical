import 'package:tabuapp/features/search/domain/entities/party_search.dart';
import 'package:tabuapp/features/search/domain/entities/user_search.dart';
import 'package:tabuapp/features/search/presentation/bloc/search_filters.dart';
import 'package:tabuapp/features/search/presentation/bloc/search_pagination.dart';

/// Estado único do SearchBloc.
///
/// Responsabilidade: Representar todo o estado visual da tela de busca.
/// É imutável — o BLoC emite novas instâncias via [copyWith].
class SearchState {
  // ── Dados ──────────────────────────────────────────────────────────────

  /// Lista bruta de usuários retornados pela busca (acumulativa entre páginas).
  /// Para exibição, use [visibleUsers], que já exclui os bloqueados.
  final List<UserSearchEntity> users;

  /// Lista de festas encontradas (acumulativa entre páginas).
  final List<PartySearchEntity> parties;

  // ── Filtros e Paginação ────────────────────────────────────────────────

  /// Estado atual dos filtros de busca.
  final SearchFilters filters;

  /// Estado atual da paginação.
  final SearchPagination pagination;

  // ── Status ──────────────────────────────────────────────────────────────

  /// True quando a primeira página está sendo carregada.
  final bool isLoading;

  /// True quando uma página adicional está sendo carregada.
  final bool isLoadingMore;

  /// Mensagem de erro, se houver.
  final String? errorMessage;

  /// UID do usuário atual.
  final String myUid;

  /// IDs dos usuários que o usuário atual segue.
  final Set<String> followingIds;

  /// IDs de todos os usuários bloqueados (bloqueei + me bloquearam).
  /// Mantido em sync com o BlockProvider via [SearchBlockedIdsUpdated].
  final Set<String> blockedIds;

  const SearchState({
    this.users = const [],
    this.parties = const [],
    this.filters = const SearchFilters(),
    this.pagination = const SearchPagination(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.myUid = '',
    this.followingIds = const {},
    this.blockedIds = const {},
  });

  // ── Getters de conveniência ─────────────────────────────────────────────

  /// Lista de usuários visíveis — exclui qualquer ID presente em [blockedIds].
  ///
  /// Use este getter na UI em vez de [users] diretamente.
  /// Garante que bloqueios aplicados via [SearchBlockedIdsUpdated] sejam
  /// refletidos imediatamente sem necessidade de novo fetch.
  List<UserSearchEntity> get visibleUsers =>
      blockedIds.isEmpty
          ? users
          : users.where((u) => !blockedIds.contains(u.uid)).toList();

  /// Retorna true se não há resultados visíveis e não está carregando.
  bool get isEmpty {
    if (isLoading) return false;
    return filters.isUsersSearch ? visibleUsers.isEmpty : parties.isEmpty;
  }

  /// Retorna true se há resultados visíveis.
  bool get hasResults =>
      filters.isUsersSearch ? visibleUsers.isNotEmpty : parties.isNotEmpty;

  /// Retorna true se está em estado de erro.
  bool get hasError => errorMessage != null;

  /// Número total de resultados visíveis na lista atual.
  int get resultCount =>
      filters.isUsersSearch ? visibleUsers.length : parties.length;

  // ── copyWith ────────────────────────────────────────────────────────────

  SearchState copyWith({
    List<UserSearchEntity>? users,
    List<PartySearchEntity>? parties,
    SearchFilters? filters,
    SearchPagination? pagination,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    String? myUid,
    Set<String>? followingIds,
    Set<String>? blockedIds,
    bool clearError = false,
  }) {
    return SearchState(
      users: users ?? this.users,
      parties: parties ?? this.parties,
      filters: filters ?? this.filters,
      pagination: pagination ?? this.pagination,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      myUid: myUid ?? this.myUid,
      followingIds: followingIds ?? this.followingIds,
      blockedIds: blockedIds ?? this.blockedIds,
    );
  }
}