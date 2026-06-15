// lib/features/perfil/data/models/edit_perfil_enums.dart

// ════════════════════════════════════════════════════════════════════════════
//  TIPO DE PERFIL
// ════════════════════════════════════════════════════════════════════════════
enum TipoPerfil {
  homem  ('Homem',  false),
  mulher ('Mulher', false),
  mulherTrans    ('Mulher Trans',    false),
  homemTrans     ('Homem Trans',     false),
  naoBinario       ('Não-binário',    false),
  prefiroNaoDizer ('Prefiro não dizer', false),
  ;

  const TipoPerfil(this.label, this.isCasal);

  final String label;
  final bool   isCasal;
}

// ════════════════════════════════════════════════════════════════════════════
//  ORIENTAÇÃO SEXUAL
// ════════════════════════════════════════════════════════════════════════════
enum OrientacaoSexual {
  hetero    ('Hétero'),
  bissexual ('Bissexual'),
  pansexual  ('Pansexual'),
  ;

  const OrientacaoSexual(this.label);

  final String label;
}

// ════════════════════════════════════════════════════════════════════════════
//  TIPO DE RELACIONAMENTO
// ════════════════════════════════════════════════════════════════════════════
enum TipoRelacionamento {
  solteiro        ('Solteiro'),
  casal           ('Casal'),
  casalLiberal    ('Casal Liberal'),
  prefiroNaoDizer ('Prefiro não dizer');

  const TipoRelacionamento(this.label);

  final String label;
}

// ════════════════════════════════════════════════════════════════════════════
//  DADOS DO PARCEIRO(A)
// ════════════════════════════════════════════════════════════════════════════
class PartnerData {
  String            nome            = '';
  DateTime?         dataNascimento;
  TipoPerfil?       genero;
  OrientacaoSexual? orientacao;

  bool get isValid =>
      nome.trim().isNotEmpty &&
      dataNascimento != null &&
      genero != null &&
      orientacao != null &&
      _isAdult(dataNascimento!);

  static bool _isAdult(DateTime dt) {
    final now   = DateTime.now();
    final years = now.year - dt.year;
    final hadBirthday = now.month > dt.month ||
        (now.month == dt.month && now.day >= dt.day);
    return years > 18 || (years == 18 && hadBirthday);
  }

  String get dataNascimentoLabel {
    if (dataNascimento == null) return '';
    final d = dataNascimento!;
    return '${d.day.toString().padLeft(2, '0')}/'
           '${d.month.toString().padLeft(2, '0')}/'
           '${d.year}';
  }

  // ── serialização ──────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'name':        nome.trim(),
    'birthdate':   dataNascimento?.toIso8601String(),
    'gender':      genero?.name    ?? '',
    'orientation': orientacao?.name ?? '',
  };

  static PartnerData fromMap(Map<String, dynamic> map) {
    final d = PartnerData()
      ..nome       = map['name']        as String? ?? ''
      ..genero     = _generoFromString(map['gender']      as String? ?? '')
      ..orientacao = _orientacaoFromString(map['orientation'] as String? ?? '');

    final raw = map['birthdate'] as String?;
    if (raw != null) d.dataNascimento = DateTime.tryParse(raw);

    return d;
  }

  static OrientacaoSexual? _orientacaoFromString(String s) {
    try { return OrientacaoSexual.values.firstWhere((e) => e.name == s); }
    catch (_) { return null; }
  }

  static TipoPerfil? _generoFromString(String s) {
    try { return TipoPerfil.values.firstWhere((e) => e.name == s); }
    catch (_) { return null; }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HELPER — monta estrutura de dados para Firebase
// ════════════════════════════════════════════════════════════════════════════
Map<String, dynamic> buildProfilePayload({
  required String            name,
  required TipoPerfil?       tipoPerfil,
  required OrientacaoSexual? orientacao,
  required String            avatarUrl,
  required String            bio,
  required List<String>      interests,
  PartnerData?               partner,
}) {
  final profileType = (tipoPerfil?.isCasal ?? false) ? 'couple' : 'single';

  final members = <Map<String, dynamic>>[
    {
      'name':        name,
      'gender':      tipoPerfil?.name  ?? '',
      'orientation': orientacao?.name  ?? '',
      'avatar':      avatarUrl,
    },
  ];

  if (profileType == 'couple' && partner != null) {
    members.add(partner.toMap());
  }

  return {
    'profileType': profileType,
    'members':     members,
    'bio':         bio,
    'interests':   interests,
  };
}

