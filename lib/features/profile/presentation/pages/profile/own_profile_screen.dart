// features/profile/presentation/pages/profile/own_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/admin/controller/admin_panel_controller.dart';
import 'package:tclub/features/admin/data/repositories/invite_repository.dart';
import 'package:tclub/features/admin/data/repositories/report_repository.dart';
import 'package:tclub/features/admin/data/repositories/stats_repository.dart';
import 'package:tclub/features/admin/data/repositories/user_repository.dart';
import 'package:tclub/features/admin/data/services/invite_service.dart';
import 'package:tclub/features/admin/data/services/report_service.dart';
import 'package:tclub/features/admin/data/services/user_service.dart';
import 'package:tclub/features/admin/presentation/pages/admin_panel_page.dart';
import 'package:tclub/features/auth/data/services/auth_service.dart';
import 'package:tclub/features/auth/presentation/pages/login_screen.dart';
import 'package:tclub/features/feed/presentation/screens/galery_feed_screen.dart';
import 'package:tclub/features/profile/controller/profile_controller.dart';
import 'package:tclub/features/profile/presentation/widgets/media_grid_tile.dart';
import 'package:tclub/features/profile/presentation/widgets/profile_avatar_section.dart';
import 'package:tclub/features/profile/presentation/widgets/profile_identity_widgets.dart';
import 'package:tclub/features/gallery/data/models/gallery_item_model.dart';
import 'package:tclub/core/widgets/full_screen_image.dart';
import 'package:tclub/core/widgets/full_screen_video.dart';
import 'package:tclub/features/gallery/presentation/pages/create_gallery_screen.dart';
import 'package:tclub/features/story/presentation/pages/story_viewer_screen.dart';
import 'package:tclub/features/profile/presentation/pages/edit_profile/edit_profile_hub.dart';
import 'package:tclub/features/gallery/data/services/gallery_service.dart';
import 'package:tclub/core/services/user_data_notifier.dart';
import 'package:tclub/core/services/media/video_preload_service.dart';
import 'package:tclub/features/admin/data/services/adm_service.dart';
import 'public_profile_screen.dart' show PublicProfileScreen;
import '_profile_painters.dart';
import '../../../data/models/profile_user_model.dart';
import 'package:tclub/features/profile/presentation/widgets/perfil_screen_widgets.dart';

class OwnProfileScreen extends StatefulWidget {
  const OwnProfileScreen({super.key, required this.userData});
  final Map<String, dynamic> userData;

  @override
  State<OwnProfileScreen> createState() => _OwnProfileScreenState();
}

class _OwnProfileScreenState extends State<OwnProfileScreen>
    with SingleTickerProviderStateMixin {
  late ProfileController _ctrl;
  late TabController _tabController;
  final _scrollController = ScrollController();

  late Map<String, dynamic> _localData;

  @override
  void initState() {
    super.initState();

    _localData = Map<String, dynamic>.from(widget.userData);

    _ctrl = ProfileController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    if (UserDataNotifier.instance.value.isEmpty) {
      UserDataNotifier.instance.init(_localData);
    } else {
      _localData = {..._localData, ...UserDataNotifier.instance.value};
    }

    _tabController = TabController(length: 1, vsync: this)
      ..addListener(() {
        setState(() {});
      });

    _scrollController.addListener(_onScroll);
    _ctrl.init(_localData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (cur < max - 400) return;
    _ctrl.loadMoreGallery();
  }

  List<Color> _gradient() {
    const p = [
      [Color(0xFF3D0018), Color(0xFF6B0030)],
      [Color(0xFF1A0030), Color(0xFF4B005A)],
      [Color(0xFF2D0010), Color(0xFF7A0028)],
      [Color(0xFF0D0020), Color(0xFF3B0050)],
      [Color(0xFF2A0012), Color(0xFFCC0044)],
    ];
    return p[_ctrl.uid.codeUnits.fold(0, (a, b) => a + b) % p.length];
  }

  void _applyUpdates(Map<String, dynamic> updates) {
    if (!mounted) return;
    UserDataNotifier.instance.update(updates);
    _ctrl.updateUserData(_data);
  }

  // ── Ações ──────────────────────────────────────────────────────────────────

  Future<void> _openEdit() async {
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileHub(userData: _localData)),
    );
    if (!mounted) return;
    final fresh = UserDataNotifier.instance.value;
    if (fresh.isNotEmpty) {
      _localData = {..._localData, ...fresh};
      _ctrl.updateUserData(_localData);
    }
  }

  void _openStoryViewer() {
    if (_ctrl.stories.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => StoryViewerScreen(
          storiesByUser: {_ctrl.uid: _ctrl.stories},
          initialUserId: _ctrl.uid,
          myUid: _ctrl.uid,
          onStoriesChanged: _ctrl.refreshStories,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _openGalleryItem(GalleryItem item) {
    HapticFeedback.selectionClick();
    final index = _ctrl.galleryItems.indexOf(item);
    Navigator.push(
      context,
      GalleryFeedScreen.route(
        items: _ctrl.galleryItems,
        initialIndex: index < 0 ? 0 : index,
        userName: _localName,
      ),
    );
  }

  Future<void> _deleteGalleryItem(GalleryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TClubColors.bgAlt,
        title: const Text('EXCLUIR DA GALERIA?',
            style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize: 14,
                letterSpacing: 4,
                color: TClubColors.textoPrincipal)),
        content: const Text('Esta ação não pode ser desfeita.',
            style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 12,
                color: TClubColors.subtle)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR',
                  style: TextStyle(color: TClubColors.dim))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('EXCLUIR',
                  style: TextStyle(color: Color(0xFFE85D5D)))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      try {
        if (item.type == 'video')
          await VideoPreloadService.instance.evict(item.id);
        await GalleryService.instance.deleteItem(_ctrl.uid, item.id);
        _ctrl.refreshGallery();
        _snack('Item removido da galeria', success: true);
      } catch (_) {
        _snack('Erro ao remover item.');
      }
    }
  }

  Future<void> _addToGallery() async {
    HapticFeedback.selectionClick();
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => CreateGalleryItemScreen(userData: _localData)));
    if (ok == true) _ctrl.refreshGallery();
  }

  void _openPublicProfile(String uid, String name) {
    HapticFeedback.selectionClick();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: uid, userName: name)));
  }

  void _openAdmin() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ChangeNotifierProvider(
          create: (_) => AdminPanelController(
            statsRepo: StatsRepository(),
            reportService: ReportService(ReportRepository()),
            userService: UserService(UserRepository()),
            inviteService: InviteService(InviteRepository()),
            userRepo: UserRepository(),
          ),
          child: AdminPanelPage(adminUid: _ctrl.uid),
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showConfigMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfigMenu(
        isAdmin: _ctrl.isAdmin,
        onSignOut: _signOut,
        onAbrirAdmin: _openAdmin,
        name: _data['name'] as String? ?? '',
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const SignOutSheet());
    if (confirm == true && mounted) {
      AdminService.instance.clearCache();
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(
                opacity:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      }
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? TClubColors.redDeep : const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      content: Text(msg,
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: TClubColors.branco,
          )),
    ));
  }

  String get _localName => _data['name'] as String? ?? 'Você';

  List<String> get _localInterests {
    final raw = _data['interests'];
    if (raw is List) return raw.whereType<String>().toList();
    return _ctrl.user?.interests ?? [];
  }

  void _openMetricSheet({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> uids,
    required String emptyLabel,
    bool isVip = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MetricSheet(
        title: title,
        icon: icon,
        accentColor: color,
        content: PaginatedUserList(
          uids: uids,
          emptyLabel: emptyLabel,
          onTap: _openPublicProfile,
          isVip: isVip,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> get _data {
    final n = UserDataNotifier.instance.value;
    if (n.isEmpty) return _localData;
    return {..._localData, ...n};
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: UserDataNotifier.instance,
      builder: (context, _, __) {
        final data = _data;
        final gradient = _gradient();
        final name = (data['name'] as String? ?? 'Usuário').toUpperCase();
        final temStory = _ctrl.stories.isNotEmpty;

        return Scaffold(
          backgroundColor: TClubColors.bg,
          body: Stack(children: [
            Positioned.fill(
              child:
                  CustomPaint(painter: AtmospherePainter(gradient: gradient)),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: TClubColors.redPrincipal,
                backgroundColor: TClubColors.bgAlt,
                onRefresh: _ctrl.refresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),
                            _buildTopBar(),
                            const SizedBox(height: 20),
                            _buildAvatarSection(gradient, temStory),
                            const SizedBox(height: 14),
                            _buildNameBlock(name),
                            _buildLocation(data),
                            const SizedBox(height: 20),
                            _buildStatsRow(),
                            const SizedBox(height: 6),
                            VipFriendsBadge(
                                count: _ctrl.loadingVip
                                    ? 0
                                    : _ctrl.vipFriends.length),
                            const SizedBox(height: 20),
                            _buildBio(data),
                            _buildPersonalityBlock(),
                            const SizedBox(height: 20),
                            _buildActionButtons(),
                            const SizedBox(height: 20),
                            _buildTabBar(),
                          ],
                        ),
                      ),
                    ),
                    ..._buildGridContent(),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          ]),
          floatingActionButton: _buildFab(),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(children: [
      if (_ctrl.isAdmin && !_ctrl.loadingAdmin)
        GestureDetector(
          onTap: _openAdmin,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: TClubColors.redDeep.withOpacity(0.15),
              border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.30),
                  width: 0.8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield_rounded,
                  color: TClubColors.redPrincipal, size: 13),
              SizedBox(width: 6),
              Text('ADMIN',
                  style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: TClubColors.redPrincipal)),
            ]),
          ),
        )
      else
        const SizedBox(width: 38),
      const Spacer(),
      GestureDetector(
        onTap: _showConfigMenu,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TClubColors.bgCard,
            border: Border.all(color: TClubColors.border, width: 0.8),
          ),
          child: const Icon(Icons.settings_outlined,
              color: TClubColors.subtle, size: 18),
        ),
      ),
    ]);
  }

  Widget _buildAvatarSection(List<Color> gradient, bool temStory) {
    return ProfileAvatarSection(
      uid: _ctrl.uid,
      name: _localName,
      avatarUrl: _data['avatar'] as String?,
      gradient: gradient,
      hasStories: temStory,
      hasUnviewedStory: false,
      isVip: false,
      isOnline: true,
      isOwn: true,
      onTap: temStory ? _openStoryViewer : _openEdit,
    );
  }

  Widget _buildNameBlock(String name) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Flexible(
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TClubTypography.displayFont,
            fontSize: 28,
            letterSpacing: 6,
            color: TClubColors.textoPrincipal,
            fontWeight: FontWeight.w400,
            shadows: [Shadow(color: TClubColors.glow, blurRadius: 20)],
          ),
        ),
      ),
      if (_ctrl.isAdmin && !_ctrl.loadingAdmin) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: TClubColors.redDeep.withOpacity(0.25),
            border: Border.all(
                color: TClubColors.redPrincipal.withOpacity(0.50), width: 0.8),
          ),
          child: const Icon(Icons.shield_rounded,
              color: TClubColors.redPrincipal, size: 10),
        ),
      ],
    ]);
  }

  Widget _buildLocation(Map<String, dynamic> data) {
    final loc = [
      (data['bairro'] as String? ?? '').trim(),
      (data['city'] as String? ?? '').trim(),
      (data['state'] as String? ?? '').trim(),
    ].where((s) => s.isNotEmpty).join(', ');
    if (loc.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.location_on_outlined,
            color: TClubColors.redPrincipal, size: 11),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            loc,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: TClubColors.redPrincipal,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBio(Map<String, dynamic> data) {
    final bio = ((data['bio'] as String?) ?? '').trim();
    if (bio.isEmpty) return const SizedBox.shrink();
    return Text(
      bio,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: TClubTypography.bodyFont,
        fontSize: 13,
        letterSpacing: 0.3,
        color: TClubColors.dim.withOpacity(0.85),
        height: 1.65,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildPersonalityBlock() {
    final user = _ctrl.user ?? ProfileUserModel.fromMap(_ctrl.uid, _localData);
    final interests = _localInterests;

    final hasIdentity = user.genderLabel.isNotEmpty ||
        user.orientationLabel.isNotEmpty ||
        user.relationshipLabel.isNotEmpty;
    final hasPartner = user.isCouple && user.partner != null;

    debugPrint('[OWN PROFILE] isCouple=${user.isCouple} '
        'partner=${user.partner?.name} '
        'rel=${user.relationshipType} '
        'profileType=${user.profileType}');

    if (!hasIdentity && !hasPartner && interests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasIdentity) ProfileIdentityRow(user: user),
        if (hasPartner) CouplePartnerCard(partner: user.partner!),
        if (interests.isNotEmpty) ProfileInterestsSection(interests: interests),
      ],
    );
  }

  // Mantidos apenas para não quebrar outras chamadas (não são mais usados
  // diretamente — _buildPersonalityBlock resolve tudo):
  bool _hasIdentityData() {
    final user = _ctrl.user ?? ProfileUserModel.fromMap(_ctrl.uid, _localData);
    return user.genderLabel.isNotEmpty ||
        user.orientationLabel.isNotEmpty ||
        user.relationshipLabel.isNotEmpty;
  }

  Widget _buildIdentityChips() {
    final user = _ctrl.user ?? ProfileUserModel.fromMap(_ctrl.uid, _localData);
    return ProfileIdentityRow(user: user);
  }

  Widget _buildActionButtons() {
    return Column(children: [
      GestureDetector(
        onTap: _openEdit,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: TClubColors.bgCard,
            border: Border.all(color: TClubColors.borderMid, width: 0.8),
          ),
          child:
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_outlined,
                color: TClubColors.redPrincipal, size: 15),
            SizedBox(width: 10),
            Text('EDITAR PERFIL',
                style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: TClubColors.redPrincipal)),
          ]),
        ),
      ),
      if (_ctrl.isAdmin && !_ctrl.loadingAdmin) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _openAdmin,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: TClubColors.redDeep.withOpacity(0.15),
              border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.50),
                  width: 0.8),
              boxShadow: [
                BoxShadow(
                    color: TClubColors.glow.withOpacity(0.15), blurRadius: 12)
              ],
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded,
                      color: TClubColors.redPrincipal, size: 15),
                  SizedBox(width: 10),
                  Text('PAINEL PROFISSIONAL',
                      style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: TClubColors.redPrincipal)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: TClubColors.redPrincipal, size: 10),
                ]),
          ),
        ),
      ],
    ]);
  }

  Widget _buildStatsRow() {
    return Row(children: [
      StatCard(
        value: _ctrl.loadingFollowers ? '—' : '${_ctrl.followersCount}',
        label: 'SEGUIDORES',
        icon: Icons.people_outline_rounded,
        onTap: () => _openMetricSheet(
          title: 'SEGUIDORES',
          icon: Icons.people_outline_rounded,
          color: TClubColors.redClaro,
          uids: _ctrl.followers,
          emptyLabel: 'Nenhum seguidor ainda',
        ),
      ),
      const SizedBox(width: 10),
      StatCard(
        value: _ctrl.loadingVip ? '—' : '${_ctrl.vipFriends.length}',
        label: 'AMIGOS VIP',
        icon: Icons.star_border_rounded,
        highlight: true,
        onTap: () => _openMetricSheet(
          title: 'AMIGOS VIP',
          icon: Icons.star_rounded,
          color: const Color(0xFFD4AF37),
          uids: _ctrl.vipFriends,
          emptyLabel: 'Nenhum amigo VIP ainda',
          isVip: true,
        ),
      ),
    ]);
  }

  Widget _buildTabBar() {
    return GalleryOnlyTabBar(
      controller: _tabController,
      galleryCount: _ctrl.galleryItems.length,
      loadingGallery: _ctrl.loadingGallery,
      hasGallery: _ctrl.hasGallery,
    );
  }

  List<Widget> _buildGridContent() {
    const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 8);

    if (_ctrl.loadingGallery) return [GridSkeleton(padding: padding)];
    if (!_ctrl.galleryCreated) {
      return [
        SliverFillRemaining(
            hasScrollBody: false, child: _buildGalleryNotCreated())
      ];
    }
    if (_ctrl.galleryItems.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _buildGalleryEmpty())
      ];
    }
    return [
      SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
            childAspectRatio: 1.0,
            mainAxisExtent: 120,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final item = _ctrl.galleryItems[i];
              return _DeletableGalleryTile(
                item: item,
                isPreloaded: VideoPreloadService.instance.isReady(item.id),
                onTap: () => _openGalleryItem(item),
                onDelete: () => _deleteGalleryItem(item),
              );
            },
            childCount: _ctrl.galleryItems.length,
          ),
        ),
      ),
      if (_ctrl.loadingMoreGallery) const LoadMoreIndicator(),
    ];
  }

  Widget? _buildFab() {
    if (_ctrl.loadingGallery) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton(
        onPressed: _addToGallery,
        backgroundColor: TClubColors.redPrincipal,
        elevation: 8,
        heroTag: 'gallery_fab',
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildGalleryNotCreated() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _addToGallery,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: TClubColors.border, width: 0.8),
              color: TClubColors.bgCard,
            ),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.photo_library_outlined,
                  color: TClubColors.border, size: 28),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TClubColors.redPrincipal,
                    boxShadow: [
                      BoxShadow(
                        color: TClubColors.glow.withOpacity(0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        const Text('SUA GALERIA PESSOAL',
            style: TextStyle(
              fontFamily: TClubTypography.displayFont,
              fontSize: 16,
              letterSpacing: 5,
              color: TClubColors.textoPrincipal,
            )),
        const SizedBox(height: 12),
        const Text(
          'Guarde fotos e vídeos que aparecem apenas no seu perfil.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 12,
            letterSpacing: 0.3,
            color: TClubColors.subtle,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: TClubColors.redPrincipal.withOpacity(0.08),
            border: Border.all(
                color: TClubColors.redPrincipal.withOpacity(0.25), width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TClubColors.redPrincipal,
                boxShadow: [
                  BoxShadow(
                    color: TClubColors.glow.withOpacity(0.35),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Text(
              'Toque no   +   para adicionar',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11,
                letterSpacing: 0.5,
                color: TClubColors.redPrincipal,
              ),
            ),
          ]),
        ),
      ]),
    ));
  }

  Widget _buildGalleryEmpty() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _addToGallery,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: TClubColors.border, width: 0.8),
              color: TClubColors.bgCard,
            ),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  color: TClubColors.border, size: 28),
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TClubColors.redPrincipal,
                    boxShadow: [
                      BoxShadow(
                        color: TClubColors.glow.withOpacity(0.40),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        const Text('GALERIA VAZIA',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: TClubColors.subtle,
            )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: TClubColors.redPrincipal.withOpacity(0.08),
            border: Border.all(
                color: TClubColors.redPrincipal.withOpacity(0.25), width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TClubColors.redPrincipal,
                boxShadow: [
                  BoxShadow(
                    color: TClubColors.glow.withOpacity(0.35),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Text(
              'Toque no   +   para adicionar',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11,
                letterSpacing: 0.5,
                color: TClubColors.redPrincipal,
              ),
            ),
          ]),
        ),
      ]),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GALLERY TILE COM LONG PRESS DELETE
// ══════════════════════════════════════════════════════════════════════════════
class _DeletableGalleryTile extends StatelessWidget {
  const _DeletableGalleryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
    this.isPreloaded = false,
  });

  final GalleryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isPreloaded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: TClubColors.bgAlt,
          shape: const RoundedRectangleBorder(),
          builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                    color: TClubColors.border,
                    borderRadius: BorderRadius.circular(2))),
            PDSMenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'REMOVER DA GALERIA',
              sublabel: 'Excluir permanentemente',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 20),
          ])),
        );
      },
      child:
          GalleryGridTile(item: item, isPreloaded: isPreloaded, onTap: onTap),
    );
  }
}

