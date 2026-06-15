// lib/features/search/presentation/widgets/party_detail_sheet.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/search/domain/entities/party_search.dart';
import 'package:tclub/features/party/data/models/party_model.dart';
import 'package:tclub/features/party/presentation/pages/edit_party_screen.dart';
import 'package:tclub/features/admin/data/services/location_service.dart';
import 'package:tclub/features/admin/data/services/party_service.dart';
import 'package:tclub/core/services/cached_avatar.dart';
import 'package:tclub/core/services/user_data_notifier.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PartyDetailSheet extends StatefulWidget {
  final PartySearchEntity festa;
  final String myUid;
  final bool isAdmin;
  final Map<String, dynamic> userData;

  /// Coordenadas de referência para badge de distância (opcional).
  final ({double latitude, double longitude})? homeCoords;

  /// Chamado após ação que muda dados (presença, comentário, exclusão).
  final VoidCallback onRefresh;

  const PartyDetailSheet({
    super.key,
    required this.festa,
    required this.myUid,
    required this.isAdmin,
    required this.userData,
    required this.homeCoords,
    required this.onRefresh,
  });

  // ── Factory estático ──────────────────────────────────────────────────────

  static Future<void> show(
    BuildContext context, {
    required PartySearchEntity festa,
    required String myUid,
    bool isAdmin = false,
    required Map<String, dynamic> userData,
    ({double latitude, double longitude})? homeCoords,
    required VoidCallback onRefresh,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => PartyDetailSheet(
        festa: festa,
        myUid: myUid,
        isAdmin: isAdmin,
        userData: userData,
        homeCoords: homeCoords,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<PartyDetailSheet> createState() => _PartyDetailSheetState();
}

class _PartyDetailSheetState extends State<PartyDetailSheet> {
  // ── Presença ──────────────────────────────────────────────────────────────
  FestaPresenca _presenca = FestaPresenca.nenhuma;
  bool _loadingPres = false;

  // ── Contadores locais (otimista + listener RT nos nós folha) ──────────────
  late int _interessados;
  late int _confirmados;
  StreamSubscription? _subInt;
  StreamSubscription? _subCon;

  // ── Comentários (carga inicial + RT via onChildAdded) ─────────────────────
  List<Map<String, dynamic>> _comentarios = [];
  bool _loadingComs = true;
  StreamSubscription? _subComs;
  // Ids já carregados — evita duplicata entre carga inicial e listener RT.
  final Set<String> _comentariosIds = {};

  final _comCtrl = TextEditingController();
  final _comFocus = FocusNode();
  bool _enviando = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _interessados = widget.festa.interessados;
    _confirmados  = widget.festa.confirmados;
    _carregarPresenca();
    // carga inicial → ao terminar, ativa o listener RT dentro do método
    _carregarComentarios();
    _ouvirContadores();
  }

  @override
  void dispose() {
    _subInt?.cancel();
    _subCon?.cancel();
    _subComs?.cancel();
    _comCtrl.dispose();
    _comFocus.dispose();
    super.dispose();
  }

  // ── Listener RT — contadores (nós folha, ~50 bytes por evento) ───────────
  void _ouvirContadores() {
    final db = FirebaseDatabase.instance;
    _subInt = db
        .ref('Festas/${widget.festa.id}/interessados')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final v = (event.snapshot.value as num? ?? 0).toInt();
      if (v != _interessados) setState(() => _interessados = v);
    });
    _subCon = db
        .ref('Festas/${widget.festa.id}/confirmados')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final v = (event.snapshot.value as num? ?? 0).toInt();
      if (v != _confirmados) setState(() => _confirmados = v);
    });
  }

  // ── Carga inicial + ativa listener RT ────────────────────────────────────
  Future<void> _carregarComentarios() async {
  setState(() => _loadingComs = true);
  try {
    final list =
        await PartyService.instance.fetchComentarios(widget.festa.id);
    if (!mounted) return;
    
    // Garante que cada map tem o campo 'id' embutido
    final withIds = list.map((c) {
      if (c['id'] == null) return {...c, 'id': c['key'] ?? c['uid'] ?? UniqueKey().toString()};
      return c;
    }).toList();
    
    setState(() {
      _comentarios = withIds;
      _comentariosIds.clear();
      for (final c in withIds) {
        final id = c['id'] as String?;
        if (id != null) _comentariosIds.add(id);
      }
      _loadingComs = false;
    });
  } catch (_) {
    if (mounted) setState(() => _loadingComs = false);
  }
  _ouvirComentarios();
}

  // ── Listener RT — novos comentários via onChildAdded ─────────────────────
  // onChildAdded re-dispara para todos os filhos ao conectar, mas
  // _comentariosIds já contém os ids da carga inicial — todos descartados.
  // Só comentários genuinamente novos passam pelo filtro.
  // Sem orderByChild → sem necessidade de .indexOn nas regras.
  void _ouvirComentarios() {
    _subComs?.cancel();
    _subComs = FirebaseDatabase.instance
        .ref('Festas/${widget.festa.id}/comentarios')
        .onChildAdded
        .listen((event) {
      if (!mounted || !event.snapshot.exists) return;
      final id = event.snapshot.key;
      if (id == null || _comentariosIds.contains(id)) return;
      final raw = event.snapshot.value;
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      data['id'] = id;
      _comentariosIds.add(id);
      setState(() => _comentarios = [..._comentarios, data]);
    });
  }

  // ── Presença ──────────────────────────────────────────────────────────────

  Future<void> _carregarPresenca() async {
    if (widget.myUid.isEmpty) return;
    final p = await PartyService.instance.getPresenca(
      widget.festa.id,
      widget.myUid,
    );
    if (mounted) setState(() => _presenca = p);
  }

  Future<void> _togglePresenca(FestaPresenca nova) async {
    if (_loadingPres) return;

    final anterior = _presenca;
    final destino  = nova == anterior ? FestaPresenca.nenhuma : nova;

    setState(() {
      if (anterior == FestaPresenca.interessado)
        _interessados = (_interessados - 1).clamp(0, 9999);
      if (anterior == FestaPresenca.confirmado)
        _confirmados  = (_confirmados  - 1).clamp(0, 9999);
      if (destino  == FestaPresenca.interessado) _interessados++;
      if (destino  == FestaPresenca.confirmado)  _confirmados++;
      _presenca    = destino;
      _loadingPres = true;
    });

    HapticFeedback.selectionClick();

    try {
      await PartyService.instance.setPresenca(
        widget.festa.id, widget.myUid, anterior, destino,
      );
      if (mounted) setState(() => _loadingPres = false);
      widget.onRefresh();
    } catch (_) {
      // Rollback completo para o estado anterior
      if (mounted) {
        setState(() {
          if (destino  == FestaPresenca.interessado)
            _interessados = (_interessados - 1).clamp(0, 9999);
          if (destino  == FestaPresenca.confirmado)
            _confirmados  = (_confirmados  - 1).clamp(0, 9999);
          if (anterior == FestaPresenca.interessado) _interessados++;
          if (anterior == FestaPresenca.confirmado)  _confirmados++;
          _presenca    = anterior;
          _loadingPres = false;
        });
      }
    }
  }

  // ── Comentário ────────────────────────────────────────────────────────────
  // Clear + unfocus ANTES do await → campo limpa e teclado fecha imediatamente.
  Future<void> _enviarComentario() async {
    final texto = _comCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    HapticFeedback.selectionClick();

    // Fecha teclado e limpa campo ANTES da chamada async
    _comCtrl.clear();
    _comFocus.unfocus();

    try {
      await PartyService.instance.addComentario(
        festaId: widget.festa.id,
        uid: widget.myUid,
        userName: UserDataNotifier.instance.name.isNotEmpty
            ? UserDataNotifier.instance.name
            : 'Usuário',
        userAvatar: UserDataNotifier.instance.avatar.isNotEmpty
            ? UserDataNotifier.instance.avatar
            : null,
        texto: texto,
      );
      // Não precisa recarregar — onChildAdded já captura o novo comentário.
      if (mounted) setState(() => _enviando = false);
    } catch (_) {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Excluir com confirmação ───────────────────────────────────────────────

  Future<void> _confirmarExclusao() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TClubColors.bgAlt,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'EXCLUIR FESTA',
          style: TextStyle(
            fontFamily: TClubTypography.displayFont,
            fontSize: 16,
            letterSpacing: 2,
            color: TClubColors.textoPrincipal,
          ),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${widget.festa.nome}"? Esta ação não pode ser desfeita.',
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 13,
            color: TClubColors.dim,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10,
                letterSpacing: 2,
                color: TClubColors.subtle,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'EXCLUIR',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Color(0xFFE85D5D),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    Navigator.pop(context);
    await PartyService.instance.deleteFesta(widget.festa.id);
    widget.onRefresh();
  }

  // ── Editar ────────────────────────────────────────────────────────────────

  Future<void> _abrirEditar() async {
    final model = PartyModel(
      id: widget.festa.id,
      creatorId: widget.festa.creatorId,
      creatorName: widget.festa.creatorName,
      nome: widget.festa.nome,
      descricao: widget.festa.descricao ?? '',
      local: widget.festa.local,
      bairro: widget.festa.bairro,
      city: widget.festa.cidade,
      state: widget.festa.estado,
      latitude: widget.festa.latitude,
      longitude: widget.festa.longitude,
      dataInicio: widget.festa.dataInicio,
      dataFim: widget.festa.dataFim,
      bannerUrl: widget.festa.bannerUrl,
      interessados: _interessados,
      confirmados: _confirmados,
      commentCount: widget.festa.commentCount,
      createdAt: widget.festa.dataInicio,
    );

    Navigator.pop(context);

    final ok = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            EditPartyScreen(festa: model, userData: widget.userData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    if (ok == true) widget.onRefresh();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? get _distLabel {
    if (widget.homeCoords == null || !widget.festa.canShowDistance) return null;
    final km = LocationService.distanceKm(
      widget.homeCoords!.latitude,
      widget.homeCoords!.longitude,
      widget.festa.latitude!,
      widget.festa.longitude!,
    );
    return LocationService.formatDistance(km);
  }

  String _fd(DateTime dt) {
    const m = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${m[dt.month - 1]} · ${dt.year}';
  }

  String _fh(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final festa = widget.festa;
    final temBanner = festa.hasBanner;
    final podeGerenciar =
        festa.creatorId == widget.myUid || widget.isAdmin;
    final dist = _distLabel;
    final descricao = festa.descricao ?? '';
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, ctrl) => AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: TClubColors.bgAlt,
            border: Border(
              top: BorderSide(color: TClubColors.redPrincipal, width: 1.5),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: TClubColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Conteúdo scrollável ─────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: ctrl,
                  children: [
                    // Banner
                    if (temBanner)
                      SizedBox(
                        height: 200,
                        child: CachedNetworkImage(
                          imageUrl:
                              CloudinaryHelper.bannerUrl(festa.bannerUrl!),
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => Container(
                              height: 200, color: TClubColors.bgCard),
                          errorWidget: (_, __, ___) => Container(
                              height: 200, color: TClubColors.bgCard),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Data ─────────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            color: TClubColors.redPrincipal,
                            child: Text(
                              _fd(festa.dataInicio),
                              style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Nome ──────────────────────────────────────────
                          Text(
                            festa.nome.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: TClubTypography.displayFont,
                              fontSize: 26,
                              letterSpacing: 3,
                              color: TClubColors.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Local + distância ─────────────────────────────
                          Row(
                            children: [
                              Icon(
                                festa.hasLocal
                                    ? Icons.location_on_outlined
                                    : Icons.location_off_outlined,
                                color: festa.hasLocal
                                    ? TClubColors.redPrincipal
                                    : TClubColors.subtle,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  festa.hasLocal
                                      ? festa.local!
                                      : 'Local não confirmado',
                                  style: TextStyle(
                                    fontFamily: TClubTypography.bodyFont,
                                    fontSize: 13,
                                    fontStyle: festa.hasLocal
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                    color: festa.hasLocal
                                        ? TClubColors.redClaro
                                        : TClubColors.subtle,
                                  ),
                                ),
                              ),
                              if (dist != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: TClubColors.redPrincipal
                                        .withOpacity(0.12),
                                    border: Border.all(
                                      color: TClubColors.redPrincipal
                                          .withOpacity(0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.near_me_rounded,
                                          color: TClubColors.redPrincipal,
                                          size: 11),
                                      const SizedBox(width: 5),
                                      Text(
                                        dist,
                                        style: const TextStyle(
                                          fontFamily: TClubTypography.bodyFont,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                          color: TClubColors.redPrincipal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),

                          // ── Horário ───────────────────────────────────────
                          Row(
                            children: [
                              const Icon(Icons.schedule_outlined,
                                  color: TClubColors.subtle, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                '${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                                style: const TextStyle(
                                  fontFamily: TClubTypography.bodyFont,
                                  fontSize: 12,
                                  color: TClubColors.dim,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Botões de presença ────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _PresenceButton(
                                  icon: Icons.star_rounded,
                                  label: 'INTERESSADO',
                                  count: _interessados,
                                  ativo: _presenca ==
                                      FestaPresenca.interessado,
                                  loading: _loadingPres,
                                  color: TClubColors.redClaro,
                                  onTap: () => _togglePresenca(
                                      FestaPresenca.interessado),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PresenceButton(
                                  icon: Icons.check_circle_rounded,
                                  label: 'VOU!',
                                  count: _confirmados,
                                  ativo: _presenca ==
                                      FestaPresenca.confirmado,
                                  loading: _loadingPres,
                                  color: const Color(0xFF4ECDC4),
                                  onTap: () => _togglePresenca(
                                      FestaPresenca.confirmado),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(height: 0.5, color: TClubColors.border),
                          const SizedBox(height: 16),

                          // ── Descrição ─────────────────────────────────────
                          if (descricao.isNotEmpty) ...[
                            const Text(
                              'SOBRE A NOITE',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: TClubColors.subtle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              descricao,
                              style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 14,
                                color: TClubColors.dim,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(height: 0.5, color: TClubColors.border),
                            const SizedBox(height: 16),
                          ],

                          // ── Badge admin ───────────────────────────────────
                          if (widget.isAdmin &&
                              festa.creatorId != widget.myUid)
                            Row(
                              children: [
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: TClubColors.redPrincipal
                                        .withOpacity(0.12),
                                    border: Border.all(
                                      color: TClubColors.redPrincipal
                                          .withOpacity(0.4),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontFamily: TClubTypography.bodyFont,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: TClubColors.redPrincipal,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          // ── Botões EDITAR / EXCLUIR ───────────────────────
                          if (podeGerenciar) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _abrirEditar,
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: TClubColors.bgCard,
                                        border: Border.all(
                                          color: TClubColors.redPrincipal
                                              .withOpacity(0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.edit_rounded,
                                              color:
                                                  TClubColors.redPrincipal,
                                              size: 14),
                                          SizedBox(width: 7),
                                          Text(
                                            'EDITAR',
                                            style: TextStyle(
                                              fontFamily:
                                                  TClubTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.5,
                                              color:
                                                  TClubColors.redPrincipal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _confirmarExclusao,
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3D0A0A),
                                        border: Border.all(
                                          color: const Color(0xFFE85D5D)
                                              .withOpacity(0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                              Icons.delete_outline_rounded,
                                              color: Color(0xFFE85D5D),
                                              size: 14),
                                          SizedBox(width: 7),
                                          Text(
                                            'EXCLUIR',
                                            style: TextStyle(
                                              fontFamily:
                                                  TClubTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.5,
                                              color: Color(0xFFE85D5D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 20),
                          Container(height: 0.5, color: TClubColors.border),
                          const SizedBox(height: 16),

                          // ── Comentários ───────────────────────────────────
                          Row(children: [
                            const Text(
                              'COMENTÁRIOS',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: TClubColors.redPrincipal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // indicador "ao vivo"
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: TClubColors.redPrincipal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),

                          if (_loadingComs)
                            const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: TClubColors.redPrincipal,
                                  strokeWidth: 1.5,
                                ),
                              ),
                            )
                          else if (_comentarios.isEmpty)
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Seja o primeiro a comentar',
                                style: TextStyle(
                                  fontFamily: TClubTypography.bodyFont,
                                  fontSize: 11,
                                  color: TClubColors.subtle,
                                ),
                              ),
                            )
                          else
                            ..._comentarios
                                .map((c) => _CommentTile(data: c)),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Barra de envio (fixada no fundo) ─────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: TClubColors.bgAlt,
                  border: Border(
                    top: BorderSide(color: TClubColors.border, width: 0.5),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  keyboardHeight > 0
                      ? 12
                      : MediaQuery.of(context).padding.bottom + 10,
                ),
                child: Row(
                  children: [
                    CachedAvatar(
                      uid: widget.myUid,
                      name: UserDataNotifier.instance.name,
                      size: 30,
                      radius: 8,
                      isOwn: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: TClubColors.bgCard,
                          border: Border.all(
                              color: TClubColors.border, width: 0.8),
                        ),
                        child: TextField(
                          controller: _comCtrl,
                          focusNode: _comFocus,
                          style: const TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 13,
                            color: TClubColors.textoPrincipal,
                          ),
                          cursorColor: TClubColors.redPrincipal,
                          decoration: const InputDecoration(
                            hintText: 'Comentar...',
                            border: InputBorder.none,
                            isDense: true,
                            hintStyle: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 13,
                              color: TClubColors.subtle,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _enviarComentario(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _enviando ? null : _enviarComentario,
                      child: Container(
                        width: 36,
                        height: 36,
                        color: TClubColors.redPrincipal,
                        child: _enviando
                            ? const Center(
                                child: SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 1.5,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

/// Botão de presença (interessado / confirmado).
class _PresenceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool ativo;
  final bool loading;
  final Color color;
  final VoidCallback onTap;

  const _PresenceButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.ativo,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: ativo ? color.withOpacity(0.15) : TClubColors.bgCard,
          border: Border.all(
            color: ativo ? color.withOpacity(0.7) : TClubColors.border,
            width: ativo ? 1.2 : 0.8,
          ),
        ),
        child: loading
            ? Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: color, strokeWidth: 1.5),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: ativo ? color : TClubColors.subtle,
                      size: 16),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: ativo ? color : TClubColors.subtle,
                        ),
                      ),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ativo
                              ? color
                              : TClubColors.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tile de um comentário.
/// Schema Firebase: { user_id, user_name, user_avatar, texto, created_at }
class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CommentTile({required this.data});

  String _formatTime(int? ms) {
    if (ms == null) return '';
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final uid   = data['user_id']    as String? ?? data['uid']      as String? ?? '';
    final name  = data['user_name']  as String? ?? data['userName'] as String? ?? 'Usuário';
    final texto = data['texto']      as String? ?? '';
    final ts    = data['created_at'] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedAvatar(uid: uid, name: name, size: 30, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: TClubColors.textoPrincipal,
                      ),
                    ),
                    if (ts != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(ts),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          color: TClubColors.subtle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 13,
                    color: TClubColors.dim,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

