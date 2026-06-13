// lib/features/search/domain/entities/paginated_result_entity.dart

/// Entidade genérica para resultados paginados.
/// 
/// Encapsula uma lista de itens junto com metadados de paginação.
/// Generic T permite reutilizar para diferentes tipos (usuários, festas, etc).
class PaginatedResultEntity<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;

  const PaginatedResultEntity({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
  });

  /// Calcula o total de páginas disponíveis
  int get totalPages => (totalCount / pageSize).ceil();

  /// Retorna true se a lista está vazia
  bool get isEmpty => items.isEmpty;

  /// Retorna true se a lista não está vazia
  bool get isNotEmpty => items.isNotEmpty;

  /// Retorna true se é a primeira página
  bool get isFirstPage => page == 0;

  /// Retorna true se é a última página
  bool get isLastPage => !hasMore;

  /// Copia a entidade com novos valores
  PaginatedResultEntity<T> copyWith({
    List<T>? items,
    int? page,
    int? pageSize,
    int? totalCount,
    bool? hasMore,
  }) {
    return PaginatedResultEntity<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}