// features/profile/presentation/pages/profile/_public_profile_actions.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/chat/data/models/chat_request_model.dart';

class PublicProfileActions extends StatelessWidget {
  const PublicProfileActions({
    super.key,
    required this.following,
    required this.loadingFollow,
    required this.vip,
    required this.loadingVip,
    required this.chatRequest,
    required this.loadingChat,
    required this.isPending,
    required this.isAccepted,
    required this.iSent,
    required this.iReceived,
    required this.onFollow,
    required this.onVip,
    required this.onChat,
  });

  final bool following;
  final bool loadingFollow;
  final bool vip;
  final bool loadingVip;
  final ChatRequest? chatRequest;
  final bool loadingChat;
  final bool isPending;
  final bool isAccepted;
  final bool iSent;
  final bool iReceived;
  final VoidCallback onFollow;
  final VoidCallback onVip;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── SEGUIR + MENSAGEM ────────────────────────────────────────────────
      Row(children: [
        Expanded(child: _FollowButton(following: following, loading: loadingFollow, onTap: onFollow)),
        const SizedBox(width: 10),
        Expanded(child: _ChatButton(
          isAccepted: isAccepted,
          isPending: isPending,
          iSent: iSent,
          iReceived: iReceived,
          loading: loadingChat,
          onTap: onChat,
        )),
      ]),

      // ── hint text ────────────────────────────────────────────────────────
      if (chatRequest != null) ...[
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              isPending && iSent
                  ? 'aguardando resposta...'
                  : isPending && iReceived
                      ? 'quer conversar com você'
                      : isAccepted
                          ? 'conversa ativa'
                          : '',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 9,
                letterSpacing: 0.5,
                color: isAccepted
                    ? TClubColors.redPrincipal.withOpacity(0.70)
                    : TClubColors.subtle,
              ),
            ),
          ),
        ),
      ],

      const SizedBox(height: 10),

      // ── VIP ──────────────────────────────────────────────────────────────
      _VipButton(
        vip: vip,
        loading: loadingVip,
        canAdd: following || vip,
        onTap: onVip,
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.loading,
    required this.onTap,
  });

  final bool following;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 50,
        decoration: BoxDecoration(
          gradient: following
              ? null
              : const LinearGradient(
                  colors: [TClubColors.redDeep, TClubColors.redPrincipal],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: following ? TClubColors.bgCard : null,
          border: Border.all(
            color: following
                ? TClubColors.border
                : TClubColors.redPrincipal.withOpacity(0.30),
            width: 0.8,
          ),
          boxShadow: following
              ? null
              : [
                  BoxShadow(
                    color: TClubColors.glow.withOpacity(0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color:
                        following ? TClubColors.subtle : Colors.white,
                    strokeWidth: 1.5,
                  ),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    following ? Icons.check_rounded : Icons.add_rounded,
                    size: 13,
                    color:
                        following ? TClubColors.subtle : TClubColors.textoPrincipal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    following ? 'SEGUINDO' : 'SEGUIR',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color:
                          following ? TClubColors.dim : TClubColors.branco,
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

class _ChatButton extends StatelessWidget {
  const _ChatButton({
    required this.isAccepted,
    required this.isPending,
    required this.iSent,
    required this.iReceived,
    required this.loading,
    required this.onTap,
  });

  final bool isAccepted;
  final bool isPending;
  final bool iSent;
  final bool iReceived;
  final bool loading;
  final VoidCallback onTap;

  Color get _color {
    if (isAccepted) return TClubColors.redPrincipal;
    if (isPending && iReceived) return const Color(0xFF22C55E);
    if (isPending && iSent) return TClubColors.subtle;
    return TClubColors.redPrincipal;
  }

  IconData get _icon {
    if (isAccepted) return Icons.chat_bubble_rounded;
    if (isPending && iSent) return Icons.schedule_rounded;
    if (isPending && iReceived) return Icons.mark_chat_unread_rounded;
    return Icons.send_rounded;
  }

  String get _label {
    if (isAccepted) return 'MENSAGEM';
    if (isPending && iSent) return 'SOLICITADO';
    if (isPending && iReceived) return 'ACEITAR';
    return 'MENSAGEM';
  }

  bool get _active => !(isPending && iSent);

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 50,
        decoration: BoxDecoration(
          color: _active ? c.withOpacity(0.10) : TClubColors.bgCard,
          border: Border.all(
            color: _active ? c.withOpacity(0.45) : TClubColors.border,
            width: _active ? 1.0 : 0.8,
          ),
          boxShadow: _active
              ? [
                  BoxShadow(
                    color: c.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
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
                      color: c, strokeWidth: 1.5),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_icon, color: c, size: 13),
                  const SizedBox(width: 8),
                  Text(
                    _label,
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: c,
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

class _VipButton extends StatelessWidget {
  const _VipButton({
    required this.vip,
    required this.loading,
    required this.canAdd,
    required this.onTap,
  });

  final bool vip;
  final bool loading;
  final bool canAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 46,
        decoration: BoxDecoration(
          color: vip ? const Color(0xFF1A0A00) : TClubColors.bgCard,
          border: Border.all(
            color: vip
                ? gold.withOpacity(0.60)
                : canAdd
                    ? TClubColors.border
                    : TClubColors.border.withOpacity(0.40),
            width: vip ? 1.0 : 0.8,
          ),
          boxShadow: vip
              ? [
                  BoxShadow(
                    color: gold.withOpacity(0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: gold, strokeWidth: 1.5),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    vip ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 14,
                    color: vip
                        ? gold
                        : canAdd
                            ? TClubColors.subtle
                            : TClubColors.border,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vip ? 'AMIGO VIP' : 'ADICIONAR COMO VIP',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: vip
                          ? gold
                          : canAdd
                              ? TClubColors.subtle
                              : TClubColors.border,
                    ),
                  ),
                  if (!canAdd) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: TClubColors.border.withOpacity(0.40),
                          width: 0.6,
                        ),
                      ),
                      child: const Text(
                        'SIGA PRIMEIRO',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 7,
                          letterSpacing: 1.5,
                          color: TClubColors.border,
                        ),
                      ),
                    ),
                  ],
                ]),
        ),
      ),
    );
  }
}

