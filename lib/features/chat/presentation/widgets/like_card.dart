// lib/features/chat/presentation/widgets/like_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/chat/controller/chat_controller.dart';
import 'package:tclub/features/chat/data/repositories/chat_repository.dart';
import 'package:tclub/features/chat/data/services/chat_service.dart';
import 'package:tclub/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:tclub/features/match/data/services/like_me_service.dart';
import 'package:tclub/features/match/presentation/pages/matched_scree.dart';
import 'package:tclub/core/services/user_data_notifier.dart';

class LikeCard extends StatefulWidget {
  final String likerUid;
  final String myUid;

  const LikeCard({
    super.key,
    required this.likerUid,
    required this.myUid,
  });

  @override
  State<LikeCard> createState() => _LikeCardState();
}

class _LikeCardState extends State<LikeCard> {
  String _name = '';
  String _avatar = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await LikeMeService().fetchUserBasicData(widget.likerUid);
    if (mounted) {
      setState(() {
        _name = data['name'] ?? 'Usuário';
        _avatar = data['avatar'] ?? '';
        _loaded = true;
      });
    }
  }

  Future<void> _onCurtir() async {
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);

    await nav.push(MatchScreen.route(
      myAvatar: UserDataNotifier.instance.avatar ?? '',
      myName: UserDataNotifier.instance.value['name'] as String? ?? '',
      otherAvatar: _avatar,
      otherName: _name,
      onSendMessage: () {
        nav.push(PageRouteBuilder(
          pageBuilder: (_, animation, __) => ChangeNotifierProvider(
            create: (_) => ChatController(
              service: ChatService(repository: ChatRepository()),
            ),
            child: OtherUserChatRoom(
              myUid: widget.myUid,
              otherUid: widget.likerUid,
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
        ));
      },
    ));

    try {
      await LikeMeService().acceptLike(widget.myUid, widget.likerUid);
    } catch (e) {
      debugPrint('[LikeCard] erro ao aceitar like: $e');
    }
  }

  Future<void> _onRecusar() async {
    HapticFeedback.selectionClick();
    await LikeMeService().declineLike(widget.myUid, widget.likerUid);
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: TClubColors.bgAlt,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: TClubTypography.displayFont,
            fontSize: 20,
            color: TClubColors.redPrincipal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LikeCardSkeleton();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(
            color: TClubColors.redPrincipal.withOpacity(0.35),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: TClubColors.glow.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LikeCardTopLine(),
            _LikeCardBody(
              name: _name,
              avatar: _avatar,
              avatarFallback: _avatarFallback,
            ),
            const _CardDivider(),
            _LikeCardActions(
              onCurtir: _onCurtir,
              onRecusar: _onRecusar,
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeCardTopLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          TClubColors.redDeep,
          TClubColors.redPrincipal,
          TClubColors.redClaro,
          TClubColors.redPrincipal,
          TClubColors.redDeep,
        ]),
      ),
    );
  }
}

class _LikeCardBody extends StatelessWidget {
  final String name;
  final String avatar;
  final Widget Function(String) avatarFallback;

  const _LikeCardBody({
    required this.name,
    required this.avatar,
    required this.avatarFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
              color: TClubColors.redPrincipal.withOpacity(0.4),
              width: 1.2,
            ),
          ),
          child: avatar.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: CloudinaryHelper.avatarUrl(avatar),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => avatarFallback(name),
                  errorWidget: (_, __, ___) => avatarFallback(name),
                )
              : avatarFallback(name),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: TClubColors.textoPrincipal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 10,
                  color: TClubColors.redPrincipal,
                ),
                const SizedBox(width: 5),
                const Text(
                  'curtiu você',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 11,
                    letterSpacing: 0.2,
                    color: TClubColors.subtle,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LikeCardActions extends StatelessWidget {
  final VoidCallback onCurtir;
  final VoidCallback onRecusar;

  const _LikeCardActions({
    required this.onCurtir,
    required this.onRecusar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: onRecusar,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: TClubColors.bgCard,
                border: Border.all(
                  color: TClubColors.border.withOpacity(0.6),
                  width: 0.7,
                ),
              ),
              child: const Center(
                child: Text(
                  'RECUSAR',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: TClubColors.subtle,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onCurtir,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [TClubColors.redDeep, TClubColors.redPrincipal],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.3),
                  width: 0.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TClubColors.glow.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  'CURTIR',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: TClubColors.textoPrincipal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LikeCardSkeleton extends StatelessWidget {
  const _LikeCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(
            color: TClubColors.border.withOpacity(0.6),
            width: 0.6,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: TClubColors.redPrincipal,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.transparent,
          TClubColors.border,
          Colors.transparent,
        ]),
      ),
    );
  }
}

