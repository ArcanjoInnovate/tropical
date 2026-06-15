// lib/features/search/domain/usecases/fetch_parties_usecase.dart

import 'package:tclub/features/search/domain/entities/paginated_result.dart';
import 'package:tclub/features/search/domain/entities/party_search.dart';
import 'package:tclub/features/search/domain/repositories/i_search_repository.dart';

/// Parâmetros para busca de festas.
class FetchPartiesParams {
  final int page;
  final String? query;
  final String? estadoSigla;
  final String? cidadeNome;
  final String? bairro;

  const FetchPartiesParams({
    this.page = 0,
    this.query,
    this.estadoSigla,
    this.cidadeNome,
    this.bairro,
  });

  /// Retorna true se há algum filtro ativo
  bool get hasFilters {
    return (query != null && query!.isNotEmpty) ||
        (estadoSigla != null && estadoSigla!.isNotEmpty) ||
        (cidadeNome != null && cidadeNome!.isNotEmpty) ||
        (bairro != null && bairro!.isNotEmpty);
  }
}

/// Caso de uso: Buscar festas com paginação.
///
/// Responsabilidade: Orquestrar a busca de festas através do repositório.
class FetchPartiesUseCase {
  final ISearchRepository _repository;

  FetchPartiesUseCase(this._repository);

  /// Executa a busca de festas.
  ///
  /// Retorna uma entidade paginada com as festas encontradas.
  Future<PaginatedResultEntity<PartySearchEntity>> call(
    FetchPartiesParams params,
  ) async {
    // Validação
    if (params.page < 0) {
      throw ArgumentError('Page cannot be negative');
    }

    // Delegação para o repositório
    final result = await _repository.fetchParties(
      page: params.page,
      query: params.query,
      estadoSigla: params.estadoSigla,
      cidadeNome: params.cidadeNome,
      bairro: params.bairro,
    );

    // Filtras as festas que já passaram
    final filteredPartys = result.items.where((party) {
      return !party.isExpired;
    }).toList();
    return PaginatedResultEntity(
        items: filteredPartys,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        hasMore: result.hasMore);
  }
}

