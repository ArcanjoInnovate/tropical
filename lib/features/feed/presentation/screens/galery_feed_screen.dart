// features/profile/presentation/pages/profile/gallery_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/services/media/video_preload_service.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/core/widgets/full_screen_image.dart';
import 'package:tclub/core/widgets/full_screen_video.dart';
import 'package:tclub/core/widgets/inline_video_card.dart';
import 'package:tclub/features/gallery/data/models/gallery_item_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GalleryFeedScreen extends StatefulWidget {
  const GalleryFeedScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.userName,
  });

  final List<GalleryItem> items;
  final int initialIndex;
  final String userName;

  static Route<void> route({
    required List<GalleryItem> items,
    required int initialIndex,
    required String userName,
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => GalleryFeedScreen(
          items: items,
          initialIndex: initialIndex,
          userName: userName,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      );

  @override
  State<GalleryFeedScreen> createState() => _GalleryFeedScreenState();
}

class _GalleryFeedScreenState extends State<GalleryFeedScreen> {
  late final PageController _pageCtrl;
  final _scrollController = ScrollController();
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _preloadAdjacent(widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _current = index);
    _preloadAdjacent(index);
  }

  void _preloadAdjacent(int index) {
    for (final offset in [-1, 0, 1]) {
      final i = index + offset;
      if (i < 0 || i >= widget.items.length) continue;
      final item = widget.items[i];
      if (item.type == 'video') {
        VideoPreloadService.instance.preload(item.id, item.mediaUrl);
      }
    }
  }

  void _openFullscreenImage(GalleryItem item) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      FullscreenImageScreen.route(
        imageUrl: item.mediaUrl,
        userName: widget.userName,
        titulo: 'Galeria',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final currentItem = widget.items[_current];
    final isCurrentVideo = currentItem.type == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: TClubColors.branco, size: 18),
          ),
        ),
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            widget.userName.toUpperCase(),
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: TClubColors.branco,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'GALERIA · ${_current + 1} / $total',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 9,
              letterSpacing: 2,
              color: TClubColors.branco,
            ),
          ),
        ]),
        centerTitle: true,
        actions: [
          // Mute — só aparece em vídeos
          if (isCurrentVideo)
            ValueListenableBuilder<bool>(
              valueListenable: VideoMuteState.notifier,
              builder: (_, isMuted, __) => GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  VideoMuteState.toggle();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color:
                        isMuted ? TClubColors.subtle : TClubColors.redPrincipal,
                    size: 18,
                  ),
                ),
              ),
            ),
          // Expandir — só aparece em fotos
          if (!isCurrentVideo)
            GestureDetector(
              onTap: () => _openFullscreenImage(currentItem),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.open_in_full_rounded,
                    color: TClubColors.subtle, size: 18),
              ),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: total,
        itemBuilder: (_, i) {
          final item = widget.items[i];
          final isActive = i == _current;

          if (item.type == 'video') {
            const gradient = [Color(0xFF1A0030), Color(0xFF4B005A)];
            return _GalleryVideoPage(
              item: item,
              gradient: gradient,
              scrollController: _scrollController,
              isActive: isActive,
            );
          }

          return _GalleryPhotoPage(
            item: item,
            onTap: () => _openFullscreenImage(item),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          total > 1 ? _PositionDots(current: _current, total: total) : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Página de vídeo
//  FIX: removido Positioned.fill em volta do InlineVideoCard.
//  Positioned só pode ser filho direto de Stack — fora disso lança
//  'ParentData is not StackParentData'. Usar SizedBox.expand resolve.
// ─────────────────────────────────────────────────────────────────────────────
class _GalleryVideoPage extends StatelessWidget {
  const _GalleryVideoPage({
    required this.item,
    required this.gradient,
    required this.scrollController,
    required this.isActive,
  });

  final GalleryItem item;
  final List<Color> gradient;
  final ScrollController scrollController;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: InlineVideoCard(
          postId: item.id,
          videoUrl: item.mediaUrl,
          thumbUrl: item.thumbUrl,
          duration: item.videoDuration,
          gradient: gradient,
          userName: '',
          titulo: 'Galeria',
          scrollController: scrollController,
          forceVisible: true,
          isActive: isActive,
          overrideCanPlay: true,
          showMuteButton: false,
          tapToPause: true,
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
//  Página de foto
// ─────────────────────────────────────────────────────────────────────────────
class _GalleryPhotoPage extends StatelessWidget {
  const _GalleryPhotoPage({
    required this.item,
    required this.onTap,
  });

  final GalleryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: CloudinaryHelper.fullScreenUrl(item.mediaUrl),
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, __) =>
              const ColoredBox(color: Colors.black, child: SizedBox.shrink()),
          errorWidget: (_, __, ___) => const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: TClubColors.border, size: 48),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TClubColors.bgCard.withOpacity(0.70),
                    border: Border.all(
                        color: TClubColors.border.withOpacity(0.50), width: 0.6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.image_outlined, size: 10, color: TClubColors.dim),
                    SizedBox(width: 5),
                    Text('FOTO',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: TClubColors.dim,
                        )),
                  ]),
                ),
                const Spacer(),
                const Text('TOQUE PARA EXPANDIR',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 7,
                      letterSpacing: 1.5,
                      color: TClubColors.subtle,
                    )),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Indicador de posição
// ─────────────────────────────────────────────────────────────────────────────
class _PositionDots extends StatelessWidget {
  const _PositionDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total > 7) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(bottom: 80),
        decoration: BoxDecoration(
          color: TClubColors.bgCard.withOpacity(0.85),
          border: Border.all(color: TClubColors.border, width: 0.6),
        ),
        child: Text(
          '${current + 1}/$total',
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: TClubColors.dim,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: active ? 6 : 4,
            height: active ? 6 : 4,
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? TClubColors.redPrincipal
                  : TClubColors.border.withOpacity(0.60),
            ),
          );
        }),
      ),
    );
  }
}

