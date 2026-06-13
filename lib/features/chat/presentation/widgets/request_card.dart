// lib/features/chat/presentation/widgets/request_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:tabuapp/core/helpers/cloudinary_helper.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/chat/controller/chat_controller.dart';
import 'package:tabuapp/features/chat/data/models/chat_request_model.dart';
import 'package:tabuapp/features/chat/data/repositories/chat_repository.dart';
import 'package:tabuapp/features/chat/data/services/chat_service.dart';
import 'package:tabuapp/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:tabuapp/core/services/chat_request_service.dart';

class RequestCard extends StatefulWidget {
  final ChatRequest request;
  final String myUid;

  const RequestCard({
    super.key,
    required this.request,
    required this.myUid,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _loadingAccept = false;
  bool _loadingDecline = false;
  bool _done = false;

  Future<void> _accept() async {
    setState(() => _loadingAccept = true);
    HapticFeedback.mediumImpact();

    await ChatRequestService().acceptRequest(widget.request.id, widget.myUid);
    if (!mounted) return;

    setState(() {
      _loadingAccept = false;
      _done = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ChangeNotifierProvider(
          create: (_) => ChatController(
            service: ChatService(repository: ChatRepository()),
          ),
          child: OtherUserChatRoom(
            myUid: widget.myUid,
            otherUid: widget.request.fromUid,
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

  Future<void> _decline() async {
    setState(() => _loadingDecline = true);
    HapticFeedback.selectionClick();

    await ChatRequestService().declineRequest(widget.request.id, widget.myUid);
    if (mounted) {
      setState(() {
        _loadingDecline = false;
        _done = true;
      });
    }
  }

  String _formatTime(int ts) {
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    final minutes = diff ~/ 60000;
    if (minutes < 1) return 'agora';
    if (minutes < 60) return 'há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'há ${hours}h';
    return 'há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    final req = widget.request;
    final isNew = !req.seen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
            color: isNew
                ? TabuColors.rosaPrincipal.withOpacity(0.35)
                : TabuColors.border.withOpacity(0.6),
            width: isNew ? 0.9 : 0.6,
          ),
          boxShadow: isNew
              ? [
                  BoxShadow(
                    color: TabuColors.glow.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNew) const _GradientTopLine(),
            _RequestCardBody(
              req: req,
              isNew: isNew,
              formatTime: _formatTime,
            ),
            const _CardDivider(),
            _RequestCardActions(
              loadingAccept: _loadingAccept,
              loadingDecline: _loadingDecline,
              onAccept: _accept,
              onDecline: _decline,
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientTopLine extends StatelessWidget {
  const _GradientTopLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          TabuColors.rosaDeep,
          TabuColors.rosaPrincipal,
          TabuColors.rosaClaro,
          TabuColors.rosaPrincipal,
          TabuColors.rosaDeep,
        ]),
      ),
    );
  }
}

class _RequestCardBody extends StatelessWidget {
  final ChatRequest req;
  final bool isNew;
  final String Function(int) formatTime;

  const _RequestCardBody({
    required this.req,
    required this.isNew,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        _RequestAvatar(
          fromAvatar: req.fromAvatar,
          fromName: req.fromName,
          isNew: isNew,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    req.fromName.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: isNew
                          ? TabuColors.textoPrincipal
                          : TabuColors.dim,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isNew) ...[
                  const SizedBox(width: 8),
                  _NewBadge(),
                ],
              ]),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(
                  Icons.mark_chat_unread_outlined,
                  size: 10,
                  color: TabuColors.subtle,
                ),
                const SizedBox(width: 5),
                const Text(
                  'quer conversar com você',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11,
                    letterSpacing: 0.2,
                    color: TabuColors.subtle,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                formatTime(req.createdAt),
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  color: TabuColors.border,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  final String fromAvatar;
  final String fromName;
  final bool isNew;

  const _RequestAvatar({
    required this.fromAvatar,
    required this.fromName,
    required this.isNew,
  });

  Widget _fallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: TabuColors.bgAlt,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 20,
            color: TabuColors.rosaPrincipal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(
            color: isNew
                ? TabuColors.rosaPrincipal.withOpacity(0.4)
                : TabuColors.border,
            width: isNew ? 1.2 : 0.6,
          ),
        ),
        child: fromAvatar.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: CloudinaryHelper.avatarUrl(fromAvatar),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _fallback(fromName),
                errorWidget: (_, __, ___) => _fallback(fromName),
              )
            : _fallback(fromName),
      ),
      if (isNew)
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: TabuColors.rosaPrincipal,
              shape: BoxShape.circle,
              border: Border.all(color: TabuColors.bgCard, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: TabuColors.glow.withOpacity(0.5),
                  blurRadius: 6,
                )
              ],
            ),
          ),
        ),
    ]);
  }
}

class _NewBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: TabuColors.rosaPrincipal.withOpacity(0.12),
        border: Border.all(
          color: TabuColors.rosaPrincipal.withOpacity(0.4),
          width: 0.7,
        ),
      ),
      child: const Text(
        'NOVA',
        style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: TabuColors.rosaPrincipal,
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
          TabuColors.border,
          Colors.transparent,
        ]),
      ),
    );
  }
}

class _RequestCardActions extends StatelessWidget {
  final bool loadingAccept;
  final bool loadingDecline;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCardActions({
    required this.loadingAccept,
    required this.loadingDecline,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final busy = loadingAccept || loadingDecline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(children: [
        Expanded(
          child: _ActionButton(
            label: 'RECUSAR',
            loading: loadingDecline,
            onTap: busy ? null : onDecline,
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'ACEITAR',
            loading: loadingAccept,
            onTap: busy ? null : onAccept,
            isPrimary: true,
          ),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : TabuColors.bgCard,
          border: Border.all(
            color: isPrimary
                ? TabuColors.rosaPrincipal.withOpacity(0.3)
                : TabuColors.border.withOpacity(0.6),
            width: 0.7,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: TabuColors.glow.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: isPrimary ? Colors.white : TabuColors.subtle,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: isPrimary
                        ? TabuColors.textoPrincipal
                        : TabuColors.subtle,
                  ),
                ),
        ),
      ),
    );
  }
}