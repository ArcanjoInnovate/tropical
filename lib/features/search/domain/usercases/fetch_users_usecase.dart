import 'package:tclub/features/search/domain/entities/paginated_result.dart';
import 'package:tclub/features/search/domain/entities/user_search.dart';
import 'package:tclub/features/search/domain/repositories/i_search_repository.dart';

class FetchUsersParams {
  final String myUid;
  final Set<String> followingIds;
  final Set<String> blockedIds; // ← NOVO
  final int page;
  final String? query;
  final String? estadoSigla;
  final String? cidadeNome;

  const FetchUsersParams({
    required this.myUid,
    required this.followingIds,
    this.blockedIds = const {}, // ← NOVO
    this.page = 0,
    this.query,
    this.estadoSigla,
    this.cidadeNome,
  });
}

class FetchUsersUseCase {
  final ISearchRepository _repository;

  FetchUsersUseCase(this._repository);

  Future<PaginatedResultEntity<UserSearchEntity>> call(
    FetchUsersParams params,
  ) async {
    if (params.myUid.isEmpty) {
      throw ArgumentError('myUid cannot be empty');
    }

    return await _repository.fetchUsers(
      myUid: params.myUid,
      followingIds: params.followingIds,
      blockedIds: params.blockedIds, // ← NOVO
      page: params.page,
      query: params.query,
      estadoSigla: params.estadoSigla,
      cidadeNome: params.cidadeNome,
    );
  }
}

