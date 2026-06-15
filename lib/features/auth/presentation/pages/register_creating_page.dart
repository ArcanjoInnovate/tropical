// lib/screens/screens_auth/register_screen/register_creating_screen.dart
//
// STEP 4 do fluxo de cadastro multi-etapas.
//
// FIXES:
//   • Navegação corrigida: usava pushNamedAndRemoveUntil('/home') que não
//     existe como named route. Agora faz o mesmo que o login:
//     busca userData + isAdmin no Firebase e navega para TabuShell.
//   • AuthService.registerWithEmail agora aceita birthDate, idade e imageFile.

import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/auth/controller/auth_controller.dart';
import 'package:tclub/core/widgets/main_navigation.dart';

class RegisterCreatingScreen extends StatefulWidget {
  final String   nome;
  final String   email;
  final String   senha;
  final DateTime birthDate;
  final int      idade;
  final File?    imageFile;

  const RegisterCreatingScreen({
    super.key,
    required this.nome,
    required this.email,
    required this.senha,
    required this.birthDate,
    required this.idade,
    this.imageFile,
  });

  @override
  State<RegisterCreatingScreen> createState() => _RegisterCreatingScreenState();
}

class _RegisterCreatingScreenState extends State<RegisterCreatingScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoFade;
  late Animation<double>   _fadePage;

  _CreatingStep _step     = _CreatingStep.iniciando;
  bool          _hasError = false;
  String?       _errorMsg;

  @override
  void initState() {
    super.initState();

    _bgController       = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fadeController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _logoController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade  = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _fadePage  = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 800), _executarCadastro);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Fluxo principal ────────────────────────────────────────────────────────
  Future<void> _executarCadastro() async {
    final authController = context.read<AuthController>();

    try {
      // Etapa 1: cria conta
      _setStep(_CreatingStep.criandoConta);
      await Future.delayed(const Duration(milliseconds: 600));

      final ok = await authController.register(
        widget.email,
        widget.senha,
        widget.nome,
        birthDate: widget.birthDate,
        idade:     widget.idade,
        imageFile: widget.imageFile,
      );

      if (!ok) {
        _setError(authController.errorMessage ?? 'Erro ao criar conta. Tente novamente.');
        return;
      }

      // Etapa 2: configurando perfil
      _setStep(_CreatingStep.configurandoPerfil);
      await Future.delayed(const Duration(milliseconds: 800));

      // Etapa 3: quase pronto
      _setStep(_CreatingStep.finalizando);
      await Future.delayed(const Duration(milliseconds: 600));

      // Etapa 4: busca userData para passar ao TabuShell
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _setError('Erro ao identificar usuário. Tente fazer login.');
        return;
      }

      Map<String, dynamic> userData;
      try {
        final snap = await FirebaseDatabase.instance.ref('Users/$uid').get();
        if (snap.exists && snap.value != null) {
          userData = Map<String, dynamic>.from(snap.value as Map);
          userData['uid'] = uid;
        } else {
          // Fallback com dados básicos se o nó ainda não sincronizou
          userData = {
            'uid':   uid,
            'name':  widget.nome,
            'email': widget.email,
            'avatar': '',
          };
        }
      } catch (_) {
        userData = {
          'uid':   uid,
          'name':  widget.nome,
          'email': widget.email,
          'avatar': '',
        };
      }

      // Verifica se é admin (novos usuários nunca são, mas mantém consistência)
      bool isAdmin = false;
      try {
        final adminSnap = await FirebaseDatabase.instance
            .ref('Administratives/admins/$uid')
            .get();
        isAdmin = adminSnap.exists && adminSnap.value == true;
      } catch (_) {}

      // Concluído
      _setStep(_CreatingStep.concluido);
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      // ── Navega para TabuShell exatamente como o login faz ────────────────
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) =>
              TabuShell(userData: userData, isAdmin: isAdmin),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (_) => false, // Remove toda a pilha de cadastro
      );

    } catch (e) {
      debugPrint('[RegisterCreating] erro: $e');
      _setError('Algo deu errado. Tente novamente.');
    }
  }

  void _setStep(_CreatingStep step) {
    if (!mounted) return;
    setState(() => _step = step);
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMsg = _friendlyError(msg);
    });
    _progressController.stop();
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use'))    return 'Este e-mail já está cadastrado. Tente fazer login.';
    if (raw.contains('weak-password'))           return 'Senha muito fraca. Use pelo menos 8 caracteres.';
    if (raw.contains('invalid-email'))           return 'E-mail inválido.';
    if (raw.contains('network-request-failed'))  return 'Sem conexão com a internet. Verifique sua rede.';
    return 'Erro inesperado. Por favor, tente novamente.';
  }

  void _voltarECorrigir() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size  = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              painter: _CreatingBgPainter(progress: _bgController.value),
            ),
          ),
        ),
        FadeTransition(
          opacity: _fadePage,
          child: SafeArea(
            child: _hasError
                ? _ErrorView(
                    message:  _errorMsg!,
                    onRetry:  _voltarECorrigir,
                    theme:    theme,
                  )
                : _LoadingView(
                    step:               _step,
                    nome:               widget.nome,
                    hasPhoto:           widget.imageFile != null,
                    progressController: _progressController,
                    logoScale:          _logoScale,
                    logoFade:           _logoFade,
                    theme:              theme,
                    size:               size,
                  ),
          ),
        ),
      ]),
    );
  }
}

// ── Enum de etapas ─────────────────────────────────────────────────────────────
enum _CreatingStep { iniciando, criandoConta, configurandoPerfil, finalizando, concluido }

extension _CreatingStepExt on _CreatingStep {
  String get label {
    switch (this) {
      case _CreatingStep.iniciando:          return 'Preparando tudo...';
      case _CreatingStep.criandoConta:       return 'Criando sua conta...';
      case _CreatingStep.configurandoPerfil: return 'Configurando seu perfil...';
      case _CreatingStep.finalizando:        return 'Quase lá...';
      case _CreatingStep.concluido:          return 'Bem-vindo ao TCLUB!';
    }
  }

  int get index2 {
    switch (this) {
      case _CreatingStep.iniciando:          return 0;
      case _CreatingStep.criandoConta:       return 1;
      case _CreatingStep.configurandoPerfil: return 2;
      case _CreatingStep.finalizando:        return 3;
      case _CreatingStep.concluido:          return 4;
    }
  }

  bool get isDone => this == _CreatingStep.concluido;
}

// ── View de loading ────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final _CreatingStep      step;
  final String             nome;
  final bool               hasPhoto;
  final AnimationController progressController;
  final Animation<double>  logoScale;
  final Animation<double>  logoFade;
  final ThemeData          theme;
  final Size               size;

  const _LoadingView({
    required this.step,
    required this.nome,
    required this.hasPhoto,
    required this.progressController,
    required this.logoScale,
    required this.logoFade,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = step.isDone;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: logoScale,
          child: FadeTransition(
            opacity: logoFade,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? TClubColors.redPrincipal : TClubColors.borderMid,
                  width: isDone ? 2.5 : 1.5,
                ),
                boxShadow: isDone ? [
                  BoxShadow(color: TClubColors.glow.withOpacity(0.5), blurRadius: 40, spreadRadius: 4),
                ] : [],
                color: TClubColors.bgCard,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        key: ValueKey('check'),
                        color: TClubColors.redPrincipal, size: 44)
                    : const Padding(
                        key: ValueKey('logo'),
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(
                          color: TClubColors.redPrincipal,
                          strokeWidth: 2,
                        ),
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 48),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: Text(
            step.label,
            key: ValueKey(step),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: isDone ? TClubColors.redPrincipal : TClubColors.textoPrincipal,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isDone
              ? Text(
                  'Olá, ${nome.split(' ').first}! Tudo pronto.',
                  key: const ValueKey('done-sub'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 14, color: TClubColors.dim, height: 1.6,
                  ),
                )
              : Text(
                  hasPhoto
                      ? 'Estamos preparando seu perfil com foto...'
                      : 'Estamos configurando tudo para você...',
                  key: const ValueKey('loading-sub'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13, color: TClubColors.subtle, height: 1.6,
                  ),
                ),
        ),

        const SizedBox(height: 56),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: _StepProgressBar(currentStep: step.index2, totalSteps: 4),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepLabel('CONTA',  step.index2 >= 1),
              _stepLabel('PERFIL', step.index2 >= 2),
              _stepLabel('MATCH',  step.index2 >= 3),
              _stepLabel('PRONTO', step.index2 >= 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepLabel(String text, bool done) => Text(
    text,
    style: TextStyle(
      fontFamily: TClubTypography.bodyFont,
      fontSize: 8, letterSpacing: 1.5,
      color: done ? TClubColors.redPrincipal : TClubColors.subtle,
      fontWeight: done ? FontWeight.w700 : FontWeight.w400,
    ),
  );
}

// ── Barra de progresso ─────────────────────────────────────────────────────────
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepProgressBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final done   = currentStep > i;
        final active = currentStep == i + 1;
        return Expanded(
          child: Row(children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: done
                      ? TClubColors.redPrincipal
                      : active
                          ? TClubColors.redPrincipal.withOpacity(0.5)
                          : TClubColors.border,
                  boxShadow: done ? [
                    BoxShadow(color: TClubColors.glow.withOpacity(0.6), blurRadius: 6),
                  ] : [],
                ),
              ),
            ),
            if (i < totalSteps - 1) const SizedBox(width: 6),
          ]),
        );
      }),
    );
  }
}

// ── View de erro ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  final ThemeData    theme;
  const _ErrorView({required this.message, required this.onRetry, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TClubColors.bgCard,
              border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
          ),

          const SizedBox(height: 32),

          Text(
            'Ops! Algo deu errado',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20, fontWeight: FontWeight.w700, color: TClubColors.textoPrincipal,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14, color: TClubColors.dim, height: 1.6,
            ),
          ),

          const SizedBox(height: 48),

          GestureDetector(
            onTap: onRetry,
            child: Container(
              width: double.infinity, height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [TClubColors.redPrincipal, TClubColors.redClaro],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(color: TClubColors.glow, blurRadius: 20, offset: Offset(0, 6)),
                ],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.refresh_rounded, color: TClubColors.textoPrincipal, size: 18),
                const SizedBox(width: 10),
                Text(
                  'TENTAR NOVAMENTE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13, letterSpacing: 3,
                    fontWeight: FontWeight.w700, color: TClubColors.textoPrincipal,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painter de fundo ───────────────────────────────────────────────────────────
class _CreatingBgPainter extends CustomPainter {
  final double progress;
  const _CreatingBgPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = TClubColors.bg,
    );

    final r = size.width * (0.7 + progress * 0.2);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2), r,
      Paint()..shader = RadialGradient(colors: [
        TClubColors.redPrincipal.withOpacity(0.12 + progress * 0.04),
        TClubColors.redDeep.withOpacity(0.06),
        Colors.transparent,
      ], stops: const [0.0, 0.4, 1.0]).createShader(
        Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: r),
      ),
    );

    final r2 = size.width * (0.5 + progress * 0.1);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.85), r2,
      Paint()..shader = RadialGradient(colors: [
        TClubColors.redDeep.withOpacity(0.10 + progress * 0.03),
        Colors.transparent,
      ], stops: const [0.0, 1.0]).createShader(
        Rect.fromCircle(
            center: Offset(size.width * 0.8, size.height * 0.85), radius: r2),
      ),
    );

    final paint = Paint()..color = TClubColors.redPrincipal.withOpacity(0.08);
    final rng = math.Random(42);
    for (int i = 0; i < 8; i++) {
      canvas.drawCircle(
        Offset(size.width * rng.nextDouble(), size.height * rng.nextDouble()),
        2.0 + rng.nextDouble() * 3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CreatingBgPainter old) => old.progress != progress;
}

