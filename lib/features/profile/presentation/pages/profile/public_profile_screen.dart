// features/profile/presentation/pages/profile/public_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tabuapp/features/chat/controller/chat_controller.dart';
import 'package:tabuapp/features/chat/data/repositories/chat_repository.dart';
import 'package:tabuapp/features/chat/data/services/chat_service.dart';
import 'package:tabuapp/core/providers/block_provider.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/gallery/data/models/gallery_item_model.dart';
import 'package:tabuapp/features/profile/controller/public_profile_controller.dart';
import 'package:tabuapp/features/profile/presentation/widgets/perfil_screen_widgets.dart';
import 'package:tabuapp/features/story/presentation/pages/story_viewer_screen.dart';
import 'package:tabuapp/features/user/moderation/moderation.dart';
import 'package:tabuapp/features/feed/presentation/screens/galery_feed_screen.dart';
import 'package:tabuapp/features/profile/presentation/widgets/media_grid_tile.dart';
import 'package:tabuapp/features/profile/presentation/widgets/profile_avatar_section.dart';
import 'package:tabuapp/features/profile/presentation/widgets/profile_identity_widgets.dart';
import 'package:tabuapp/features/chat/presentation/pages/chat_screen.dart';
import '../../../data/models/profile_user_model.dart';
import '_profile_painters.dart';
import '_public_profile_actions.dart';
import '_options_sheet.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  final String userId;
  final String userName;
  final String? userAvatar;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with TickerProviderStateMixin {
  late PublicProfileController _ctrl;
  late TabController _tabController;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  final _scrollController = ScrollController();

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _ctrl = PublicProfileController(targetUid: widget.userId)..init();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    _tabController = TabController(length: 1, vsync: this)
      ..addListener(() {
        setState(() {});
      });

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryCtrl.dispose();
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

  List<Color> _gradient(String id) {
    const p = [
      [Color(0xFF3D0018), Color(0xFF6B0030)],
      [Color(0xFF1A0030), Color(0xFF4B005A)],
      [Color(0xFF2D0010), Color(0xFF7A0028)],
      [Color(0xFF0D0020), Color(0xFF3B0050)],
      [Color(0xFF2A0012), Color(0xFFCC0044)],
    ];
    return p[id.codeUnits.fold(0, (a, b) => a + b) % p.length];
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _openStories() {
    if (_ctrl.stories.isEmpty) return;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => StoryViewerScreen(
          storiesByUser: {widget.userId: _ctrl.stories},
          initialUserId: widget.userId,
          myUid: _myUid,
          onStoriesChanged: _ctrl.refreshStories,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _handleChatButton() async {
    final result = await _ctrl.sendOrHandleChat();
    if (!mounted) return;
    switch (result) {
      case 'navigate_chat':
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => ChangeNotifierProvider(
              create: (_) => ChatController(
                service: ChatService(repository: ChatRepository()),
              ),
              child: ChatRoomScreen(
                myUid: _myUid,
                otherUid: widget.userId,
                otherName: widget.userName,
                otherAvatar: widget.userAvatar,
              ),
            ),
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 280),
          ),
        );
        break;
      case 'sent':
        _snack('Solicitação enviada! 🎉');
        break;
      case 'exists':
        _snack('Solicitação já enviada.');
        break;
      case 'already_sent':
        _snack('Aguardando resposta...');
        break;
      case 'timeout':
        _snack('Tempo esgotado. Verifique sua conexão.');
        break;
      case 'error':
        _snack('Erro. Tente novamente.');
        break;
    }
  }

  void _openGalleryItem(GalleryItem item) {
    HapticFeedback.selectionClick();
    final index = _ctrl.galleryItems.indexOf(item);
    Navigator.push(
      context,
      GalleryFeedScreen.route(
        items: _ctrl.galleryItems,
        initialIndex: index < 0 ? 0 : index,
        userName: widget.userName,
      ),
    );
  }

  void _openOptions() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.60),
      builder: (_) => ProfileOptionsSheet(
        userName: widget.userName,
        onReport: () {
          Navigator.pop(context);
          ReportPage.push(
            context,
            config: ReportPageConfig.user(
              reportedUserId: widget.userId,
              reportedUserName: widget.userName,
            ),
          );
        },
        onBlock: () {
          Navigator.pop(context);
          _showBlockDialog();
        },
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock, color: Colors.red.shade600, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Bloquear Usuário',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Ele não poderá mais ver suas vagas ou entrar em contato com você.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(
                    color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final bp = context.read<BlockProvider>();
              await bp.blockUser(widget.userId);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Bloquear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TabuColors.bgAlt,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
      content: Text(msg,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 11,
            letterSpacing: 0.5,
            color: TabuColors.dim,
          )),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final gradient = _gradient(widget.userId);

    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: AtmospherePainter(gradient: gradient)),
        ),
        _TopAccentLine(),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
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
                          _buildAvatarSection(gradient),
                          const SizedBox(height: 14),
                          _buildNameBlock(),
                          _buildLocation(),
                          const SizedBox(height: 20),
                          _buildStatsRow(),
                          const SizedBox(height: 20),
                          _buildBio(),
                          _buildPersonalityBlock(),
                          const SizedBox(height: 20),
                          if (!_ctrl.isMe) _buildActionButtons(),
                          if (!_ctrl.isMe) const SizedBox(height: 20),
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
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8),
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              color: TabuColors.dim, size: 16),
        ),
      ),
      const Spacer(),
      if (!_ctrl.isMe)
        GestureDetector(
          onTap: _openOptions,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8),
            ),
            child: const Icon(Icons.more_horiz,
                color: TabuColors.subtle, size: 18),
          ),
        )
      else
        const SizedBox(width: 38),
    ]);
  }

  Widget _buildAvatarSection(List<Color> gradient) {
    final hasStories = _ctrl.stories.isNotEmpty;
    return ProfileAvatarSection(
      uid: widget.userId,
      name: widget.userName,
      avatarUrl: widget.userAvatar,
      gradient: gradient,
      hasStories: hasStories,
      hasUnviewedStory: _ctrl.hasUnviewedStory,
      isVip: _ctrl.vip,
      isOnline: _ctrl.user?.isOnline ?? false,
      onTap: hasStories ? _openStories : null,
    );
  }

  Widget _buildNameBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.userName.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 28,
            letterSpacing: 6,
            color: TabuColors.textoPrincipal,
            fontWeight: FontWeight.w400,
            shadows: [Shadow(color: TabuColors.glow, blurRadius: 20)],
          ),
        ),
        if (_ctrl.vip) ...[
          const SizedBox(height: 6),
          const VipBadge(),
        ],
      ],
    );
  }

  Widget _buildLocation() {
    final user = _ctrl.user;
    if (user == null || user.locationDisplay.isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.location_on_outlined,
            color: TabuColors.rosaPrincipal, size: 11),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            user.locationDisplay,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: TabuColors.rosaPrincipal,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatsRow() {
    if (_ctrl.loadingUser) return const MetricsBarSkeleton();
    final user = _ctrl.user;
    return Row(children: [
      StatCard(
        value: '${user?.followers ?? 0}',
        label: 'SEGUIDORES',
        icon: Icons.people_outline_rounded,
        onTap: () {},
      ),
      const SizedBox(width: 10),
      StatCard(
        value: '${_ctrl.galleryItems.length}',
        label: 'GALERIA',
        icon: Icons.photo_library_outlined,
        highlight: true,
        onTap: () {},
      ),
    ]);
  }

  Widget _buildBio() {
    final bio = (_ctrl.user?.bio ?? '').trim();
    if (bio.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        bio,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 13,
          letterSpacing: 0.3,
          color: TabuColors.dim.withOpacity(0.85),
          height: 1.65,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildPersonalityBlock() {
    final user = _ctrl.user;
    if (user == null) return const SizedBox.shrink();

    final hasIdentity = user.genderLabel.isNotEmpty ||
        user.orientationLabel.isNotEmpty ||
        user.relationshipLabel.isNotEmpty;
    final hasCouple = user.isCouple && user.partner != null;
    final hasInterest = user.hasInterests;

    if (!hasIdentity && !hasCouple && !hasInterest)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasIdentity) ProfileIdentityRow(user: user),
        if (hasCouple) ...[
          const SizedBox(height: 10),
          CouplePartnerCard(partner: user.partner!),
        ],
        if (hasInterest) ...[
          if (hasIdentity || hasCouple) const SizedBox(height: 8),
          ProfileInterestsSection(interests: user.interests),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return PublicProfileActions(
      following: _ctrl.following,
      loadingFollow: _ctrl.loadingFollow,
      vip: _ctrl.vip,
      loadingVip: _ctrl.loadingVip,
      chatRequest: _ctrl.chatRequest,
      loadingChat: _ctrl.loadingChat,
      isPending: _ctrl.isPending,
      isAccepted: _ctrl.isAccepted,
      iSent: _ctrl.iSent,
      iReceived: _ctrl.iReceived,
      onFollow: _ctrl.toggleFollow,
      onVip: _ctrl.toggleVip,
      onChat: _handleChatButton,
    );
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
    if (!_ctrl.hasGallery || _ctrl.galleryItems.isEmpty) {
      return [
        const EmptyGridState(
          label: 'Sem galeria',
          sublabel: 'Este usuário ainda não criou uma galeria',
        )
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
              return GalleryGridTile(
                item: item,
                onTap: () => _openGalleryItem(item),
              );
            },
            childCount: _ctrl.galleryItems.length,
          ),
        ),
      ),
      if (_ctrl.loadingMoreGallery) const LoadMoreIndicator(),
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TOP ACCENT LINE
// ══════════════════════════════════════════════════════════════════════════════
class _TopAccentLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 1.5,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            TabuColors.rosaDeep,
            TabuColors.rosaPrincipal,
            TabuColors.rosaClaro,
            TabuColors.rosaPrincipal,
            TabuColors.rosaDeep,
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}