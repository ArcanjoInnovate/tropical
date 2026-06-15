// lib/features/search/presentation/bloc/search_pagination.dart

/// Value object que encapsula o estado de paginação.
///
/// Responsabilidade: Gerenciar e expor informações sobre a página atual,
/// se há mais dados disponíveis e se uma busca está em andamento.
/// É imutável — use [copyWith] para modificar.
class SearchPagination {
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const SearchPagination({
    this.currentPage = 0,
    this.pageSize = 10,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// Retorna true se é a primeira página.
  bool get isFirstPage => currentPage == 0;

  /// Calcula o total de páginas disponíveis.
  int get totalPages =>
      totalCount == 0 ? 0 : (totalCount / pageSize).ceil();

  /// Retorna o número da próxima página.
  int get nextPage => currentPage + 1;

  /// Retorna true se pode carregar mais itens.
  bool get canLoadMore => hasMore && !isLoadingMore;

  /// Retorna a paginação com a página avançada.
  SearchPagination advance() {
    return copyWith(
      currentPage: currentPage + 1,
      isLoadingMore: false,
    );
  }

  /// Retorna a paginação resetada para a primeira página.
  SearchPagination reset() {
    return const SearchPagination();
  }

  /// Marca que um carregamento adicional está em progresso.
  SearchPagination startLoadingMore() {
    return copyWith(isLoadingMore: true);
  }

  /// Cria uma cópia com valores modificados.
  SearchPagination copyWith({
    int? currentPage,
    int? pageSize,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SearchPagination(
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchPagination &&
        other.currentPage == currentPage &&
        other.pageSize == pageSize &&
        other.totalCount == totalCount &&
        other.hasMore == hasMore &&
        other.isLoadingMore == isLoadingMore;
  }

  @override
  int get hashCode => Object.hash(
        currentPage,
        pageSize,
        totalCount,
        hasMore,
        isLoadingMore,
      );
}

