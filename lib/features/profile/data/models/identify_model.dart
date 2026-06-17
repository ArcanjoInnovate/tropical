// lib/features/profile/data/models/identity_model.dart

import 'package:tclub/core/utils/map_utils.dart';

/// Modelo de identidade do usuário persistido em Users/{uid} e Matchs/{uid}.
class IdentityModel {
  final String profileType; // 'single' | 'couple'
  final String genderIdentity;
  final String relationshipType;
  final String sexualOrientation;
  final PartnerModel? partner;

  const IdentityModel({
    required this.profileType,
    required this.genderIdentity,
    required this.relationshipType,
    required this.sexualOrientation,
    this.partner,
  });

  Map<String, dynamic> toMap() => {
        'profile_type':       profileType,
        'gender_identity':    genderIdentity,
        'relationship_type':  relationshipType,
        'sexual_orientation': sexualOrientation,
        if (partner != null) 'partner': partner!.toMap(),
      };

  factory IdentityModel.fromMap(Map<String, dynamic> map) => IdentityModel(
        profileType:       map['profile_type']       as String? ?? 'single',
        genderIdentity:    map['gender_identity']     as String? ?? '',
        relationshipType:  map['relationship_type']   as String? ?? '',
        sexualOrientation: map['sexual_orientation']  as String? ?? '',
        partner: map['partner'] != null
            ? PartnerModel.fromMap(safeMapCast(map['partner']))
            : null,
      );
}

/// Dados do parceiro(a) — persistidos somente quando profile_type == 'couple'.
class PartnerModel {
  final String name;
  final String birthDate;
  final String genderIdentity;
  final String sexualOrientation;
  final String avatarUrl;

  const PartnerModel({
    required this.name,
    required this.birthDate,
    required this.genderIdentity,
    required this.sexualOrientation,
    this.avatarUrl = '',
  });

  Map<String, dynamic> toMap() => {
        'name':               name,
        'birth_date':         birthDate,
        'gender_identity':    genderIdentity,
        'sexual_orientation': sexualOrientation,
        if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      };

  factory PartnerModel.fromMap(Map<String, dynamic> map) => PartnerModel(
        name:              map['name']               as String? ?? '',
        birthDate:         map['birth_date']          as String? ?? '',
        genderIdentity:    map['gender_identity']     as String? ?? '',
        sexualOrientation: map['sexual_orientation']  as String? ?? '',
        avatarUrl:         map['avatar_url']          as String? ?? '',
      );
}