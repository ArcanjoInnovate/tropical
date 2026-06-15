// lib/screens/screens_home/home_screen/home/inline_video_card.dart
//
// FIXES aplicados nesta versão:
//
//  1. PAUSA AO TROCAR ABA (IndexedStack)
//  2. PAUSA AO EMPILHAR QUALQUER PAGE ROUTE
//  3. REDE DE SEGURANÇA NO CONTROLLER
//  4. _canPlay como verdade única
//  5. overrideCanPlay — para PostListScreen / GalleryFeedScreen
//  6. _buildVideoLayer usa SizedBox.expand (sem AspectRatio/FittedBox)
//  7. _routeIsTop com fallback true nos primeiros frames
//  8. GlobalKey fora do ValueListenableBuilder
//  9. _tryInit usa addPostFrameCallback para controller do cache
// 10. [FIX CRÍTICO] Positioned sempre filho DIRETO do Stack.
//     IgnorePointer envolvia Positioned — Flutter lançava
//     'ParentData is not StackParentData'. Corrigido: Positioned por fora,
//     IgnorePointer/GestureDetector por dentro.
// 11. [FIX] ignoreRouteCheck — para telas admin/detalhe onde o vídeo deve
//     tocar independente de profundidade de rota ou aba ativa.
// 12. [FIX] Removidos play/pause inline e ícone de play central.
//     O toque no vídeo agora é responsabilidade do widget pai, que
//     navega para FullscreenVideoScreen. Mantido apenas o botão de mute.
// 13. [FIX] tapToPause — quando true, tocar no vídeo alterna play/pause
//     inline (usado na GalleryFeedScreen que já é fullscreen).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tclub/core/controllers/tclub_shell_controller.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/services/media/video_preload_service.dart';
import 'package:video_player/video_player.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Observer global de rotas ─────────────────────────────────────────────────
final RouteObserver<ModalRoute<void>> videoRouteObserver =
    RouteObserver<ModalRoute<void>>();

// ── Navigator observer global ────────────────────────────────────────────────
final VideoStackObserver videoStackObserver = VideoStackObserver();

class VideoStackObserver extends NavigatorObserver {
  final ValueNotifier<int> depth = ValueNotifier<int>(0);

  @override
  void didPush(Route route, Route? previousRoute) {
    if (previousRoute != null) depth.value += 1;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (depth.value > 0) depth.value -= 1;
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (depth.value > 0) depth.value -= 1;
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {}
}

// ── Estado global de mute ─────────────────────────────────────────────────────
class VideoMuteState {
  VideoMuteState._();
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);
  static bool _initialized = false;
  static const String _key = 'video_mute_state';

  static bool get isMuted => notifier.value;

  /// Carrega a preferência salva. Chamar uma vez no início do app.
  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    notifier.value = prefs.getBool(_key) ?? false;
    _initialized = true;
  }

  static void toggle() {
    notifier.value = !notifier.value;
    _persist();
  }

  static void setMuted(bool v) {
    notifier.value = v;
    _persist();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, notifier.value);
  }
}

const int _feedTabIndex = 0;

class InlineVideoCard extends StatefulWidget {
  final String postId;
  final ValueChanged<double>? onHeightChanged;
  final double? externalHeight;
  final String videoUrl;
  final String? thumbUrl;
  final int? duration;
  final List<Color> gradient;
  final String userName;
  final String titulo;
  final ScrollController scrollController;

  final bool forceVisible;
  final bool isActive;
  final bool overrideCanPlay;

  /// Quando true, ignora completamente as checagens de rota, aba e stack.
  /// Use em telas de detalhe (admin, preview) onde o vídeo deve sempre
  /// tocar se o widget estiver visível — sem depender do TclubShell ou do
  /// videoStackObserver.
  final bool ignoreRouteCheck;

  /// Quando false, esconde o botão de mute no player.
  final bool showMuteButton;

  /// Quando true, tocar no vídeo alterna play/pause inline.
  /// Use na GalleryFeedScreen (que já é fullscreen) para permitir
  /// controle direto sem abrir outra tela.
  final bool tapToPause;

  const InlineVideoCard({
    super.key,
    this.onHeightChanged,
    this.externalHeight,
    required this.postId,
    required this.videoUrl,
    required this.gradient,
    required this.userName,
    required this.titulo,
    required this.scrollController,
    this.thumbUrl,
    this.duration,
    this.forceVisible = false,
    this.isActive = false,
    this.overrideCanPlay = false,
    this.ignoreRouteCheck = false,
    this.showMuteButton = true,
    this.tapToPause = false,
  });

  @override
  State<InlineVideoCard> createState() => _InlineVideoCardState();
}

class _InlineVideoCardState extends State<InlineVideoCard>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _returningFromRoute = false;
  bool _loading = false;
  bool _showMuteHint = false;

  // GlobalKey fora do ValueListenableBuilder — RenderBox persiste entre rebuilds
  final GlobalKey _cardKey = GlobalKey();

  bool _isVisible = false;
  static const int _baseDepth = 0;
  bool _routeIsActive = true;
  Animation<double>? _secondaryAnim;

  bool get _stackIsClean => videoStackObserver.depth.value <= _baseDepth;

  bool get _feedTabIsActive =>
      TclubShellController.instance.currentTabIndex == _feedTabIndex;

  bool get _routeIsTop {
    if (!mounted) return false;
    // FIX 11: ignoreRouteCheck pula todas as checagens de rota
    if (widget.ignoreRouteCheck) return true;
    final secVal = _secondaryAnim?.value ?? 0.0;
    if (secVal > 0.01) return false;
    final r = ModalRoute.of(context);
    if (r == null) return true;
    return r.isCurrent;
  }

  bool get _canPlay {
    // FIX 11: ignoreRouteCheck — toca sempre se visível, sem checar aba/stack/rota
    if (widget.ignoreRouteCheck) return true;
    if (widget.overrideCanPlay) return _routeIsTop;
    return _feedTabIsActive && _stackIsClean && _routeIsTop;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VideoMuteState.notifier.addListener(_onGlobalMuteChanged);

    // FIX 11: não ouve stack/tab se ignoreRouteCheck — evita pausas indevidas
    if (!widget.ignoreRouteCheck) {
      videoStackObserver.depth.addListener(_onStackChanged);
      TclubShellController.instance.addListener(_onTabChanged);
    }

    if (widget.forceVisible) {
      _isVisible = widget.isActive;
      if (widget.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryInit());
      }
    } else {
      widget.scrollController.addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryInit();
        _checkVisibility();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      videoRouteObserver.subscribe(this, route);
      // FIX 11: não ouve secondaryAnimation se ignoreRouteCheck
      if (!widget.ignoreRouteCheck &&
          !identical(_secondaryAnim, route.secondaryAnimation)) {
        _secondaryAnim?.removeListener(_onSecondaryAnim);
        _secondaryAnim = route.secondaryAnimation;
        _secondaryAnim?.addListener(_onSecondaryAnim);
      }
    }
  }

  @override
  void dispose() {
    videoRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    if (!widget.ignoreRouteCheck) {
      videoStackObserver.depth.removeListener(_onStackChanged);
      TclubShellController.instance.removeListener(_onTabChanged);
    }
    _secondaryAnim?.removeListener(_onSecondaryAnim);
    if (!widget.forceVisible) {
      widget.scrollController.removeListener(_onScroll);
    }
    VideoMuteState.notifier.removeListener(_onGlobalMuteChanged);
    _ctrl?.removeListener(_onCtrlUpdate);

    final cached = VideoPreloadService.instance.getController(widget.postId);
    if (cached == null || !identical(_ctrl, cached)) {
      _ctrl?.dispose();
    } else {
      _ctrl?.pause();
      _ctrl?.seekTo(Duration.zero);
    }
    super.dispose();
  }

  void _onSecondaryAnim() {
    if (!mounted) return;
    final v = _secondaryAnim?.value ?? 0.0;
    if (v > 0.01) {
      _ctrl?.pause();
    } else {
      if (_isVisible && _canPlay) _ctrl?.play();
    }
    if (mounted) setState(() {});
  }

  void _onStackChanged() {
    if (!mounted) return;
    if (!_canPlay) {
      _ctrl?.pause();
    } else {
      if (_isVisible) _ctrl?.play();
    }
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (!_canPlay) {
      _ctrl?.pause();
    } else {
      if (_isVisible) _ctrl?.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void didPushNext() {
    // FIX 11: tela admin não pausa ao empilhar sub-rotas internas
    if (widget.ignoreRouteCheck) return;
    _routeIsActive = false;
    _ctrl?.pause();
  }

  @override
void didPopNext() {
  _routeIsActive = true;
  
  // Re-verifica o controller ao voltar do fullscreen
  final cached = VideoPreloadService.instance.getController(widget.postId);
  if (cached != null && cached.value.isInitialized) {
    if (!identical(_ctrl, cached)) {
      // Controller mudou, reatribui
      _ctrl?.removeListener(_onCtrlUpdate);
      _attachController(cached);
    }
    if (_isVisible && _canPlay) {
      cached.seekTo(Duration.zero).then((_) {
        if (mounted && _canPlay) cached.play();
      });
    }
  } else if (_isVisible && _canPlay) {
    // Cache foi perdido, reinicializa do zero
    _initialized = false;
    _loading = false;
    _tryInit();
  }
}

  void _retryPlay() {
    // Tenta imediatamente
    if (_isVisible && _canPlay && _initialized && _ctrl != null) {
      _ctrl!.play();
      if (mounted) setState(() {});
      return;
    }
    // Retry em intervalos até a transição estabilizar
    for (final ms in [100, 300, 500]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted || !_isVisible || !_routeIsActive) return;
        if (_ctrl != null && !_ctrl!.value.isPlaying && _canPlay) {
          _ctrl!.play();
          if (mounted) setState(() {});
        }
      });
    }
  }

  @override
  void didPush() => _routeIsActive = true;

  @override
  void didPop() {
    _routeIsActive = false;
    _ctrl?.pause();
  }

  @override
  void didUpdateWidget(InlineVideoCard old) {
    super.didUpdateWidget(old);
    if (widget.forceVisible) {
      final activeMudou = old.isActive != widget.isActive;
      if (activeMudou) {
        _isVisible = widget.isActive;
        if (widget.isActive) {
          if (_initialized && _ctrl != null && _canPlay) {
            _ctrl!.play();
          } else if (!_initialized && !_loading) {
            _tryInit();
          }
        } else {
          _ctrl?.pause();
          _ctrl?.seekTo(Duration.zero);
        }
      }
    }
  }

  void _onGlobalMuteChanged() {
    if (!mounted) return;
    _ctrl?.setVolume(VideoMuteState.isMuted ? 0.0 : 1.0);
    if (_isVisible) {
      setState(() => _showMuteHint = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showMuteHint = false);
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ctrl?.pause();
    } else if (state == AppLifecycleState.resumed && _isVisible && _canPlay) {
      _ctrl?.play();
    }
  }

  void _onScroll() => _checkVisibility();

  void _checkVisibility() {
    if (widget.forceVisible) return;
    if (!mounted) return;
    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final cardTop = box.localToGlobal(Offset.zero).dy;
    final cardBottom = cardTop + box.size.height;
    final visibleTop = cardTop.clamp(0.0, screenHeight);
    final visibleBottom = cardBottom.clamp(0.0, screenHeight);
    final visibleRatio = (visibleBottom - visibleTop) / box.size.height;
    final nowVisible = visibleRatio >= 0.4;

    if (nowVisible != _isVisible) {
      _isVisible = nowVisible;
      if (_isVisible && _canPlay) {
        _tryInit();
        _ctrl?.play();
      } else {
        _ctrl?.pause();
        _ctrl?.seekTo(Duration.zero);
      }
    }
  }

  Future<void> _tryInit() async {
    if (_initialized || _loading) return;

    final cached = VideoPreloadService.instance.getController(widget.postId);
    if (cached != null && cached.value.isInitialized) {
      _attachController(cached);
      final shouldPlay = widget.forceVisible
          ? widget.isActive && _canPlay
          : _isVisible && _canPlay;
      if (shouldPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _canPlay) cached.play();
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      _attachController(ctrl);

      final shouldPlay = widget.forceVisible
          ? widget.isActive && _canPlay
          : _isVisible && _canPlay;
      if (shouldPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _canPlay) ctrl.play();
        });
      }
    } catch (e) {
      debugPrint('[InlineVideo] init error — postId: ${widget.postId}');
      debugPrint('[InlineVideo] url: ${widget.videoUrl}');
      debugPrint('[InlineVideo] erro: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _attachController(VideoPlayerController ctrl) {
    ctrl.setVolume(VideoMuteState.isMuted ? 0.0 : 1.0);
    ctrl.addListener(_onCtrlUpdate);
    if (mounted) {
      final screenWidth = MediaQuery.of(context).size.width;
      final h = (screenWidth / ctrl.value.aspectRatio)
          .clamp(300.0, screenWidth * 1.35);
      widget.onHeightChanged?.call(h);
      setState(() {
        _ctrl = ctrl;
        _initialized = true;
        _loading = false;
      });
    }
  }

  void _onCtrlUpdate() {
    if (!mounted || _ctrl == null) return;
    if (!_canPlay && _ctrl!.value.isPlaying) {
      _ctrl!.pause();
      if (mounted) setState(() {});
      return;
    }
    if (_ctrl!.value.position >= _ctrl!.value.duration &&
        _ctrl!.value.duration.inSeconds > 0) {
      _ctrl!.seekTo(Duration.zero);
      if (_isVisible && _canPlay) _ctrl!.play();
      return;
    }
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    VideoMuteState.toggle();
  }

  // FIX 13: tap-to-pause para uso inline em telas fullscreen (gallery)
  void _onTapTogglePlay() {
    if (!_initialized || _ctrl == null) return;
    HapticFeedback.selectionClick();
    if (_ctrl!.value.isPlaying) {
      _ctrl!.pause();
    } else {
      if (_canPlay) _ctrl!.play();
    }
    if (mounted) setState(() {});
  }

  double get _aspectRatio {
    if (_initialized && _ctrl != null) {
      return _ctrl!.value.aspectRatio;
    }
    return 4 / 5;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double videoHeight = (_initialized && _ctrl != null)
        ? (screenWidth / _aspectRatio).clamp(300.0, screenWidth * 1.35)
        : screenWidth * 1.25;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      key: _cardKey,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: TClubColors.borderMid, width: 0.5),
          bottom: BorderSide(color: TClubColors.borderMid, width: 0.5),
        ),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: VideoMuteState.notifier,
        builder: (context, isMuted, _) {
          _ctrl?.setVolume(isMuted ? 0.0 : 1.0);

          return GestureDetector(
            onTap: widget.tapToPause ? _onTapTogglePlay : null,
            behavior: widget.tapToPause
                ? HitTestBehavior.opaque
                : HitTestBehavior.deferToChild,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Vídeo ou thumb ──────────────────────────────────
                IgnorePointer(child: _buildVideoLayer()),
                // ── 2. Gradiente inferior ──────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 3. Progress bar ──────────────────────────────────
                if (_initialized && _ctrl != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: _InlineProgressBar(controller: _ctrl!),
                    ),
                  ),

                // ── 4. Ícone "toque para ver" — hint visual ──────────
                // Mostra apenas enquanto o vídeo ainda não inicializou
                // e tapToPause está desativado (modo feed normal).
                if (!widget.tapToPause && !_initialized && !_loading)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.55),
                          border: Border.all(
                              color: TClubColors.redPrincipal, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: TClubColors.glow.withOpacity(0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_circle_outline_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),

                // ── 5. Botão mudo ──────────────────────────────────────
                if (widget.showMuteButton)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _toggleMute,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 0.6),
                        ),
                        child: Icon(
                          isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: isMuted
                              ? Colors.white54
                              : TClubColors.redPrincipal,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                // ── 6. Hint de duração ──────────────────────────────────
                if (widget.duration != null)
                  Positioned(
                    bottom: 8,
                    right: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          border: Border.all(
                              color: TClubColors.redPrincipal.withOpacity(0.4),
                              width: 0.7),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.play_circle_outline_rounded,
                              color: TClubColors.redPrincipal, size: 9),
                          const SizedBox(width: 3),
                          Text(
                            _fmtDuration(widget.duration!),
                            style: const TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),

                // ── 7. Ícone "tela cheia" — hint visual ─────────────
                if (!widget.tapToPause)
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                              width: 0.6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.fullscreen_rounded,
                              color: Colors.white54, size: 10),
                          const SizedBox(width: 3),
                          const Text(
                            'TELA CHEIA',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 7,
                              letterSpacing: 1.5,
                              color: Colors.white54,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),

                // ── 8. Loading ──────────────────────────────────────────
                if (_loading)
                  IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            color: TClubColors.redPrincipal, strokeWidth: 2),
                      ),
                    ),
                  ),

                // ── 9. Hint SOM ATIVADO / DESATIVADO ────────────────
                if (_showMuteHint && widget.showMuteButton)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          border: Border.all(
                              color: TClubColors.redPrincipal.withOpacity(0.4),
                              width: 0.8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: TClubColors.redPrincipal,
                            size: 14,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            isMuted ? 'SOM DESATIVADO' : 'SOM ATIVADO',
                            style: const TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),

                // ── 10. Ícone de pause (tapToPause) ─────────────────
                if (widget.tapToPause &&
                    _initialized &&
                    _ctrl != null &&
                    !_ctrl!.value.isPlaying)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.55),
                          border: Border.all(
                              color: TClubColors.redPrincipal.withOpacity(0.6),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: TClubColors.glow.withOpacity(0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (_initialized && _ctrl != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _ctrl!.value.size.width,
            height: _ctrl!.value.size.height,
            child: VideoPlayer(_ctrl!),
          ),
        ),
      );
    }
    if (widget.thumbUrl != null) {
      return CachedNetworkImage(
        imageUrl: CloudinaryHelper.videoThumbnail(widget.thumbUrl!),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => _gradientBg(),
        errorWidget: (_, __, ___) => _gradientBg(),
      );
    }
    return _gradientBg();
  }

  Widget _gradientBg() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white24, size: 56),
        ),
      );

  String _fmtDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────
class _InlineProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _InlineProgressBar({required this.controller});

  @override
  State<_InlineProgressBar> createState() => _InlineProgressBarState();
}

class _InlineProgressBarState extends State<_InlineProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      height: 2.5,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12)),
      child: FractionallySizedBox(
        widthFactor: pct,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TClubColors.redDeep, TClubColors.redPrincipal],
            ),
          ),
        ),
      ),
    );
  }
}

