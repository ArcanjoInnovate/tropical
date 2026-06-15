// features/profile/presentation/widgets/profile/profile_avatar_section.dart
//
// Avatar com anel de story, indicador online e anel VIP.

import 'package:flutter/material.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/core/services/cached_avatar.dart';

class ProfileAvatarSection extends StatelessWidget {
  const ProfileAvatarSection({
    super.key,
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.gradient,
    this.hasStories = false,
    this.hasUnviewedStory = false,
    this.isVip = false,
    this.isOnline = false,
    this.isOwn = false,
    this.onTap,
  });

  final String uid;
  final String name;
  final String? avatarUrl;
  final List<Color> gradient;
  final bool hasStories;
  final bool hasUnviewedStory;
  final bool isVip;
  final bool isOnline;
  final bool isOwn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(alignment: Alignment.center, children: [
        // ── ring externo ───────────────────────────────────────────────────
        if (hasStories)
          _StoryRing(
            hasUnviewed: hasUnviewedStory,
            isVip: isVip,
          )
        else
          _StaticRing(),

        // ── separador branco ───────────────────────────────────────────────
        Container(
          width: hasStories ? 116 : 112,
          height: hasStories ? 116 : 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: TClubColors.bg,
          ),
        ),

        // ── avatar ────────────────────────────────────────────────────────
        CachedAvatar(
          uid: uid,
          name: name,
          size: 102,
          radius: 51,
          isOwn: isOwn,
          gradient: gradient,
        ),

        // ── online dot ────────────────────────────────────────────────────
        if (isOnline)
          Positioned(
            bottom: hasStories ? 8 : 4,
            right: hasStories ? 8 : 4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E),
                border: Border.all(color: TClubColors.bg, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5022C55E),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
          ),

        // ── story indicator dot (quando NÃO está online) ─────────────────
        if (hasStories && !isOnline)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasUnviewedStory
                    ? (isVip
                        ? const Color(0xFFD4AF37)
                        : TClubColors.redPrincipal)
                    : const Color(0xFF3A3A4A),
                border: Border.all(color: TClubColors.bg, width: 2),
                boxShadow: hasUnviewedStory
                    ? [
                        BoxShadow(
                          color: (isVip
                                  ? const Color(0xFFD4AF37)
                                  : TClubColors.glow)
                              .withOpacity(0.5),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                hasUnviewedStory
                    ? Icons.play_arrow_rounded
                    : Icons.check_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),

        // ── vip star (canto superior direito) ────────────────────────────
        if (isVip)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A0A00),
                border:
                    Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFD4AF37), size: 12),
            ),
          ),
      ]),
    );
  }
}

// ── ring com gradiente de story ───────────────────────────────────────────────
class _StoryRing extends StatelessWidget {
  const _StoryRing({required this.hasUnviewed, required this.isVip});
  final bool hasUnviewed;
  final bool isVip;

  @override
  Widget build(BuildContext context) {
    final bool golden = hasUnviewed && isVip;
    final bool pink = hasUnviewed && !isVip;
    final bool seen = !hasUnviewed;

    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: golden
            ? const LinearGradient(
                colors: [
                  Color(0xFF6B4A00),
                  Color(0xFFD4AF37),
                  Color(0xFFFFE066),
                  Color(0xFFD4AF37),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : pink
                ? const LinearGradient(
                    colors: [
                      TClubColors.redDeep,
                      TClubColors.redPrincipal,
                      TClubColors.redClaro,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
        color: seen ? const Color(0xFF3A3A4A) : null,
        boxShadow: hasUnviewed
            ? [
                BoxShadow(
                  color: (isVip
                          ? const Color(0xFFD4AF37)
                          : TClubColors.glow)
                      .withOpacity(0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
    );
  }
}

// ── ring estático quando não há story ────────────────────────────────────────
class _StaticRing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [
          TClubColors.redDeep.withOpacity(0.0),
          TClubColors.redPrincipal.withOpacity(0.50),
          TClubColors.redClaro.withOpacity(0.20),
          TClubColors.redPrincipal.withOpacity(0.50),
          TClubColors.redDeep.withOpacity(0.0),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STORY PILL  — botão "VER STORY / STORY VISTO"
// ══════════════════════════════════════════════════════════════════════════════
class StoryPill extends StatelessWidget {
  const StoryPill({
    super.key,
    required this.hasUnviewed,
    required this.isVip,
    required this.onTap,
  });

  final bool hasUnviewed;
  final bool isVip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hasUnviewed
        ? (isVip ? const Color(0xFFD4AF37) : TClubColors.redPrincipal)
        : const Color(0xFF3A3A4A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: hasUnviewed
              ? (isVip
                  ? const Color(0xFF1A0A00)
                  : TClubColors.redPrincipal.withOpacity(0.12))
              : TClubColors.bgCard,
          border: Border.all(
            color: hasUnviewed ? color.withOpacity(0.6) : color,
            width: 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            hasUnviewed
                ? Icons.auto_awesome_rounded
                : Icons.visibility_outlined,
            size: 9,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            hasUnviewed ? 'VER STORY' : 'STORY VISTO',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: color,
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PROFILE TAB BAR
// ══════════════════════════════════════════════════════════════════════════════
class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.controller,
    required this.postCount,
    required this.galleryCount,
    required this.loadingPosts,
    required this.loadingGallery,
    required this.hasGallery,
  });

  final TabController controller;
  final int postCount;
  final int galleryCount;
  final bool loadingPosts;
  final bool loadingGallery;
  final bool hasGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(color: TClubColors.border, width: 0.8),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: TClubColors.redPrincipal,
        indicatorWeight: 2,
        labelColor: TClubColors.redPrincipal,
        unselectedLabelColor: TClubColors.subtle,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
        tabs: [
          Tab(
            icon: const Icon(Icons.grid_view_rounded, size: 14),
            text: loadingPosts ? 'PUBLICAÇÕES' : 'PUBLICAÇÕES · $postCount',
          ),
          Tab(
            icon: const Icon(Icons.photo_library_outlined, size: 14),
            text: loadingGallery
                ? 'GALERIA'
                : hasGallery
                    ? 'GALERIA · $galleryCount'
                    : 'GALERIA',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GALLERY SECTION DIVIDER  — separador estilo Instagram: linha + ícone central
// ══════════════════════════════════════════════════════════════════════════════
class GalleryOnlyTabBar extends StatelessWidget {
  const GalleryOnlyTabBar({
    super.key,
    required this.controller,
    required this.galleryCount,
    required this.loadingGallery,
    required this.hasGallery,
  });

  final TabController controller;
  final int galleryCount;
  final bool loadingGallery;
  final bool hasGallery;

  @override
  Widget build(BuildContext context) {
    final count = loadingGallery ? null : (hasGallery ? galleryCount : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── linha superior ─────────────────────────────────────────────────
        Container(height: 0.5, color: TClubColors.border),

        // ── ícone + contagem ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.grid_on_rounded,
                color: TClubColors.redPrincipal,
                size: 16,
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: TClubColors.border,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: TClubColors.redPrincipal,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── linha inferior com acento rosa ─────────────────────────────────
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              TClubColors.redDeep,
              TClubColors.redPrincipal,
              TClubColors.redDeep,
              Colors.transparent,
            ]),
          ),
        ),
      ],
    );
  }
}

