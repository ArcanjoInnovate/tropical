// lib/features/match/data/models/match_profile_model.dart
//
// Mapeado diretamente dos campos reais do nó Matchs/{uid} no Firebase.
// Os valores de gender_identity, sexual_orientation e relationship_type
// são os .name dos enums de edit_perfil_enums.dart:
//   TipoPerfil          → homem | mulher | mulherTrans | homemTrans |
//                          naoBinario | prefiroNaoDizer
//   OrientacaoSexual    → hetero | bissexual | pansexual
//   TipoRelacionamento  → solteiro | casal | prefiroNaoDizer
//   profile_type        → single | couple

// ════════════════════════════════════════════════════════════════════════════
//  PARTNER MODEL  (campo "partner" presente apenas quando profile_type == couple)
// ════════════════════════════════════════════════════════════════════════════
class MatchPartnerModel {
  const MatchPartnerModel({
    required this.name,
    required this.genderIdentity,
    required this.sexualOrientation,
    this.birthDate,
    this.avatarUrl = '',
  });

  final String  name;
  final String  genderIdentity;
  final String  sexualOrientation;
  final String? birthDate;
  final String  avatarUrl;

  String get genderLabel {
    const map = {
      'homem':       'Homem',
      'mulher':      'Mulher',
      'mulhertrans': 'Mulher Trans',
      'homemtrans':  'Homem Trans',
      'naobinario':  'Não-binário',
    };
    return map[genderIdentity.toLowerCase()] ?? genderIdentity;
  }

  String get orientationLabel {
    const map = {
      'hetero':    'Hétero',
      'bissexual': 'Bissexual',
      'pansexual': 'Pansexual',
    };
    return map[sexualOrientation.toLowerCase()] ?? sexualOrientation;
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

  factory MatchPartnerModel.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return MatchPartnerModel(
      name:              map['name']               as String? ?? '',
      genderIdentity:    map['gender_identity']     as String? ?? '',
      sexualOrientation: map['sexual_orientation']  as String? ?? '',
      birthDate:         map['birth_date']           as String?,
      avatarUrl:         map['avatar_url']           as String? ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class MatchProfileModel {
  const MatchProfileModel({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.city,
    required this.state,
    required this.lat,
    required this.lng,
    required this.genderIdentity,
    required this.sexualOrientation,
    required this.relationshipType,
    required this.profileType,
    this.bio,
    this.bairro,
    this.interests = const [],
    this.distanceKm,
    this.birthDate,
    this.ageFromDb,
    this.partner,
  });

  final String  uid;
  final String  name;
  final String  avatarUrl;
  final String  city;
  final String  state;
  final double  lat;
  final double  lng;

  final String  genderIdentity;
  final String  sexualOrientation;
  final String  relationshipType;
  final String  profileType;

  final String? bio;
  final String? bairro;

  /// Lista de interesses do usuário (campo "interests" no nó Matchs).
  final List<String> interests;

  /// Distância calculada em runtime (não vem do banco).
  final double? distanceKm;

  /// Data de nascimento no formato "yyyy-MM-dd" (campo "birth_date" no nó Matchs).
  final String? birthDate;

  /// Idade salva diretamente no Firebase (campo "age"). Tem prioridade sobre o cálculo.
  final int? ageFromDb;

  /// Parceiro(a) do casal. Presente apenas quando profile_type == 'couple'.
  final MatchPartnerModel? partner;

  // ── rótulos legíveis para UI ──────────────────────────────────────────────

  String get genderLabel {
    // Valores = TipoPerfil.name
    const map = {
      'homem':           'Homem',
      'mulher':          'Mulher',
      'mulhertrans':     'Mulher Trans',
      'homemtrans':      'Homem Trans',
      'naobinario':      'Não-binário',
      'prefironaodizerx':'Prefiro não dizer',
    };
    return map[genderIdentity.toLowerCase()] ?? genderIdentity;
  }

  String get orientationLabel {
    // Valores = OrientacaoSexual.name
    const map = {
      'hetero':    'Hétero',
      'bissexual': 'Bissexual',
      'pansexual': 'Pansexual',
    };
    return map[sexualOrientation.toLowerCase()] ?? sexualOrientation;
  }

  String get relationshipLabel {
    // Valores = TipoRelacionamento.name
    const map = {
      'solteiro':        'Solteiro(a)',
      'casal':           'Casal',
      'casalLiberal':    'Casal Liberal',
      'prefironaodizerx':'Prefiro não dizer',
    };
    return map[relationshipType.toLowerCase()] ?? relationshipType;
  }

  /// Idade do perfil. Prioriza o campo "age" do Firebase;
  /// se ausente, calcula a partir de "birth_date".
  int? get age {
    if (ageFromDb != null && ageFromDb! > 0) return ageFromDb;
    if (birthDate == null || birthDate!.isEmpty) return null;
    final birth = DateTime.tryParse(birthDate!);
    if (birth == null) return null;
    final now = DateTime.now();
    int years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years > 0 ? years : null;
  }

  /// Rótulo de idade para exibição. Ex: "28 anos". Vazio se não disponível.
  String get ageLabel => age != null ? '$age anos' : '';

  /// Linha resumida exibida no card: "Mulher  ·  Solteira"
  String get summaryLine {
    final parts = [
      if (age != null) '$age anos',
      if (genderLabel.isNotEmpty) genderLabel,
      if (relationshipLabel.isNotEmpty) relationshipLabel,
    ];
    return parts.join('  ·  ');
  }

  String get locationDisplay {
    final parts = [if (bairro?.isNotEmpty == true) bairro!, city, state]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  String get distanceLabel {
    if (distanceKm == null) return '';
    final km = distanceKm!;
    if (km < 1) return '< 1 km de você';
    return '≈ ${km.round()} km de você';
  }

  // ── Firebase deserialization ──────────────────────────────────────────────

  factory MatchProfileModel.fromMap(String uid, Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return MatchProfileModel(
      uid:                uid,
      name:               map['name']               as String? ?? '',
      avatarUrl:          map['avatar']              as String? ?? '',
      bio:                map['bio']                 as String?,
      bairro:             map['bairro']              as String?,
      interests: (map['interests'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      city:               map['city']                as String? ?? '',
      state:              map['state']               as String? ?? '',
      lat:                (map['latitude']   as num?)?.toDouble() ?? 0.0,
      lng:                (map['longitude']  as num?)?.toDouble() ?? 0.0,
      genderIdentity:     map['gender_identity']     as String? ?? '',
      sexualOrientation:  map['sexual_orientation']  as String? ?? '',
      relationshipType:   map['relationship_type']   as String? ?? '',
      profileType:        map['profile_type']        as String? ?? 'single',
      birthDate:          map['birth_date']           as String?,
      ageFromDb:          (map['age'] as num?)?.toInt(),
      partner: map['partner'] is Map
          ? MatchPartnerModel.fromMap(map['partner'] as Map)
          : null,
    );
  }

  MatchProfileModel withDistance(double km) => MatchProfileModel(
    uid:               uid,
    name:              name,
    avatarUrl:         avatarUrl,
    bio:               bio,
    bairro:            bairro,
    interests:         interests,
    city:              city,
    state:             state,
    lat:               lat,
    lng:               lng,
    genderIdentity:    genderIdentity,
    sexualOrientation: sexualOrientation,
    relationshipType:  relationshipType,
    profileType:       profileType,
    birthDate:         birthDate,
    ageFromDb:         ageFromDb,
    partner:           partner,
    distanceKm:        km,
  );
}

