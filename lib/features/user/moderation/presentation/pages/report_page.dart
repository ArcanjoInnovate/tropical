// lib/features/user/moderation/presentation/pages/report_page.dart
//
//  Tela unificada de denúncia.
//  Substitui: ReportChatScreen, ReportUserScreen, ReportScreen (post)
//             e StoryReportScreen.
//
//  Uso:
//    await ReportPage.push(context, config: ReportPageConfig.chat(...));
//    await ReportPage.push(context, config: ReportPageConfig.post(...));
//    await ReportPage.push(context, config: ReportPageConfig.story(...));
//    await ReportPage.push(context, config: ReportPageConfig.user(...));

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/user/moderation/data/models/report_motives.dart';
import '../../controller/report_controller.dart';
import '../../data/models/report_models.dart';
import '../../data/models/report_motives.dart';
import '../widgets/report_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CONFIG  ·  parâmetros de entrada para cada tipo de denúncia
// ══════════════════════════════════════════════════════════════════════════════
class ReportPageConfig {
  final ReportTargetType type;
  final String           targetId;
  final String           targetOwnerId;
  final String?          targetName;    // user/chat
  final String?          targetTitulo;  // post

  // Texto contextual exibido no header do formulário
  final String           tituloTela;    // ex: 'DENUNCIAR CONVERSA'
  final String           subtituloCard; // ex: 'CONVERSA COM'
  final IconData         iconeCard;

  // Motivos disponíveis para este tipo
  final List<ReportMotivoModel> motivos;

  // Hint do campo de descrição
  final String hintDescricao;

  const ReportPageConfig._({
    required this.type,
    required this.targetId,
    required this.targetOwnerId,
    this.targetName,
    this.targetTitulo,
    required this.tituloTela,
    required this.subtituloCard,
    required this.iconeCard,
    required this.motivos,
    required this.hintDescricao,
  });

  factory ReportPageConfig.post({
    required String postId,
    required String postOwnerId,
    required String postTitulo,
  }) => ReportPageConfig._(
    type:          ReportTargetType.post,
    targetId:      postId,
    targetOwnerId: postOwnerId,
    targetTitulo:  postTitulo,
    tituloTela:    'DENUNCIAR POST',
    subtituloCard: 'POST',
    iconeCard:     Icons.article_outlined,
    motivos:       ReportMotives.post,
    hintDescricao: 'Descreva o que há de errado neste post...',
  );

  factory ReportPageConfig.story({
    required String storyId,
    required String storyOwnerId,
  }) => ReportPageConfig._(
    type:          ReportTargetType.story,
    targetId:      storyId,
    targetOwnerId: storyOwnerId,
    tituloTela:    'DENUNCIAR STORY',
    subtituloCard: 'STORY',
    iconeCard:     Icons.auto_stories_outlined,
    motivos:       ReportMotives.story,
    hintDescricao: 'Descreva o que aconteceu neste story...',
  );

  factory ReportPageConfig.chat({
    required String chatId,
    required String reportedUid,
    required String reportedName,
  }) => ReportPageConfig._(
    type:          ReportTargetType.chat,
    targetId:      chatId,
    targetOwnerId: reportedUid,
    targetName:    reportedName,
    tituloTela:    'DENUNCIAR CONVERSA',
    subtituloCard: 'CONVERSA COM',
    iconeCard:     Icons.chat_bubble_outline_rounded,
    motivos:       ReportMotives.chat,
    hintDescricao: 'Descreva o que aconteceu nesta conversa...',
  );

  factory ReportPageConfig.user({
    required String reportedUserId,
    required String reportedUserName,
  }) => ReportPageConfig._(
    type:          ReportTargetType.user,
    targetId:      reportedUserId,
    targetOwnerId: reportedUserId,
    targetName:    reportedUserName,
    tituloTela:    'DENUNCIAR USUÁRIO',
    subtituloCard: 'USUÁRIO',
    iconeCard:     Icons.person_outline_rounded,
    motivos:       ReportMotives.user,
    hintDescricao: 'Descreva o comportamento deste usuário...',
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  REPORT PAGE
// ══════════════════════════════════════════════════════════════════════════════
class ReportPage extends StatefulWidget {
  final ReportPageConfig config;

  const ReportPage({super.key, required this.config});

  /// Abre a tela com slide-up e aguarda o resultado.
  static Future<void> push(
    BuildContext context, {
    required ReportPageConfig config,
  }) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ReportPage(config: config),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end:   Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve:  Curves.easeOutCubic,
          )),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {

  late final ReportController _ctrl;
  final _descCtrl  = TextEditingController();
  final _descFocus = FocusNode();

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  ReportPageConfig get _cfg => widget.config;

  @override
  void initState() {
    super.initState();

    _ctrl = ReportController();

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    _descCtrl.addListener(() => _ctrl.atualizarDescricao(_descCtrl.text));
    _descFocus.addListener(() => setState(() {}));

    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    _ctrl.init(type: _cfg.type, targetId: _cfg.targetId);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Enviar ─────────────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    if (!_ctrl.podeEnviar) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final payload = ReportPayload(
      targetId:      _cfg.targetId,
      targetOwnerId: _cfg.targetOwnerId,
      targetName:    _cfg.targetName,
      // reporter_uid e created_at são injetados pelo ReportRepository
      // para garantir que batem com auth.uid nas security rules
      motivoId:      _ctrl.motivoSelecionado!.id,
      motivoLabel:   _ctrl.motivoSelecionado!.label,
      artigo:        _ctrl.motivoSelecionado!.artigo,
      descricao:     _ctrl.descricao,
    );

    final ok = await _ctrl.enviar(type: _cfg.type, payload: payload);

    if (ok) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.pop(context);
    } else if (_ctrl.erro != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF3D0A0A),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.all(16),
        content: Text('ERRO: ${_ctrl.erro}',
            style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: TClubColors.textoPrincipal)),
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: TClubColors.bgAlt,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_ctrl.state) {
      case ReportFlowState.checking:
        return _buildLoading();
      case ReportFlowState.alreadyReported:
        return _buildJaReportou();
      case ReportFlowState.success:
        return _buildSucesso();
      case ReportFlowState.idle:
      case ReportFlowState.sending:
        return _buildFormulario();
    }
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() => const Center(
    child: SizedBox(width: 18, height: 18,
      child: CircularProgressIndicator(
          color: TClubColors.redPrincipal, strokeWidth: 1.5)));

  // ── Já denunciou ───────────────────────────────────────────────────────────
  Widget _buildJaReportou() => SafeArea(child: Column(children: [
    _buildAppBar(),
    Expanded(child: ReportJaReportouView(
      titulo:   'JÁ DENUNCIADO',
      mensagem: 'Você já enviou uma denúncia para este conteúdo.\n\nNossa equipe irá analisar em breve.',
      nota:     'Art. 18º e 19º – Código de Conduta Tabu',
      onVoltar: () => Navigator.pop(context),
    )),
  ]));

  // ── Sucesso ────────────────────────────────────────────────────────────────
  Widget _buildSucesso() => SafeArea(child: Column(children: [
    _buildAppBar(),
    Expanded(child: ReportSucessoView(
      titulo:   'DENÚNCIA ENVIADA',
      mensagem: 'Recebemos sua denúncia.\n\nNossa equipe irá analisar o conteúdo '
                'e tomar as medidas cabíveis conforme nossos Termos de Uso.',
      nota:     'Art. 18º, 19º e 20º – Código de Conduta Tabu\nLGPD – Lei 13.709/2018',
      legalBoxItems: const [
        'Sua identidade não será revelada ao denunciado.',
        'A análise é feita de forma sigilosa pela equipe Tabu.',
        'O denunciado não é notificado sobre sua identidade.',
      ],
    )),
  ]));

  // ── Formulário ─────────────────────────────────────────────────────────────
  Widget _buildFormulario() => SafeArea(child: Column(children: [
    _buildAppBar(),
    const ReportLinhaRosa(),
    Expanded(child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        const ReportDivider(),
        const SizedBox(height: 20),

        // ── Aviso de privacidade ─────────────────────────────────────────────
        ReportAvisoPrivacidade(itens: const [
          ReportPrivacyItem(
            icon:  Icons.lock_outline_rounded,
            texto: 'Sua identidade não será revelada ao denunciado em nenhum momento.'),
          ReportPrivacyItem(
            icon:  Icons.visibility_off_outlined,
            texto: 'O conteúdo será acessado somente pela equipe de moderação Tabu.'),
          ReportPrivacyItem(
            icon:  Icons.policy_outlined,
            texto: 'Os dados são tratados conforme a LGPD (Lei 13.709/2018).'),
        ]),
        const SizedBox(height: 20),
        const ReportDivider(),
        const SizedBox(height: 20),

        // ── Passo 01: Motivo ─────────────────────────────────────────────────
        const ReportStepLabel(step: '01', label: 'O QUE ACONTECEU?'),
        const SizedBox(height: 6),
        const Text(
          'Selecione a categoria que melhor descreve o problema',
          style: TextStyle(fontFamily: TClubTypography.bodyFont,
              fontSize: 10, letterSpacing: 0.5, color: TClubColors.subtle)),
        const SizedBox(height: 14),

        // ── FIX: Column em vez de spread para evitar RangeError ──────────────
        Column(
          children: _cfg.motivos.map((m) => ReportMotivoTile(
            motivo:      m,
            selecionado: _ctrl.motivoSelecionado == m,
            onTap:       () => _ctrl.selecionarMotivo(m),
          )).toList(),
        ),

        const SizedBox(height: 20),
        const ReportDivider(),
        const SizedBox(height: 20),

        // ── Passo 02: Descrição ──────────────────────────────────────────────
        const ReportStepLabel(step: '02', label: 'DESCREVA O QUE ACONTECEU'),
        const SizedBox(height: 6),
        Row(children: [
          Text('Mínimo de ${_ctrl.minChars} caracteres',
              style: const TextStyle(fontFamily: TClubTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.5, color: TClubColors.subtle)),
          const Spacer(),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10, letterSpacing: 0.5,
              color: _ctrl.descValida
                  ? TClubColors.redPrincipal
                  : _descCtrl.text.isEmpty
                      ? TClubColors.border
                      : const Color(0xFFE85D5D)),
            child: Text(
                '${_descCtrl.text.trim().length}/${_ctrl.minChars}'),
          ),
        ]),
        const SizedBox(height: 10),
        ReportCampoDescricao(
          controller: _descCtrl,
          focusNode:  _descFocus,
          descValida: _ctrl.descValida,
          minChars:   _ctrl.minChars,
          hintText:   _cfg.hintDescricao,
        ),
        if (!_ctrl.descValida && _descCtrl.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFFE85D5D), size: 11),
              const SizedBox(width: 5),
              Text(
                'Faltam ${_ctrl.minChars - _descCtrl.text.trim().length} caracteres',
                style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 10, letterSpacing: 0.8,
                    color: Color(0xFFE85D5D))),
            ])),

        const SizedBox(height: 20),
        const ReportDivider(),
        const SizedBox(height: 20),

        // ── Passo 03: Base legal ─────────────────────────────────────────────
        const ReportStepLabel(step: '03', label: 'BASE LEGAL'),
        const SizedBox(height: 10),
        _buildBaseLegal(),

        const SizedBox(height: 20),
        const ReportDivider(),
        const SizedBox(height: 20),

        // ── Passo 04: Confirmações (apenas chat) ─────────────────────────────
        if (_ctrl.requerConfirmacoes) ...[
          const ReportStepLabel(step: '04', label: 'CONFIRMAÇÕES OBRIGATÓRIAS'),
          const SizedBox(height: 6),
          const Text(
            'Leia e confirme os itens abaixo antes de enviar',
            style: TextStyle(fontFamily: TClubTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.5, color: TClubColors.subtle)),
          const SizedBox(height: 14),
          ReportCheckConfirm(
            valor:     _ctrl.confirmaVerdade,
            onChanged: _ctrl.toggleConfirmaVerdade,
            texto: 'Confirmo que as informações fornecidas são verídicas e que '
                   'esta denúncia é feita de boa-fé, conforme Art. 19º do Código de Conduta Tabu.',
          ),
          const SizedBox(height: 10),
          ReportCheckConfirm(
            valor:     _ctrl.confirmaConsequencias,
            onChanged: _ctrl.toggleConfirmaConsequencias,
            texto: 'Estou ciente de que denúncias falsas ou de má-fé podem '
                   'resultar em penalidades contra minha conta, incluindo suspensão.',
          ),
          const SizedBox(height: 20),
          const ReportDivider(),
          const SizedBox(height: 20),
        ],

        // ── O que acontece depois ────────────────────────────────────────────
        _buildOQueAcontece(),
        const SizedBox(height: 28),

        // ── Botões ───────────────────────────────────────────────────────────
        ReportBotaoEnviar(
          ativo:    _ctrl.podeEnviar,
          enviando: _ctrl.state == ReportFlowState.sending,
          onTap:    _enviar,
        ),
        const SizedBox(height: 8),
        ReportBotaoSecundario(
          label: 'CANCELAR',
          onTap: () => Navigator.pop(context)),
      ],
    )),
  ]));

  // ── Sub-widgets do formulário ──────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: TClubColors.dim, size: 16),
          onPressed: () => Navigator.pop(context)),
        const Spacer(),
        Text(_cfg.tituloTela, style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700,
            letterSpacing: 3, color: TClubColors.subtle)),
        const SizedBox(width: 6),
      ]),
    );
  }

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF3D0A0A),
            border: Border.all(
                color: const Color(0xFFE85D5D).withOpacity(0.5), width: 0.8)),
          child: const Icon(Icons.report_gmailerrorred_rounded,
              color: Color(0xFFE85D5D), size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Text(_cfg.tituloTela, style: const TextStyle(
            fontFamily: TClubTypography.displayFont,
            fontSize: 17, letterSpacing: 4,
            color: TClubColors.textoPrincipal))),
      ]),
      const SizedBox(height: 14),

      // Card do alvo
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.border, width: 0.6)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: TClubColors.bg,
              border: Border.all(
                  color: TClubColors.border.withOpacity(0.8), width: 0.7)),
            child: Icon(_cfg.iconeCard,
                color: TClubColors.subtle, size: 15)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${_cfg.subtituloCard}  ',
                    style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9, letterSpacing: 1.5,
                        color: TClubColors.subtle)),
                if (_cfg.targetName != null)
                  Text(_cfg.targetName!.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 12, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: TClubColors.textoPrincipal)),
                if (_cfg.targetTitulo != null)
                  Flexible(child: Text(_cfg.targetTitulo!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: TClubColors.dim))),
              ]),
              const SizedBox(height: 4),
              const Text(
                'O conteúdo será usado como base para a análise.',
                style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 9, letterSpacing: 0.3,
                    color: TClubColors.subtle, height: 1.4)),
            ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF3D0A0A),
              border: Border.all(
                  color: const Color(0xFFE85D5D).withOpacity(0.4), width: 0.6)),
            child: Text(_cfg.subtituloCard,
                style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 7, fontWeight: FontWeight.w700,
                    letterSpacing: 2, color: Color(0xFFE85D5D)))),
        ])),
      const SizedBox(height: 10),
      const Text(
        'Denúncias são tratadas de forma confidencial, conforme nossa Política de Privacidade e LGPD.',
        style: TextStyle(fontFamily: TClubTypography.bodyFont,
            fontSize: 9, letterSpacing: 0.3,
            color: TClubColors.subtle, height: 1.5)),
    ]);
  }

  Widget _buildBaseLegal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(color: TClubColors.border, width: 0.6)),
      child: _ctrl.motivoSelecionado != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.gavel_outlined,
                    color: TClubColors.subtle, size: 12),
                const SizedBox(width: 8),
                Expanded(child: Text(_ctrl.motivoSelecionado!.label,
                    style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: TClubColors.textoPrincipal))),
              ]),
              const SizedBox(height: 8),
              Text(_ctrl.motivoSelecionado!.descricao,
                  style: const TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 10, letterSpacing: 0.3,
                      color: TClubColors.dim, height: 1.55)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TClubColors.redPrincipal.withOpacity(0.07),
                  border: Border.all(
                      color: TClubColors.redPrincipal.withOpacity(0.25),
                      width: 0.6)),
                child: Text(_ctrl.motivoSelecionado!.artigo,
                    style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9, letterSpacing: 1,
                        color: TClubColors.redPrincipal))),
            ])
          : const Row(children: [
              Icon(Icons.gavel_outlined, color: TClubColors.border, size: 12),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'Selecione um motivo para ver a base legal aplicável.',
                  style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 10, letterSpacing: 0.3,
                      color: TClubColors.subtle, height: 1.5))),
            ]),
    );
  }

  Widget _buildOQueAcontece() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(color: TClubColors.border, width: 0.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline_rounded, color: TClubColors.subtle, size: 12),
          SizedBox(width: 8),
          Text('O QUE ACONTECE APÓS O ENVIO', style: TextStyle(
              fontFamily: TClubTypography.bodyFont, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: TClubColors.subtle)),
        ]),
        const SizedBox(height: 12),
        const ReportProcessoItem(numero: '1',
            texto: 'Nossa equipe recebe a denúncia e inicia a análise em até 72h.'),
        const SizedBox(height: 8),
        const ReportProcessoItem(numero: '2',
            texto: 'O conteúdo é revisado de forma sigilosa.'),
        const SizedBox(height: 8),
        const ReportProcessoItem(numero: '3',
            texto: 'Se confirmada a violação: aviso, suspensão temporária ou banimento.'),
        const SizedBox(height: 8),
        const ReportProcessoItem(numero: '4',
            texto: 'Você pode ser notificado sobre o resultado, conforme nossa Política de Privacidade.'),
      ]),
    );
  }
}

