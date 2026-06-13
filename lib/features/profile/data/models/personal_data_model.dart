// lib/features/profile/data/models/personal_data_model.dart

/// Dados editáveis na tela de dados pessoais.
class PersonalDataModel {
  final String name;
  final String bio;

  /// Data de nascimento no formato ISO-8601 "yyyy-MM-dd" (ex.: "1995-08-23").
  /// Nulo quando o usuário não preencheu.
  final String? birthDate;

  /// Idade calculada a partir de [birthDate]. Gravada como campo inteiro
  /// separado no banco para facilitar filtros de match sem precisar parsear
  /// a data em todo o acesso.
  /// Nulo quando [birthDate] for nulo.
  final int? age;

  const PersonalDataModel({
    required this.name,
    required this.bio,
    this.birthDate,
    this.age,
  });

  /// Calcula a idade completa em anos a partir de uma data de nascimento.
  static int? calculateAge(DateTime? birth) {
    if (birth == null) return null;
    final today = DateTime.now();
    int years = today.year - birth.year;
    final notHadBirthdayYet = today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day);
    if (notHadBirthdayYet) years--;
    return years < 0 ? 0 : years;
  }

  factory PersonalDataModel.fromMap(Map<String, dynamic> map) {
    final birthDateStr = map['birth_date'] as String?;
    DateTime? birth;
    if (birthDateStr != null && birthDateStr.isNotEmpty) {
      birth = DateTime.tryParse(birthDateStr);
    }
    return PersonalDataModel(
      name:      (map['name'] as String? ?? '').trim(),
      bio:       (map['bio']  as String? ?? '').trim(),
      birthDate: birthDateStr,
      age:       (map['age'] as int?) ?? calculateAge(birth),
    );
  }

  /// Retorna APENAS os campos que o usuário pode editar em Users/{uid}.
  ///
  /// NUNCA inclua aqui campos com ".write": false nas regras do Firebase:
  /// followers_count, following_count, report_count, banido, suspenso,
  /// isPremium, vip_lists, ranking, boost, is_verified, partys,
  /// reservations, vip_of, penalidades, unreadNotificationsCount, etc.
  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'bio':  bio.trim(),
      if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
      if (age != null) 'age': age,
    };
  }

  PersonalDataModel copyWith({
    String? name,
    String? bio,
    String? birthDate,
    int?    age,
  }) =>
      PersonalDataModel(
        name:      name      ?? this.name,
        bio:       bio       ?? this.bio,
        birthDate: birthDate ?? this.birthDate,
        age:       age       ?? this.age,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MatchProfileModel
//
//  Snapshot do perfil sincronizado em Matchs/{uid}.
//  Contém todos os campos que o sistema de match precisa exibir E filtrar,
//  inclusive os campos de identidade que NÃO ficam em PersonalDataModel mas
//  precisam ser preservados ao fazer update parcial.
// ─────────────────────────────────────────────────────────────────────────────
class MatchProfileModel {
  const MatchProfileModel({
    required this.uid,
    required this.name,
    required this.bio,
    required this.avatar,
    required this.city,
    required this.state,
    required this.bairro,
    required this.latitude,
    required this.longitude,
    required this.genderIdentity,
    required this.sexualOrientation,
    required this.relationshipType,
    required this.profileType,
    this.birthDate,
    this.age,
    this.interests = const [],
    this.partner,
  });

  final String uid;
  final String name;
  final String bio;
  final String avatar;
  final String city;
  final String state;
  final String bairro;

  /// Coordenadas necessárias para os filtros de distância no sistema de match.
  final double latitude;
  final double longitude;

  /// Campos de identidade — lidos de Users/{uid} e espelhados em Matchs/{uid}.
  final String genderIdentity;
  final String sexualOrientation;
  final String relationshipType;
  final String profileType;

  final String? birthDate;
  final int?    age;

  /// Lista de interesses do usuário.
  final List<String> interests;

  /// Parceiro(a) — presente apenas quando profileType == 'couple'.
  final Map<String, dynamic>? partner;

  factory MatchProfileModel.fromMap(Map<String, dynamic> map) {
    return MatchProfileModel(
      uid:               map['uid']               as String? ?? '',
      name:              map['name']              as String? ?? '',
      bio:               map['bio']               as String? ?? '',
      avatar:            map['avatar']            as String? ?? '',
      city:              map['city']              as String? ?? '',
      state:             map['state']             as String? ?? '',
      bairro:            map['bairro']            as String? ?? '',
      latitude:          (map['latitude']  as num?)?.toDouble() ?? 0.0,
      longitude:         (map['longitude'] as num?)?.toDouble() ?? 0.0,
      genderIdentity:    map['gender_identity']    as String? ?? '',
      sexualOrientation: map['sexual_orientation'] as String? ?? '',
      relationshipType:  map['relationship_type']  as String? ?? '',
      profileType:       map['profile_type']       as String? ?? 'single',
      birthDate:         map['birth_date']          as String?,
      age:               (map['age'] as num?)?.toInt(),
      interests: (map['interests'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      partner: map['partner'] is Map
          ? Map<String, dynamic>.from(map['partner'] as Map)
          : null,
    );
  }

  /// Monta o map completo para `.set()` ao criar o nó pela primeira vez.
  Map<String, dynamic> toMap() {
    return {
      'uid':               uid,
      'name':              name.trim(),
      'bio':               bio.trim(),
      'avatar':            avatar,
      'city':              city,
      'state':             state,
      'bairro':            bairro,
      'latitude':          latitude,
      'longitude':         longitude,
      'gender_identity':   genderIdentity,
      'sexual_orientation':sexualOrientation,
      'relationship_type': relationshipType,
      'profile_type':      profileType,
      if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
      if (age != null) 'age': age,
      if (interests.isNotEmpty) 'interests': interests,
      if (partner != null) 'partner': partner,
    };
  }

  /// Monta apenas os campos editados por [PersonalDataModel] para `.update()`.
  ///
  /// Usado quando o nó Matchs/{uid} já existe — preserva todos os outros
  /// campos (likes_given, disliked, etc.) sem reescrever o nó inteiro.
  Map<String, dynamic> toPartialUpdateMap() {
    return {
      'name':   name.trim(),
      'bio':    bio.trim(),
      'avatar': avatar,
      if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
      if (age != null) 'age': age,
    };
  }

  /// Cria um [MatchProfileModel] a partir dos dados completos de Users/{uid},
  /// mesclando os novos campos editados ([PersonalDataModel]).
  ///
  /// [fullUserData] deve ser o snapshot COMPLETO de Users/{uid} — é daqui que
  /// vêm os campos de identidade, localização e parceiro que não passam pela
  /// tela de dados pessoais.
  factory MatchProfileModel.fromUserWithEdits({
    required Map<String, dynamic> fullUserData,
    required PersonalDataModel edits,
  }) {
    // Interesses: aceita List<dynamic> ou Map (Firebase pode retornar ambos)
    List<String> interests = const [];
    final rawInterests = fullUserData['interests'];
    if (rawInterests is List) {
      interests = rawInterests.whereType<String>().toList();
    } else if (rawInterests is Map) {
      interests = rawInterests.values.whereType<String>().toList();
    }

    // Parceiro
    Map<String, dynamic>? partner;
    if (fullUserData['partner'] is Map) {
      partner = Map<String, dynamic>.from(fullUserData['partner'] as Map);
    }

    return MatchProfileModel(
      uid:               fullUserData['uid']               as String? ?? '',
      name:              edits.name,
      bio:               edits.bio,
      avatar:            fullUserData['avatar']            as String? ?? '',
      city:              fullUserData['city']              as String? ?? '',
      state:             fullUserData['state']             as String? ?? '',
      bairro:            fullUserData['bairro']            as String? ?? '',
      latitude:          (fullUserData['latitude']  as num?)?.toDouble() ?? 0.0,
      longitude:         (fullUserData['longitude'] as num?)?.toDouble() ?? 0.0,
      genderIdentity:    fullUserData['gender_identity']    as String? ?? '',
      sexualOrientation: fullUserData['sexual_orientation'] as String? ?? '',
      relationshipType:  fullUserData['relationship_type']  as String? ?? '',
      profileType:       fullUserData['profile_type']       as String? ?? 'single',
      birthDate:         edits.birthDate,
      age:               edits.age,
      interests:         interests,
      partner:           partner,
    );
  }
}