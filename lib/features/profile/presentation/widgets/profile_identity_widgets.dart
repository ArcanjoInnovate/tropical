// features/profile/presentation/widgets/shared/profile_identity_widgets.dart
//
// Widgets reutilizados nas telas pública e própria.

import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/profile/data/models/profile_user_model.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ONLINE DOT
// ══════════════════════════════════════════════════════════════════════════════
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, this.size = 10});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF22C55E),
        border: Border.all(color: TabuColors.bg, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x5522C55E), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  IDENTITY CHIP  (gênero · orientação · relacionamento)
// ══════════════════════════════════════════════════════════════════════════════
class IdentityChip extends StatelessWidget {
  const IdentityChip({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? TabuColors.rosaPrincipal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withOpacity(0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  IDENTITY ROW  — gênero · orientação · relacionamento
// ══════════════════════════════════════════════════════════════════════════════
class ProfileIdentityRow extends StatelessWidget {
  const ProfileIdentityRow({super.key, required this.user});
  final ProfileUserModel user;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (user.age != null) {
      chips.add(IdentityChip(
        label: '${user.age} anos',
        icon: Icons.cake_outlined,
        color: _relationColor(user.relationshipType),
      ));
    }

    if (user.genderLabel.isNotEmpty) {
      chips.add(IdentityChip(
        label: user.genderLabel,
        icon: Icons.person_outline_rounded,
        color: _genderColor(user.genderIdentity),
      ));
    }

    if (user.orientationLabel.isNotEmpty) {
      chips.add(IdentityChip(
        label: user.orientationLabel,
        icon: Icons.favorite_border_rounded,
        color: const Color(0xFFEC4899),
      ));
    }

    if (user.relationshipLabel.isNotEmpty) {
      chips.add(IdentityChip(
        label: user.relationshipLabel,
        icon: _relationIcon(user.relationshipType),
        color: _relationColor(user.relationshipType),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Color _genderColor(String? g) => switch (g) {
        'homem' || 'homemTrans' || 'trans_masculino' => const Color(0xFF3B82F6),
        'mulher' || 'mulherTrans' || 'trans_feminino' => const Color(0xFFEC4899),
        _ => const Color(0xFF8B5CF6),
      };

  IconData _relationIcon(String? r) => switch (r) {
        'casado' => Icons.ring_volume_rounded,
        'namorando' => Icons.favorite_rounded,
        'casalLiberal' ||
        'relacionamento_aberto' ||
        'swing' ||
        'poliamoroso' =>
          Icons.people_rounded,
        _ => Icons.person_outline_rounded,
      };

  Color _relationColor(String? r) => switch (r) {
        'casado' => const Color(0xFFD4AF37),
        'namorando' => const Color(0xFFEC4899),
        'solteiro' => const Color(0xFF22C55E),
        'casalLiberal' ||
        'relacionamento_aberto' ||
        'swing' ||
        'poliamoroso' =>
          const Color(0xFF8B5CF6),
        _ => TabuColors.rosaPrincipal,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
//  INTERESTS SECTION  — grid de chips de interesse
// ══════════════════════════════════════════════════════════════════════════════
class ProfileInterestsSection extends StatefulWidget {
  const ProfileInterestsSection({
    super.key,
    required this.interests,
    this.maxVisible = 12,
  });

  final List<String> interests;
  final int maxVisible;

  @override
  State<ProfileInterestsSection> createState() =>
      _ProfileInterestsSectionState();
}

class _ProfileInterestsSectionState extends State<ProfileInterestsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.interests.isEmpty) return const SizedBox.shrink();

    final visible = _expanded
        ? widget.interests
        : widget.interests.take(widget.maxVisible).toList();
    final hasMore = widget.interests.length > widget.maxVisible;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [TabuColors.rosaDeep, TabuColors.rosaClaro],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'INTERESSES',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: TabuColors.subtle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.10),
                    border: Border.all(
                        color: TabuColors.rosaPrincipal.withOpacity(0.25),
                        width: 0.6),
                  ),
                  child: Text(
                    '${widget.interests.length}',
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: TabuColors.rosaPrincipal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...visible.map((item) => _InterestTag(label: item)),
              if (hasMore)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: TabuColors.bgCard,
                      border:
                          Border.all(color: TabuColors.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 11,
                          color: TabuColors.dim,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _expanded
                              ? 'VER MENOS'
                              : '+${widget.interests.length - widget.maxVisible}',
                          style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: TabuColors.dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterestTag extends StatelessWidget {
  const _InterestTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(
            color: TabuColors.border.withOpacity(0.8), width: 0.7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: TabuColors.dim,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CASAL CARD  (expandido com avatar, idade, gênero e orientação)
// ══════════════════════════════════════════════════════════════════════════════
class CouplePartnerCard extends StatelessWidget {
  const CouplePartnerCard({super.key, required this.partner});
  final PartnerModel partner;

  @override
  Widget build(BuildContext context) {
    // debug
    debugPrint('[CouplePartnerCard] partner.name=${partner.name} '
        'avatar=${partner.avatarUrl} '
        'birth=${partner.birthDate} '
        'gender=${partner.genderIdentity} '
        'orient=${partner.sexualOrientation}');

    final bool isLiberal = false; // reservado para futura flag no model
    final accentColor =
        isLiberal ? const Color(0xFF8B5CF6) : const Color(0xFFD4AF37);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        border:
            Border.all(color: accentColor.withOpacity(0.30), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── avatar do parceiro ──────────────────────────────────────────
          _PartnerAvatar(avatarUrl: partner.avatarUrl, accent: accentColor),
          const SizedBox(width: 14),

          // ── dados do parceiro ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // label
                Text(
                  'EM CASAL COM',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: accentColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 3),

                // nome
                Row(
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: accentColor, size: 11),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        partner.name?.toUpperCase() ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // chips de identidade do parceiro
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (partner.age != null)
                      _MiniChip(
                        label: '${partner.age} anos',
                        icon: Icons.cake_outlined,
                        color: accentColor,
                      ),
                    if ((partner.genderLabel).isNotEmpty)
                      _MiniChip(
                        label: partner.genderLabel,
                        icon: Icons.person_outline_rounded,
                        color: _genderColor(partner.genderIdentity),
                      ),
                    if ((partner.orientationLabel).isNotEmpty)
                      _MiniChip(
                        label: partner.orientationLabel,
                        icon: Icons.favorite_border_rounded,
                        color: const Color(0xFFEC4899),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _genderColor(String? g) => switch (g) {
        'homem' || 'homemTrans' || 'trans_masculino' =>
          const Color(0xFF3B82F6),
        'mulher' || 'mulherTrans' || 'trans_feminino' =>
          const Color(0xFFEC4899),
        _ => const Color(0xFF8B5CF6),
      };
}

// ── avatar circular do parceiro ──────────────────────────────────────────────
class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.avatarUrl, required this.accent});
  final String? avatarUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
        color: TabuColors.bgCard,
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(accent),
              )
            : _placeholder(accent),
      ),
    );
  }

  Widget _placeholder(Color color) => Center(
        child: Icon(Icons.person_rounded, color: color.withOpacity(0.4), size: 26),
      );
}

// ── mini chip para dados do parceiro ─────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT CELL
// ══════════════════════════════════════════════════════════════════════════════
class ProfileStatCell extends StatelessWidget {
  const ProfileStatCell({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.accent = false,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = accent ? TabuColors.rosaPrincipal : TabuColors.textoPrincipal;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Icon(icon,
                size: 13,
                color: accent ? TabuColors.rosaPrincipal : TabuColors.subtle),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 22,
                letterSpacing: 0.5,
                color: color,
                shadows: accent
                    ? [Shadow(color: TabuColors.glow, blurRadius: 12)]
                    : null,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: accent
                    ? TabuColors.rosaPrincipal.withOpacity(0.7)
                    : TabuColors.subtle,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VERTICAL DIVIDER
// ══════════════════════════════════════════════════════════════════════════════
class ProfileVertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, color: TabuColors.border);
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIP BADGE
// ══════════════════════════════════════════════════════════════════════════════
class VipBadge extends StatelessWidget {
  const VipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A00),
        border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.15),
              blurRadius: 10)
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 10),
          SizedBox(width: 6),
          Text(
            'AMIGO VIP',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: Color(0xFFD4AF37),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  METRICS SKELETON
// ══════════════════════════════════════════════════════════════════════════════
class MetricsBarSkeleton extends StatelessWidget {
  const MetricsBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        border: Border.all(
            color: TabuColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Row(
        children: List.generate(7, (i) {
          if (i.isOdd) return Container(width: 0.5, color: TabuColors.border);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _skeleton(20, 8),
                const SizedBox(height: 5),
                _skeleton(28, 16),
                const SizedBox(height: 4),
                _skeleton(22, 6),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _skeleton(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: TabuColors.border.withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  GRID SKELETON
// ══════════════════════════════════════════════════════════════════════════════
class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, this.padding});
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 14, 20, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Container(
            color: TabuColors.bgCard,
            child: Opacity(
              opacity: 1.0 - (i * 0.07).clamp(0.0, 0.55),
              child: Container(color: TabuColors.border.withOpacity(0.12)),
            ),
          ),
          childCount: 9,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LOAD MORE INDICATOR
// ══════════════════════════════════════════════════════════════════════════════
class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: TabuColors.rosaPrincipal,
              strokeWidth: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════
class EmptyGridState extends StatelessWidget {
  const EmptyGridState({
    super.key,
    required this.label,
    this.sublabel,
  });

  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: TabuColors.border, width: 0.8),
                color: TabuColors.bgCard,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: TabuColors.border, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: TabuColors.subtle,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 6),
              Text(
                sublabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11,
                  color: TabuColors.subtle,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}