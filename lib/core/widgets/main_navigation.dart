// lib/widgets/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/feed/presentation/screens/feed_administrative_screen.dart';
import 'package:tclub/features/feed/presentation/screens/feed_screen.dart';
import 'package:tclub/features/match/presentation/pages/match_profile_page.dart';
import 'package:tclub/features/profile/presentation/pages/profile/own_profile_screen.dart';
import 'package:tclub/core/services/user_data_notifier.dart';
import 'package:tclub/core/services/user_avatar_service.dart';
import 'package:tclub/core/controllers/tclub_shell_controller.dart';
import 'package:tclub/features/search/presentation/screens/search_screen.dart';
import 'package:tclub/features/chat/presentation/pages/chat_list_screen.dart';


class TabuShell extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isAdmin;

  const TabuShell({
    super.key,
    required this.userData,
    this.isAdmin = false,
  });

  @override
  State<TabuShell> createState() => _TabuShellState();
}

class _TabuShellState extends State<TabuShell> {
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    UserDataNotifier.instance.init(widget.userData);
    final uid = widget.userData['uid'] as String?
             ?? widget.userData['id']  as String? ?? '';
    if (uid.isNotEmpty) UserAvatarService.instance.invalidate(uid);

    TclubShellController.instance.initialize(isAdmin: widget.isAdmin);
    TclubShellController.instance.addListener(_onControllerChanged);

    if (widget.isAdmin) {
      _screens = [
        HomeScreen(userData: widget.userData, isAdmin: true),
        HomeScreenAdministrative(userData: widget.userData),
        SearchScreen(myUid: _myUid),
        const ChatListScreen(),
        OwnProfileScreen(userData: widget.userData),
      ];
    } else {
      _screens = [
        HomeScreen(userData: widget.userData, isAdmin: false),
        SearchScreen(myUid: _myUid),
        const ChatListScreen(),
        OwnProfileScreen(userData: widget.userData),
      ];
    }
  }

  @override
  void dispose() {
    TclubShellController.instance.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    TclubShellController.instance.setTabIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      extendBody: true,
      body: IndexedStack(
        index: TclubShellController.instance.currentTabIndex,
        children: _screens,
      ),
      bottomNavigationBar: _TclubNavBar(
        currentIndex: TclubShellController.instance.currentTabIndex,
        isAdmin:      widget.isAdmin,
        myUid:        _myUid,
        onTap:        _onTabTapped,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM NAV BAR
// ════════════════════════════════════════════════════════════════════════════
class _TclubNavBar extends StatelessWidget {
  const _TclubNavBar({
    required this.currentIndex,
    required this.isAdmin,
    required this.myUid,
    required this.onTap,
  });

  final int    currentIndex;
  final bool   isAdmin;
  final String myUid;
  final ValueChanged<int> onTap;

  static final _adminItems = [
    _NavItem(icon: Icons.home_outlined,                  activeIcon: Icons.home,                  label: 'FEED'),
    _NavItem(icon: Icons.local_fire_department_outlined, activeIcon: Icons.local_fire_department,  label: 'FESTAS'),
    _NavItem(icon: Icons.search,                         activeIcon: Icons.search,                 label: 'SEARCH'),
    _NavItem(icon: Icons.chat_bubble_outline,            activeIcon: Icons.chat_bubble,            label: 'CHAT'),
    _NavItem(icon: Icons.person_outline,                 activeIcon: Icons.person,                 label: 'PERFIL'),
  ];

  static final _userItems = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,               label: 'FEED'),
    _NavItem(icon: Icons.search,              activeIcon: Icons.search,             label: 'SEARCH'),
    _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble,        label: 'CHAT'),
    _NavItem(icon: Icons.person_outline,      activeIcon: Icons.person,             label: 'PERFIL'),
  ];

  int get _chatIndex => isAdmin ? 3 : 2;

  /// Lê o badge combinado: mensagens + solicitações + likes de match.
  /// A Cloud Function grava em UserBadges/$myUid/chatTabBadge sempre que
  /// qualquer um dos três muda.
  Stream<int> _chatBadgeStream() {
    if (myUid.isEmpty) return const Stream.empty();
    // ✅ TROCA CIRÚRGICA: Users → UserBadges
    return FirebaseDatabase.instance
        .ref('UserBadges/$myUid/chatTabBadge')
        .onValue
        .map((e) => (e.snapshot.value as int?) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _adminItems : _userItems;

    return Container(
      decoration: const BoxDecoration(
        color: TClubColors.nav,
        border: Border(top: BorderSide(color: TClubColors.borderMid, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(items.length, (i) {
              if (i == _chatIndex) {
                return Expanded(
                  child: StreamBuilder<int>(
                    stream: _chatBadgeStream(),
                    initialData: 0,
                    builder: (_, snap) => _NavButton(
                      item:     items[i],
                      isActive: i == currentIndex,
                      badge:    snap.data ?? 0,
                      onTap:    () => onTap(i),
                    ),
                  ),
                );
              }
              return Expanded(
                child: _NavButton(
                  item:     items[i],
                  isActive: i == currentIndex,
                  badge:    0,
                  onTap:    () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NAV ITEM MODEL
// ════════════════════════════════════════════════════════════════════════════
class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String   label;
}

// ════════════════════════════════════════════════════════════════════════════
//  NAV BUTTON
// ════════════════════════════════════════════════════════════════════════════
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.onTap,
  });

  final _NavItem     item;
  final bool         isActive;
  final int          badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey(isActive),
                color: isActive ? TClubColors.redPrincipal : TClubColors.subtle,
                size: 26,
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -4, right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color:  TClubColors.redPrincipal,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TClubColors.bg, width: 1.5),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily:  TClubTypography.bodyFont,
                      fontSize:    9,
                      fontWeight:  FontWeight.w700,
                      color:       TClubColors.textoPrincipal,
                      height:      1.4,
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: 2,
            width:  isActive ? 24 : 0,
            decoration: BoxDecoration(
              color: TClubColors.redPrincipal,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

