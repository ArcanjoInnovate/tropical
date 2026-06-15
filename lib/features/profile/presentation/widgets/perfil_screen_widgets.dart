// lib/screens/screens_home/perfil_screen/perfil/perfil_screen_widgets.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/settings/presentation/pages/delete_screen.dart';
import 'package:tclub/features/settings/presentation/pages/settings_screen.dart';
import 'package:tclub/core/services/cached_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  PERFIL BACKGROUND
// ══════════════════════════════════════════════════════════════════════════════
class PerfilBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A0014),
          Color(0xFF1A0020),
          Color(0xFF0A0014),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.5),
        radius: 1.5,
        colors: [
          TClubColors.glow.withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVATAR
// ══════════════════════════════════════════════════════════════════════════════
class Avatar extends StatelessWidget {
  final String avatarUrl;
  final bool showCamera;

  const Avatar({
    super.key,
    required this.avatarUrl,
    this.showCamera = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TClubColors.bgCard,
            border: Border.all(color: TClubColors.border, width: 0.8),
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: CloudinaryHelper.avatarUrl(avatarUrl),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => const Icon(
                      Icons.person_outline,
                      color: TClubColors.subtle,
                      size: 36,
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.person_outline,
                      color: TClubColors.subtle,
                      size: 36,
                    ),
                  )
                : const Icon(
                    Icons.person_outline,
                    color: TClubColors.subtle,
                    size: 36,
                  ),
          ),
        ),
        if (showCamera)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TClubColors.redPrincipal,
                border: Border.all(color: TClubColors.bg, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════════════════════════════════════
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFFD4AF37).withOpacity(0.05)
                : TClubColors.bgCard,
            border: Border.all(
              color: highlight
                  ? const Color(0xFFD4AF37).withOpacity(0.3)
                  : TClubColors.border,
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: highlight
                    ? const Color(0xFFD4AF37)
                    : TClubColors.redPrincipal,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontFamily: TClubTypography.displayFont,
                  fontSize: 16,
                  letterSpacing: 2,
                  color:
                      highlight ? const Color(0xFFD4AF37) : TClubColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: highlight
                      ? const Color(0xFFD4AF37).withOpacity(0.7)
                      : TClubColors.dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VIP FRIENDS BADGE
// ══════════════════════════════════════════════════════════════════════════════
class VipFriendsBadge extends StatelessWidget {
  final int count;

  const VipFriendsBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFD4AF37),
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            '$count AMIGO${count == 1 ? '' : 'S'} VIP',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Color(0xFFD4AF37),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  GALERIA SKELETON
// ══════════════════════════════════════════════════════════════════════════════
class GaleriaSkeleton extends StatelessWidget {
  const GaleriaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
          childAspectRatio: 1.0,
          mainAxisExtent: 120.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.all(0.75),
            child: Container(
              decoration: BoxDecoration(
                color: TClubColors.bgCard,
                border: Border.all(color: TClubColors.border, width: 0.8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: TClubColors.redPrincipal,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
          childCount: 9,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class PostDetailSheet extends StatelessWidget {
  final dynamic post;
  final String myUid;

  const PostDetailSheet({
    super.key,
    required this.post,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TClubColors.bgAlt,
        border: Border.all(color: TClubColors.border, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TClubColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.titulo?.toUpperCase() ?? 'POST',
                    style: const TextStyle(
                      fontFamily: TClubTypography.displayFont,
                      fontSize: 14,
                      letterSpacing: 4,
                      color: TClubColors.textoPrincipal,
                    ),
                  ),
                  if (post.descricao?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      post.descricao!,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 12,
                        color: TClubColors.subtle,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFIG MENU
// ══════════════════════════════════════════════════════════════════════════════
class ConfigMenu extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onSignOut;
  final String name;
  final VoidCallback onAbrirAdmin;

  const ConfigMenu({
    super.key,
    required this.isAdmin,
    required this.onSignOut,
    required this.onAbrirAdmin,
    required this.name,
  });

  void deleteAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImprovedDeleteAccountSheet(userName: name),
      ),
    );
  }

  void openSettings(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    Navigator.push(context,
        MaterialPageRoute(builder: (context) => SettingsScreen(name: name, myUserId: uid,)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TClubColors.bgAlt,
        border: Border.all(color: TClubColors.border, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TClubColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isAdmin)
              PDSMenuTile(
                icon: Icons.shield_rounded,
                label: 'PAINEL ADMINISTRATIVO',
                sublabel: 'Acessar ferramentas admin',
                onTap: () {
                  Navigator.pop(context);
                  onAbrirAdmin();
                },
              ),
            PDSMenuTile(
              icon: Icons.logout_rounded,
              label: 'SAIR DO APP',
              sublabel: 'Encerrar sessão',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                onSignOut();
              },
            ),
            
            PDSMenuTile(
              icon: Icons.settings,
              label: 'CONFIGURAÇÕES',
              sublabel: 'Abrir configurações',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                openSettings(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PDS MENU TILE
// ══════════════════════════════════════════════════════════════════════════════
class PDSMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool danger;
  final VoidCallback onTap;

  const PDSMenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFFE85D5D).withOpacity(0.05)
              : TClubColors.bgCard,
          border: Border.all(
            color: danger
                ? const Color(0xFFE85D5D).withOpacity(0.3)
                : TClubColors.border,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  danger ? const Color(0xFFE85D5D) : TClubColors.redPrincipal,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color:
                          danger ? const Color(0xFFE85D5D) : TClubColors.textoPrincipal,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 10,
                        color: TClubColors.subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: danger ? const Color(0xFFE85D5D) : TClubColors.dim,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SIGN OUT SHEET
// ══════════════════════════════════════════════════════════════════════════════
class SignOutSheet extends StatelessWidget {
  const SignOutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TClubColors.bgAlt,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: TClubColors.border, width: 0.8),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: TClubColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.logout_rounded,
                color: Color(0xFFE85D5D), size: 28),
            const SizedBox(height: 16),
            const Text(
              'SAIR DO APP?',
              style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize: 14,
                letterSpacing: 4,
                color: TClubColors.textoPrincipal,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tem certeza que deseja sair?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 12,
                  color: TClubColors.subtle,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: TClubColors.bgCard,
                          border: Border.all(
                              color: TClubColors.borderMid, width: 0.8),
                        ),
                        child: const Center(
                          child: Text(
                            'CANCELAR',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
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
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        height: 46,
                        decoration:
                            const BoxDecoration(color: Color(0xFFE85D5D)),
                        child: const Center(
                          child: Text(
                            'SAIR',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  METRIC SHEET (Seguidores / VIP)
// ══════════════════════════════════════════════════════════════════════════════
class MetricSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget content;

  const MetricSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TClubColors.bgAlt,
        border: Border.all(color: TClubColors.border, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: TClubColors.border, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    border: Border.all(
                        color: accentColor.withOpacity(0.3), width: 0.8),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: TClubTypography.displayFont,
                      fontSize: 14,
                      letterSpacing: 4,
                      color: TClubColors.textoPrincipal,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TClubColors.bgCard,
                      border: Border.all(color: TClubColors.border, width: 0.8),
                    ),
                    child: const Icon(Icons.close,
                        color: TClubColors.subtle, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  USER TILE — mostra card de "conta deletada" quando usuário não existe mais
// ══════════════════════════════════════════════════════════════════════════════
class UserTile extends StatefulWidget {
  final String uid;
  final bool isVip;
  final void Function(String uid, String name) onTap;

  const UserTile({
    super.key,
    required this.uid,
    required this.onTap,
    this.isVip = false,
  });

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _deleted = false; // true quando o nó Users/{uid} não existe

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('UsersPublic/${widget.uid}').get();

      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          _loading = false;
          _deleted = false;
        });
      } else {
        // Nó não existe — usuário deletou a conta
        setState(() {
          _loading = false;
          _deleted = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar usuário ${widget.uid}: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _deleted = true;
        });
      }
    }
  }

  // ── Loading skeleton ───────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(color: TClubColors.border, width: 0.8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: TClubColors.bgCard,
                    border: Border.all(color: TClubColors.border, width: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 80,
                  decoration: BoxDecoration(
                    color: TClubColors.bgCard,
                    border: Border.all(color: TClubColors.border, width: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card para conta deletada ───────────────────────────────────────────────
  Widget _buildDeletedCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          // Avatar genérico com ícone de conta deletada
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(
                color: TClubColors.border.withOpacity(0.5),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.person_off_outlined,
              color: TClubColors.dim,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTA DELETADA',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: TClubColors.dim,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Este usuário removeu a conta',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 10,
                    color: TClubColors.dim.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Sem arrow — conta não é clicável
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(color: TClubColors.border, width: 0.5),
            ),
            child: const Icon(
              Icons.block_rounded,
              color: TClubColors.dim,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card normal ────────────────────────────────────────────────────────────
  Widget _buildNormalCard() {
    final name = (_userData!['name'] as String? ?? 'Usuário').toUpperCase();
    final bio = (_userData!['bio'] as String? ?? '').trim();

    return GestureDetector(
      onTap: () {
        debugPrint('👆 Tap em usuário: ${widget.uid}');
        widget.onTap(widget.uid, name);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            CachedAvatar(
              uid: widget.uid,
              name: name,
              size: 48,
              radius: 0,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: TClubColors.textoPrincipal,
                          ),
                        ),
                      ),
                      if (widget.isVip) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 11,
                        color: TClubColors.subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: TClubColors.dim,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();
    if (_deleted) return _buildDeletedCard();
    return _buildNormalCard();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAGINATED USER LIST
// ══════════════════════════════════════════════════════════════════════════════
class PaginatedUserList extends StatefulWidget {
  final List<String> uids;
  final String emptyLabel;
  final void Function(String uid, String name) onTap;
  final bool isVip;

  const PaginatedUserList({
    super.key,
    required this.uids,
    required this.emptyLabel,
    required this.onTap,
    this.isVip = false,
  });

  @override
  State<PaginatedUserList> createState() => _PaginatedUserListState();
}

class _PaginatedUserListState extends State<PaginatedUserList> {
  static const int _pageSize = 10;
  int _visibleCount = _pageSize;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    debugPrint('📋 PaginatedUserList iniciada com ${widget.uids.length} UIDs');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (cur >= max - 100 && _visibleCount < widget.uids.length) {
      setState(() {
        final newCount =
            (_visibleCount + _pageSize).clamp(0, widget.uids.length);
        debugPrint(
            '📊 Carregando mais: $_visibleCount -> $newCount de ${widget.uids.length}');
        _visibleCount = newCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            widget.emptyLabel.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              color: TClubColors.subtle,
            ),
          ),
        ),
      );
    }

    final slice = widget.uids.take(_visibleCount).toList();
    final hasMore = _visibleCount < widget.uids.length;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: slice.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          Container(height: 0.5, color: TClubColors.border),
      itemBuilder: (context, i) {
        if (i == slice.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: TClubColors.redPrincipal,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          );
        }

        return UserTile(
          uid: slice[i],
          isVip: widget.isVip,
          onTap: (uid, name) {
            debugPrint('👆 Tap em usuário: $uid ($name)');
            widget.onTap(uid, name);
          },
        );
      },
    );
  }
}

