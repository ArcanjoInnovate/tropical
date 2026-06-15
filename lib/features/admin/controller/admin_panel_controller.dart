// lib/screens/admin/controllers/admin_panel_controller.dart

import 'package:flutter/foundation.dart';
import '../data/models/admin_stats_model.dart';
import '../data/models/report_model.dart';
import '../data/models/user_model.dart';
import '../data/models/invite_model.dart';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/report_service.dart';
import '../data/services/user_service.dart';
import '../data/services/invite_service.dart';

class AdminPanelController extends ChangeNotifier {
  final StatsRepository _statsRepo;
  final ReportService   _reportService;
  final UserService     _userService;
  final InviteService   _inviteService;
  final UserRepository  _userRepo;

  AdminPanelController({
    required StatsRepository statsRepo,
    required ReportService   reportService,
    required UserService     userService,
    required InviteService   inviteService,
    required UserRepository  userRepo,
  })  : _statsRepo     = statsRepo,
        _reportService = reportService,
        _userService   = userService,
        _inviteService = inviteService,
        _userRepo      = userRepo;

  // ── Estado ───────────────────────────────────────────────────────────────
  AdminStatsModel   stats   = const AdminStatsModel.empty();
  List<ReportModel> reports = [];
  List<UserModel>   users   = [];
  List<InviteModel> invites = [];

  bool loadingStats     = true;
  bool loadingReports   = true;
  bool loadingUsers     = true;
  bool loadingInvites   = true;
  bool loadingMoreUsers = false;

  bool    hasMoreUsers = false;
  String? lastUserName;

  int get pendingReports => reports.where((r) => r.isPending).length;
  int get pendingInvites => invites.where((i) => i.isPending).length;

  // ── Carregamento inicial ──────────────────────────────────────────────────
  // Users é baixado UMA única vez e reaproveitado por stats e lista,
  // evitando download duplo do nó mais pesado do banco.
  Future<void> loadAll() async {
    final usersRaw = await _userRepo.fetchRawMap();

    await Future.wait([
      _loadStats(usersRaw: usersRaw),
      _loadUsersFromRaw(usersRaw),   // ← reutiliza o mesmo download
      _loadReports(),
      _loadInvites(),
    ]);
  }

  Future<void> _loadStats({required Map<String, dynamic> usersRaw}) async {
    loadingStats = true;
    notifyListeners();
    try {
      stats = await _statsRepo.fetchStats(usersRaw: usersRaw);
    } finally {
      loadingStats = false;
      notifyListeners();
    }
  }

  // Monta a lista de usuários a partir do mapa já baixado — sem nova leitura.
  Future<void> _loadUsersFromRaw(Map<String, dynamic> usersRaw) async {
    loadingUsers = true;
    lastUserName = null;
    hasMoreUsers = false;
    notifyListeners();
    try {
      final result = _userService.paginateFromRaw(usersRaw);
      users        = result.users;
      hasMoreUsers = result.hasMore;
      if (users.isNotEmpty) lastUserName = users.last.name;
    } finally {
      loadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> _loadReports() async {
    loadingReports = true;
    notifyListeners();
    try {
      reports = await _reportService.fetchAllMerged();
    } finally {
      loadingReports = false;
      notifyListeners();
    }
  }

  Future<void> _loadInvites() async {
    loadingInvites = true;
    notifyListeners();
    try {
      invites = await _inviteService.fetchAll();
    } finally {
      loadingInvites = false;
      notifyListeners();
    }
  }

  // ── Paginação de usuários ─────────────────────────────────────────────────
  Future<void> loadMoreUsers() async {
    if (loadingMoreUsers || !hasMoreUsers || lastUserName == null) return;

    loadingMoreUsers = true;
    notifyListeners();
    try {
      final result = await _userService.fetchNextPage(lastUserName!);
      users.addAll(result.users);
      hasMoreUsers = result.hasMore;
      if (result.users.isNotEmpty) lastUserName = result.users.last.name;
    } finally {
      loadingMoreUsers = false;
      notifyListeners();
    }
  }

  // ── Ações de reports ──────────────────────────────────────────────────────
  Future<void> dismissReport(ReportModel report) async {
    await _reportService.dismiss(report);
    await Future.wait([_loadReports(), _refreshStats()]);
  }

  Future<void> deleteReportContent(ReportModel report) async {
    await _reportService.deleteContent(report);
    await Future.wait([_loadReports(), _refreshStats()]);
  }

  bool canDeleteReportContent(ReportModel report) =>
      _reportService.canDeleteDirectly(report);

  // ── Ações de convites ─────────────────────────────────────────────────────
  Future<void> processarConvite({
    required String pedidoId,
    required String acao,
    String? motivoRejeicao,
  }) async {
    _setInviteProcessing(pedidoId, true);
    try {
      await _inviteService.processar(
        pedidoId:       pedidoId,
        acao:           acao,
        motivoRejeicao: motivoRejeicao,
      );
      await Future.wait([_loadInvites(), _refreshStats()]);
    } catch (_) {
      _setInviteProcessing(pedidoId, false);
      rethrow;
    }
  }

  void _setInviteProcessing(String pedidoId, bool value) {
    final idx = invites.indexWhere((i) => i.key == pedidoId);
    if (idx != -1) {
      invites[idx] = invites[idx].copyWith(isProcessing: value);
      notifyListeners();
    }
  }

  // ── Refresh de stats — reutiliza users já em memória quando possível ──────
  // Só baixa Users novamente se a lista local estiver vazia,
  // caso contrário reconstrói as stats a partir dos dados em memória.
  Future<void> _refreshStats() async {
    final usersRaw = users.isNotEmpty
        ? { for (final u in users) u.uid: u.toMap() }
        : await _userRepo.fetchRawMap();

    stats = await _statsRepo.fetchStats(usersRaw: usersRaw);
    notifyListeners();
  }

  // ── Refresh público (pull-to-refresh) ────────────────────────────────────
  Future<void> refreshReports() => _loadReports();
  Future<void> refreshInvites() => _loadInvites();

  // Pull-to-refresh de usuários precisa baixar dados frescos do Firebase
  Future<void> refreshUsers() async {
    final usersRaw = await _userRepo.fetchRawMap();
    await Future.wait([
      _loadUsersFromRaw(usersRaw),
      _loadStats(usersRaw: usersRaw),
    ]);
  }
}

