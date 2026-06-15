// lib/features/search/data/models/user_search_model.dart

import 'package:tclub/features/search/domain/entities/user_search.dart';


/// Model que representa um usuário nos resultados de busca.
/// 
/// Responsabilidade: Conversão entre dados externos (Firebase) e entidade de domínio.
/// Implementa fromJson/toJson para serialização.
/// Herda de UserSearchEntity para manter compatibilidade.
class UserSearchModel extends UserSearchEntity {
  const UserSearchModel({
    required super.uid,
    required super.name,
    required super.avatar,
    required super.bio,
    required super.city,
    required super.state,
    required super.followersCount,
    required super.followingCount,
    super.latitude,
    super.longitude,
    super.neighborhood,
    super.genderIdentity,
    super.profileType,
  });

  /// Cria um modelo a partir de dados do Firebase.
  /// 
  /// [uid]: ID do usuário (vem da chave do Map)
  /// [json]: Map com os dados do Firebase
  factory UserSearchModel.fromFirebase(String uid, Map<String, dynamic> json) {
    // Extrai dados de followers e following
    final followersMap = json['followers'];
    final followingMap = json['following'];

    return UserSearchModel(
      uid: uid,
      name: (json['name'] as String? ?? '').trim(),
      avatar: json['avatar'] as String? ?? '',
      bio: (json['bio'] as String? ?? '').trim(),
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      followersCount: followersMap is Map ? followersMap.length : 0,
      followingCount: followingMap is Map ? followingMap.length : 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      neighborhood: json['bairro'] as String? ?? '',
      genderIdentity: json['gender_identity'] as String? ?? '',
      profileType: json['profile_type'] as String? ?? 'single',
    );
  }

  /// Converte o modelo para JSON.
  /// 
  /// Útil para cache ou outras operações de persistência.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'bio': bio,
      'city': city,
      'state': state,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'latitude': latitude,
      'longitude': longitude,
      'neighborhood': neighborhood,
      'genderIdentity': genderIdentity,
      'profileType': profileType,
    };
  }

  /// Cria um modelo a partir de JSON.
  /// 
  /// Usado para deserialização do cache.
  factory UserSearchModel.fromJson(Map<String, dynamic> json) {
    return UserSearchModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String,
      bio: json['bio'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      followersCount: json['followersCount'] as int,
      followingCount: json['followingCount'] as int,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      neighborhood: json['neighborhood'] as String? ?? '',
      genderIdentity: json['genderIdentity'] as String? ?? '',
      profileType: json['profileType'] as String? ?? 'single',
    );
  }

  /// Converte para a entidade de domínio.
  /// 
  /// Como já herda de UserSearchEntity, pode retornar this.
  /// Mas mantemos o método para seguir o padrão.
  UserSearchEntity toEntity() => this;

  /// Cria uma cópia com valores modificados.
  UserSearchModel copyWith({
    String? uid,
    String? name,
    String? avatar,
    String? bio,
    String? city,
    String? state,
    int? followersCount,
    int? followingCount,
    double? latitude,
    double? longitude,
    String? neighborhood,
    String? genderIdentity,
    String? profileType,
  }) {
    return UserSearchModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      state: state ?? this.state,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      neighborhood: neighborhood ?? this.neighborhood,
      genderIdentity: genderIdentity ?? this.genderIdentity,
      profileType: profileType ?? this.profileType,
    );
  }
}

