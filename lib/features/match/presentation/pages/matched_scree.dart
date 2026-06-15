// lib/features/match/presentation/pages/match_screen.dart
//
// Tela "DEU MATCH!" — exibida como rota completa sobre a stack de navegação.
// Uso:
//   Navigator.of(context).push(MatchScreen.route(
//     myAvatar:    '...',  myName:    'Ana',
//     otherAvatar: '...',  otherName: 'João',
//     onSendMessage: () { /* abre o chat */ },
//   ));

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';


// ═════════════════════════════════════════════════════════════════════════════
//  Rota estática
// ═════════════════════════════════════════════════════════════════════════════
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.myAvatar,
    required this.myName,
    required this.otherAvatar,
    required this.otherName,
    this.onSendMessage,
  });

  final String    myAvatar;
  final String    myName;
  final String    otherAvatar;
  final String    otherName;
  final VoidCallback? onSendMessage;

  static Route<void> route({
    required String myAvatar,
    required String myName,
    required String otherAvatar,
    required String otherName,
    VoidCallback?   onSendMessage,
  }) =>
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => MatchScreen(
          myAvatar:       myAvatar,
          myName:         myName,
          otherAvatar:    otherAvatar,
          otherName:      otherName,
          onSendMessage:  onSendMessage,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      );

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

// ═════════════════════════════════════════════════════════════════════════════
//  State principal
// ═════════════════════════════════════════════════════════════════════════════
class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _bgCtrl;        // fade do fundo
  late final AnimationController _avatarCtrl;    // avatares entram
  late final AnimationController _heartCtrl;     // coração central aparece
  late final AnimationController _pulseCtrl;     // coração pulsa em loop
  late final AnimationController _textCtrl;      // textos aparecem
  late final AnimationController _btnCtrl;       // botões aparecem
  late final AnimationController _ringsCtrl;     // anéis expansivos

  // ── Animations ───────────────────────────────────────────────────────────
  late final Animation<double> _bgFade;
  late final Animation<Offset>  _myAvatarOffset;
  late final Animation<Offset>  _otherAvatarOffset;
  late final Animation<double>  _avatarFade;
  late final Animation<double>  _heartScale;
  late final Animation<double>  _heartFade;
  late final Animation<double>  _pulseAnim;
  late final Animation<double>  _titleScale;
  late final Animation<double>  _titleFade;
  late final Animation<double>  _subtitleFade;
  late final Animation<Offset>  _subtitleSlide;
  late final Animation<double>  _btnFade;
  late final Animation<Offset>  _btnSlide;

  // ── Partículas ────────────────────────────────────────────────────────────
  final List<_Particle> _particles = [];
  final Random _rng = Random();
  Timer? _spawnTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    // Fundo
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

    // Avatares
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _myAvatarOffset = Tween<Offset>(
            begin: const Offset(-2.5, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _avatarCtrl, curve: Curves.easeOutBack));
    _otherAvatarOffset = Tween<Offset>(
            begin: const Offset(2.5, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _avatarCtrl, curve: Curves.easeOutBack));
    _avatarFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _avatarCtrl,
        curve: const Interval(0, 0.4, curve: Curves.easeOut)));

    // Coração
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _heartScale = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
    _heartFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _heartCtrl,
            curve: const Interval(0, 0.3, curve: Curves.easeOut)));

    // Pulse loop
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Anéis expansivos
    _ringsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    // Texto
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _titleScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutBack));
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.4, 1, curve: Curves.easeOut)));
    _subtitleSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.4, 1, curve: Curves.easeOutCubic)));

    // Botões
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _btnFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));
    _btnSlide = Tween<Offset>(
            begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _btnCtrl, curve: Curves.easeOutCubic));
  }

  Future<void> _runSequence() async {
    HapticFeedback.heavyImpact();

    _bgCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 100));
    _avatarCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 480));
    HapticFeedback.mediumImpact();
    _heartCtrl.forward();
    _ringsCtrl.forward();
    _launchParticles();

    await Future.delayed(const Duration(milliseconds: 260));
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 320));
    HapticFeedback.selectionClick();
    _btnCtrl.forward();
  }

  // ── Partículas ────────────────────────────────────────────────────────────
  void _launchParticles() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;

      for (int i = 0; i < 70; i++) {
        _particles.add(_Particle.burst(size, _rng));
      }

      _spawnTimer =
          Timer.periodic(const Duration(milliseconds: 70), (_) {
        if (!mounted) { _spawnTimer?.cancel(); return; }
        for (int i = 0; i < 5; i++) {
          _particles.add(_Particle.falling(size, _rng));
        }
      });
      Future.delayed(const Duration(seconds: 3), () {
        _spawnTimer?.cancel();
      });

      _tickTimer =
          Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!mounted) { _tickTimer?.cancel(); return; }
        setState(() {
          for (final p in _particles) p.tick();
          _particles.removeWhere((p) => p.dead);
        });
      });
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _avatarCtrl.dispose();
    _heartCtrl.dispose();
    _pulseCtrl.dispose();
    _ringsCtrl.dispose();
    _textCtrl.dispose();
    _btnCtrl.dispose();
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // ── Fundo escuro com vinheta rosa ─────────────────────────────────
        FadeTransition(
          opacity: _bgFade,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xF0080810),
          ),
        ),

        // ── Brilho radial central ─────────────────────────────────────────
        FadeTransition(
          opacity: _bgFade,
          child: Center(
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TClubColors.redPrincipal.withOpacity(0.18),
                    TClubColors.redDeep.withOpacity(0.06),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),

        // ── Anéis expansivos ──────────────────────────────────────────────
        AnimatedBuilder(
          animation: _ringsCtrl,
          builder: (_, __) {
            return Stack(children: List.generate(3, (i) {
              final delay = i * 0.25;
              final t = ((_ringsCtrl.value - delay) / (1 - delay)).clamp(0, 1).toDouble();
              if (t <= 0) return const SizedBox.shrink();
              final radius = t * size.width * 0.65;
              final opacity = (1 - t) * 0.35;
              return Center(
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: TClubColors.redPrincipal.withOpacity(opacity),
                        width: 1.5),
                  ),
                ),
              );
            }));
          },
        ),

        // ── Confete ───────────────────────────────────────────────────────
        if (_particles.isNotEmpty)
          CustomPaint(
            painter: _ParticlePainter(_particles),
            size: size,
          ),

        // ── Conteúdo principal ────────────────────────────────────────────
        SafeArea(
          child: Column(children: [

            const Spacer(flex: 2),

            // ── Avatares ─────────────────────────────────────────────────
            FadeTransition(
              opacity: _avatarFade,
              child: SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [

                    // Avatar — eu (esquerda)
                    SlideTransition(
                      position: _myAvatarOffset,
                      child: Transform.translate(
                        offset: const Offset(-64, 0),
                        child: _Avatar(
                          url:  widget.myAvatar,
                          name: widget.myName,
                          size: 130,
                        ),
                      ),
                    ),

                    // Avatar — outro (direita)
                    SlideTransition(
                      position: _otherAvatarOffset,
                      child: Transform.translate(
                        offset: const Offset(64, 0),
                        child: _Avatar(
                          url:  widget.otherAvatar,
                          name: widget.otherName,
                          size: 130,
                        ),
                      ),
                    ),

                    // Coração central
                    AnimatedBuilder(
                      animation: Listenable.merge(
                          [_heartCtrl, _pulseCtrl]),
                      builder: (_, __) => FadeTransition(
                        opacity: _heartFade,
                        child: Transform.scale(
                          scale: _heartScale.value * _pulseAnim.value,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: TClubColors.redPrincipal,
                              border: Border.all(
                                  color: const Color(0xFF080810),
                                  width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: TClubColors.glow.withOpacity(0.9),
                                  blurRadius: 28,
                                  spreadRadius: 4),
                                BoxShadow(
                                  color: TClubColors.redPrincipal
                                      .withOpacity(0.5),
                                  blurRadius: 50,
                                  spreadRadius: 10),
                              ],
                            ),
                            child: const Icon(
                                Icons.favorite_rounded,
                                size: 24,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // ── "DEU MATCH!" ──────────────────────────────────────────────
            AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => FadeTransition(
                opacity: _titleFade,
                child: Transform.scale(
                  scale: _titleScale.value,
                  child: Column(children: [

                    // Linha decorativa superior
                    _DecorLine(),

                    const SizedBox(height: 18),

                    ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: [
                            Color(0xFFFFCCDD),
                            TClubColors.redClaro,
                            TClubColors.redPrincipal,
                            TClubColors.redClaro,
                            Color(0xFFFFCCDD),
                          ]).createShader(bounds),
                      child: const Text(
                        'DEU MATCH!',
                        style: TextStyle(
                          fontFamily: TClubTypography.displayFont,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 7,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Linha decorativa inferior
                    _DecorLine(),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Nomes & subtítulo ─────────────────────────────────────────
            SlideTransition(
              position: _subtitleSlide,
              child: FadeTransition(
                opacity: _subtitleFade,
                child: Column(children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                      children: [
                        TextSpan(
                          text: widget.myName
                              .split(' ')
                              .first
                              .toUpperCase(),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9)),
                        ),
                        const TextSpan(
                          text: '  ♥  ',
                          style: TextStyle(
                              color: TClubColors.redPrincipal),
                        ),
                        TextSpan(
                          text: widget.otherName
                              .split(' ')
                              .first
                              .toUpperCase(),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Vocês se curtiram mutuamente',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ]),
              ),
            ),

            const Spacer(flex: 3),

            // ── Botões ────────────────────────────────────────────────────
            SlideTransition(
              position: _btnSlide,
              child: FadeTransition(
                opacity: _btnFade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(children: [

                    // Botão primário — Ir para o Chat
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                        widget.onSendMessage?.call();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              TClubColors.redDeep,
                              TClubColors.redPrincipal,
                              TClubColors.redClaro,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: TClubColors.glow.withOpacity(0.55),
                              blurRadius: 28,
                              offset: const Offset(0, 10)),
                            BoxShadow(
                              color: TClubColors.redPrincipal
                                  .withOpacity(0.35),
                              blurRadius: 50,
                              offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                                Icons.chat_bubble_rounded,
                                size: 17,
                                color: Colors.white),
                            const SizedBox(width: 10),
                            const Text(
                              'ENVIAR MENSAGEM',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botão secundário
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'CONTINUAR NAVEGANDO',
                          style: TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.5,
                            color: Colors.white.withOpacity(0.30),
                          ),
                        ),
                      ),
                    ),

                  ]),
                ),
              ),
            ),

            const SizedBox(height: 36),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Widget: Avatar
// ═════════════════════════════════════════════════════════════════════════════
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, this.size = 120});
  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: TClubColors.redPrincipal.withOpacity(0.65),
            width: 2.5),
        boxShadow: [
          BoxShadow(
            color: TClubColors.glow.withOpacity(0.45),
            blurRadius: 24,
            spreadRadius: 2),
          BoxShadow(
            color: TClubColors.redPrincipal.withOpacity(0.25),
            blurRadius: 50,
            spreadRadius: 8),
        ],
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: CloudinaryHelper.avatarUrl(url),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: TClubTypography.displayFont,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: TClubColors.redPrincipal,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Widget: Linha decorativa
// ═════════════════════════════════════════════════════════════════════════════
class _DecorLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32, height: 0.8,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent, TClubColors.redPrincipal,
            ])),
        ),
        const SizedBox(width: 8),
        Container(
          width: 5, height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: TClubColors.redPrincipal,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 32, height: 0.8,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              TClubColors.redPrincipal, Colors.transparent,
            ])),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Partículas
// ═════════════════════════════════════════════════════════════════════════════
class _Particle {
  _Particle._({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotSpeed,
    required this.opacity,
    required this.isHeart,
  });

  factory _Particle.burst(Size screen, Random rng) {
    final angle = rng.nextDouble() * 2 * pi;
    final speed = rng.nextDouble() * 6 + 2;
    return _Particle._(
      pos:       Offset(screen.width / 2, screen.height * 0.38),
      vel:       Offset(cos(angle) * speed, sin(angle) * speed - 3),
      color:     _randomColor(rng),
      size:      rng.nextDouble() * 9 + 4,
      rotation:  rng.nextDouble() * 2 * pi,
      rotSpeed:  (rng.nextDouble() - 0.5) * 0.18,
      opacity:   rng.nextDouble() * 0.3 + 0.7,
      isHeart:   rng.nextDouble() < 0.35,
    );
  }

  factory _Particle.falling(Size screen, Random rng) => _Particle._(
    pos:       Offset(rng.nextDouble() * screen.width, -12),
    vel:       Offset((rng.nextDouble() - 0.5) * 2.5, rng.nextDouble() * 3 + 2),
    color:     _randomColor(rng),
    size:      rng.nextDouble() * 8 + 3,
    rotation:  rng.nextDouble() * 2 * pi,
    rotSpeed:  (rng.nextDouble() - 0.5) * 0.12,
    opacity:   rng.nextDouble() * 0.35 + 0.55,
    isHeart:   rng.nextDouble() < 0.3,
  );

  static Color _randomColor(Random rng) => [
    TClubColors.redPrincipal,
    TClubColors.redClaro,
    TClubColors.redDeep,
    const Color(0xFFFFD6E8),
    const Color(0xFFFF99BB),
    Colors.white,
    const Color(0xFFFFE4EE),
  ][rng.nextInt(7)];

  Offset pos;
  Offset vel;
  final Color  color;
  final double size;
  double       rotation;
  final double rotSpeed;
  double       opacity;
  final bool   isHeart;

  bool get dead => opacity <= 0 || pos.dy > 1000;

  void tick() {
    pos       = pos + vel;
    vel       = Offset(vel.dx * 0.985, vel.dy + 0.065);
    rotation += rotSpeed;
    opacity   = (opacity - 0.0055).clamp(0, 1);
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter(this.particles);
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.rotation);

      if (p.isHeart) {
        _drawHeart(canvas, paint, p.size * 0.55);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero,
                width: p.size,
                height: p.size * 0.48),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, double s) {
    final path = Path()
      ..moveTo(0, s * 0.35)
      ..cubicTo(-s * 0.05, 0, -s * 1.1, 0, -s * 1.1, s * 0.65)
      ..cubicTo(-s * 1.1, s * 1.2, 0, s * 1.55, 0, s * 1.75)
      ..cubicTo(0, s * 1.55, s * 1.1, s * 1.2, s * 1.1, s * 0.65)
      ..cubicTo(s * 1.1, 0, s * 0.05, 0, 0, s * 0.35)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

