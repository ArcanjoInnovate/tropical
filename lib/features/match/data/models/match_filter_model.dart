// lib/features/match/data/models/match_filter_model.dart

// ════════════════════════════════════════════════════════════════════════════
//  ENUM — IDENTIDADE DE GÊNERO  (espelha TipoPerfil do edit_perfil_enums)
// ════════════════════════════════════════════════════════════════════════════
enum FiltroGenero {
  homem        ('Homem'),
  mulher       ('Mulher'),
  mulherTrans  ('Mulher Trans'),
  homemTrans   ('Homem Trans'),
  naoBinario   ('Não-binário'),
  ;

  const FiltroGenero(this.label);
  final String label;
}

// ════════════════════════════════════════════════════════════════════════════
//  ENUM — ORIENTAÇÃO SEXUAL  (espelha OrientacaoSexual)
// ════════════════════════════════════════════════════════════════════════════
enum FiltroOrientacao {
  hetero    ('Hétero'),
  bissexual ('Bissexual'),
  pansexual ('Pansexual'),
  ;

  const FiltroOrientacao(this.label);
  final String label;
}

// ════════════════════════════════════════════════════════════════════════════
//  ENUM — TIPO DE RELACIONAMENTO  (espelha TipoRelacionamento)
// ════════════════════════════════════════════════════════════════════════════
enum FiltroRelacionamento {
  solteiro     ('Solteiro(a)'),
  casal        ('Casal'),
  casalLiberal ('Casal Liberal'),
  ;

  const FiltroRelacionamento(this.label);
  final String label;
}

// ════════════════════════════════════════════════════════════════════════════
//  ENUM — TIPO DE LOCALIZAÇÃO
// ════════════════════════════════════════════════════════════════════════════
enum TipoLocalizacao { atual, personalizada }

// ════════════════════════════════════════════════════════════════════════════
//  MODEL
// ════════════════════════════════════════════════════════════════════════════
class MatchFilterModel {
  const MatchFilterModel({
    this.generos          = const {},
    this.orientacoes      = const {},
    this.relacionamentos  = const {},
    this.distanciaKm      = 50.0,
    this.onlyInDistance   = true,
    this.idadeMin         = 18,
    this.idadeMax         = 35,
    this.onlyInAge        = false,
    this.tipoLocalizacao  = TipoLocalizacao.atual,
    this.cidade,
    this.estado,
    this.lat,
    this.lng,
  })  : assert(idadeMin >= 18 && idadeMin <= 70),
        assert(idadeMax >= 18 && idadeMax <= 70),
        assert(idadeMin <= idadeMax),
        assert(distanciaKm >= 1 && distanciaKm <= 320);

  // ── campos de seleção múltipla ────────────────────────────────────────────

  /// Conjunto de gêneros de interesse. Vazio = sem filtro (mostra todos).
  final Set<FiltroGenero>        generos;

  /// Conjunto de orientações de interesse. Vazio = sem filtro.
  final Set<FiltroOrientacao>    orientacoes;

  /// Conjunto de tipos de relacionamento de interesse. Vazio = sem filtro.
  final Set<FiltroRelacionamento> relacionamentos;

  // ── demais campos ─────────────────────────────────────────────────────────
  final double          distanciaKm;
  final bool            onlyInDistance;
  final int             idadeMin;
  final int             idadeMax;
  final bool            onlyInAge;
  final TipoLocalizacao tipoLocalizacao;
  final String?         cidade;
  final String?         estado;
  final double?         lat;
  final double?         lng;

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Resumo dos filtros de perfil para exibição na UI.
  /// Exemplo: "Mulher, Mulher Trans  ·  Hétero"
  String get procurandoPorLabel {
    final g = generos.isEmpty
        ? 'Todos os gêneros'
        : generos.map((e) => e.label).join(', ');
    final o = orientacoes.isEmpty
        ? null
        : orientacoes.map((e) => e.label).join(', ');
    return o != null ? '$g  ·  $o' : g;
  }

  bool get hasProcurandoPorFilter =>
      generos.isNotEmpty || orientacoes.isNotEmpty || relacionamentos.isNotEmpty;

  String get localizacaoLabel {
    if (tipoLocalizacao == TipoLocalizacao.atual) return 'Localização atual';
    if (cidade != null && estado != null)          return '$cidade, $estado';
    return 'Personalizada';
  }

  bool get isLocalizacaoAtual => tipoLocalizacao == TipoLocalizacao.atual;

  // ── copyWith ──────────────────────────────────────────────────────────────
  MatchFilterModel copyWith({
    Set<FiltroGenero>?         generos,
    Set<FiltroOrientacao>?     orientacoes,
    Set<FiltroRelacionamento>? relacionamentos,
    double?                    distanciaKm,
    bool?                      onlyInDistance,
    int?                       idadeMin,
    int?                       idadeMax,
    bool?                      onlyInAge,
    TipoLocalizacao?           tipoLocalizacao,
    String?                    cidade,
    String?                    estado,
    double?                    lat,
    double?                    lng,
  }) =>
      MatchFilterModel(
        generos:         generos         ?? this.generos,
        orientacoes:     orientacoes     ?? this.orientacoes,
        relacionamentos: relacionamentos ?? this.relacionamentos,
        distanciaKm:     distanciaKm     ?? this.distanciaKm,
        onlyInDistance:  onlyInDistance  ?? this.onlyInDistance,
        idadeMin:        idadeMin        ?? this.idadeMin,
        idadeMax:        idadeMax        ?? this.idadeMax,
        onlyInAge:       onlyInAge       ?? this.onlyInAge,
        tipoLocalizacao: tipoLocalizacao ?? this.tipoLocalizacao,
        cidade:          cidade          ?? this.cidade,
        estado:          estado          ?? this.estado,
        lat:             lat             ?? this.lat,
        lng:             lng             ?? this.lng,
      );

  // ── serialização ─────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'generos':          generos.map((e) => e.name).toList(),
    'orientacoes':      orientacoes.map((e) => e.name).toList(),
    'relacionamentos':  relacionamentos.map((e) => e.name).toList(),
    'distancia_km':     distanciaKm,
    'only_in_distance': onlyInDistance,
    'idade_min':        idadeMin,
    'idade_max':        idadeMax,
    'only_in_age':      onlyInAge,
    'tipo_localizacao': tipoLocalizacao.name,
    if (cidade != null) 'cidade': cidade,
    if (estado != null) 'estado': estado,
    if (lat    != null) 'lat':    lat,
    if (lng    != null) 'lng':    lng,
  };

  factory MatchFilterModel.fromMap(Map<String, dynamic> map) {
    Set<T> _parseSet<T extends Enum>(
      List<T> values,
      dynamic raw,
    ) {
      if (raw is! List) return {};
      return raw
          .map((name) => values.cast<Enum>().where((e) => e.name == name).firstOrNull)
          .whereType<T>()
          .toSet();
    }

    return MatchFilterModel(
      generos:         _parseSet(FiltroGenero.values,        map['generos']),
      orientacoes:     _parseSet(FiltroOrientacao.values,    map['orientacoes']),
      relacionamentos: _parseSet(FiltroRelacionamento.values, map['relacionamentos']),
      distanciaKm:     (map['distancia_km']   as num?)?.toDouble() ?? 50.0,
      onlyInDistance:  map['only_in_distance'] as bool?             ?? true,
      idadeMin:        map['idade_min']        as int?               ?? 18,
      idadeMax:        map['idade_max']        as int?               ?? 35,
      onlyInAge:       map['only_in_age']      as bool?             ?? false,
      tipoLocalizacao: TipoLocalizacao.values.firstWhere(
        (e) => e.name == map['tipo_localizacao'],
        orElse: () => TipoLocalizacao.atual,
      ),
      cidade: map['cidade'] as String?,
      estado: map['estado'] as String?,
      lat:    (map['lat']   as num?)?.toDouble(),
      lng:    (map['lng']   as num?)?.toDouble(),
    );
  }
}

