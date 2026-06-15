// features/profile/presentation/widgets/shared/media_grid_tile.dart

import 'package:flutter/material.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/post/data/models/post_model.dart';
import 'package:tclub/features/gallery/data/models/gallery_item_model.dart';
import 'package:tclub/core/services/media/video_preload_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  POST GRID TILE
// ══════════════════════════════════════════════════════════════════════════════
class PostGridTile extends StatelessWidget {
  const PostGridTile({
    super.key,
    required this.post,
    required this.onTap,
  });

  final PostModel post;
  final VoidCallback onTap;

  static const _gradients = [
    [Color(0xFF3D0018), Color(0xFF6B0030)],
    [Color(0xFF1A0030), Color(0xFF4B005A)],
    [Color(0xFF2D0010), Color(0xFF7A0028)],
    [Color(0xFF0D0020), Color(0xFF3B0050)],
    [Color(0xFF2A0012), Color(0xFFCC0044)],
  ];

  List<Color> _gradient() =>
      _gradients[post.userId.codeUnits.fold(0, (a, b) => a + b) %
          _gradients.length];

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final isPreloaded =
        post.tipo == 'video' && VideoPreloadService.instance.isReady(post.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: TClubColors.bgCard,
        child: Stack(fit: StackFit.expand, children: [
          // ── fundo ─────────────────────────────────────────────────────────
          if (post.tipo == 'foto' && post.mediaUrl != null)
            CachedNetworkImage(imageUrl: CloudinaryHelper.optimizeImageUrl(post.mediaUrl!),
                fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _gradient_bg(),
                errorWidget: (_, __, ___) => _gradient_bg())
          else if (post.tipo == 'video' && post.thumbUrl != null)
            CachedNetworkImage(imageUrl: CloudinaryHelper.videoThumbnail(post.thumbUrl!),
                fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _gradient_bg(),
                errorWidget: (_, __, ___) => _gradient_bg())
          else
            _gradient_bg(),

          // ── video overlay ──────────────────────────────────────────────────
          if (post.tipo == 'video') ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.88,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.30)
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.60),
                  border: Border.all(
                    color: TClubColors.redPrincipal,
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            if (post.videoDuration != null)
              Positioned(
                bottom: 5,
                right: 5,
                child: _durationBadge(_fmt(post.videoDuration!)),
              ),
            
          ],

          // ── emoji / texto ──────────────────────────────────────────────────
          if (post.tipo == 'emoji' && post.emoji != null)
            Center(
                child:
                    Text(post.emoji!, style: const TextStyle(fontSize: 30))),
          if (post.tipo == 'texto')
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  post.titulo,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    height: 1.4,
                  ),
                ),
              ),
            ),

          // ── foto badge ─────────────────────────────────────────────────────
          if (post.tipo == 'foto')
            Positioned(
              top: 5,
              right: 5,
              child: _typeBadge(Icons.photo_outlined),
            ),

          // ── vignette ───────────────────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.88,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.18)
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _gradient_bg() {
    final g = _gradient();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: g,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
    );
  }

  Widget _durationBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.70),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(text,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
      );

  Widget _typeBadge(IconData icon) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.50),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(icon, color: Colors.white, size: 11),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  GALLERY GRID TILE  (somente visualização)
// ══════════════════════════════════════════════════════════════════════════════
class GalleryGridTile extends StatelessWidget {
  const GalleryGridTile({
    super.key,
    required this.item,
    required this.onTap,
    this.isPreloaded = false,
  });

  final GalleryItem item;
  final VoidCallback onTap;
  final bool isPreloaded;

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: TClubColors.bgCard,
        child: Stack(fit: StackFit.expand, children: [
          if (item.type == 'video' && item.thumbUrl != null)
            CachedNetworkImage(imageUrl: CloudinaryHelper.videoThumbnail(item.thumbUrl!),
                fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _fundo(), errorWidget: (_, __, ___) => _fundo())
          else if (item.type == 'foto')
            CachedNetworkImage(imageUrl: CloudinaryHelper.optimizeImageUrl(item.mediaUrl),
                fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _fundo(), errorWidget: (_, __, ___) => _fundo())
          else
            _fundo(),

          if (item.type == 'video') ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.88,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25)
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.60),
                  border: Border.all(
                    color: isPreloaded
                        ? const Color(0xFF22C55E)
                        : TClubColors.redPrincipal,
                    width: 1.2,
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            if (item.videoDuration != null)
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(_fmt(item.videoDuration!),
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
              ),
            
          ] else
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.50),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Icon(Icons.photo_outlined,
                    color: Colors.white, size: 11),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _fundo() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D0010), Color(0xFF7A0028)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

