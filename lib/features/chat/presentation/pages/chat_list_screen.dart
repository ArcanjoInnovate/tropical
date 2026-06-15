// lib/features/chat/presentation/pages/chat_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/chat/controller/chat_controller.dart';
import 'package:tclub/features/chat/data/models/chat_model.dart';
import 'package:tclub/features/chat/data/models/chat_request_model.dart';
import 'package:tclub/features/chat/data/repositories/chat_repository.dart';
import 'package:tclub/features/chat/data/services/chat_service.dart';
import 'package:tclub/features/chat/presentation/pages/chat_screen.dart';
import 'package:tclub/features/chat/presentation/widgets/chat_tile.dart';
import 'package:tclub/features/chat/presentation/widgets/chat_tile_list.dart';
import 'package:tclub/features/chat/presentation/widgets/request_card.dart';
import 'package:tclub/features/chat/presentation/widgets/like_card.dart';
import 'package:tclub/features/match/data/services/like_me_service.dart';
import 'package:tclub/core/services/chat_request_service.dart';
import 'package:tclub/core/services/user_data_notifier.dart';

class ChatListScreen extends StatefulWidget {
  final int initialTab;
  final String? blockedChatId;

  const ChatListScreen({
    super.key,
    this.initialTab = 0,
    this.blockedChatId,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _showBlockedBanner = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });

    if (widget.blockedChatId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _showBlockedBanner = true);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showBlockedBanner = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    _tabCtrl.animateTo(index);
    setState(() {});
    if (index == 1 && _myUid.isNotEmpty) {
      ChatRequestService().markAllAsSeen(_myUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Stack(children: [
        const _GradientTopLine(),
        SafeArea(
          child: Column(children: [
            _ChatListHeader(myUid: _myUid),
            if (_showBlockedBanner)
              _BlockedBanner(
                onDismiss: () => setState(() => _showBlockedBanner = false),
              ),
            _ChatTabBar(
              currentIndex: _tabCtrl.index,
              myUid: _myUid,
              onTabTap: _goToTab,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ChatsTab(myUid: _myUid),
                  _RequestsTab(myUid: _myUid),
                  _LikeMeTab(myUid: _myUid),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LINHA GRADIENTE DO TOPO
// ══════════════════════════════════════════════════════════════════════════════

class _GradientTopLine extends StatelessWidget {
  const _GradientTopLine();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 1.5,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            TClubColors.redDeep,
            TClubColors.redPrincipal,
            TClubColors.redClaro,
            TClubColors.redPrincipal,
            TClubColors.redDeep,
            Colors.transparent,
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _ChatListHeader extends StatelessWidget {
  final String myUid;
  const _ChatListHeader({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: TClubColors.bg,
        border: Border(
          bottom: BorderSide(
            color: TClubColors.border.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(children: [
        Container(width: 1, height: 14, color: TClubColors.redPrincipal),
        const SizedBox(width: 10),
        const Text(
          'MENSAGENS',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: TClubColors.textoPrincipal,
          ),
        ),
        const Spacer(),
        _UnreadBadgeTotal(myUid: myUid),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BADGE TOTAL NÃO LIDOS
// ══════════════════════════════════════════════════════════════════════════════

class _UnreadBadgeTotal extends StatelessWidget {
  final String myUid;
  const _UnreadBadgeTotal({required this.myUid});

  @override
  Widget build(BuildContext context) {
    if (myUid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      // ✅ TROCA CIRÚRGICA: Users → UserBadges
      stream: FirebaseDatabase.instance
          .ref('UserBadges/$myUid/unreadChatsCount')
          .onValue,
      builder: (_, snap) {
        final total = (snap.data?.snapshot.value as int?) ?? 0;
        if (total == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: TClubColors.redPrincipal.withOpacity(0.15),
            border: Border.all(
              color: TClubColors.redPrincipal.withOpacity(0.4),
              width: 0.8,
            ),
          ),
          child: Text(
            '$total',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: TClubColors.redPrincipal,
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB BAR
// ══════════════════════════════════════════════════════════════════════════════

class _ChatTabBar extends StatelessWidget {
  final int currentIndex;
  final String myUid;
  final ValueChanged<int> onTabTap;

  const _ChatTabBar({
    required this.currentIndex,
    required this.myUid,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: TClubColors.bg,
        border: Border(
          bottom: BorderSide(
            color: TClubColors.border.withOpacity(0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(children: [
        _TabBtn(
          label: 'CONVERSAS',
          isActive: currentIndex == 0,
          onTap: () => onTabTap(0),
        ),
        _TabBtn(
          label: 'SOLICITAÇÕES',
          isActive: currentIndex == 1,
          onTap: () => onTabTap(1),
          badgeStream: ChatRequestService().unseenCountStream(myUid),
        ),
        _TabBtn(
          label: 'ME CURTIU',
          isActive: currentIndex == 2,
          onTap: () => onTabTap(2),
          badgeStream: LikeMeService().likeCountStream(myUid),
        ),
      ]),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;

  const _TabBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeStream,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color:
                      isActive ? TClubColors.redPrincipal : TClubColors.subtle,
                ),
              ),
              if (badgeStream != null)
                StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (_, snap) {
                    final n = snap.data ?? 0;
                    if (n == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: TClubColors.redPrincipal,
                          shape: BoxShape.circle,
                          border: Border.all(color: TClubColors.bg, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ]),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 1.5,
              width: isActive ? 32 : 0,
              color: TClubColors.redPrincipal,
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BANNER DE BLOQUEIO
// ══════════════════════════════════════════════════════════════════════════════

class _BlockedBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _BlockedBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.12),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFDC2626).withOpacity(0.4),
            width: 0.8,
          ),
        ),
      ),
      child: Row(children: [
        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFDC2626)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Esta conversa foi bloqueada.',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 11,
              letterSpacing: 0.4,
              color: const Color(0xFFDC2626).withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Color(0xFFDC2626),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ABA: CONVERSAS
// ══════════════════════════════════════════════════════════════════════════════

class _ChatsTab extends StatefulWidget {
  final String myUid;
  const _ChatsTab({required this.myUid});

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(repository: ChatRepository());
  }

  void _openChat(BuildContext context, TabuChat chat, String otherUid) {
    if (chat.blockDialog) {
      _showBlockedSnackbar(context);
      return;
    }
    HapticFeedback.selectionClick();
    _navigateToChatRoom(context, otherUid);
  }

  void _showBlockedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: Row(children: [
          const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 10),
          const Text(
            'Esta conversa está bloqueada.',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 11,
              letterSpacing: 0.4,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToChatRoom(BuildContext context, String otherUid) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ChangeNotifierProvider(
          create: (_) => ChatController(
            service: ChatService(repository: ChatRepository()),
          ),
          child: OtherUserChatRoom(
            myUid: widget.myUid,
            otherUid: otherUid,
          ),
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _chatService.chatIdsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingIndicator();
        }
        final chatIds = snap.data ?? [];
        if (chatIds.isEmpty) return const _EmptyChats();

        return ChatTileList(
          chatIds: chatIds,
          myUid: widget.myUid,
          onTap: (chat, otherUid) => _openChat(context, chat, otherUid),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ABA: SOLICITAÇÕES
// ══════════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatelessWidget {
  final String myUid;
  const _RequestsTab({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRequest>>(
      stream: ChatRequestService().pendingRequestsStream(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingIndicator();
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) return const _EmptyRequests();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: requests.length,
          itemBuilder: (ctx, i) => RequestCard(
            key: ValueKey(requests[i].id),
            request: requests[i],
            myUid: myUid,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ABA: ME CURTIU
// ══════════════════════════════════════════════════════════════════════════════

class _LikeMeTab extends StatelessWidget {
  final String myUid;
  const _LikeMeTab({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: LikeMeService().likeMeUidsStream(myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingIndicator();
        }
        final uids = snap.data ?? [];
        if (uids.isEmpty) return const _EmptyLikes();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: uids.length,
          itemBuilder: (ctx, i) => LikeCard(
            key: ValueKey(uids[i]),
            likerUid: uids[i],
            myUid: myUid,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ESTADOS VAZIOS
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) => _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'NENHUMA CONVERSA AINDA',
        subtitle: 'Visite perfis e envie mensagens',
      );
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) => _EmptyState(
        icon: Icons.mark_chat_unread_outlined,
        title: 'SEM SOLICITAÇÕES',
        subtitle: 'Quando alguém quiser conversar,\naparece aqui',
      );
}

class _EmptyLikes extends StatelessWidget {
  const _EmptyLikes();

  @override
  Widget build(BuildContext context) => _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'NINGUÉM CURTIU AINDA',
        subtitle: 'Quando alguém curtir você,\naparece aqui',
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: TClubColors.border, width: 0.8),
              color: TClubColors.bgCard,
            ),
            child: Icon(icon, color: TClubColors.border, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.5,
              color: TClubColors.subtle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 12,
              letterSpacing: 0.3,
              color: TClubColors.dim,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LOADING
// ══════════════════════════════════════════════════════════════════════════════

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: TClubColors.redPrincipal,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPER: carrega dados do outro usuário e abre ChatRoomScreen
// ══════════════════════════════════════════════════════════════════════════════

class OtherUserChatRoom extends StatelessWidget {
  final String myUid;
  final String otherUid;

  const OtherUserChatRoom({
    super.key,
    required this.myUid,
    required this.otherUid,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('UsersPublic/$otherUid').once(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: TClubColors.bg,
            body: _LoadingIndicator(),
          );
        }
        final data = snap.data!.snapshot.value as Map<dynamic, dynamic>?;
        final name = data?['name'] as String? ?? 'Usuário';
        final avatar = data?['avatar'] as String?;

        return ChatRoomScreen(
          myUid: myUid,
          otherUid: otherUid,
          otherName: name,
          otherAvatar: avatar,
        );
      },
    );
  }
}

