// lib/features/search/data/models/paginated_result_model.dart

import 'package:tabuapp/features/search/domain/entities/paginated_result.dart';


/// Model genérico para resultados paginados.
/// 
/// Responsabilidade: Serialização/deserialização de resultados paginados.
/// Permite cache e transferência de dados.
class PaginatedResultModel<T> extends PaginatedResultEntity<T> {
  const PaginatedResultModel({
    required super.items,
    required super.page,
    required super.pageSize,
    required super.totalCount,
    required super.hasMore,
  });

  /// Converte para JSON.
  /// 
  /// [itemToJson]: Função para converter cada item para JSON.
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) itemToJson) {
    return {
      'items': items.map(itemToJson).toList(),
      'page': page,
      'page_size': pageSize,
      'total_count': totalCount,
      'has_more': hasMore,
    };
  }

  /// Cria um modelo a partir de JSON.
  /// 
  /// [json]: Map com os dados
  /// [itemFromJson]: Função para converter cada item do JSON
  factory PaginatedResultModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final itemsList = (json['items'] as List)
        .map((item) => itemFromJson(item as Map<String, dynamic>))
        .toList();

    return PaginatedResultModel<T>(
      items: itemsList,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalCount: json['total_count'] as int,
      hasMore: json['has_more'] as bool,
    );
  }

  /// Converte para a entidade de domínio.
  PaginatedResultEntity<T> toEntity() => this;

  /// Cria uma cópia com valores modificados.
  @override
  PaginatedResultModel<T> copyWith({
    List<T>? items,
    int? page,
    int? pageSize,
    int? totalCount,
    bool? hasMore,
  }) {
    return PaginatedResultModel<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}