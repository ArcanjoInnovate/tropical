import 'package:tabuapp/features/search/domain/entities/user_search.dart';
import 'package:tabuapp/features/search/domain/repositories/i_search_repository.dart';

class FetchUsersByProximityParams {
  final String myUid;
  final Set<String> followingIds;
  final Set<String> blockedIds; // ← NOVO
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String? query;

  const FetchUsersByProximityParams({
    required this.myUid,
    required this.followingIds,
    this.blockedIds = const {}, // ← NOVO
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.query,
  });

  bool get isValid {
    return myUid.isNotEmpty &&
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180 &&
        radiusKm > 0;
  }
}

class FetchUsersByProximityUseCase {
  final ISearchRepository _repository;

  FetchUsersByProximityUseCase(this._repository);

  Future<List<UserSearchEntity>> call(
    FetchUsersByProximityParams params,
  ) async {
    if (!params.isValid) {
      throw ArgumentError('Invalid proximity search parameters');
    }

    if (params.radiusKm > 1000) {
      throw ArgumentError('Radius cannot exceed 1000km');
    }

    return await _repository.fetchUsersByProximity(
      myUid: params.myUid,
      followingIds: params.followingIds,
      blockedIds: params.blockedIds, // ← NOVO
      latitude: params.latitude,
      longitude: params.longitude,
      radiusKm: params.radiusKm,
      query: params.query,
    );
  }
}