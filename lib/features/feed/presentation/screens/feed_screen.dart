// lib/screens/screens_home/home_screen/home/home_screen.dart
//
// NÍVEL 2.13 — AJUSTES INTEGRADOS:
//   • _hasMoreComs / _loadingMoreComs removidos de _HomeScreen (eram dead code).
//   • _enviarComentario: clear + unfocus ANTES do await (campo limpa imediatamente).
//   • Duplicata de clear/unfocus após await removida.
//   • Listener RT via onChildAdded sem orderByChild (sem índice necessário).
//   • Deduplicação por _comentariosIds garante zero duplicatas.
import 'dart:async';

import 'package:tclub/core/widgets/full_screen_video.dart';
import 'package:tclub/features/user/moderation/moderation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/providers/block_provider.dart';
import 'package:tclub/features/story/data/models/story_model.dart';
import 'package:tclub/core/widgets/full_screen_image.dart';
import 'package:tclub/core/widgets/inline_video_card.dart';
import 'package:tclub/features/gallery/presentation/pages/create_gallery_screen.dart';
import 'package:tclub/core/services/media/video_preload_service.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/post/data/models/post_model.dart';
import 'package:tclub/features/party/data/models/party_model.dart';
import 'package:tclub/features/party/presentation/pages/edit_party_screen.dart';
import 'package:tclub/features/post/presentation/pages/comments_screen.dart';
import 'package:tclub/features/post/presentation/pages/create_post_screen.dart';
import 'package:tclub/features/story/presentation/pages/create_story_screen.dart';
import 'package:tclub/features/story/presentation/pages/story_viewer_screen.dart';
import 'package:tclub/features/profile/presentation/pages/profile/public_profile_screen.dart';
import 'package:tclub/features/party/presentation/pages/create_party_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/features/admin/data/services/location_service.dart';
import 'package:tclub/features/post/data/services/post_service.dart';
import 'package:tclub/features/story/data/services/story_service.dart';
import 'package:tclub/core/services/follow_service.dart';
import 'package:tclub/core/services/cached_avatar.dart';
import 'package:tclub/core/services/user_data_notifier.dart';
import 'package:tclub/features/admin/data/services/party_service.dart';
import 'package:tclub/core/services/user_profile_cache.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  FEED SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isAdmin;
  const HomeScreen({super.key, required this.userData, this.isAdmin = false});

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _createMenuController;
  late Animation<double> _createMenuAnim;
  bool _menuOpen = false;
  Set<String> _lastKnownBlockedIds = {};

  List<PostModel> _allPosts = [];
  List<PostModel> get _visiblePosts {
    if (_lastKnownBlockedIds.isEmpty) return _allPosts;
    return _allPosts
        .where((p) => !_lastKnownBlockedIds.contains(p.userId))
        .toList();
  }

  Map<String, List<StoryModel>> _stories = {};
  Map<String, List<StoryModel>> get _visibleStories {
    if (_lastKnownBlockedIds.isEmpty) return _stories;
    return Map.fromEntries(
      _stories.entries.where((e) => !_lastKnownBlockedIds.contains(e.key)),
    );
  }

  List<PartyModel> _festas = [];
  Set<String> _viewedStoryUserIds = {};
  Set<String> _vipUserIds = {};

  ({double latitude, double longitude})? _homeCoords;

  bool _loadingPosts = true;
  bool _loadingStories = true;
  bool _loadingFestas = true;

  final _scrollController = ScrollController();
  bool _loadingMore = false;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (widget.userData['uid'] as String? ?? '') ??
      (widget.userData['id'] as String? ?? '');

  @override
  void initState() {
    super.initState();
    UserDataNotifier.instance.init(widget.userData);
    UserDataNotifier.instance.addListener(_onUserDataChanged);
    _createMenuController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _createMenuAnim = CurvedAnimation(
      parent: _createMenuController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockProvider = context.read<BlockProvider>();
      _lastKnownBlockedIds = Set.from(blockProvider.allBlockedIds);
      blockProvider.addListener(_onBlockProviderChanged);
    });
    _carregarDados();
  }

  @override
  void dispose() {
    UserDataNotifier.instance.removeListener(_onUserDataChanged);
    _scrollController.dispose();
    _createMenuController.dispose();
    try {
      context.read<BlockProvider>().removeListener(_onBlockProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onUserDataChanged() {
    if (mounted) setState(() {});
  }

  void _onBlockProviderChanged() {
    if (!mounted) return;
    final blockProvider = context.read<BlockProvider>();
    final current = blockProvider.allBlockedIds;
    final changed = current.length != _lastKnownBlockedIds.length ||
        !current.containsAll(_lastKnownBlockedIds);
    if (changed) {
      _lastKnownBlockedIds = Set.from(current);
      if (mounted) setState(() {});
    }
  }

  void _onScroll() {
    if (_loadingMore || _loadingPosts) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= max - 300) _carregarMaisPosts();
  }

  Future<void> _carregarMaisPosts() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final novos = await PostService.instance.fetchPosts(
        myUid: _uid,
        limit: 5,
        startAfter: _allPosts.isNotEmpty ? _allPosts.last.createdAt : null,
      );
      if (mounted)
        setState(() {
          if (novos.isNotEmpty) _allPosts.addAll(novos);
          _loadingMore = false;
        });
    } catch (e) {
      debugPrint('_carregarMaisPosts error: $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _carregarDados() async {
    await Future.wait([
      _carregarPosts(),
      _carregarStories(),
      _carregarFestas(),
    ]);
  }

  Future<void> _carregarFestas() async {
    setState(() => _loadingFestas = true);
    try {
      final results = await Future.wait([
        LocationService.instance.getUserHomeCoords(_uid),
        PartyService.instance.fetchFestas(),
      ]);
      final home = results[0] as ({double latitude, double longitude})?;
      var festas = results[1] as List<PartyModel>;
      final now = DateTime.now();
      festas.sort((a, b) {
        final diffA = a.dataInicio.difference(now).abs();
        final diffB = b.dataInicio.difference(now).abs();
        return diffA.compareTo(diffB);
      });
      if (mounted)
        setState(() {
          _homeCoords = home;
          _festas = festas;
          _loadingFestas = false;
        });
    } catch (e) {
      debugPrint('_carregarFestas error: $e');
      if (mounted) setState(() => _loadingFestas = false);
    }
  }

  Future<void> _carregarPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final posts =
          await PostService.instance.fetchPosts(myUid: _uid, limit: 30);
      if (mounted)
        setState(() {
          _allPosts = posts;
          _loadingPosts = false;
        });
    } catch (e) {
      debugPrint('_carregarPosts error: $e');
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  void _removerPost(String postId) {
    if (!mounted) return;
    setState(() {
      _allPosts.removeWhere((p) => p.id == postId);
    });
  }

  Future<void> _carregarStories() async {
    setState(() => _loadingStories = true);
    try {
      final grouped = await StoryService.instance.fetchStoriesForUser(
        myUid: _uid,
      );

      final viewedUsers = <String>{};
      await Future.wait(
        grouped.entries.map((entry) async {
          try {
            final checks = await Future.wait(
              entry.value.map(
                (story) => StoryService.instance.hasViewed(story.id, _uid),
              ),
            );
            if (checks.isNotEmpty && checks.every((seen) => seen)) {
              viewedUsers.add(entry.key);
            }
          } catch (_) {}
        }),
      );

      Set<String> myVipIds = {};
      try {
        myVipIds = Set<String>.from(
          await FollowService.instance.getVipFriends(_uid),
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _stories = grouped;
          _viewedStoryUserIds = viewedUsers;
          _vipUserIds = myVipIds;
          _loadingStories = false;
        });
      }

      _preloadStoryVideos(grouped);
    } catch (e) {
      debugPrint('_carregarStories error: $e');
      if (mounted) setState(() => _loadingStories = false);
    }
  }

  void _preloadStoryVideos(Map<String, List<StoryModel>> grouped) {
    for (final stories in grouped.values) {
      for (final story in stories) {
        if (story.isVideo && story.mediaUrl != null) {
          VideoPreloadService.instance.preload(story.id, story.mediaUrl!);
          break;
        }
      }
    }
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    _menuOpen
        ? _createMenuController.forward()
        : _createMenuController.reverse();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
    _createMenuController.reverse();
  }

  void _onCreatePost() {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreatePostScreen(userData: widget.userData)),
    ).then((ok) {
      if (ok == true) _carregarPosts();
    });
  }

  void _onCreateStory() {
    _closeMenu();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            CreateStoryScreen(userData: widget.userData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 340),
      ),
    ).then((ok) {
      if (ok == true) _carregarStories();
    });
  }

  void _onCreateGallery() {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateGalleryItemScreen(userData: widget.userData)),
    );
  }

  void _onCreateFesta() {
    _closeMenu();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            CreatePartyScreen(userData: widget.userData),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ).then((ok) {
      if (ok == true) _carregarFestas();
    });
  }

  void _abrirStoryViewer(String userId) {
    final visible = _visibleStories;
    final userStories = visible[userId];
    if (userStories == null || userStories.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => StoryViewerScreen(
          storiesByUser: visible,
          initialUserId: userId,
          myUid: _uid,
          onStoriesChanged: _carregarStories,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = UserDataNotifier.instance.nameUpper.isNotEmpty
        ? UserDataNotifier.instance.nameUpper
        : (widget.userData['name'] as String? ?? 'Você').toUpperCase();
    final avatarUrl = UserDataNotifier.instance.avatar.isNotEmpty
        ? UserDataNotifier.instance.avatar
        : (widget.userData['avatar'] as String? ?? '');

    context.watch<BlockProvider>().allBlockedIds;

    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: GestureDetector(
        onTap: _closeMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _FeedBg())),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  TClubColors.redDeep,
                  TClubColors.redPrincipal,
                  TClubColors.redClaro,
                  TClubColors.redPrincipal,
                  TClubColors.redDeep,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: TClubColors.redPrincipal,
              backgroundColor: TClubColors.bgAlt,
              onRefresh: _carregarDados,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar(name, avatarUrl)),
                  SliverToBoxAdapter(child: _buildCreateBox(avatarUrl)),
                  SliverToBoxAdapter(child: _buildFestasSection()),
                  SliverToBoxAdapter(child: _buildStoriesSection()),
                  SliverToBoxAdapter(
                    child: Container(
                      height: 0.5,
                      color: TClubColors.border,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  if (_loadingPosts)
                    const SliverToBoxAdapter(child: _PostsSkeleton())
                  else if (_visiblePosts.isEmpty)
                    SliverToBoxAdapter(child: _buildPostsVazio())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final post = _visiblePosts[i];
                          return _PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            uid: _uid,
                            userData: widget.userData,
                            scrollController: _scrollController,
                            onDeleted: () => _removerPost(post.id),
                          );
                        },
                        childCount: _visiblePosts.length,
                      ),
                    ),
                  if (_loadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: TClubColors.redPrincipal.withOpacity(0.5),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMenu,
                child: Container(color: Colors.black.withOpacity(0.45)),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 52,
            right: 16,
            child: IgnorePointer(
              ignoring: !_menuOpen,
              child: _buildCreateMenu(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar(String name, String avatarUrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Row(children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [TClubColors.redPrincipal, TClubColors.redClaro],
          ).createShader(b),
          child: const Text(
            'TCLUB',
            style: TextStyle(
              fontFamily: TClubTypography.displayFont,
              fontSize: 28,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _toggleMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _menuOpen ? TClubColors.redPrincipal : TClubColors.bgCard,
              border: Border.all(
                color:
                    _menuOpen ? TClubColors.redPrincipal : TClubColors.borderMid,
                width: 0.8,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedRotation(
                turns: _menuOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 260),
                child: const Icon(Icons.add, color: TClubColors.dim, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('CRIAR',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: TClubColors.dim,
                  )),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        _SquircleAvatar(
          size: 36,
          radius: 8,
          avatarUrl: avatarUrl,
          gradient: const [TClubColors.redDeep, TClubColors.redPrincipal],
          ringColor: TClubColors.borderMid,
        ),
      ]),
    );
  }

  Widget _buildCreateMenu() {
    return AnimatedBuilder(
      animation: _createMenuAnim,
      builder: (_, __) {
        final v = _createMenuAnim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, -12 * (1 - v)),
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: TClubColors.bgAlt,
                border: Border.all(color: TClubColors.borderMid, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: TClubColors.glow.withOpacity(0.15),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      TClubColors.redDeep,
                      TClubColors.redPrincipal,
                      TClubColors.redDeep,
                    ]),
                  ),
                ),
                _MenuOption(
                  icon: Icons.grid_view_rounded,
                  label: 'POST',
                  sublabel: 'Foto, vídeo ou texto',
                  onTap: _onCreatePost,
                ),
                Container(height: 0.5, color: TClubColors.border),
                _MenuOption(
                  icon: Icons.auto_awesome_rounded,
                  label: 'STORY',
                  sublabel: 'Desaparece em 24h',
                  onTap: _onCreateStory,
                  accent: true,
                ),
                Container(height: 0.5, color: TClubColors.border),
                _MenuOption(
                  icon: Icons.photo_library_outlined,
                  label: 'GALERIA',
                  sublabel: 'Apenas no seu perfil',
                  onTap: _onCreateGallery,
                ),
                if (widget.isAdmin) ...[
                  Container(height: 0.5, color: TClubColors.border),
                  _MenuOption(
                    icon: Icons.local_fire_department_rounded,
                    label: 'FESTA',
                    sublabel: 'Evento para todos',
                    onTap: _onCreateFesta,
                    accent: true,
                  ),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateBox(String avatarUrl) {
    return GestureDetector(
      onTap: _onCreatePost,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.border, width: 0.8),
        ),
        child: Row(children: [
          _SquircleAvatar(
            size: 40,
            radius: 9,
            avatarUrl: avatarUrl,
            gradient: const [TClubColors.redDeep, TClubColors.redPrincipal],
            ringColor: TClubColors.border,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: TClubColors.bgAlt,
                border: Border.all(color: TClubColors.border, width: 0.8),
              ),
              alignment: Alignment.centerLeft,
              child: const Text('O que está rolando?',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 13,
                    color: TClubColors.subtle,
                    letterSpacing: 0.3,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _onCreateStory,
            child: const Icon(
              Icons.photo_camera_outlined,
              color: TClubColors.redPrincipal,
              size: 20,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFestasSection() {
    final festasVisiveis = _festas;
    if (!_loadingFestas && festasVisiveis.isEmpty)
      return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          const Icon(Icons.local_fire_department_rounded,
              color: TClubColors.redPrincipal, size: 12),
          const SizedBox(width: 8),
          const Text('FESTAS',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TClubColors.redPrincipal,
              )),
          const SizedBox(width: 8),
          if (!_loadingFestas &&
              _homeCoords != null &&
              festasVisiveis.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: TClubColors.redPrincipal.withOpacity(0.12),
                border: Border.all(
                    color: TClubColors.redPrincipal.withOpacity(0.4),
                    width: 0.6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.near_me_rounded,
                    color: TClubColors.redPrincipal, size: 8),
                const SizedBox(width: 4),
                Text('${festasVisiveis.length} PRÓXIMAS',
                    style: const TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: TClubColors.redPrincipal,
                    )),
              ]),
            ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 0.5, color: TClubColors.border)),
        ]),
      ),
      const SizedBox(height: 12),
      if (_loadingFestas)
        SizedBox(
          height: 190,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: TClubColors.redPrincipal.withOpacity(0.5),
                strokeWidth: 1.5,
              ),
            ),
          ),
        )
      else
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: festasVisiveis.length,
            itemBuilder: (_, i) => _FestaCard(
              festa: festasVisiveis[i],
              myUid: _uid,
              isAdmin: widget.isAdmin,
              userData: widget.userData,
              homeCoords: _homeCoords,
              onRefresh: _carregarFestas,
            ),
          ),
        ),
      const SizedBox(height: 8),
      Container(height: 0.5, color: TClubColors.border),
    ]);
  }

  Widget _buildStoriesSection() {
    final visible = _visibleStories;
    final otherUserIds = visible.keys.where((id) => id != _uid).toList();
    final temMeuStory = visible.containsKey(_uid);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Row(children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                color: TClubColors.redPrincipal, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('STORIES',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TClubColors.redPrincipal,
              )),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 0.5, color: TClubColors.border)),
        ]),
      ),
      SizedBox(
        height: 102,
        child: _loadingStories
            ? const _StoriesSkeleton()
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: 1 + otherUserIds.length,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _StoryBubble(
                      uid: _uid,
                      userData: widget.userData,
                      name: UserDataNotifier.instance.nameUpper.isNotEmpty
                          ? UserDataNotifier.instance.nameUpper
                          : (widget.userData['name'] as String? ?? 'EU')
                              .toUpperCase(),
                      avatarUrl: UserDataNotifier.instance.avatar.isNotEmpty
                          ? UserDataNotifier.instance.avatar
                          : (widget.userData['avatar'] as String? ?? ''),
                      isOwn: true,
                      hasNew: temMeuStory,
                      viewed: _viewedStoryUserIds.contains(_uid),
                      isVip: false,
                      onTap: () => _abrirStoryViewer(_uid),
                    );
                  }
                  final userId = otherUserIds[i - 1];
                  final firstStory = visible[userId]!.first;
                  return _StoryBubble(
                    uid: userId,
                    userData: widget.userData,
                    name: firstStory.userName.toUpperCase(),
                    avatarUrl: firstStory.userAvatar ?? '',
                    isOwn: false,
                    hasNew: true,
                    viewed: _viewedStoryUserIds.contains(userId),
                    isVip: _vipUserIds.contains(userId),
                    onTap: () => _abrirStoryViewer(userId),
                  );
                },
              ),
      ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _buildPostsVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.dynamic_feed_rounded,
              color: TClubColors.border, size: 48),
          const SizedBox(height: 16),
          const Text('NENHUM POST AINDA',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TClubColors.subtle,
              )),
          const SizedBox(height: 8),
          const Text('Seja o primeiro a publicar!',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 12,
                color: TClubColors.subtle,
              )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA CARD
// ══════════════════════════════════════════════════════════════════════════════
class _FestaCard extends StatelessWidget {
  final PartyModel festa;
  final String myUid;
  final bool isAdmin;
  final Map<String, dynamic> userData;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback onRefresh;

  const _FestaCard({
    required this.festa,
    required this.myUid,
    required this.isAdmin,
    required this.userData,
    required this.homeCoords,
    required this.onRefresh,
  });

  String? get _distLabel {
    if (homeCoords == null || !festa.canShowDistance) return null;
    final km = LocationService.distanceKm(
      homeCoords!.latitude,
      homeCoords!.longitude,
      festa.latitude!,
      festa.longitude!,
    );
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final dist = _distLabel;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.8),
          builder: (_) => _FestaDetailSheet(
            festa: festa,
            myUid: myUid,
            isAdmin: isAdmin,
            userData: userData,
            homeCoords: homeCoords,
            onRefresh: onRefresh,
          ),
        );
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.borderMid, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: TClubColors.glow.withOpacity(0.1),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(children: [
          Positioned.fill(
            child: temBanner
                ? CachedNetworkImage(
                    imageUrl: CloudinaryHelper.bannerUrl(festa.bannerUrl!),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => _bg(),
                    errorWidget: (_, __, ___) => _bg())
                : _bg(),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.25, 1.0],
                ),
              ),
            ),
          ),
          if (dist != null)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  border: Border.all(
                      color: TClubColors.redPrincipal.withOpacity(0.6),
                      width: 0.8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.near_me_rounded,
                      color: TClubColors.redPrincipal, size: 9),
                  const SizedBox(width: 4),
                  Text(dist,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: TClubColors.redPrincipal,
                      )),
                ]),
              ),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12), width: 0.5),
              ),
              child: Text('${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 8,
                    letterSpacing: 1,
                    color: Colors.white70,
                  )),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    color: TClubColors.redPrincipal,
                    child: Text(_fd(festa.dataInicio),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Colors.white,
                        )),
                  ),
                  const SizedBox(height: 6),
                  Text(festa.nome.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TClubTypography.displayFont,
                        fontSize: 16,
                        letterSpacing: 1.5,
                        color: Colors.white,
                        height: 1.2,
                      )),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                      festa.hasLocal
                          ? Icons.location_on_outlined
                          : Icons.location_off_outlined,
                      color: festa.hasLocal
                          ? TClubColors.redClaro
                          : TClubColors.subtle,
                      size: 9,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        festa.hasLocal ? festa.local! : 'Local não confirmado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          fontStyle: festa.hasLocal
                              ? FontStyle.normal
                              : FontStyle.italic,
                          color: festa.hasLocal
                              ? TClubColors.redClaro
                              : TClubColors.subtle,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _FB(Icons.star_outline_rounded, festa.interessados,
                        'interesse'),
                    const SizedBox(width: 8),
                    _FB(Icons.check_circle_outline_rounded, festa.confirmados,
                        'vão'),
                    const SizedBox(width: 8),
                    _FB(Icons.chat_bubble_outline_rounded, festa.commentCount,
                        'com'),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3D0018), Color(0xFF6B0030)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  String _fd(DateTime dt) {
    const d = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    const m = [
      'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
      'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'
    ];
    return '${d[dt.weekday - 1]}, ${dt.day} ${m[dt.month - 1]}';
  }

  String _fh(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _FB extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _FB(this.icon, this.count, this.label);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white54, size: 10),
        const SizedBox(width: 3),
        Text('$count $label',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 8,
              letterSpacing: 0.3,
              color: Colors.white54,
            )),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  FESTA DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _FestaDetailSheet extends StatefulWidget {
  final PartyModel festa;
  final String myUid;
  final bool isAdmin;
  final Map<String, dynamic> userData;
  final ({double latitude, double longitude})? homeCoords;
  final VoidCallback onRefresh;

  const _FestaDetailSheet({
    required this.festa,
    required this.myUid,
    required this.isAdmin,
    required this.userData,
    required this.homeCoords,
    required this.onRefresh,
  });

  @override
  State<_FestaDetailSheet> createState() => _FestaDetailSheetState();
}

class _FestaDetailSheetState extends State<_FestaDetailSheet> {
  FestaPresenca _presenca = FestaPresenca.nenhuma;
  bool _loadingPres = false;

  // ── Contadores (otimista + listener RT) ───────────────────────────────────
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

  // ── Listener RT — contadores ──────────────────────────────────────────────
  // Escuta apenas os dois nós folha: ~50 bytes por evento.
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
      setState(() {
        _comentarios = list;
        _comentariosIds.clear();
        for (final c in list) {
          final id = c['id'] as String?;
          if (id != null) _comentariosIds.add(id);
        }
        _loadingComs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingComs = false);
    }
    // Listener RT ativado após carga inicial para não duplicar dados.
    _ouvirComentarios();
  }

  // ── Listener RT — novos comentários ──────────────────────────────────────
  // onChildAdded re-dispara para todos os filhos existentes ao conectar, mas
  // _comentariosIds já contém os ids da carga inicial — todos são descartados.
  // Somente comentários genuinamente novos passam pelo filtro.
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

  Future<void> _carregarPresenca() async {
    if (widget.myUid.isEmpty) return;
    final p = await PartyService.instance
        .getPresenca(widget.festa.id, widget.myUid);
    if (mounted) setState(() => _presenca = p);
  }

  // ── Toggle de presença com atualização otimista ───────────────────────────
  Future<void> _togglePresenca(FestaPresenca nova) async {
    if (_loadingPres) return;

    final anterior = _presenca;
    final destino  = nova == anterior ? FestaPresenca.nenhuma : nova;

    setState(() {
      if (anterior == FestaPresenca.interessado)
        _interessados = (_interessados - 1).clamp(0, 9999);
      if (anterior == FestaPresenca.confirmado)
        _confirmados = (_confirmados - 1).clamp(0, 9999);
      if (destino == FestaPresenca.interessado) _interessados++;
      if (destino == FestaPresenca.confirmado) _confirmados++;
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
      // Rollback completo em caso de erro
      if (mounted) {
        setState(() {
          if (destino  == FestaPresenca.interessado)
            _interessados = (_interessados - 1).clamp(0, 9999);
          if (destino  == FestaPresenca.confirmado)
            _confirmados  = (_confirmados  - 1).clamp(0, 9999);
          if (anterior == FestaPresenca.interessado) _interessados++;
          if (anterior == FestaPresenca.confirmado) _confirmados++;
          _presenca    = anterior;
          _loadingPres = false;
        });
      }
    }
  }

  // ── Enviar comentário ─────────────────────────────────────────────────────
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

  String? get _distLabel {
    if (widget.homeCoords == null || !widget.festa.canShowDistance) return null;
    final km = LocationService.distanceKm(
        widget.homeCoords!.latitude,
        widget.homeCoords!.longitude,
        widget.festa.latitude!,
        widget.festa.longitude!);
    return LocationService.formatDistance(km);
  }

  @override
  Widget build(BuildContext context) {
    final festa = widget.festa;
    final temBanner = festa.bannerUrl != null && festa.bannerUrl!.isNotEmpty;
    final podeGerenciar =
        festa.creatorId == widget.myUid || widget.isAdmin;
    final dist = _distLabel;
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
          child: Column(children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: TClubColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                children: [
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
                        // ── Cabeçalho ─────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: TClubColors.redPrincipal,
                          child: Text(_fd(festa.dataInicio),
                              style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white,
                              )),
                        ),
                        const SizedBox(height: 10),
                        Text(festa.nome.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: TClubTypography.displayFont,
                              fontSize: 26,
                              letterSpacing: 3,
                              color: TClubColors.dim,
                            )),
                        const SizedBox(height: 10),
                        Row(children: [
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
                                    Text(dist,
                                        style: const TextStyle(
                                          fontFamily: TClubTypography.bodyFont,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                          color: TClubColors.redPrincipal,
                                        )),
                                  ]),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule_outlined,
                              color: TClubColors.subtle, size: 13),
                          const SizedBox(width: 5),
                          Text(
                              '${_fh(festa.dataInicio)} – ${_fh(festa.dataFim)}',
                              style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 12,
                                color: TClubColors.dim,
                              )),
                        ]),
                        const SizedBox(height: 20),

                        // ── Botões de presença ─────────────────────────────
                        Row(children: [
                          Expanded(
                            child: _PB(
                              icon: Icons.star_rounded,
                              label: 'INTERESSADO',
                              count: _interessados,
                              ativo:
                                  _presenca == FestaPresenca.interessado,
                              loading: _loadingPres,
                              color: TClubColors.redClaro,
                              onTap: () => _togglePresenca(
                                  FestaPresenca.interessado),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PB(
                              icon: Icons.check_circle_rounded,
                              label: 'VOU!',
                              count: _confirmados,
                              ativo:
                                  _presenca == FestaPresenca.confirmado,
                              loading: _loadingPres,
                              color: const Color(0xFF4ECDC4),
                              onTap: () => _togglePresenca(
                                  FestaPresenca.confirmado),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        Container(height: 0.5, color: TClubColors.border),
                        const SizedBox(height: 16),

                        // ── Descrição ──────────────────────────────────────
                        if (festa.descricao.isNotEmpty) ...[
                          const Text('SOBRE A NOITE',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: TClubColors.subtle,
                              )),
                          const SizedBox(height: 10),
                          Text(festa.descricao,
                              style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 14,
                                color: TClubColors.dim,
                                height: 1.6,
                              )),
                          const SizedBox(height: 16),
                          Container(height: 0.5, color: TClubColors.border),
                          const SizedBox(height: 16),
                        ],

                        // ── Gerenciar (admin/criador) ──────────────────────
                        if (podeGerenciar) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  Navigator.pop(context);
                                  final ok = await Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, animation, __) =>
                                          EditPartyScreen(
                                        festa: festa,
                                        userData: widget.userData,
                                      ),
                                      transitionsBuilder:
                                          (_, animation, __, child) =>
                                              FadeTransition(
                                        opacity: CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOut),
                                        child: child,
                                      ),
                                      transitionDuration:
                                          const Duration(milliseconds: 250),
                                    ),
                                  );
                                  if (ok == true) widget.onRefresh();
                                },
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
                                            color: TClubColors.redPrincipal,
                                            size: 14),
                                        SizedBox(width: 7),
                                        Text('EDITAR',
                                            style: TextStyle(
                                              fontFamily:
                                                  TClubTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.5,
                                              color: TClubColors.redPrincipal,
                                            )),
                                      ]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  Navigator.pop(context);
                                  await PartyService.instance
                                      .deleteFesta(festa.id);
                                  widget.onRefresh();
                                },
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
                                        Icon(Icons.delete_outline_rounded,
                                            color: Color(0xFFE85D5D),
                                            size: 14),
                                        SizedBox(width: 7),
                                        Text('EXCLUIR',
                                            style: TextStyle(
                                              fontFamily:
                                                  TClubTypography.bodyFont,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.5,
                                              color: Color(0xFFE85D5D),
                                            )),
                                      ]),
                                ),
                              ),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 20),
                        Container(height: 0.5, color: TClubColors.border),
                        const SizedBox(height: 16),

                        // ── Comentários ────────────────────────────────────
                        Row(children: [
                          const Text('COMENTÁRIOS',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: TClubColors.redPrincipal,
                              )),
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
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Seja o primeiro a comentar',
                                style: TextStyle(
                                  fontFamily: TClubTypography.bodyFont,
                                  fontSize: 11,
                                  color: TClubColors.subtle,
                                )),
                          )
                        else
                          ..._comentarios.map((com) => _CT(data: com)),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Input de comentário ────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: TClubColors.bgAlt,
                border: Border(
                    top: BorderSide(color: TClubColors.border, width: 0.5)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                keyboardHeight > 0
                    ? 12
                    : MediaQuery.of(context).padding.bottom + 10,
              ),
              child: Row(children: [
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
                        color: TClubColors.dim,
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
              ]),
            ),
          ]),
        ),
      ),
    );
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
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST CARD
// ══════════════════════════════════════════════════════════════════════════════
class _PostCard extends StatefulWidget {
  final PostModel post;
  final String uid;
  final Map<String, dynamic> userData;
  final ScrollController scrollController;
  final VoidCallback? onDeleted;

  const _PostCard({
    required this.post,
    required this.uid,
    required this.userData,
    required this.scrollController,
    this.onDeleted,
    super.key,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  late int _likes;
  late int _commentCount;
  bool _loadingLike = false;
  bool _isVip = false;

  late String _liveUserName;
  late String _liveUserAvatar;

  // FIX 12: altura do vídeo controlada aqui — começa com placeholder portrait.
  double _videoHeight = 440.0;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likes;
    _commentCount = widget.post.commentCount;
    _liveUserName = widget.post.userName;
    _liveUserAvatar = widget.post.userAvatar ?? '';

    if (_isOwnPost) {
      final n = UserDataNotifier.instance.nameUpper;
      final a = UserDataNotifier.instance.avatar;
      if (n.isNotEmpty) _liveUserName = n;
      if (a.isNotEmpty) _liveUserAvatar = a;
    }

    _checkLike();
    _checkVip();
    _loadLiveProfile();

    if (widget.post.tipo == 'video' && widget.post.mediaUrl != null) {
      VideoPreloadService.instance
          .preload(widget.post.id, widget.post.mediaUrl!);
    }
  }

  @override
  void dispose() {
    // REMOVA isto — InlineVideoCard já gerencia o ciclo de vida do controller
    // VideoPreloadService.instance.evict(widget.post.id);
    super.dispose();
  }
  bool get _isOwnPost => widget.post.userId == widget.uid;

  Future<void> _loadLiveProfile() async {
    final cached =
        UserProfileCache.instance.getCached(widget.post.userId);
    if (cached != null) {
      final newName =
          cached.name.isNotEmpty ? cached.name : _liveUserName;
      final newAvatar =
          cached.avatar.isNotEmpty ? cached.avatar : _liveUserAvatar;
      if (newName != _liveUserName || newAvatar != _liveUserAvatar) {
        if (mounted)
          setState(() {
            _liveUserName = newName;
            _liveUserAvatar = newAvatar;
          });
      }
      return;
    }
    final profile =
        await UserProfileCache.instance.fetch(widget.post.userId);
    if (!mounted) return;
    final newName =
        profile.name.isNotEmpty ? profile.name : _liveUserName;
    final newAvatar =
        profile.avatar.isNotEmpty ? profile.avatar : _liveUserAvatar;
    if (newName != _liveUserName || newAvatar != _liveUserAvatar) {
      setState(() {
        _liveUserName = newName;
        _liveUserAvatar = newAvatar;
      });
    }
  }

  Future<void> _checkVip() async {
    if (widget.uid.isEmpty || _isOwnPost) return;
    final vip = await FollowService.instance
        .isVip(widget.uid, widget.post.userId);
    if (mounted) setState(() => _isVip = vip);
  }

  Future<void> _checkLike() async {
    if (widget.uid.isEmpty) return;
    final liked = await PostService.instance
        .isLikedBy(widget.post.id, widget.uid);
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggleLike() async {
    if (_loadingLike || widget.uid.isEmpty) return;
    setState(() => _loadingLike = true);
    HapticFeedback.selectionClick();
    try {
      final nowLiked = await PostService.instance
          .toggleLike(widget.post.id, widget.uid);
      if (mounted)
        setState(() {
          _liked = nowLiked;
          _likes += nowLiked ? 1 : -1;
          _loadingLike = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingLike = false);
    }
  }

  Future<void> _abrirComentarios() async {
    HapticFeedback.selectionClick();
    final newCount = await showCommentsSheet(context,
        post: widget.post, userData: widget.userData);
    if (newCount != null && mounted)
      setState(() => _commentCount = newCount);
  }

  void _abrirPerfil() {
    if (_isOwnPost) return;
    HapticFeedback.selectionClick();
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(
            userId: widget.post.userId,
            userName: widget.post.userName,
            userAvatar: widget.post.userAvatar,
          ),
        ));
  }

  void _abrirImagemFullscreen() {
    HapticFeedback.selectionClick();
    Navigator.push(
        context,
        FullscreenImageScreen.route(
          imageUrl: widget.post.mediaUrl!,
          userName: widget.post.userName,
          titulo: widget.post.titulo,
        ));
  }

  void _mostrarMenuPost(BuildContext context, bool isOwnPost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TClubColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: TClubColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          if (isOwnPost) ...[
            _PostMenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'EXCLUIR POST',
              sublabel: 'Remove permanentemente',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                _confirmarDelete(context);
              },
            ),
            Container(height: 0.5, color: TClubColors.border),
          ],
          _PostMenuTile(
            icon: Icons.flag_outlined,
            label: 'DENUNCIAR',
            sublabel: 'Reportar este conteúdo',
            onTap: () {
              Navigator.pop(context);
              ReportPage.push(
                context,
                config: ReportPageConfig.post(
                  postId: widget.post.id,
                  postOwnerId: widget.post.userId,
                  postTitulo: widget.post.titulo,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _confirmarDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TClubColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: TClubColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Text('EXCLUIR POST?',
              style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize: 14,
                letterSpacing: 4,
                color: TClubColors.dim,
              )),
          const SizedBox(height: 8),
          const Text('Esta ação não pode ser desfeita.',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 12,
                color: TClubColors.subtle,
              )),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(sheetCtx),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: TClubColors.bgCard,
                      border: Border.all(
                          color: TClubColors.border, width: 0.8),
                    ),
                    child: const Center(
                        child: Text('CANCELAR',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              color: TClubColors.dim,
                            ))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    HapticFeedback.mediumImpact();
                    try {
                      await PostService.instance
                          .deletePost(widget.post.id);
                      widget.onDeleted?.call();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: TClubColors.bgAlt,
                            margin: const EdgeInsets.fromLTRB(
                                16, 0, 16, 24),
                            shape: const RoundedRectangleBorder(),
                            duration: const Duration(seconds: 3),
                            content: Row(children: const [
                              Icon(Icons.check_circle_outline_rounded,
                                  color: Color(0xFF4ECDC4), size: 16),
                              SizedBox(width: 10),
                              Text(
                                'Post excluído com sucesso',
                                style: TextStyle(
                                  fontFamily: TClubTypography.bodyFont,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                  color: TClubColors.dim,
                                ),
                              ),
                            ]),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('_confirmarDelete error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: TClubColors.bgAlt,
                            margin: const EdgeInsets.fromLTRB(
                                16, 0, 16, 24),
                            shape: const RoundedRectangleBorder(),
                            duration: const Duration(seconds: 3),
                            content: Row(children: const [
                              Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFE85D5D), size: 16),
                              SizedBox(width: 10),
                              Text(
                                'Erro ao excluir. Tente novamente.',
                                style: TextStyle(
                                  fontFamily: TClubTypography.bodyFont,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                  color: TClubColors.dim,
                                ),
                              ),
                            ]),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    height: 46,
                    color: const Color(0xFFE85D5D),
                    child: const Center(
                        child: Text('EXCLUIR',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              color: Colors.white,
                            ))),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  List<Color> _gradientForUser(String userId) {
    final palettes = [
      [const Color(0xFF3D0018), const Color(0xFF6B0030)],
      [const Color(0xFF1A0030), const Color(0xFF4B005A)],
      [const Color(0xFF2D0010), const Color(0xFF7A0028)],
      [const Color(0xFF0D0020), const Color(0xFF3B0050)],
      [const Color(0xFF2A0012), const Color(0xFFCC0044)],
    ];
    final idx =
        userId.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
    return palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final gradient = _gradientForUser(post.userId);
    final isVideo = post.tipo == 'video';
    final isPhoto = post.tipo == 'foto';
    final isEmoji = post.tipo == 'emoji';
    final temMidia = (isPhoto && post.mediaUrl != null) ||
        (isVideo && post.mediaUrl != null) ||
        isEmoji;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: TClubColors.border, width: 0.5)),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: _abrirPerfil,
              child: Stack(children: [
                CachedAvatar(
                  uid: post.userId,
                  name: _liveUserName,
                  size: 48,
                  radius: 12,
                  isOwn: _isOwnPost,
                  glowRing: _isOwnPost,
                ),
                if (_isVip)
                  Positioned.fill(
                      child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.7),
                          width: 1.5),
                    ),
                  )),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: _abrirPerfil,
                        child: Text(_liveUserName,
                            style: const TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: TClubColors.dim,
                            )),
                      ),
                      if (_isOwnPost) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: TClubColors.redPrincipal
                                .withOpacity(0.15),
                            border: Border.all(
                                color: TClubColors.redPrincipal
                                    .withOpacity(0.5),
                                width: 0.8),
                          ),
                          child: const Text('VOCÊ',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: TClubColors.redPrincipal,
                              )),
                        ),
                      ],
                      if (isVideo) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            border: Border.all(
                                color: TClubColors.redPrincipal
                                    .withOpacity(0.4),
                                width: 0.8),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.videocam_rounded,
                                    color: TClubColors.redPrincipal,
                                    size: 9),
                                SizedBox(width: 3),
                                Text('VÍDEO',
                                    style: TextStyle(
                                      fontFamily: TClubTypography.bodyFont,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      color: TClubColors.redPrincipal,
                                    )),
                              ]),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(_formatTime(post.createdAt),
                          style: const TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: TClubColors.subtle,
                          )),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                            color: TClubColors.subtle,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      _VisibilidadeChip(
                          visibilidade: post.visibilidade),
                    ]),
                  ]),
            ),
            GestureDetector(
              onTap: () => _mostrarMenuPost(context, _isOwnPost),
              child: const Icon(Icons.more_horiz,
                  color: TClubColors.subtle, size: 18),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(post.titulo,
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: TClubColors.dim,
                height: 1.4,
              )),
        ),
        if (temMidia) _buildMidia(post, gradient),
        if (post.descricao != null && post.descricao!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Text(post.descricao!,
                style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 14,
                  letterSpacing: 0.2,
                  color: TClubColors.dim,
                  height: 1.5,
                )),
          ),
        if (!temMidia &&
            (post.descricao == null || post.descricao!.isEmpty))
          const SizedBox(height: 10),
        Container(
          height: 0.5,
          color: TClubColors.border,
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            _ActionBtn(
              icon: _liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: '$_likes',
              color: _liked
                  ? TClubColors.redPrincipal
                  : TClubColors.subtle,
              onTap: _toggleLike,
            ),
            _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: _commentCount > 0 ? '$_commentCount' : 'COMENTAR',
              color: TClubColors.subtle,
              onTap: _abrirComentarios,
            ),
          ]),
        ),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _buildMidia(PostModel post, List<Color> gradient) {
    if (post.tipo == 'emoji' && post.emoji != null) {
      return Container(
        height: 220,
        margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            top: BorderSide(color: TClubColors.border, width: 0.5),
            bottom: BorderSide(color: TClubColors.border, width: 0.5),
          ),
        ),
        child: Center(
            child:
                Text(post.emoji!, style: const TextStyle(fontSize: 110))),
      );
    }

    if (post.tipo == 'video' && post.mediaUrl != null) {
      return ClipRect(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: SizedBox(
            height: _videoHeight,
            child: InlineVideoCard(
              tapToPause: true,
                postId: post.id,
                videoUrl: post.mediaUrl!,
                thumbUrl: post.thumbUrl,
                duration: post.videoDuration,
                gradient: gradient,
                userName: post.userName,
                titulo: post.titulo,
                scrollController: widget.scrollController,
                onHeightChanged: (h) {
                  if (mounted && h != _videoHeight) {
                    setState(() => _videoHeight = h);
                  }
                },
              ),
            ),
          ),
      
      
        );
      }

    if (post.mediaUrl != null) {
      return GestureDetector(
        onTap: _abrirImagemFullscreen,
        child: Container(
          height: 340,
          margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          decoration: BoxDecoration(
            color: TClubColors.bgCard,
            border: Border(
              top: BorderSide(color: TClubColors.border, width: 0.5),
              bottom: BorderSide(color: TClubColors.border, width: 0.5),
            ),
          ),
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: CloudinaryHelper.bannerUrl(post.mediaUrl!),
              fit: BoxFit.cover,
              width: double.infinity,
              fadeInDuration: const Duration(milliseconds: 200),
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: TClubColors.subtle, size: 36)),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.5),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.fullscreen_rounded,
                          color: Colors.white54, size: 10),
                      SizedBox(width: 3),
                      Text('TELA CHEIA',
                          style: TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 7,
                            letterSpacing: 1.5,
                            color: Colors.white54,
                          )),
                    ]),
              ),
            ),
          ]),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEEK BAR
// ══════════════════════════════════════════════════════════════════════════════
class _SeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _SeekBar({required this.controller});
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pos =
        widget.controller.value.position.inMilliseconds.toDouble();
    final total =
        widget.controller.value.duration.inMilliseconds.toDouble();
    final pct =
        total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (total <= 0) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localX =
            details.localPosition.dx.clamp(0.0, box.size.width);
        final seekMs =
            (localX / box.size.width * total).clamp(0.0, total);
        widget.controller
            .seekTo(Duration(milliseconds: seekMs.toInt()));
      },
      child: Container(
        height: 3,
        decoration:
            BoxDecoration(color: Colors.white.withOpacity(0.15)),
        child: FractionallySizedBox(
          widthFactor: pct,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TClubColors.redDeep, TClubColors.redPrincipal],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS COMPARTILHADOS
// ══════════════════════════════════════════════════════════════════════════════
class _PB extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool ativo, loading;
  final Color color;
  final VoidCallback onTap;
  const _PB({
    required this.icon,
    required this.label,
    required this.count,
    required this.ativo,
    required this.loading,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: ativo ? color.withOpacity(0.15) : TClubColors.bgCard,
            border: Border.all(
              color:
                  ativo ? color.withOpacity(0.6) : TClubColors.border,
              width: ativo ? 1.2 : 0.8,
            ),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          color: color, strokeWidth: 1.5)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color: ativo ? color : TClubColors.subtle,
                        size: 14),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: ativo ? color : TClubColors.subtle,
                            )),
                        if (count > 0)
                          Text('$count',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9,
                                color: ativo
                                    ? color.withOpacity(0.7)
                                    : TClubColors.border,
                              )),
                      ],
                    ),
                  ]),
        ),
      );
}

class _CT extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CT({required this.data});
  @override
  Widget build(BuildContext context) {
    final uid = data['user_id'] as String? ?? '';
    final name = data['user_name'] as String? ?? '';
    final texto = data['texto'] as String? ?? '';
    final ts = data['created_at'] as int? ?? 0;
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    final tempo = diff.inMinutes < 60
        ? '${diff.inMinutes}min'
        : diff.inHours < 24
            ? '${diff.inHours}h'
            : '${diff.inDays}d';
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
                  Row(children: [
                    Text(name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: TClubColors.dim,
                        )),
                    const SizedBox(width: 8),
                    Text(tempo,
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          color: TClubColors.subtle,
                        )),
                  ]),
                  const SizedBox(height: 3),
                  Text(texto,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 13,
                        color: TClubColors.dim,
                        height: 1.4,
                      )),
                ])),
          ]),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final VoidCallback onTap;
  final bool accent;
  const _MenuOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.accent = false,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent
                    ? TClubColors.redPrincipal.withOpacity(0.15)
                    : TClubColors.bgCard,
                border: Border.all(
                  color: accent
                      ? TClubColors.redPrincipal
                      : TClubColors.border,
                  width: 0.8,
                ),
              ),
              child: Icon(icon,
                  color:
                      accent ? TClubColors.redPrincipal : TClubColors.dim,
                  size: 16),
            ),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: accent
                            ? TClubColors.redPrincipal
                            : TClubColors.dim,
                      )),
                  Text(sublabel,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: TClubColors.subtle,
                      )),
                ]),
          ]),
        ),
      );
}

class _SquircleAvatar extends StatelessWidget {
  final double size, radius;
  final String avatarUrl;
  final List<Color> gradient;
  final Color ringColor;
  final bool hasNewStory;
  const _SquircleAvatar({
    required this.size,
    required this.radius,
    required this.avatarUrl,
    required this.gradient,
    required this.ringColor,
    this.hasNewStory = false,
  });
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: hasNewStory
              ? const LinearGradient(colors: [
                  TClubColors.redDeep,
                  TClubColors.redPrincipal,
                  TClubColors.redClaro,
                ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : LinearGradient(colors: [ringColor, ringColor]),
          boxShadow: hasNewStory
              ? [
                  BoxShadow(
                      color: TClubColors.glow,
                      blurRadius: 10,
                      spreadRadius: 1)
                ]
              : null,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 2),
          child: avatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: CloudinaryHelper.avatarUrl(avatarUrl),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder())
              : _placeholder(),
        ),
      );
  Widget _placeholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.person_outline,
            color: TClubColors.redPrincipal, size: 18),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  STORY BUBBLE
// ══════════════════════════════════════════════════════════════════════════════
class _StoryBubble extends StatelessWidget {
  final String uid, name, avatarUrl;
  final bool isOwn, hasNew, viewed, isVip;
  final Map<String, dynamic> userData;
  final VoidCallback onTap;

  const _StoryBubble({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.isOwn,
    required this.hasNew,
    required this.userData,
    required this.onTap,
    this.viewed = false,
    this.isVip = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child:
                    Stack(alignment: Alignment.center, children: [
                  if (isVip && hasNew && !viewed)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6B4A00),
                            Color(0xFFD4AF37),
                            Color(0xFFFFE066),
                            Color(0xFFD4AF37)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFD4AF37),
                            blurRadius: 14,
                            spreadRadius: 1,
                            blurStyle: BlurStyle.outer,
                          ),
                        ],
                      ),
                    )
                  else if (hasNew && !viewed)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            TClubColors.redDeep,
                            TClubColors.redPrincipal,
                            TClubColors.redClaro
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: TClubColors.glow,
                              blurRadius: 12,
                              spreadRadius: 1),
                        ],
                      ),
                    )
                  else if (hasNew && viewed)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.grey, width: 1.5),
                        gradient: const LinearGradient(
                          colors: [Colors.grey, Colors.grey],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: TClubColors.border,
                      ),
                    ),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: TClubColors.bg, width: 2.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.5),
                      child: CachedAvatar(
                        uid: uid,
                        name: name,
                        size: 57,
                        radius: 10.5,
                        isOwn: isOwn,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            if (isOwn)
              Positioned(
                bottom: 1,
                right: 1,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, animation, __) =>
                              CreateStoryScreen(userData: userData),
                          transitionsBuilder:
                              (_, animation, __, child) =>
                                  FadeTransition(
                            opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.06),
                                      end: Offset.zero)
                                  .animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                          ),
                          transitionDuration:
                              const Duration(milliseconds: 340),
                        ),
                      );
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: TClubColors.redPrincipal,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: TClubColors.bg, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: TClubColors.glow.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add,
                          color: TClubColors.dim, size: 12),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          isOwn ? 'SEU' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color:
                hasNew ? TClubColors.redPrincipal : TClubColors.subtle,
          ),
        ),
      ]),
    );
  }
}

class _VisibilidadeChip extends StatelessWidget {
  final String visibilidade;
  const _VisibilidadeChip({required this.visibilidade});
  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (visibilidade) {
      case 'seguidores':
        icon = Icons.people_outline_rounded;
        break;
      case 'vip':
        icon = Icons.star_border_rounded;
        break;
      default:
        icon = Icons.public_rounded;
    }
    return Icon(icon, color: TClubColors.subtle, size: 10);
  }
}

class _PostMenuTile extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final bool danger;
  final VoidCallback onTap;
  const _PostMenuTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) {
    final color =
        danger ? const Color(0xFFE85D5D) : TClubColors.dim;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 0.8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: color,
                    )),
                Text(sublabel,
                    style: const TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: TClubColors.subtle,
                    )),
              ]),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 17),
                  const SizedBox(width: 5),
                  Text(label,
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: color,
                      )),
                ]),
          ),
        ),
      );
}

class _PostsSkeleton extends StatelessWidget {
  const _PostsSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
            2,
            (_) => Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: TClubColors.border, width: 0.5)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _SkeletonBox(
                              width: 44, height: 44, radius: 10),
                          const SizedBox(width: 12),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _SkeletonBox(
                                    width: 120,
                                    height: 12,
                                    radius: 4),
                                const SizedBox(height: 6),
                                _SkeletonBox(
                                    width: 80, height: 10, radius: 4),
                              ]),
                        ]),
                        const SizedBox(height: 12),
                        _SkeletonBox(
                            width: double.infinity,
                            height: 16,
                            radius: 4),
                        const SizedBox(height: 8),
                        _SkeletonBox(
                            width: 200, height: 14, radius: 4),
                        const SizedBox(height: 12),
                        _SkeletonBox(
                            width: double.infinity,
                            height: 280,
                            radius: 0),
                      ]),
                )),
      );
}

class _StoriesSkeleton extends StatelessWidget {
  const _StoriesSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 5,
        itemBuilder: (_, __) => SizedBox(
          width: 68,
          child: Column(children: [
            _SkeletonBox(width: 68, height: 68, radius: 16),
            const SizedBox(height: 6),
            _SkeletonBox(width: 40, height: 8, radius: 4),
          ]),
        ),
      );
}

class _SkeletonBox extends StatelessWidget {
  final double width, height, radius;
  const _SkeletonBox(
      {required this.width,
      required this.height,
      required this.radius});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: TClubColors.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _FeedBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TClubColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.1),
      size.width * 0.7,
      Paint()
        ..shader = RadialGradient(colors: [
          TClubColors.redPrincipal.withOpacity(0.07),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.1),
          radius: size.width * 0.7,
        )),
    );
  }

  @override
  bool shouldRepaint(_FeedBg _) => false;
}

