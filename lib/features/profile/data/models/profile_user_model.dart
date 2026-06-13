// features/profile/data/models/profile_user_model.dart

class PartnerModel {
  final String? name;
  final String? genderIdentity;
  final String? sexualOrientation;
  final String? birthDate;
  final String? avatarUrl;

  const PartnerModel({
    this.name,
    this.genderIdentity,
    this.sexualOrientation,
    this.birthDate,
    this.avatarUrl,
  });

  factory PartnerModel.fromMap(Map<dynamic, dynamic> map) {
    return PartnerModel(
      name:              map['name']               as String?,
      genderIdentity:    map['gender_identity']     as String?,
      sexualOrientation: map['sexual_orientation']  as String?,
      birthDate:         map['birth_date']          as String?,
      avatarUrl:         map['avatar_url']          as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (name != null)              'name':               name,
    if (genderIdentity != null)    'gender_identity':    genderIdentity,
    if (sexualOrientation != null) 'sexual_orientation': sexualOrientation,
    if (birthDate != null)         'birth_date':         birthDate,
    if (avatarUrl != null)         'avatar_url':         avatarUrl,
  };

  String get genderLabel {
    const map = {
      'homem': 'Homem', 'mulher': 'Mulher', 'naoBinario': 'Não-binário',
      'mulherTrans': 'Mulher Trans', 'homemTrans': 'Homem Trans',
      'prefiroNaoDizer': 'Prefiro não dizer',
      'nao_binario': 'Não-binário', 'trans_masculino': 'Trans masculino',
      'trans_feminino': 'Trans feminino', 'outro': 'Outro',
    };
    return map[genderIdentity] ?? genderIdentity ?? '';
  }

  String get orientationLabel {
    const map = {
      'hetero': 'Hétero', 'bissexual': 'Bissexual', 'pansexual': 'Pansexual',
      'gay': 'Gay', 'lesbica': 'Lésbica', 'bi': 'Bissexual',
      'pan': 'Pansexual', 'assexual': 'Assexual', 'outro': 'Outro',
    };
    return map[sexualOrientation] ?? sexualOrientation ?? '';
  }

  int? get age {
    if (birthDate == null || birthDate!.isEmpty) return null;
    final birth = DateTime.tryParse(birthDate!);
    if (birth == null) return null;
    final now = DateTime.now();
    int years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) years--;
    return years > 0 ? years : null;
  }
}

class PresenceModel {
  final bool online;
  final int lastSeen;

  const PresenceModel({required this.online, required this.lastSeen});

  factory PresenceModel.fromMap(Map<dynamic, dynamic> map) {
    return PresenceModel(
      online:   map['online']    as bool? ?? false,
      lastSeen: (map['last_seen'] as num? ?? 0).toInt(),
    );
  }

  DateTime get lastSeenAt => DateTime.fromMillisecondsSinceEpoch(lastSeen);
}

class ProfileUserModel {
  final String uid;
  final String name;
  final String email;
  final String? avatar;
  final String bio;
  final String bairro;
  final String city;
  final String state;

  final String? genderIdentity;
  final String? sexualOrientation;
  final String? profileType;
  final String? relationshipType;

  final PartnerModel? partner;
  final List<String> interests;

  final int partys;
  final int reservations;
  final int vipLists;
  final bool isPremium;
  final String? birthDate;

  final PresenceModel? presence;

  final int followers;
  final int following;
  final int postCount;

  const ProfileUserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.avatar,
    this.bio = '',
    this.bairro = '',
    this.city = '',
    this.state = '',
    this.genderIdentity,
    this.sexualOrientation,
    this.profileType,
    this.relationshipType,
    this.partner,
    this.interests = const [],
    this.partys = 0,
    this.reservations = 0,
    this.vipLists = 0,
    this.isPremium = false,
    this.birthDate,
    this.presence,
    this.followers = 0,
    this.following = 0,
    this.postCount = 0,
  });

  factory ProfileUserModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    PartnerModel? partner;
    if (map['partner'] is Map) {
      partner = PartnerModel.fromMap(map['partner'] as Map);
    }

    PresenceModel? presence;
    if (map['presence'] is Map) {
      presence = PresenceModel.fromMap(map['presence'] as Map);
    }

    final rawInterests = map['interests'];
    final interests = rawInterests is List
        ? rawInterests.whereType<String>().where((s) => s.isNotEmpty).toList()
        : <String>[];

    return ProfileUserModel(
      uid:               uid,
      name:              map['name']               as String? ?? '',
      email:             map['email']              as String? ?? '',
      avatar:            map['avatar']             as String?,
      bio:               (map['bio']               as String? ?? '').trim(),
      bairro:            (map['bairro']            as String? ?? '').trim(),
      city:              map['city']               as String? ?? '',
      state:             map['state']              as String? ?? '',
      genderIdentity:    map['gender_identity']    as String?,
      sexualOrientation: map['sexual_orientation'] as String?,
      profileType:       map['profile_type']       as String?,
      relationshipType:  map['relationship_type']  as String?,
      partner:           partner,
      interests:         interests,
      partys:            (map['partys']            as num? ?? 0).toInt(),
      reservations:      (map['reservations']      as num? ?? 0).toInt(),
      vipLists:          (map['vip_lists']         as num? ?? 0).toInt(),
      isPremium:         map['isPremium']           as bool? ?? false,
      birthDate:         map['birth_date']          as String?,
      presence:          presence,
    );
  }

  // ── Rótulos ───────────────────────────────────────────────────────────────

  String get genderLabel {
    const map = {
      'homem': 'Homem', 'mulher': 'Mulher', 'naoBinario': 'Não-binário',
      'mulherTrans': 'Mulher Trans', 'homemTrans': 'Homem Trans',
      'prefiroNaoDizer': 'Prefiro não dizer',
      'nao_binario': 'Não-binário', 'trans_masculino': 'Trans masculino',
      'trans_feminino': 'Trans feminino', 'outro': 'Outro',
    };
    return map[genderIdentity] ?? genderIdentity ?? '';
  }

  String get orientationLabel {
    const map = {
      'hetero': 'Hétero', 'bissexual': 'Bissexual', 'pansexual': 'Pansexual',
      'gay': 'Gay', 'lesbica': 'Lésbica', 'bi': 'Bissexual',
      'pan': 'Pansexual', 'assexual': 'Assexual', 'outro': 'Outro',
    };
    return map[sexualOrientation] ?? sexualOrientation ?? '';
  }

  String get relationshipLabel {
    const map = {
      'solteiro': 'Solteiro(a)', 'casal': 'Casal',
      'casalLiberal': 'Casal Liberal', 'prefiroNaoDizer': 'Prefiro não dizer',
      'casado': 'Casado(a)', 'namorando': 'Namorando',
      'relacionamento_aberto': 'Relacionamento aberto',
      'swing': 'Swinger', 'poliamoroso': 'Poliamoroso(a)',
    };
    return map[relationshipType] ?? relationshipType ?? '';
  }

  String get profileTypeLabel {
    const map = {'single': 'Perfil individual', 'couple': 'Casal', 'group': 'Grupo'};
    return map[profileType] ?? profileType ?? '';
  }

  bool get isCouple => profileType == 'couple' ||
      relationshipType == 'casal' ||
      relationshipType == 'casalLiberal';
  bool get isOnline => presence?.online ?? false;
  bool get hasInterests => interests.isNotEmpty;

  int? get age {
    if (birthDate == null || birthDate!.isEmpty) return null;
    final birth = DateTime.tryParse(birthDate!);
    if (birth == null) return null;
    final now = DateTime.now();
    int years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) years--;
    return years > 0 ? years : null;
  }

  String get locationDisplay =>
      [bairro, city, state].where((s) => s.isNotEmpty).join(', ');

  ProfileUserModel copyWith({
    int? followers,
    int? following,
    int? postCount,
    List<String>? interests,
    String? birthDate,
    String? genderIdentity,
    String? sexualOrientation,
    String? profileType,
    String? relationshipType,
    String? bio,
    PartnerModel? partner,        // ← adicionado
    bool clearPartner = false,    // ← para remover parceiro explicitamente
  }) =>
      ProfileUserModel(
        uid:               uid,
        name:              name,
        email:             email,
        avatar:            avatar,
        bio:               bio ?? this.bio,
        bairro:            bairro,
        city:              city,
        state:             state,
        genderIdentity:    genderIdentity    ?? this.genderIdentity,
        sexualOrientation: sexualOrientation ?? this.sexualOrientation,
        profileType:       profileType       ?? this.profileType,
        relationshipType:  relationshipType  ?? this.relationshipType,
        partner:           clearPartner ? null : (partner ?? this.partner),
        interests:         interests         ?? this.interests,
        partys:            partys,
        reservations:      reservations,
        vipLists:          vipLists,
        isPremium:         isPremium,
        birthDate:         birthDate         ?? this.birthDate,
        presence:          presence,
        followers:         followers         ?? this.followers,
        following:         following         ?? this.following,
        postCount:         postCount         ?? this.postCount,
      );
}