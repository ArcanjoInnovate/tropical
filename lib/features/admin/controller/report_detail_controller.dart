// lib/screens/admin/controllers/report_detail_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/admin_theme.dart';
import '../data/models/report_model.dart';
import '../data/models/user_model.dart';
import '../data/services/report_service.dart';
import '../data/services/user_service.dart';

// ── Enum de ações disciplinares ───────────────────────────────────────────────
enum AcaoAdmin {
  ignorar,
  advertencia,
  suspensao,
  banimento,
  removerConteudo;

  String get id {
    switch (this) {
      case AcaoAdmin.ignorar:         return 'ignorar';
      case AcaoAdmin.advertencia:     return 'advertencia';
      case AcaoAdmin.suspensao:       return 'suspensao';
      case AcaoAdmin.banimento:       return 'banimento';
      case AcaoAdmin.removerConteudo: return 'remover_conteudo';
    }
  }

  String get label {
    switch (this) {
      case AcaoAdmin.ignorar:         return 'IGNORAR';
      case AcaoAdmin.advertencia:     return 'ADVERTÊNCIA';
      case AcaoAdmin.suspensao:       return 'SUSPENSÃO';
      case AcaoAdmin.banimento:       return 'BANIMENTO';
      case AcaoAdmin.removerConteudo: return 'REMOVER CONTEÚDO';
    }
  }

  String get descricao {
    switch (this) {
      case AcaoAdmin.ignorar:         return 'Nenhuma medida. Denúncia arquivada como improcedente.';
      case AcaoAdmin.advertencia:     return 'Notifica o usuário formalmente. Sem bloqueio de acesso.';
      case AcaoAdmin.suspensao:       return 'Bloqueia o acesso do usuário por período determinado.';
      case AcaoAdmin.banimento:       return 'Remove o acesso permanentemente. Ação irreversível.';
      case AcaoAdmin.removerConteudo: return 'Apaga o conteúdo denunciado da plataforma.';
    }
  }

  Color get cor {
    switch (this) {
      case AcaoAdmin.ignorar:         return AdminColors.inkPrincipal;
      case AcaoAdmin.advertencia:     return AdminColors.pending;
      case AcaoAdmin.suspensao:       return AdminColors.warning;
      case AcaoAdmin.banimento:       return AdminColors.danger;
      case AcaoAdmin.removerConteudo: return AdminColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case AcaoAdmin.ignorar:         return Icons.check_circle_outline_rounded;
      case AcaoAdmin.advertencia:     return Icons.warning_amber_rounded;
      case AcaoAdmin.suspensao:       return Icons.pause_circle_outline_rounded;
      case AcaoAdmin.banimento:       return Icons.block_rounded;
      case AcaoAdmin.removerConteudo: return Icons.delete_outline_rounded;
    }
  }
}

// ── Controller ────────────────────────────────────────────────────────────────
class ReportDetailController extends ChangeNotifier {
  final ReportService _reportService;
  final UserService   _userService;
  final ReportModel   report;

  ReportDetailController({
    required ReportService reportService,
    required UserService   userService,
    required this.report,
  })  : _reportService = reportService,
        _userService   = userService;

  // ── Estado ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? contentData;
  UserModel?            reportedUser;
  // ── NOVO: dados do usuário que fez a denúncia ─────────────────────────
  UserModel?            reporterUser;
  bool                  loadingContent = true;
  bool                  processando    = false;
  String?               protocolo;

  AcaoAdmin?  acaoSelecionada;
  DateTime?   suspensaoInicio;
  DateTime?   suspensaoFim;

  // ── UID resolvido do denunciado (varia por tipo de denúncia) ──────────
  // Exposto como getter para a View usar (ex: no _buildConteudoChat)
  String? get resolvedReportedUid {
    if (report.tipo == 'posts')   return report.postOwnerId;
    if (report.tipo == 'stories') return report.storyOwnerId;
    if (report.tipo == 'users')   return report.reportedUserId;
    if (report.tipo == 'chats')   return report.reportedUid;
    return null;
  }

  // ── Ações disponíveis por tipo de report ─────────────────────────────────
  List<AcaoAdmin> get acoesDisponiveis {
    const todasAcoes = AcaoAdmin.values;
    if (report.tipo == 'users') {
      return todasAcoes
          .where((a) => a != AcaoAdmin.removerConteudo)
          .toList();
    }
    return todasAcoes.toList();
  }

  // ── Carregamento ─────────────────────────────────────────────────────────
  Future<void> loadContent() async {
    loadingContent = true;
    notifyListeners();
    try {
      final uidDenunciado = resolvedReportedUid;

      await Future.wait([
        _loadContentData(),
        if (uidDenunciado != null) _loadReportedUser(uidDenunciado),
        // ── NOVO: carrega o denunciante em paralelo ──────────────────
        _loadReporterUser(report.reporterUid),
      ]);
    } finally {
      loadingContent = false;
      notifyListeners();
    }
  }

  Future<void> _loadContentData() async {
    contentData = await _reportService.fetchContentData(report);
  }

  Future<void> _loadReportedUser(String uid) async {
    reportedUser = await _userService.fetchById(uid);
  }

  // ── NOVO ──────────────────────────────────────────────────────────────
  Future<void> _loadReporterUser(String uid) async {
    // uid '—' é o fallback do model quando reporter_uid está ausente
    if (uid == '—' || uid.isEmpty) return;
    try {
      reporterUser = await _userService.fetchById(uid);
    } catch (_) {
      // falha silenciosa — a View usa o uid como fallback
    }
  }

  // ── Seleção de ação ───────────────────────────────────────────────────────
  void selectAcao(AcaoAdmin acao) {
    acaoSelecionada = acao;
    notifyListeners();
  }

  void setSuspensaoInicio(DateTime date) {
    suspensaoInicio = date;
    notifyListeners();
  }

  void setSuspensaoFim(DateTime date) {
    suspensaoFim = date;
    notifyListeners();
  }

  // ── Processamento ─────────────────────────────────────────────────────────
  Future<String> processarAcao({
    required String artigoViolado,
    required String motivoAdmin,
  }) async {
    assert(acaoSelecionada != null, 'Selecione uma ação antes de processar');

    processando = true;
    notifyListeners();

    try {
      protocolo = await _reportService.processarDenuncia(
        report:          report,
        acao:            acaoSelecionada!.id,
        motivoAdmin:     motivoAdmin,
        artigoViolado:   artigoViolado,
        suspensaoInicio: suspensaoInicio,
        suspensaoFim:    suspensaoFim,
      );
      return protocolo!;
    } finally {
      processando = false;
      notifyListeners();
    }
  }
}