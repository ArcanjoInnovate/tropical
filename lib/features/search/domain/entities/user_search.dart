// lib/features/search/domain/entities/user_search_entity.dart

/// Entidade que representa um usuário nos resultados de busca.
/// 
/// Esta é a representação no domínio (regras de negócio) de um usuário.
/// Não possui dependências de frameworks ou bibliotecas externas.
/// Contém apenas os dados necessários para a lógica de negócio.
class UserSearchEntity {
  final String uid;
  final String name;
  final String avatar;
  final String bio;
  final String city;
  final String state;
  final int followersCount;
  final int followingCount;
  final double? latitude;
  final double? longitude;
  final String neighborhood;
  final String genderIdentity;
  final String profileType;

  const UserSearchEntity({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.city,
    required this.state,
    required this.followersCount,
    required this.followingCount,
    this.latitude,
    this.longitude,
    this.neighborhood = '',
    this.genderIdentity = '',
    this.profileType = 'single',
  });

  /// Retorna true se o usuário possui coordenadas válidas
  bool get hasValidCoordinates => latitude != null && longitude != null;

  /// Retorna a localização formatada (cidade, estado)
  String get formattedLocation {
    final parts = [city, state].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  /// Retorna true se o usuário tem localização preenchida
  bool get hasLocation => city.isNotEmpty || state.isNotEmpty;
}

