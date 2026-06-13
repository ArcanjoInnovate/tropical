// lib/screens/admin/presentation/pages/report_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tabuapp/core/helpers/cloudinary_helper.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/core/theme/admin_theme.dart';
import 'package:tabuapp/features/admin/controller/report_detail_controller.dart';
import 'package:tabuapp/core/widgets/inline_video_card.dart';
// ── NOVO: import para navegar ao perfil público ───────────────────────────────
import 'package:tabuapp/features/profile/presentation/pages/profile/public_profile_screen.dart';
import '../../data/models/report_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/report_service.dart';
import '../../data/services/user_service.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/user_repository.dart';

// ── Artigos do Tabu ───────────────────────────────────────────────────────────
class ArtigoTabu {
  final String codigo;
  final String fonte;
  final String titulo;
  final String descricaoBase;

  const ArtigoTabu({
    required this.codigo,
    required this.fonte,
    required this.titulo,
    required this.descricaoBase,
  });

  String get label => '$codigo – $titulo';
}

const List<ArtigoTabu> kArtigosTabu = [
  ArtigoTabu(
    codigo: 'Art. 1º – TU', fonte: 'Termos de Uso',
    titulo: 'Restrição de idade (18+)',
    descricaoBase:
        'Você está sendo penalizado porque utilizou o Tabu sendo menor de 18 anos, '
        'ou forneceu dados falsos para burlar a restrição etária da plataforma. '
        'O acesso ao app é exclusivo para maiores de idade e sua conduta viola diretamente essa regra.',
  ),
  ArtigoTabu(
    codigo: 'Art. 4º – TU', fonte: 'Termos de Uso',
    titulo: 'Informações de cadastro falsas',
    descricaoBase:
        'Você está sendo penalizado porque criou sua conta com informações falsas ou '
        'deliberadamente incorretas. Mentir no cadastro é uma violação direta dos Termos de Uso '
        'e compromete a integridade da plataforma para todos os outros usuários.',
  ),
  ArtigoTabu(
    codigo: 'Art. 5º – TU', fonte: 'Termos de Uso',
    titulo: 'Comprometimento de segurança da conta',
    descricaoBase:
        'Você está sendo penalizado porque sua conta foi utilizada de forma indevida, '
        'seja por compartilhamento de acesso, negligência com suas credenciais ou '
        'permissão de uso por terceiros. Você é o único responsável por tudo que acontece na sua conta.',
  ),
  ArtigoTabu(
    codigo: 'Art. 6º – TU', fonte: 'Termos de Uso',
    titulo: 'Informações fraudulentas',
    descricaoBase:
        'Você está sendo penalizado porque foram identificadas fraudes ou inconsistências '
        'graves nas informações vinculadas à sua conta. Contas com dados fraudulentos '
        'são passíveis de suspensão imediata ou exclusão definitiva da plataforma.',
  ),
  ArtigoTabu(
    codigo: 'Art. 9º – TU', fonte: 'Termos de Uso',
    titulo: 'Responsabilidade pelo conteúdo publicado',
    descricaoBase:
        'Você está sendo penalizado porque publicou ou compartilhou conteúdo impróprio '
        'na plataforma. Tudo o que você posta é de sua responsabilidade — '
        'não existe "foi sem querer" ou "era uma brincadeira" como justificativa válida.',
  ),
  ArtigoTabu(
    codigo: 'Art. 10º, I – TU', fonte: 'Termos de Uso',
    titulo: 'Conteúdo ilegal',
    descricaoBase:
        'Você está sendo penalizado porque publicou conteúdo que viola a lei. '
        'A plataforma não tolera qualquer tipo de conteúdo ilegal e se reserva o direito '
        'de reportar o caso às autoridades competentes caso necessário.',
  ),
  ArtigoTabu(
    codigo: 'Art. 10º, II – TU', fonte: 'Termos de Uso',
    titulo: 'Conteúdo ofensivo, discriminatório ou prejudicial',
    descricaoBase:
        'Você está sendo penalizado porque seu conteúdo foi considerado ofensivo, '
        'discriminatório ou diretamente prejudicial a outros usuários. '
        'Esse tipo de comportamento não será tolerado e pode resultar em punições progressivas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 10º, III – TU', fonte: 'Termos de Uso',
    titulo: 'Comprometimento da segurança do app',
    descricaoBase:
        'Você está sendo penalizado porque seu comportamento ou conteúdo colocou '
        'em risco a segurança e a integridade do aplicativo. Isso inclui tentativas '
        'de explorar brechas, disseminar malware ou prejudicar a experiência de outros usuários.',
  ),
  ArtigoTabu(
    codigo: 'Art. 18º – TU', fonte: 'Termos de Uso',
    titulo: 'Violação sujeita a denúncia',
    descricaoBase:
        'Você está sendo penalizado porque sua conduta foi denunciada por outros usuários '
        'e a equipe do Tabu confirmou a violação após análise. '
        'Reincidências serão tratadas com punições cada vez mais severas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 19º – TU', fonte: 'Termos de Uso',
    titulo: 'Aplicação de penalidade formal',
    descricaoBase:
        'Você está sendo penalizado formalmente após análise da equipe do Tabu. '
        'Esta penalidade foi aplicada dentro dos critérios previstos nos Termos de Uso '
        'e representa uma medida oficial da plataforma contra sua conduta.',
  ),
  ArtigoTabu(
    codigo: 'Art. 20º – TU', fonte: 'Termos de Uso',
    titulo: 'Violação grave – medidas legais',
    descricaoBase:
        'Você está sendo penalizado por uma violação considerada grave pela equipe do Tabu. '
        'Além da punição na plataforma, o Tabu se reserva o direito de tomar as medidas '
        'legais cabíveis, incluindo registro de boletim de ocorrência e acionamento judicial.',
  ),
  ArtigoTabu(
    codigo: 'Art. 2º – PP', fonte: 'Política de Privacidade',
    titulo: 'Uso indevido de dados pessoais',
    descricaoBase:
        'Você está sendo penalizado porque utilizou ou tentou utilizar dados pessoais '
        'de outros usuários de forma não autorizada. Dados coletados pela plataforma '
        'existem para o funcionamento do app — qualquer uso fora disso é uma violação grave.',
  ),
  ArtigoTabu(
    codigo: 'Art. 3º – PP', fonte: 'Política de Privacidade',
    titulo: 'Compartilhamento não autorizado de dados',
    descricaoBase:
        'Você está sendo penalizado porque compartilhou ou expôs dados pessoais de '
        'outros usuários sem consentimento. Isso inclui prints, repasses em grupos externos '
        'e qualquer forma de divulgação não autorizada de informações privadas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 5º – PP', fonte: 'Política de Privacidade',
    titulo: 'Exposição indevida de dados de terceiros',
    descricaoBase:
        'Você está sendo penalizado porque publicou conteúdo que expõe informações '
        'privadas de outras pessoas sem autorização. Você é responsável por tudo que '
        'publica, inclusive quando envolve dados de terceiros.',
  ),
  ArtigoTabu(
    codigo: 'Art. 6º – PP', fonte: 'Política de Privacidade',
    titulo: 'Violação da política de privacidade',
    descricaoBase:
        'Você está sendo penalizado porque seu conteúdo ou comportamento viola '
        'diretamente a Política de Privacidade do Tabu. O conteúdo em questão '
        'foi ou será removido, e punições adicionais podem ser aplicadas.',
  ),
  ArtigoTabu(
    codigo: 'Art. 8º – PP', fonte: 'Política de Privacidade',
    titulo: 'Comprometimento de credenciais',
    descricaoBase:
        'Você está sendo penalizado porque suas credenciais foram comprometidas '
        'por negligência ou uso irresponsável. A segurança da sua conta é sua '
        'responsabilidade — qualquer acesso não autorizado decorrente disso recai sobre você.',
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
//  PAGE (entrypoint — cria o controller via Provider)
// ══════════════════════════════════════════════════════════════════════════════
class ReportDetailPage extends StatelessWidget {
  final ReportModel report;

  const ReportDetailPage({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final reportRepo = ReportRepository();
        final userRepo   = UserRepository();
        return ReportDetailController(
          reportService: ReportService(reportRepo),
          userService:   UserService(userRepo),
          report:        report,
        )..loadContent();
      },
      child: const _ReportDetailView(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _ReportDetailView extends StatefulWidget {
  const _ReportDetailView();

  @override
  State<_ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<_ReportDetailView> {
  ArtigoTabu? _artigoSelecionado;
  bool        _editandoArtigo   = false;
  bool        _descricaoEditada = false;

  final _videoScrollCtrl  = ScrollController();
  final _artigoCustomCtrl = TextEditingController();
  final _motivoCtrl       = TextEditingController();

  @override
  void initState() {
    super.initState();
    final report = context.read<ReportDetailController>().report;
    _preencherArtigoInicial(report.artigo);
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _artigoCustomCtrl.dispose();
    _videoScrollCtrl.dispose();
    super.dispose();
  }

  void _preencherArtigoInicial(String artigo) {
    if (artigo.isEmpty) return;
    final match = kArtigosTabu
        .where((a) => a.codigo.toLowerCase() == artigo.toLowerCase())
        .firstOrNull;
    if (match != null) {
      _artigoSelecionado = match;
      _motivoCtrl.text   = match.descricaoBase;
    } else {
      _editandoArtigo        = true;
      _artigoCustomCtrl.text = artigo;
    }
  }

  String get _artigoFinal => _editandoArtigo
      ? _artigoCustomCtrl.text.trim()
      : _artigoSelecionado?.codigo ?? '';

  String get _tipoLabel {
    final tipo = context.read<ReportDetailController>().report.tipo;
    switch (tipo) {
      case 'posts':   return 'POST';
      case 'stories': return 'STORY';
      case 'users':   return 'USUÁRIO';
      default:        return 'CHAT';
    }
  }

  // ── Navegação para perfil público ─────────────────────────────────────────
  void _abrirPerfil(String uid, String nome, {String? avatar}) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PublicProfileScreen(
          userId:     uid,
          userName:   nome,
          userAvatar: avatar,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end:   Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  // ── Seletor de artigo via BottomSheet ─────────────────────────────────────
  Future<void> _abrirSeletorArtigo() async {
    HapticFeedback.selectionClick();

    final grupos = <String, List<ArtigoTabu>>{};
    for (final a in kArtigosTabu) {
      grupos.putIfAbsent(a.fonte, () => []).add(a);
    }

    final selecionado = await showModalBottomSheet<ArtigoTabu>(
      context:            context,
      backgroundColor:    AdminColors.bgAlt,
      isScrollControlled: true,
      shape:              const RoundedRectangleBorder(),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize:     0.4,
        maxChildSize:     0.95,
        expand:           false,
        builder: (_, scrollCtrl) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 3,
            decoration: BoxDecoration(
              color:        AdminColors.border,
              borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Container(width: 2, height: 14, color: AdminColors.accent),
              const SizedBox(width: 10),
              const Text('SELECIONAR ARTIGO VIOLADO', style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      9, fontWeight: FontWeight.w700,
                letterSpacing: 2.5, color: AdminColors.inkPrincipal)),
            ]),
          ),
          Container(height: 0.6, color: AdminColors.border),
          Expanded(child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final entry in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                  child: Row(children: [
                    Container(
                      width:  2, height: 10,
                      color: entry.key == 'Termos de Uso'
                          ? AdminColors.inkPrincipal
                          : const Color(0xFF4FC3F7)),
                    const SizedBox(width: 8),
                    Text(entry.key.toUpperCase(), style: TextStyle(
                      fontFamily:    TabuTypography.bodyFont,
                      fontSize:      7, fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: entry.key == 'Termos de Uso'
                          ? AdminColors.inkPrincipal.withOpacity(0.6)
                          : const Color(0xFF4FC3F7).withOpacity(0.8))),
                  ]),
                ),
                for (final artigo in entry.value)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, artigo),
                    child: Container(
                      margin:  const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _artigoSelecionado?.codigo == artigo.codigo
                            ? AdminColors.inkPrincipal.withOpacity(0.06)
                            : AdminColors.fill,
                        border: Border.all(
                          color: _artigoSelecionado?.codigo == artigo.codigo
                              ? AdminColors.inkPrincipal.withOpacity(0.4)
                              : AdminColors.border,
                          width: 0.6)),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(artigo.codigo, style: TextStyle(
                              fontFamily:    TabuTypography.bodyFont,
                              fontSize:      11, fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color:         AdminColors.inkDeep)),
                            const SizedBox(height: 2),
                            Text(artigo.titulo, style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 10,
                              color: AdminColors.inkDeep.withOpacity(0.55))),
                          ],
                        )),
                        if (_artigoSelecionado?.codigo == artigo.codigo)
                          const Icon(Icons.check_rounded,
                            color: AdminColors.inkPrincipal, size: 14),
                      ]),
                    ),
                  ),
              ],
            ],
          )),
        ]),
      ),
    );

    if (selecionado != null) {
      setState(() {
        _artigoSelecionado = selecionado;
        _descricaoEditada  = false;
        _motivoCtrl.text   = selecionado.descricaoBase;
      });
    }
  }

  // ── Processamento ─────────────────────────────────────────────────────────
  Future<void> _processarAcao() async {
    final ctrl = context.read<ReportDetailController>();

    if (ctrl.acaoSelecionada == null) return;
    if (_artigoFinal.isEmpty) {
      _snack('Selecione ou informe o artigo violado.');
      return;
    }
    if (_motivoCtrl.text.trim().isEmpty) {
      _snack('Preencha a justificativa / descrição da infração.');
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      final protocolo = await ctrl.processarAcao(
        artigoViolado: _artigoFinal,
        motivoAdmin:   _motivoCtrl.text.trim(),
      );
      await _mostrarSucesso(protocolo, ctrl.acaoSelecionada!);
    } on Exception catch (e) {
      _snack('Erro: $e');
    }
  }

  Future<void> _mostrarSucesso(String protocolo, AcaoAdmin acao) async {
    await showModalBottomSheet(
      context:            context,
      backgroundColor:    AdminColors.bg,
      isDismissible:      false,
      isScrollControlled: true,
      shape:              const RoundedRectangleBorder(),
      builder: (_) => _SucessoSheet(
        protocolo: protocolo,
        acao:      acao,
        onOk: () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
        style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 11, letterSpacing: 0.5, color: Colors.white)),
      backgroundColor: AdminColors.inkDeep,
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final ctrl      = context.watch<ReportDetailController>();
    final isPending = ctrl.report.isPending;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor:          AdminColors.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(children: [
            _buildHeader(ctrl),
            Expanded(child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24),
              child: Column(children: [
                _buildInfoDenuncia(ctrl),           // ← recebe ctrl agora
                if (ctrl.reportedUser != null)
                  _buildReportedUser(ctrl.reportedUser!),
                _buildConteudoDenunciado(ctrl),
                if (ctrl.reportedUser != null)
                  _buildHistoricoPenalidades(ctrl.reportedUser!),
                if (!isPending)
                  _buildJaResolvido(ctrl.report),
                if (isPending && ctrl.protocolo == null)
                  _buildFormAcao(ctrl),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(ReportDetailController ctrl) {
    return Container(
      decoration: BoxDecoration(
        color:     AdminColors.bg,
        border:    Border(bottom: BorderSide(
          color: AdminColors.border, width: 0.8)),
        boxShadow: [BoxShadow(
          color: AdminColors.glow, blurRadius: 10,
          offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 38, height: 38,
              color: Colors.transparent,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AdminColors.inkPrincipal, size: 18))),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  color: AdminColors.inkPrincipal,
                  child: Text(_tipoLabel, style: const TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      8, fontWeight: FontWeight.w700,
                    letterSpacing: 2, color: Colors.white))),
                const SizedBox(width: 10),
                const Text('DENÚNCIA · DETALHES', style: TextStyle(
                  fontFamily: TabuTypography.displayFont,
                  fontSize: 11, letterSpacing: 3,
                  color: AdminColors.inkDeep)),
              ]),
              const SizedBox(height: 3),
              Text(ctrl.report.key, style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, letterSpacing: 0.5,
                color: AdminColors.inkPrincipal.withOpacity(0.35))),
            ],
          )),
        ]),
      ),
    );
  }

  // ── Info da denúncia ──────────────────────────────────────────────────────
  // FIX: agora recebe o controller para acessar reporterUser e reportedUser,
  //      e exibe nome clicável para ambos os usuários.
  Widget _buildInfoDenuncia(ReportDetailController ctrl) {
    final r            = ctrl.report;
    final reporterUser = ctrl.reporterUser;   // ← novo campo no controller
    final reportedUser = ctrl.reportedUser;

    // Nome do denunciante: usa o model se carregado, senão o uid como fallback
    final reporterName   = reporterUser?.name.isNotEmpty == true
        ? reporterUser!.name
        : r.reporterUid;
    final reporterAvatar = reporterUser?.avatar;

    // UID resolvido: posts → postOwnerId, chats → reportedUid, etc.
    // r.reportedUid é nulo para posts — sempre usar o getter do controller.
    final reportedUid    = ctrl.resolvedReportedUid;

    // Nome do denunciado: usa o model se carregado, senão reported_name salvo
    // no Firebase (chats têm esse campo), senão o uid como último recurso.
    final reportedName   = reportedUser?.name.isNotEmpty == true
        ? reportedUser!.name
        : (r.reportedName?.isNotEmpty == true ? r.reportedName! : (reportedUid ?? '—'));
    final reportedAvatar = reportedUser?.avatar;

    return _card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('DETALHES DA DENÚNCIA'),
        const SizedBox(height: 14),
        _infoRow('MOTIVO', r.motivo, AdminColors.inkPrincipal),
        const SizedBox(height: 8),
        _infoRow('ARTIGO', r.artigo, AdminColors.inkDeep.withOpacity(0.6)),
        const SizedBox(height: 8),

        // ── Denunciante clicável ─────────────────────────────────────────
        _infoRowClickable(
          label:    'DENUNCIANTE',
          value:    reporterName,
          color:    AdminColors.inkDeep.withOpacity(0.55),
          avatar:   reporterAvatar,
          onTap:    () => _abrirPerfil(
            r.reporterUid,
            reporterName,
            avatar: reporterAvatar,
          ),
        ),

        const SizedBox(height: 8),

        // ── Denunciado clicável ──────────────────────────────────────────
        if (reportedUid != null && reportedUid.isNotEmpty) ...[
          _infoRowClickable(
            label:  'DENUNCIADO',
            value:  reportedName,
            color:  AdminColors.inkDeep.withOpacity(0.55),
            avatar: reportedAvatar,
            onTap:  () => _abrirPerfil(
              reportedUid,
              reportedName,
              avatar: reportedAvatar,
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (r.createdAt != null) ...[
          _infoRow('DATA', _formatData(r.createdAt!), AdminColors.inkDeep.withOpacity(0.45)),
          const SizedBox(height: 8),
        ],
        _infoRow('STATUS', r.status.toUpperCase(), _statusColor(r.status)),
        if (r.descricao.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(12),
            color:   AdminColors.fill,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DESCRIÇÃO', style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      8, fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color:         AdminColors.inkPrincipal.withOpacity(0.4))),
              const SizedBox(height: 6),
              Text(r.descricao, style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12, height: 1.6,
                color: AdminColors.inkDeep.withOpacity(0.75))),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Usuário denunciado ────────────────────────────────────────────────────
  Widget _buildReportedUser(UserModel u) {
    final borderColor = u.banido
        ? AdminColors.danger.withOpacity(0.4)
        : u.suspenso
            ? AdminColors.warning.withOpacity(0.4)
            : AdminColors.border;

    return _card(
      margin:      const EdgeInsets.fromLTRB(16, 10, 16, 0),
      borderColor: borderColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('USUÁRIO DENUNCIADO'),
        const SizedBox(height: 14),

        // ── Card clicável que abre o perfil ──────────────────────────────
        GestureDetector(
          onTap: () => _abrirPerfil(
            u.uid,
            u.name,
            avatar: u.avatar,
          ),
          child: Row(children: [
            // Avatar ou ícone padrão
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color:  AdminColors.fillStrong,
                border: Border.all(color: AdminColors.border)),
              child: u.avatar != null && u.avatar!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl:    u.avatar!,
                      fit:         BoxFit.cover,
                      placeholder: (_, __) => const Icon(Icons.person_outline,
                        color: AdminColors.inkPrincipal, size: 20),
                      errorWidget: (_, __, ___) => const Icon(Icons.person_outline,
                        color: AdminColors.inkPrincipal, size: 20),
                    )
                  : const Icon(Icons.person_outline,
                      color: AdminColors.inkPrincipal, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(u.name.toUpperCase(), style: TextStyle(
                      fontFamily:    TabuTypography.bodyFont,
                      fontSize:      14, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5, color: AdminColors.inkDeep)),
                  ),
                  // ← Ícone indica que é clicável
                  Icon(Icons.open_in_new_rounded,
                    color: AdminColors.inkPrincipal.withOpacity(0.35), size: 13),
                ]),
                if (u.email.isNotEmpty)
                  Text(u.email, style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10, letterSpacing: 0.3,
                    color: AdminColors.inkDeep.withOpacity(0.45))),
                if (u.city.isNotEmpty)
                  Text('${u.city} · ${u.state}', style: TextStyle(
                    fontFamily: TabuTypography.bodyFont, fontSize: 9,
                    color: AdminColors.inkDeep.withOpacity(0.35))),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (u.banido)
                _statusBadge('BANIDO', AdminColors.danger)
              else if (u.suspenso)
                _statusBadge('SUSPENSO', AdminColors.warning)
              else if (u.penalidadeAtiva != null)
                _statusBadge(u.penalidadeAtiva!.toUpperCase(), AdminColors.pending),
              if (u.reportCount > 0) ...[
                const SizedBox(height: 4),
                _statusBadge('${u.reportCount} REPORTS',
                  AdminColors.inkPrincipal.withOpacity(0.45)),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Conteúdo denunciado ───────────────────────────────────────────────────
  Widget _buildConteudoDenunciado(ReportDetailController ctrl) {
    if (ctrl.loadingContent) return _loadingCard();

    return _card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('CONTEÚDO DENUNCIADO'),
        const SizedBox(height: 14),
        if (ctrl.contentData == null)
          Text('Conteúdo não encontrado ou já removido.',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12,
              color: AdminColors.inkDeep.withOpacity(0.4)))
        else if (ctrl.report.tipo == 'posts' || ctrl.report.tipo == 'stories')
          _buildConteudoPost(ctrl.contentData!, ctrl.report)
        else if (ctrl.report.tipo == 'chats')
          _buildConteudoChat(ctrl.contentData!, ctrl.resolvedReportedUid ?? ''),
      ]),
    );
  }

  // ── Conteúdo post/story ───────────────────────────────────────────────────
  Widget _buildConteudoPost(Map<String, dynamic> c, ReportModel report) {
    final titulo    = c['titulo']         as String? ?? c['central_text']  as String?;
    final descricao = c['descricao']      as String? ?? '';
    final tipo      = c['tipo']           as String? ?? c['type']          as String? ?? '—';
    final emoji     = c['emoji']          as String? ?? c['central_emoji'] as String?;
    final mediaUrl  = c['media_url']      as String?;
    final thumbUrl  = c['thumb_url']      as String?;
    final duration  = c['video_duration'] as int?;
    final userName  = c['user_name']      as String? ?? '—';
    final likes     = (c['likes']         as num? ?? 0).toInt();
    final views     = (c['view_count']    as num? ?? 0).toInt();

    final isVideo = tipo == 'video' && mediaUrl != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          color: AdminColors.fill,
          child: Text(tipo.toUpperCase(), style: TextStyle(
            fontFamily:    TabuTypography.bodyFont,
            fontSize:      8, fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color:         AdminColors.inkPrincipal.withOpacity(0.7)))),
        const SizedBox(width: 8),
        Text('por $userName', style: TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 10,
          color: AdminColors.inkDeep.withOpacity(0.45))),
      ]),
      const SizedBox(height: 10),

      if (isVideo)
        ClipRect(
          child: SizedBox(
            height: 220,
            child: InlineVideoCard(
              postId:           report.postId ?? mediaUrl!,
              videoUrl:         mediaUrl!,
              thumbUrl:         thumbUrl,
              duration:         duration,
              gradient:         const [Color(0xFF1a1a1a), Color(0xFF2a2a2a)],
              userName:         userName,
              titulo:           titulo ?? '',
              scrollController: _videoScrollCtrl,
              forceVisible:     true,
              isActive:         true,
              ignoreRouteCheck: true,
            ),
          ),
        ),

      if (!isVideo && emoji != null) ...[
        Center(child: Container(
          width: double.infinity, height: 100,
          color: AdminColors.fill,
          child: Center(child: Text(emoji,
            style: const TextStyle(fontSize: 48))))),
        const SizedBox(height: 10),
      ],

      if (!isVideo && mediaUrl != null && emoji == null) ...[
        ClipRect(child: SizedBox(
          height: 180, width: double.infinity,
          child: CachedNetworkImage(
            imageUrl:       CloudinaryHelper.optimizeImageUrl(mediaUrl),
            fit:            BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder:    (_, __) =>
              Container(height: 80, color: AdminColors.fill),
            errorWidget: (_, __, ___) => Container(
              height: 80, color: AdminColors.fill,
              child: Center(child: Icon(Icons.broken_image_outlined,
                color: AdminColors.inkPrincipal.withOpacity(0.3)))),
          ))),
        const SizedBox(height: 10),
      ],

      if (titulo != null && titulo.isNotEmpty) ...[
        if (isVideo) const SizedBox(height: 10),
        Text(titulo, style: TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      14, fontWeight: FontWeight.w600,
          color:         AdminColors.inkDeep, letterSpacing: 0.3)),
      ],

      if (descricao.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(descricao, style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 12, height: 1.5,
          color: AdminColors.inkDeep.withOpacity(0.55))),
      ],

      const SizedBox(height: 10),
      Row(children: [
        Icon(Icons.favorite_border_rounded,
          color: AdminColors.inkPrincipal.withOpacity(0.35), size: 12),
        const SizedBox(width: 4),
        Text('$likes curtidas', style: TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 9,
          color: AdminColors.inkPrincipal.withOpacity(0.35))),
        if (views > 0) ...[
          const SizedBox(width: 12),
          Icon(Icons.visibility_outlined,
            color: AdminColors.inkPrincipal.withOpacity(0.35), size: 12),
          const SizedBox(width: 4),
          Text('$views visualizações', style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 9,
            color: AdminColors.inkPrincipal.withOpacity(0.35))),
        ],
      ]),
    ]);
  }

  Widget _buildConteudoChat(Map<String, dynamic> msgs, String reportedUid) {
    final entries = msgs.entries
        .where((e) => e.key != 'rs' && e.value is Map)
        .map((e) => Map<String, dynamic>.from(e.value as Map))
        .toList()
      ..sort((a, b) =>
          (a['timestamp'] as int? ?? 0).compareTo(b['timestamp'] as int? ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((msg) {
        final sender     = msg['sender_id'] as String? ?? '';
        final text       = msg['text']      as String? ?? '';
        final ts         = msg['timestamp'] as int?;
        final isReported = sender == reportedUid;

        return Container(
          margin:  const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isReported
                ? AdminColors.danger.withOpacity(0.05)
                : AdminColors.fill,
            border: Border.all(
              color: isReported
                  ? AdminColors.danger.withOpacity(0.2)
                  : AdminColors.border,
              width: 0.6)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isReported)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                margin:  const EdgeInsets.only(right: 8, top: 2),
                color:   AdminColors.danger.withOpacity(0.15),
                child: const Text('●', style: TextStyle(
                  fontSize: 6, color: AdminColors.danger))),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, height: 1.5,
                  color: isReported
                      ? AdminColors.inkDeep.withOpacity(0.8)
                      : AdminColors.inkDeep.withOpacity(0.45))),
                if (ts != null)
                  Text(_formatData(ts), style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      8, letterSpacing: 0.3,
                    color:         AdminColors.inkPrincipal.withOpacity(0.35))),
              ],
            )),
          ]),
        );
      }).toList(),
    );
  }

  // ── Histórico de penalidades ──────────────────────────────────────────────
  Widget _buildHistoricoPenalidades(UserModel u) {
    if (u.penalidades == null) return const SizedBox.shrink();

    final lista = u.penalidades!.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      v['_key'] = e.key;
      return v;
    }).toList()
      ..sort((a, b) =>
          (b['aplicada_em'] as int? ?? 0).compareTo(a['aplicada_em'] as int? ?? 0));

    if (lista.isEmpty) return const SizedBox.shrink();

    return _card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('HISTÓRICO DE PENALIDADES (${lista.length})'),
        const SizedBox(height: 14),
        ...lista.map((p) {
          final tipo   = p['tipo']           as String? ?? '—';
          final artigo = p['artigo_violado']  as String? ?? '—';
          final motivo = p['motivo_admin']    as String? ?? '';
          final proto  = p['protocolo']       as String? ?? '—';
          final em     = p['aplicada_em']     as int?;

          Color tCor = AdminColors.inkPrincipal.withOpacity(0.45);
          if (tipo == 'banimento')        tCor = AdminColors.danger;
          if (tipo == 'suspensao')        tCor = AdminColors.warning;
          if (tipo == 'advertencia')      tCor = AdminColors.pending;
          if (tipo == 'remover_conteudo') tCor = AdminColors.danger;

          return Container(
            margin:  const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:  tCor.withOpacity(0.05),
              border: Border.all(color: tCor.withOpacity(0.25), width: 0.6)),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo.toUpperCase().replaceAll('_', ' '), style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: tCor)),
                  Text(artigo, style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9, letterSpacing: 0.5,
                    color: tCor.withOpacity(0.65))),
                  if (motivo.isNotEmpty)
                    Text(motivo, style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, height: 1.4,
                      color: AdminColors.inkDeep.withOpacity(0.5))),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(proto, style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8, letterSpacing: 0.5,
                  color: AdminColors.inkPrincipal.withOpacity(0.35))),
                if (em != null)
                  Text(_formatData(em), style: TextStyle(
                    fontFamily: TabuTypography.bodyFont, fontSize: 8,
                    color: AdminColors.inkPrincipal.withOpacity(0.35))),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Já resolvido ──────────────────────────────────────────────────────────
  Widget _buildJaResolvido(ReportModel r) {
    final proto = r.protocolo;
    final acao  = r.toMap()['acao_tomada']  as String?;
    final em    = r.toMap()['resolvido_em'] as int?;

    return _card(
      margin:      const EdgeInsets.fromLTRB(16, 10, 16, 0),
      borderColor: r.status == 'actioned'
          ? AdminColors.actioned.withOpacity(0.3)
          : AdminColors.border,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            r.status == 'actioned'
                ? Icons.check_circle_rounded
                : Icons.cancel_outlined,
            color: r.status == 'actioned'
                ? AdminColors.actioned
                : AdminColors.inkDeep.withOpacity(0.3),
            size: 16),
          const SizedBox(width: 8),
          Text(
            r.status == 'actioned'
                ? 'DENÚNCIA RESOLVIDA'
                : 'DENÚNCIA IGNORADA',
            style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      10, fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color:         AdminColors.inkDeep.withOpacity(0.6))),
        ]),
        if (acao != null) ...[
          const SizedBox(height: 8),
          Text('Ação: ${acao.toUpperCase().replaceAll('_', ' ')}',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 11,
              color: AdminColors.inkDeep.withOpacity(0.6))),
        ],
        if (em != null) ...[
          const SizedBox(height: 4),
          Text('Resolvido em: ${_formatData(em)}',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 10,
              color: AdminColors.inkDeep.withOpacity(0.45))),
        ],
        if (proto != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:  AdminColors.fillStrong,
              border: Border.all(color: AdminColors.borderStrong)),
            child: Row(children: [
              const Icon(Icons.tag_rounded,
                color: AdminColors.accent, size: 12),
              const SizedBox(width: 6),
              Text(proto, style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 13, letterSpacing: 2,
                color: AdminColors.inkPrincipal)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Formulário de ação ────────────────────────────────────────────────────
  Widget _buildFormAcao(ReportDetailController ctrl) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color:  AdminColors.fillStrong,
            border: Border.all(color: AdminColors.borderStrong, width: 0.8)),
          child: Row(children: [
            const Icon(Icons.gavel_rounded,
              color: AdminColors.accent, size: 16),
            const SizedBox(width: 10),
            const Text('TOMAR MEDIDA DISCIPLINAR', style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      10, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: AdminColors.inkPrincipal)),
          ]),
        ),
        const SizedBox(height: 12),
        Column(
          children: ctrl.acoesDisponiveis
              .map((a) => _acaoTile(a, ctrl))
              .toList(),
        ),
        if (ctrl.acaoSelecionada == AcaoAdmin.suspensao) ...[
          const SizedBox(height: 12),
          _buildDatePickers(ctrl),
        ],
        const SizedBox(height: 16),
        _buildArtigoVioladoSection(),
        const SizedBox(height: 16),
        _buildConfirmarBtn(ctrl),
        const SizedBox(height: 8),
        Text('Emails serão enviados automaticamente ao denunciante e ao denunciado.',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 9,
            letterSpacing: 0.3,
            color: AdminColors.inkPrincipal.withOpacity(0.35))),
      ]),
    );
  }

  Widget _acaoTile(AcaoAdmin a, ReportDetailController ctrl) {
    final sel = ctrl.acaoSelecionada == a;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ctrl.selectAcao(a);
      },
      child: Container(
        margin:  const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:  sel ? a.cor.withOpacity(0.08) : AdminColors.fill,
          border: Border.all(
            color: sel ? a.cor.withOpacity(0.6) : AdminColors.border,
            width: sel ? 1.0 : 0.6)),
        child: Row(children: [
          Icon(a.icon,
            color: sel ? a.cor : AdminColors.inkPrincipal.withOpacity(0.45),
            size: 16),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.label, style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      11, fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color:         sel ? a.cor : AdminColors.inkDeep.withOpacity(0.65))),
              const SizedBox(height: 2),
              Text(a.descricao, style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9, height: 1.4,
                color: AdminColors.inkDeep.withOpacity(0.4))),
            ],
          )),
          if (sel)
            Icon(Icons.check_circle_rounded, color: a.cor, size: 16),
        ]),
      ),
    );
  }

  Widget _buildDatePickers(ReportDetailController ctrl) {
    return Row(children: [
      Expanded(child: _datePicker(
        label: 'INÍCIO',
        value: ctrl.suspensaoInicio,
        onTap: () async {
          final d = await showDatePicker(
            context:     context,
            initialDate: DateTime.now(),
            firstDate:   DateTime.now(),
            lastDate:    DateTime.now().add(const Duration(days: 365)),
            builder:     (_, child) => _datePickerTheme(child!),
          );
          if (d != null) ctrl.setSuspensaoInicio(d);
        },
      )),
      const SizedBox(width: 8),
      Expanded(child: _datePicker(
        label: 'FIM',
        value: ctrl.suspensaoFim,
        onTap: () async {
          final d = await showDatePicker(
            context:     context,
            initialDate: (ctrl.suspensaoInicio ?? DateTime.now())
                .add(const Duration(days: 1)),
            firstDate: (ctrl.suspensaoInicio ?? DateTime.now())
                .add(const Duration(days: 1)),
            lastDate:    DateTime.now().add(const Duration(days: 365)),
            builder:     (_, child) => _datePickerTheme(child!),
          );
          if (d != null) ctrl.setSuspensaoFim(d);
        },
      )),
    ]);
  }

  Widget _datePicker({
    required String    label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final fmt = DateFormat('dd/MM/yyyy');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:  AdminColors.fill,
          border: Border.all(
            color: value != null
                ? AdminColors.warning.withOpacity(0.5)
                : AdminColors.border,
            width: 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
            fontFamily:    TabuTypography.bodyFont,
            fontSize:      8, fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color:         AdminColors.inkPrincipal.withOpacity(0.4))),
          const SizedBox(height: 6),
          Text(
            value != null ? fmt.format(value) : 'Selecionar',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont, fontSize: 12,
              color: value != null
                  ? AdminColors.inkDeep
                  : AdminColors.inkPrincipal.withOpacity(0.45))),
        ]),
      ),
    );
  }

  Widget _datePickerTheme(Widget child) => Theme(
    data: ThemeData.light().copyWith(
      colorScheme: ColorScheme.light(
        primary:   AdminColors.inkPrincipal,
        onPrimary: Colors.white,
        surface:   AdminColors.bgAlt,
      )),
    child: child);

  // ── Artigo violado ────────────────────────────────────────────────────────
  Widget _buildArtigoVioladoSection() {
    final temArtigo = _artigoSelecionado != null ||
        (_editandoArtigo && _artigoCustomCtrl.text.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color:  AdminColors.fill,
        border: Border.all(
          color: temArtigo ? AdminColors.borderStrong : AdminColors.border,
          width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Container(width: 2, height: 12, color: AdminColors.accent),
            const SizedBox(width: 8),
            Text('ARTIGO VIOLADO *', style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      8, fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color:         AdminColors.inkPrincipal.withOpacity(0.5))),
            const Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _editandoArtigo = !_editandoArtigo;
                  if (_editandoArtigo && _artigoSelecionado != null) {
                    _artigoCustomCtrl.text = _artigoSelecionado!.codigo;
                  } else {
                    _artigoCustomCtrl.clear();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:  _editandoArtigo
                      ? AdminColors.fillStrong
                      : AdminColors.fill,
                  border: Border.all(
                    color: _editandoArtigo
                        ? AdminColors.borderStrong
                        : AdminColors.border,
                    width: 0.6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _editandoArtigo
                        ? Icons.list_rounded
                        : Icons.edit_rounded,
                    color: AdminColors.inkPrincipal, size: 10),
                  const SizedBox(width: 5),
                  Text(
                    _editandoArtigo ? 'USAR LISTA' : 'INSERIR MANUALMENTE',
                    style: const TextStyle(
                      fontFamily:    TabuTypography.bodyFont,
                      fontSize:      7, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color:         AdminColors.inkPrincipal)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        if (!_editandoArtigo) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: GestureDetector(
              onTap: _abrirSeletorArtigo,
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:  AdminColors.bg,
                  border: Border.all(
                    color: _artigoSelecionado != null
                        ? AdminColors.borderStrong
                        : AdminColors.border,
                    width: 0.8)),
                child: Row(children: [
                  Expanded(child: _artigoSelecionado != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_artigoSelecionado!.codigo, style: TextStyle(
                              fontFamily:    TabuTypography.bodyFont,
                              fontSize:      11, fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color:         AdminColors.inkDeep)),
                            const SizedBox(height: 2),
                            Text(_artigoSelecionado!.titulo, style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 9,
                              color: AdminColors.inkDeep.withOpacity(0.55))),
                          ],
                        )
                      : Text('Selecionar artigo violado...', style: TextStyle(
                          fontFamily: TabuTypography.bodyFont, fontSize: 12,
                          color: AdminColors.inkPrincipal.withOpacity(0.35)))),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AdminColors.inkPrincipal, size: 18),
                ]),
              ),
            ),
          ),
          if (_artigoSelecionado != null) ...[
            const SizedBox(height: 10),
            _buildDescricaoComArtigo(),
          ],
        ],

        if (_editandoArtigo) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _campoTexto(
              controller: _artigoCustomCtrl,
              hint:       'Ex: Art. 10º, II – Termos de Uso',
              maxLines:   1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child:   _buildDescricaoManual(mostrarLabel: true),
          ),
        ],
      ]),
    );
  }

  Widget _buildDescricaoComArtigo() {
    final isTU = _artigoSelecionado!.fonte == 'Termos de Uso';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color:   isTU
                ? AdminColors.fillStrong
                : const Color(0xFF4FC3F7).withOpacity(0.12),
            child: Text(_artigoSelecionado!.fonte.toUpperCase(), style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      7, fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color:         isTU
                  ? AdminColors.inkPrincipal
                  : const Color(0xFF4FC3F7)))),
          const SizedBox(width: 8),
          Text('JUSTIFICATIVA / DESCRIÇÃO DA INFRAÇÃO', style: TextStyle(
            fontFamily:    TabuTypography.bodyFont,
            fontSize:      7, fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color:         AdminColors.inkPrincipal.withOpacity(0.35))),
          const Spacer(),
          if (_descricaoEditada)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color:   AdminColors.pending.withOpacity(0.15),
              child: const Text('EDITADO', style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      7, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: AdminColors.pending))),
        ]),
        const SizedBox(height: 8),
        _buildDescricaoManual(mostrarLabel: false),
      ]),
    );
  }

  Widget _buildDescricaoManual({required bool mostrarLabel}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (mostrarLabel) ...[
        const Text('JUSTIFICATIVA / DESCRIÇÃO DA INFRAÇÃO *', style: TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      8, fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color:         AdminColors.inkSubtle)),
        const SizedBox(height: 6),
      ],
      Container(
        decoration: BoxDecoration(
          color:  AdminColors.bg,
          border: Border.all(
            color: _descricaoEditada
                ? AdminColors.pending.withOpacity(0.45)
                : AdminColors.border,
            width: 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _motivoCtrl,
            maxLines:   5,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12, color: AdminColors.inkDeep, height: 1.6),
            cursorColor: AdminColors.inkPrincipal,
            onChanged: (_) {
              if (!_descricaoEditada && _artigoSelecionado != null) {
                setState(() {
                  _descricaoEditada =
                    _motivoCtrl.text != _artigoSelecionado!.descricaoBase;
                });
              }
            },
            decoration: InputDecoration(
              hintText:  'Descreva o motivo da infração e a medida tomada...',
              hintStyle: TextStyle(
                fontFamily: TabuTypography.bodyFont, fontSize: 11,
                color: AdminColors.inkPrincipal.withOpacity(0.3)),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none),
          ),
          if (_descricaoEditada && _artigoSelecionado != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _motivoCtrl.text  = _artigoSelecionado!.descricaoBase;
                  _descricaoEditada = false;
                });
              },
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(
                    color: AdminColors.pending.withOpacity(0.35), width: 0.4))),
                child: Row(children: [
                  const Icon(Icons.refresh_rounded,
                    color: AdminColors.pending, size: 11),
                  const SizedBox(width: 6),
                  const Text('RESTAURAR TEXTO SUGERIDO', style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      8, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: AdminColors.pending)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _buildConfirmarBtn(ReportDetailController ctrl) {
    return GestureDetector(
      onTap: ctrl.acaoSelecionada == null || ctrl.processando
          ? null
          : _processarAcao,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: ctrl.acaoSelecionada != null
              ? LinearGradient(
                  colors: [
                    ctrl.acaoSelecionada!.cor.withOpacity(0.85),
                    ctrl.acaoSelecionada!.cor,
                  ],
                  begin: Alignment.centerLeft,
                  end:   Alignment.centerRight)
              : null,
          color:  ctrl.acaoSelecionada == null ? AdminColors.fill : null,
          border: Border.all(
            color: ctrl.acaoSelecionada == null
                ? AdminColors.border
                : ctrl.acaoSelecionada!.cor,
            width: 0.8)),
        child: Center(child: ctrl.processando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (ctrl.acaoSelecionada != null)
                  Icon(ctrl.acaoSelecionada!.icon,
                    color: Colors.white, size: 15),
                const SizedBox(width: 10),
                Text(
                  ctrl.acaoSelecionada == null
                      ? 'SELECIONE UMA AÇÃO'
                      : 'CONFIRMAR · ${ctrl.acaoSelecionada!.label}',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      10, fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color:         ctrl.acaoSelecionada == null
                        ? AdminColors.inkPrincipal.withOpacity(0.4)
                        : Colors.white)),
              ])),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _campoTexto({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:  AdminColors.bg,
        border: Border.all(color: AdminColors.border, width: 0.8)),
      child: TextField(
        controller: controller,
        maxLines:   maxLines,
        style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 12, color: AdminColors.inkDeep, height: 1.5),
        cursorColor: AdminColors.inkPrincipal,
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 11,
            color: AdminColors.inkPrincipal.withOpacity(0.3)),
          contentPadding: const EdgeInsets.all(12),
          border: InputBorder.none),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    Color? borderColor,
  }) {
    return Container(
      margin:  margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:     AdminColors.bgCard,
        border:    Border.all(
          color: borderColor ?? AdminColors.border, width: 0.8),
        boxShadow: [BoxShadow(
          color: AdminColors.glow, blurRadius: 8,
          offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _loadingCard() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    height: 80,
    decoration: BoxDecoration(
      color:  AdminColors.bgCard,
      border: Border.all(color: AdminColors.border, width: 0.8)),
    child: Center(child: SizedBox(width: 20, height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation(AdminColors.accent)))));

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 2, height: 12, color: AdminColors.accent),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(
      fontFamily:    TabuTypography.bodyFont,
      fontSize:      8, fontWeight: FontWeight.w700,
      letterSpacing: 2.5,
      color:         AdminColors.inkPrincipal.withOpacity(0.5))),
  ]);

  Widget _infoRow(String label, String value, Color color) => Row(children: [
    SizedBox(width: 90,
      child: Text(label, style: TextStyle(
        fontFamily:    TabuTypography.bodyFont,
        fontSize:      8, fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color:         AdminColors.inkPrincipal.withOpacity(0.35)))),
    Expanded(child: Text(value, style: TextStyle(
      fontFamily: TabuTypography.bodyFont,
      fontSize: 11, color: color, letterSpacing: 0.3))),
  ]);

  /// Linha de info clicável — exibe mini avatar + nome + seta
  Widget _infoRowClickable({
    required String        label,
    required String        value,
    required Color         color,
    required VoidCallback  onTap,
    String?                avatar,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        SizedBox(width: 90,
          child: Text(label, style: TextStyle(
            fontFamily:    TabuTypography.bodyFont,
            fontSize:      8, fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color:         AdminColors.inkPrincipal.withOpacity(0.35)))),
        // Mini avatar
        if (avatar != null && avatar.isNotEmpty)
          Container(
            width: 18, height: 18,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color:  AdminColors.fillStrong,
              border: Border.all(color: AdminColors.border, width: 0.5)),
            child: CachedNetworkImage(
              imageUrl:    avatar,
              fit:         BoxFit.cover,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Expanded(child: Row(children: [
          Flexible(
            child: Text(value, style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      11, color: color,
              letterSpacing: 0.3,
              decoration:    TextDecoration.underline,
              decorationColor: color.withOpacity(0.4),
              decorationStyle: TextDecorationStyle.dotted)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.open_in_new_rounded,
            color: AdminColors.inkPrincipal.withOpacity(0.3), size: 10),
        ])),
      ]),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(0.5), width: 0.7)),
    child: Text(label, style: TextStyle(
      fontFamily:    TabuTypography.bodyFont,
      fontSize:      8, fontWeight: FontWeight.w700,
      letterSpacing: 1.5, color: color)));

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':   return AdminColors.pending;
      case 'actioned':  return AdminColors.actioned;
      default:          return AdminColors.inkPrincipal.withOpacity(0.35);
    }
  }

  String _formatData(int ms) =>
      DateFormat('dd/MM/yyyy · HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(ms));
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUCESSO SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _SucessoSheet extends StatelessWidget {
  final String       protocolo;
  final AcaoAdmin    acao;
  final VoidCallback onOk;

  const _SucessoSheet({
    required this.protocolo,
    required this.acao,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
            decoration: BoxDecoration(
              color:        AdminColors.border,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(width: 60, height: 60,
            color: acao.cor.withOpacity(0.1),
            child: Icon(acao.icon, color: acao.cor, size: 26)),
          const SizedBox(height: 16),
          const Text('MEDIDA APLICADA', style: TextStyle(
            fontFamily:    TabuTypography.displayFont,
            fontSize:      16, letterSpacing: 4,
            color:         AdminColors.inkDeep)),
          const SizedBox(height: 6),
          Text(acao.label, style: TextStyle(
            fontFamily:    TabuTypography.bodyFont,
            fontSize:      12, letterSpacing: 2, color: acao.cor)),
          const SizedBox(height: 20),
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:  AdminColors.fillStrong,
              border: Border.all(color: AdminColors.borderStrong)),
            child: Column(children: [
              Text('PROTOCOLO DA DENÚNCIA', style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      8, fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color:         AdminColors.inkPrincipal.withOpacity(0.45))),
              const SizedBox(height: 8),
              Text(protocolo, style: const TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 20, letterSpacing: 3,
                color: AdminColors.inkPrincipal)),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            'Emails enviados automaticamente para o denunciante e denunciado.\n'
            'Guarde o protocolo para referências futuras.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 10, height: 1.6,
              color: AdminColors.inkDeep.withOpacity(0.4))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onOk,
            child: Container(
              width: double.infinity, height: 52,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AdminColors.inkDeep, AdminColors.inkPrincipal],
                  begin:  Alignment.centerLeft,
                  end:    Alignment.centerRight)),
              child: const Center(child: Text('CONCLUIR', style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      11, fontWeight: FontWeight.w700,
                letterSpacing: 3, color: Colors.white))))),
        ]),
      ),
    );
  }
}