// lib/screens/admin/presentation/pages/admin_panel_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/core/theme/admin_theme.dart';
import 'package:tabuapp/features/admin/controller/admin_panel_controller.dart';
import 'package:tabuapp/features/profile/presentation/pages/profile/public_profile_screen.dart';
import '../../data/models/report_model.dart';
import '../widgets/report_tile.dart';
import '../widgets/user_admin_tile.dart';
import '../widgets/admin_shared_widgets.dart';
import 'report_detail_page.dart';

class AdminPanelPage extends StatefulWidget {
  final String adminUid;

  const AdminPanelPage({super.key, required this.adminUid});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {

  late TabController     _tabCtrl;
  final ScrollController _usersScrollCtrl   = ScrollController();

  // ── Denúncias: busca + filtro ─────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool   _showArchived = false;   // alterna entre pendentes e arquivadas

  @override
  void initState() {
    super.initState();
    // 2 abas: DENÚNCIAS e USUÁRIOS
    _tabCtrl = TabController(length: 2, vsync: this);
    _usersScrollCtrl.addListener(_onUsersScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminPanelController>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _usersScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onUsersScroll() {
    if (_usersScrollCtrl.position.pixels >=
        _usersScrollCtrl.position.maxScrollExtent - 200) {
      context.read<AdminPanelController>().loadMoreUsers();
    }
  }

  // ── Navegação ─────────────────────────────────────────────────────────────
  void _abrirDetalhe(ReportModel report) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ReportDetailPage(report: report),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
          child: child),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ).then((_) => context.read<AdminPanelController>().refreshReports());
  }

  void _abrirPerfilPublico(dynamic user) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PublicProfileScreen(
          userId:     user.uid,
          userName:   user.name,
          userAvatar: user.avatar,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
          child: child),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  // ── Modal: confirmar remoção de conteúdo ──────────────────────────────────
  void _confirmarDelete(ReportModel report) {
    showModalBottomSheet(
      context:         context,
      backgroundColor: AdminColors.bgCard,
      shape:           const RoundedRectangleBorder(),
      builder: (_) => SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
            decoration: BoxDecoration(
              color: AdminColors.border,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(width: 52, height: 52,
            decoration: BoxDecoration(
              color: AdminColors.danger.withOpacity(0.10)),
            child: const Icon(Icons.delete_outline_rounded,
              color: AdminColors.danger, size: 24)),
          const SizedBox(height: 14),
          Text('REMOVER ${report.tipo.toUpperCase()}?',
            style: const TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 14, letterSpacing: 4,
              color: AdminColors.inkDeep)),
          const SizedBox(height: 8),
          const Text(
            'O conteúdo será excluído permanentemente. '
            'Esta ação não pode ser desfeita.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11, height: 1.6,
              color: AdminColors.inkSubtle)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(height: 46,
                decoration: BoxDecoration(
                  color:  AdminColors.fill,
                  border: Border.all(color: AdminColors.border)),
                child: const Center(child: Text('CANCELAR',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color:         AdminColors.inkSubtle)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                context.read<AdminPanelController>()
                    .deleteReportContent(report);
              },
              child: Container(height: 46,
                decoration: const BoxDecoration(color: AdminColors.danger),
                child: const Center(child: Text('REMOVER',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      10, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: Colors.white)))))),
          ]),
        ]),
      )),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.main,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AdminColors.bg,
          body: Column(children: [
            _buildHeader(),
            _buildStats(),
            _buildTabBar(),
            Expanded(child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildDenuncias(),
                _buildUsuarios(),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final pendingReports =
        context.select<AdminPanelController, int>((c) => c.pendingReports);

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.bgCard,
        border: Border(bottom: BorderSide(
          color: AdminColors.borderStrong, width: 0.8))),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const SizedBox(width: 35, height: 35,
              child: Icon(Icons.arrow_back_ios_new_rounded,
                color: AdminColors.inkPrincipal, size: 18))),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  color: AdminColors.inkPrincipal,
                  child: const Text('ADMIN',
                    style: TextStyle(
                      fontFamily:    TabuTypography.bodyFont,
                      fontSize:      7, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5, color: Colors.white))),
                const SizedBox(width: 10),
                const Text('PAINEL PROFISSIONAL',
                  style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 12, letterSpacing: 1,
                    color: AdminColors.inkDeep)),
              ]),
              const SizedBox(height: 3),
              const Text('Tabu · Acesso Restrito',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 1,
                  color: AdminColors.inkSubtle)),
            ],
          )),
          if (pendingReports > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:  AdminColors.fill,
                border: Border.all(color: AdminColors.borderStrong)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.flag_rounded,
                  color: AdminColors.pending, size: 12),
                const SizedBox(width: 5),
                Text('$pendingReports',
                  style: const TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      11, fontWeight: FontWeight.w700,
                    color:         AdminColors.pending)),
              ])),
        ]),
      )),
    );
  }

  // ── Stats Bar ─────────────────────────────────────────────────────────────
  Widget _buildStats() {
    final ctrl = context.watch<AdminPanelController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      decoration: BoxDecoration(
        color:  AdminColors.bgAlt,
        border: Border(bottom: BorderSide(
          color: AdminColors.border, width: 0.5))),
      child: ctrl.loadingStats
          ? const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(AdminColors.inkPrincipal))))
          : Row(children: [
              AdminStatChip(label: 'USERS',   value: '${ctrl.stats.totalUsers}',
                icon: Icons.people_outline_rounded),
              const AdminStatDivider(),
              AdminStatChip(label: 'POSTS',   value: '${ctrl.stats.totalPosts}',
                icon: Icons.grid_view_rounded),
              const AdminStatDivider(),
              AdminStatChip(label: 'STORIES', value: '${ctrl.stats.totalStories}',
                icon: Icons.auto_stories_rounded),
              const AdminStatDivider(),
              AdminStatChip(label: 'FESTAS',  value: '${ctrl.stats.totalFestas}',
                icon: Icons.celebration_outlined),
              const AdminStatDivider(),
              AdminStatChip(label: 'REPORTS', value: '${ctrl.stats.pendingReports}',
                icon: Icons.flag_rounded,
                highlight: ctrl.stats.pendingReports > 0),
            ]),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final ctrl = context.watch<AdminPanelController>();

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.bgCard,
        border: const Border(bottom: BorderSide(
          color: AdminColors.border, width: 0.5))),
      child: TabBar(
        controller:           _tabCtrl,
        indicatorColor:       AdminColors.inkPrincipal,
        indicatorWeight:      2,
        labelColor:           AdminColors.inkDeep,
        unselectedLabelColor: AdminColors.inkSubtle,
        isScrollable:         false,
        labelStyle: const TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      9, fontWeight: FontWeight.w700,
          letterSpacing: 2),
        unselectedLabelStyle: const TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      9, fontWeight: FontWeight.w700,
          letterSpacing: 2),
        tabs: [
          Tab(text: 'DENÚNCIAS${ctrl.pendingReports > 0 ? " (${ctrl.pendingReports})" : ""}'),
          const Tab(text: 'USUÁRIOS'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ABA: DENÚNCIAS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDenuncias() {
    final ctrl = context.watch<AdminPanelController>();

    if (ctrl.loadingReports) return const AdminLoadingWidget();

    // Separa pendentes de arquivadas/resolvidas
    // Assume que ReportModel tem campo `isResolved` ou `status`.
    // Ajuste o nome do campo conforme seu modelo real.
    final pendentes  = ctrl.reports.where((r) => !_isResolved(r)).toList();
    final arquivadas = ctrl.reports.where((r) =>  _isResolved(r)).toList();

    // Filtra pelo campo de busca (protocolo)
    final query = _searchQuery.trim().toLowerCase();
    final filteredPendentes  = query.isEmpty ? pendentes
        : pendentes.where((r)  => _matchesQuery(r, query)).toList();
    final filteredArquivadas = query.isEmpty ? arquivadas
        : arquivadas.where((r) => _matchesQuery(r, query)).toList();

    final exibindo = _showArchived ? filteredArquivadas : filteredPendentes;

    return Column(children: [
      // ── Barra de busca ───────────────────────────────────────────────────
      _buildSearchBar(),
      // ── Seletor pendentes / arquivadas ───────────────────────────────────
      _buildReportToggle(
        pendentesCount:  filteredPendentes.length,
        arquivadasCount: filteredArquivadas.length,
      ),
      // ── Lista ────────────────────────────────────────────────────────────
      Expanded(child: exibindo.isEmpty
          ? AdminEmptyState(
              icon:  _showArchived
                  ? Icons.inventory_2_outlined
                  : Icons.check_circle_outline_rounded,
              label: query.isNotEmpty
                  ? 'NENHUM RESULTADO PARA "$query"'
                  : _showArchived
                      ? 'SEM DENÚNCIAS ARQUIVADAS'
                      : 'SEM DENÚNCIAS PENDENTES')
          : RefreshIndicator(
              color:           AdminColors.inkPrincipal,
              backgroundColor: AdminColors.bgCard,
              onRefresh:       ctrl.refreshReports,
              child: ListView.separated(
                padding:     const EdgeInsets.only(top: 4, bottom: 80),
                itemCount:   exibindo.length,
                separatorBuilder: (_, __) =>
                    Container(height: 0.5, color: AdminColors.border),
                itemBuilder: (_, i) {
                  final report = exibindo[i];
                  return ReportTile(
                    report:    report,
                    onTap:     () => _abrirDetalhe(report),
                    onDismiss: _showArchived ? null : () {
                      HapticFeedback.mediumImpact();
                      ctrl.dismissReport(report);
                    },
                    onDelete: () => ctrl.canDeleteReportContent(report)
                        ? _confirmarDelete(report)
                        : _abrirDetalhe(report),
                  );
                },
              ),
            )),
    ]);
  }

  /// Barra de pesquisa por protocolo
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      color: AdminColors.bg,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color:  AdminColors.fill,
          border: Border.all(color: AdminColors.border, width: 0.8)),
        child: Row(children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded,
            color: AdminColors.inkGhost, size: 16),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize:   12,
              color:      AdminColors.inkDeep),
            cursorColor: AdminColors.inkPrincipal,
            decoration: const InputDecoration(
              hintText: 'Buscar por protocolo...',
              hintStyle: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize:   11,
                color:      AdminColors.inkGhost),
              border:         InputBorder.none,
              isDense:        true,
              contentPadding: EdgeInsets.zero),
            onChanged: (v) => setState(() => _searchQuery = v),
          )),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close_rounded,
                  color: AdminColors.inkSubtle, size: 16),
              ),
            ),
        ]),
      ),
    );
  }

  /// Toggle pendentes / arquivadas
  Widget _buildReportToggle({
    required int pendentesCount,
    required int arquivadasCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: AdminColors.bg,
      child: Row(children: [
        _ToggleChip(
          label:    'PENDENTES',
          count:    pendentesCount,
          selected: !_showArchived,
          danger:   true,
          onTap: () => setState(() => _showArchived = false),
        ),
        const SizedBox(width: 8),
        _ToggleChip(
          label:    'ARQUIVADAS',
          count:    arquivadasCount,
          selected: _showArchived,
          danger:   false,
          onTap: () => setState(() => _showArchived = true),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ABA: USUÁRIOS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUsuarios() {
    final ctrl = context.watch<AdminPanelController>();

    if (ctrl.loadingUsers) return const AdminLoadingWidget();
    if (ctrl.users.isEmpty) return const AdminEmptyState(
      icon:  Icons.people_outline_rounded,
      label: 'SEM USUÁRIOS');

    return RefreshIndicator(
      color:           AdminColors.inkPrincipal,
      backgroundColor: AdminColors.bgCard,
      onRefresh:       ctrl.refreshUsers,
      child: ListView.separated(
        controller:  _usersScrollCtrl,
        padding:     const EdgeInsets.only(top: 4, bottom: 80),
        itemCount:   ctrl.users.length + (ctrl.hasMoreUsers ? 1 : 0),
        separatorBuilder: (_, __) =>
            Container(height: 0.5, color: AdminColors.border),
        itemBuilder: (_, i) {
          if (i == ctrl.users.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: ctrl.loadingMoreUsers
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.5,
                          valueColor:
                              AlwaysStoppedAnimation(AdminColors.inkPrincipal)))
                    : const SizedBox.shrink()),
            );
          }
          final user = ctrl.users[i];
          return UserAdminTile(
            user:  user,
            // ← abre PublicProfileScreen ao tocar no tile
            onTap: () => _abrirPerfilPublico(user),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Denúncia resolvida = qualquer status diferente de 'pending'
  bool _isResolved(ReportModel r) => !r.isPending;

  /// Bate com protocolo, key ou nome do denunciado
  bool _matchesQuery(ReportModel r, String query) {
    return (r.protocolo    ?? '').toLowerCase().contains(query) ||
            r.key           .toLowerCase().contains(query)      ||
           (r.reportedName ?? '').toLowerCase().contains(query);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ToggleChip — chip pendentes / arquivadas
// ══════════════════════════════════════════════════════════════════════════════
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final int    count;
  final bool   selected;
  final bool   danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AdminColors.pending : AdminColors.inkSubtle;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve:    Curves.easeOut,
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AdminColors.inkPrincipal : AdminColors.fill,
          border: Border.all(
            color: selected ? AdminColors.inkPrincipal : AdminColors.border,
            width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
            style: TextStyle(
              fontFamily:    TabuTypography.bodyFont,
              fontSize:      9,
              fontWeight:    FontWeight.w700,
              letterSpacing: 1.5,
              color: selected ? Colors.white : AdminColors.inkSubtle)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.20)
                    : (danger
                        ? AdminColors.pending.withOpacity(0.12)
                        : AdminColors.border),
                borderRadius: BorderRadius.circular(4)),
              child: Text('$count',
                style: TextStyle(
                  fontFamily:    TabuTypography.bodyFont,
                  fontSize:      9,
                  fontWeight:    FontWeight.w700,
                  color: selected ? Colors.white : accent)),
            ),
          ],
        ]),
      ),
    );
  }
}