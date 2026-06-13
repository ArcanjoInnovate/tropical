// lib/screens/screens_auth/login_screen/login_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/data/services/auth_service.dart';
import 'package:tabuapp/features/penalty/presentation/pages/ban_page.dart';
import 'package:tabuapp/features/penalty/presentation/pages/suspension_page.dart';
import 'package:tabuapp/features/penalty/presentation/pages/warning_page.dart';
import 'package:tabuapp/core/guards/auth_guard.dart';
import 'package:tabuapp/features/auth/presentation/pages/acess_code_screen.dart';
import 'package:tabuapp/features/auth/presentation/pages/register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool showRegister;
  const LoginScreen({super.key, this.showRegister = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _shakeController;
  late AnimationController _errorPulseController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _shake;
  late Animation<double> _errorPulse;

  bool _obscurePassword  = true;
  bool _emailFocused     = false;
  bool _passwordFocused  = false;
  bool _isLoading        = false;
  bool _emailHasError    = false;
  bool _passwordHasError = false;

  String? _errorMain;
  String? _errorHint;

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus         = FocusNode();
  final _passwordFocus      = FocusNode();
  final _authService        = AuthService();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _errorPulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _fade = CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.15, 1.0, curve: Curves.easeOut)));
    _shake = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _errorPulse = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(
            parent: _errorPulseController, curve: Curves.easeInOut));

    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(
        () => setState(() => _passwordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _shakeController.dispose();
    _errorPulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Erros ──────────────────────────────────────────────────────────────────
  void _clearErrors() {
    _errorMain        = null;
    _errorHint        = null;
    _emailHasError    = false;
    _passwordHasError = false;
  }

  void _setError({
    required String main,
    String? hint,
    bool emailError    = false,
    bool passwordError = false,
  }) {
    setState(() {
      _errorMain        = main;
      _errorHint        = hint;
      _emailHasError    = emailError;
      _passwordHasError = passwordError;
      _isLoading        = false;
    });
    HapticFeedback.mediumImpact();
    _shakeController.reset();
    _shakeController.forward();
    _errorPulseController.reset();
    _errorPulseController.repeat(
        reverse: true, period: const Duration(milliseconds: 1000));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _errorPulseController.stop();
        _errorPulseController.value = 0;
      }
    });
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final senha = _passwordController.text;

    if (email.isEmpty && senha.isEmpty) {
      _setError(main: 'Preencha o e-mail e a senha.',
          emailError: true, passwordError: true);
      _emailFocus.requestFocus();
      return;
    }
    if (email.isEmpty) {
      _setError(main: 'Digite seu e-mail.', emailError: true);
      _emailFocus.requestFocus();
      return;
    }
    if (senha.isEmpty) {
      _setError(main: 'Digite sua senha.', passwordError: true);
      _passwordFocus.requestFocus();
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _setError(main: 'Digite um e-mail válido.',
          hint: 'Ex: seunome@gmail.com', emailError: true);
      _emailFocus.requestFocus();
      return;
    }

    setState(() { _isLoading = true; _clearErrors(); });

    try {
      await _authService.signInWithEmail(email: email, password: senha);

      // ── Login limpo ────────────────────────────────────────────────────────
      // Navega explicitamente para o AuthGuard. Não depende do authStateChanges
      // porque o Firebase não re-emite o evento se o mesmo usuário já estava
      // logado (ex: segundo login após falha de navegação).
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGuard()),
        (_) => false,
      );

    } on WarnedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final uid = e.userData['uid'] as String? ?? '';
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WarningPage(
            penalidade:    e.penalidade,
            penalidadeKey: e.penalidadeKey,
            uid:           uid,
            onOk: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGuard()),
              (_) => false,
            ),
          ),
        ),
        (_) => false,
      );

    } on BannedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final uid = e.userData['uid'] as String? ?? '';
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BanPage(userData: e.userData, uid: uid),
        ),
        (_) => false,
      );

    } on SuspendedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final uid = e.userData['uid'] as String? ?? '';
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SuspensionPage(userData: e.userData, uid: uid),
        ),
        (_) => false,
      );

    } on AuthException catch (e) {
      if (!mounted) return;
      _applyFirebaseError(e.code, email);

    } catch (e) {
      if (!mounted) return;
      _applyFirebaseError(e.toString(), email);
    }
  }

  void _applyFirebaseError(String rawError, String email) {
    final code = rawError
        .toLowerCase()
        .replaceAll('authexception: ', '')
        .replaceAll('exception: ', '')
        .trim();

    if (code.contains('user-not-found') || code.contains('no user record')) {
      _setError(main: 'E-mail não cadastrado.',
          hint: 'Verifique o endereço ou crie uma conta.', emailError: true);
      _emailFocus.requestFocus();
    } else if (code.contains('wrong-password') ||
        code.contains('invalid-credential') ||
        code.contains('invalid-login-credentials') ||
        code.contains('password is invalid')) {
      _setError(main: 'E-mail ou senha incorretos.',
          hint: 'Verifique os dados ou redefina sua senha.',
          passwordError: true);
      _passwordController.clear();
      _passwordFocus.requestFocus();
    } else if (code.contains('user-disabled')) {
      _setError(main: 'Esta conta foi banida.',
          hint: 'Entre em contato com o suporte.', emailError: true);
    } else if (code.contains('too-many-requests') || code.contains('blocked')) {
      _setError(main: 'Muitas tentativas. Aguarde alguns minutos.',
          hint: 'Acesso temporariamente bloqueado por segurança.');
    } else if (code.contains('network') || code.contains('timeout')) {
      _setError(main: 'Sem conexão com a internet.',
          hint: 'Verifique seu Wi-Fi ou dados móveis.');
    } else if (code.contains('invalid-email')) {
      _setError(main: 'Digite um e-mail válido.',
          hint: 'Ex: seunome@gmail.com', emailError: true);
    } else {
      _setError(main: 'Não foi possível entrar. Tente novamente.',
          hint: 'Se o problema persistir, contate o suporte.');
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder:        (_, a, __) => const RegisterScreen(),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  void _forgotPassword() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setError(main: 'Digite seu e-mail para redefinir a senha.',
          emailError: true);
      _emailFocus.requestFocus();
      return;
    }
    _authService.sendPasswordResetEmail(email).then((_) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('E-mail de redefinição enviado para $email',
            style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 11, letterSpacing: 0.5, color: Colors.white)),
        backgroundColor: const Color(0xFF1A0030),
        behavior: SnackBarBehavior.floating,
        shape:    const RoundedRectangleBorder(),
        margin:   const EdgeInsets.all(16),
      ));
    }).catchError((e) {
      if (!mounted) return;
      final code = e.toString().toLowerCase();
      if (code.contains('user-not-found')) {
        _setError(main: 'E-mail não cadastrado.',
            hint: 'Verifique o endereço ou crie uma conta.', emailError: true);
      } else if (code.contains('invalid-email')) {
        _setError(main: 'Digite um e-mail válido.',
            hint: 'Ex: seunome@gmail.com', emailError: true);
      } else {
        _setError(main: 'Não foi possível enviar o e-mail.',
            hint: 'Verifique se o endereço está correto.', emailError: true);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:          TabuColors.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => CustomPaint(
                  painter:
                      _FundoEscuroPainter(progress: _bgController.value)),
            ),
          ),
          Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        TabuColors.rosaDeep,
                        TabuColors.rosaPrincipal,
                        TabuColors.rosaClaro,
                        TabuColors.rosaPrincipal,
                        TabuColors.rosaDeep,
                      ])))),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.07),
                      const _LogoSection(),
                      SizedBox(height: size.height * 0.05),
                      Text('Bem-vindo de volta',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              letterSpacing: 2,
                              fontSize: 13,
                              color: TabuColors.dim)),
                      const SizedBox(height: 36),

                      // E-mail
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(
                              _emailHasError
                                  ? math.sin(_shake.value * math.pi * 4) * 8
                                  : 0.0,
                              0),
                          child: child),
                        child: _TabuTextField(
                          label:        'E-MAIL',
                          hint:         'seu@email.com',
                          keyboardType: TextInputType.emailAddress,
                          controller:   _emailController,
                          focusNode:    _emailFocus,
                          isFocused:    _emailFocused,
                          hasError:     _emailHasError,
                          prefixIcon:   Icons.mail_outline,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Senha
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(
                              _passwordHasError
                                  ? math.sin(_shake.value * math.pi * 4) * 8
                                  : 0.0,
                              0),
                          child: child),
                        child: _TabuTextField(
                          label:       'SENHA',
                          hint:        'sua senha',
                          obscureText: _obscurePassword,
                          controller:  _passwordController,
                          focusNode:   _passwordFocus,
                          isFocused:   _passwordFocused,
                          hasError:    _passwordHasError,
                          prefixIcon:  Icons.lock_outline,
                          suffixIcon:  _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _forgotPassword,
                          child: Text('Esqueceu a senha?',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:       TabuColors.rosaClaro,
                                  fontStyle:   FontStyle.italic,
                                  letterSpacing: 1,
                                  fontSize:    11)),
                        ),
                      ),

                      // Bloco de erro
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: _errorMain != null
                            ? AnimatedBuilder(
                                key: const ValueKey('error'),
                                animation: _errorPulse,
                                builder: (_, child) => Transform.scale(
                                    scale: _errorPulse.value, child: child),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                            width:  4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                                color: TabuColors.rosaPrincipal,
                                                shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(_errorMain!,
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: TabuColors
                                                          .rosaPrincipal,
                                                      fontSize:    11,
                                                      letterSpacing: 1,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                            width:  4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                                color: TabuColors.rosaPrincipal,
                                                shape: BoxShape.circle)),
                                      ],
                                    ),
                                    if (_errorHint != null) ...[
                                      const SizedBox(height: 5),
                                      Text(_errorHint!,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: TabuColors
                                                      .rosaPrincipal
                                                      .withOpacity(0.55),
                                                  fontSize:    10,
                                                  letterSpacing: 0.5,
                                                  fontStyle:
                                                      FontStyle.italic)),
                                    ],
                                  ]),
                                ))
                            : const SizedBox(key: ValueKey('no-error')),
                      ),

                      const SizedBox(height: 36),
                      _LoginButton(isLoading: _isLoading, onTap: _login),
                      const SizedBox(height: 28),

                      if (widget.showRegister)
                        GestureDetector(
                          onTap: _goToRegister,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: RichText(
                              text: TextSpan(
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                          fontSize: 12,
                                          letterSpacing: 0.5),
                                  children: [
                                    const TextSpan(text: 'Novo membro?  '),
                                    TextSpan(
                                        text: 'Criar uma conta',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                                color: TabuColors
                                                    .rosaPrincipal,
                                                letterSpacing: 1,
                                                fontSize: 12,
                                                decoration: TextDecoration
                                                    .underline,
                                                decorationColor: TabuColors
                                                    .rosaPrincipal
                                                    .withOpacity(0.5))),
                                  ]),
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AccessCodeScreen())),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios,
                                    size:  10,
                                    color: TabuColors.subtle),
                                const SizedBox(width: 6),
                                Text('Voltar ao código de acesso',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color:       TabuColors.subtle,
                                            fontSize:    11,
                                            letterSpacing: 1,
                                            fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 48),
                      Text('— TABU BAR & LOUNGE —',
                          style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 4,
                              color:    TabuColors.subtle,
                              fontSize: 8)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: TabuColors.bg.withOpacity(0.7),
                child: Center(
                  child: Container(
                    width:  52,
                    height: 52,
                    decoration: BoxDecoration(
                        color:  TabuColors.bgCard,
                        border: Border.all(
                            color: TabuColors.border, width: 0.8)),
                    child: const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: TabuColors.rosaPrincipal)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Logo ───────────────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  const _LogoSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      SizedBox(
          width:  64,
          height: 64,
          child:  CustomPaint(painter: _RosaGlowIcon())),
      const SizedBox(height: 20),
      Text('TABU',
          style: theme.textTheme.displayMedium?.copyWith(
              fontSize:      60,
              letterSpacing: 24,
              fontWeight:    FontWeight.w400,
              color:         TabuColors.textoPrincipal,
              height:        1,
              shadows: [Shadow(color: TabuColors.glow, blurRadius: 24)])),
      const SizedBox(height: 6),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:      MainAxisSize.min,
          children: [
            Container(
                width: 20, height: 1.5, color: TabuColors.rosaPrincipal),
            const SizedBox(width: 10),
            Text('LOUNGE',
                style: theme.textTheme.labelSmall?.copyWith(
                    color:         TabuColors.rosaPrincipal,
                    letterSpacing: 6,
                    fontSize:      10,
                    fontWeight:    FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
                width: 20, height: 1.5, color: TabuColors.rosaPrincipal),
          ]),
    ]);
  }
}

class _RosaGlowIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), cx,
        Paint()
          ..color       = TabuColors.rosaPrincipal.withOpacity(0.3)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final rosa = Paint()..color = TabuColors.rosaPrincipal;
    canvas.drawCircle(Offset(cx, cy + 3), 11, rosa);
    canvas.drawCircle(Offset(cx - 9, cy + 6), 8, rosa);
    canvas.drawCircle(Offset(cx + 9, cy + 6), 8, rosa);
    canvas.drawCircle(Offset(cx - 4, cy - 1), 9, rosa);
    canvas.drawCircle(Offset(cx + 4, cy - 1), 9, rosa);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 17, cy + 3, 34, 12),
            const Radius.circular(3)),
        rosa);
    final glow = Paint()
      ..color       = TabuColors.glow
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(cx - 4, cy - 1), 9, glow);
    canvas.drawCircle(Offset(cx + 4, cy - 1), 9, glow);
    canvas.drawCircle(Offset(cx, cy + 3), 11, glow);
  }
  @override
  bool shouldRepaint(_RosaGlowIcon old) => false;
}

// ── Campo de texto ─────────────────────────────────────────────────────────────
class _TabuTextField extends StatelessWidget {
  final String             label, hint;
  final bool               obscureText;
  final TextInputType?     keyboardType;
  final TextEditingController? controller;
  final FocusNode?         focusNode;
  final bool               isFocused;
  final bool               hasError;
  final IconData           prefixIcon;
  final IconData?          suffixIcon;
  final VoidCallback?      onSuffixTap;

  const _TabuTextField({
    required this.label,
    required this.hint,
    this.obscureText  = false,
    this.keyboardType,
    this.controller,
    this.focusNode,
    required this.isFocused,
    this.hasError    = false,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color  labelColor  = hasError || isFocused
        ? TabuColors.rosaPrincipal : TabuColors.subtle;
    final Color  borderColor = hasError
        ? TabuColors.rosaPrincipal.withOpacity(0.8)
        : isFocused ? TabuColors.borderMid : TabuColors.border;
    final double borderWidth = hasError || isFocused ? 1.5 : 0.8;
    final Color  bgColor     = hasError
        ? const Color(0x1FE85D8A)
        : isFocused ? const Color(0x14E85D8A) : TabuColors.bgCard;
    final shadows = isFocused || hasError
        ? [BoxShadow(
            color:      TabuColors.glow
                .withOpacity(hasError ? 0.18 : 0.25),
            blurRadius: 12,
            offset:     const Offset(0, 4))]
        : <BoxShadow>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: theme.textTheme.labelSmall?.copyWith(
              fontSize:      9,
              letterSpacing: 3,
              fontWeight:    FontWeight.w700,
              color:         labelColor)),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
            color:     bgColor,
            border:    Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows),
        child: TextField(
          controller:   controller,
          focusNode:    focusNode,
          obscureText:  obscureText,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge?.copyWith(
              fontSize:      14,
              letterSpacing: 0.3,
              color:         TabuColors.textoPrincipal),
          decoration: InputDecoration(
              hintText:   hint,
              hintStyle:  theme.inputDecorationTheme.hintStyle,
              prefixIcon: Icon(prefixIcon,
                  color: isFocused || hasError
                      ? TabuColors.rosaPrincipal : TabuColors.subtle,
                  size: 18),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(
                      onTap: onSuffixTap,
                      child: Icon(suffixIcon,
                          color: TabuColors.subtle, size: 18))
                  : null,
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 4)),
        ),
      ),
    ]);
  }
}

// ── Botão de login ─────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool         isLoading;
  final VoidCallback onTap;
  const _LoginButton({required this.isLoading, required this.onTap});
  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown:   (_) { setState(() => _pressed = true);  HapticFeedback.lightImpact(); },
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration:           const Duration(milliseconds: 120),
        width:              double.infinity,
        height:             56,
        transform:          Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
            gradient: _pressed
                ? const LinearGradient(colors: [
                    TabuColors.rosaDeep,
                    TabuColors.rosaPrincipal,
                  ])
                : const LinearGradient(
                    colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
                    begin:  Alignment.centerLeft,
                    end:    Alignment.centerRight),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                        color:      TabuColors.glow,
                        blurRadius: 20,
                        offset:     const Offset(0, 6)),
                    BoxShadow(
                        color:      TabuColors.rosaPrincipal.withOpacity(0.3),
                        blurRadius: 30,
                        offset:     const Offset(0, 10)),
                  ]),
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _shimmer,
            builder:   (_, __) => CustomPaint(
                painter: _ShimmerPainter(
                    progress: _shimmer.value,
                    color:    Colors.white.withOpacity(0.2)),
                size: const Size(double.infinity, 56)),
          ),
          widget.isLoading
              ? const SizedBox(
                  width:  20,
                  height: 20,
                  child:  CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('ENTRAR',
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontSize:      14,
                      letterSpacing: 7,
                      fontWeight:    FontWeight.w700,
                      color:         TabuColors.textoPrincipal)),
        ]),
      ),
    );
  }
}

// ── Painters ───────────────────────────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _ShimmerPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (progress * 1.6 - 0.3);
    canvas.drawRect(
        Rect.fromLTWH(x - 70, 0, 140, size.height),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              color,
              color.withOpacity(0.5),
              color,
              Colors.transparent,
            ],
            stops:     const [0.0, 0.3, 0.5, 0.7, 1.0],
            transform: GradientRotation(math.pi / 6),
          ).createShader(Rect.fromLTWH(x - 70, 0, 140, size.height)));
  }
  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

class _FundoEscuroPainter extends CustomPainter {
  final double progress;
  const _FundoEscuroPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    final nr = size.width * (0.9 + progress * 0.15);
    canvas.drawCircle(
        Offset(size.width * 0.6, -size.height * 0.08),
        nr,
        Paint()
          ..shader = RadialGradient(colors: [
            TabuColors.rosaPrincipal.withOpacity(0.20 - progress * 0.06),
            TabuColors.rosaDeep.withOpacity(0.08),
            Colors.transparent,
          ], stops: const [0.0, 0.45, 1.0]).createShader(Rect.fromCircle(
              center: Offset(size.width * 0.6, -size.height * 0.08),
              radius: nr)));
    final sr = size.width * (0.55 + (1 - progress) * 0.1);
    canvas.drawCircle(
        Offset(size.width * 1.05, size.height * 0.15),
        sr,
        Paint()
          ..shader = RadialGradient(colors: [
            TabuColors.bgAlt.withOpacity(0.9),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(
              center: Offset(size.width * 1.05, size.height * 0.15),
              radius: sr)));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = RadialGradient(
              center: Alignment.center,
              radius: 0.7,
              colors: [
                TabuColors.rosaDeep.withOpacity(0.10 + progress * 0.06),
                Colors.transparent,
              ]).createShader(
                  Rect.fromLTWH(0, 0, size.width, size.height)));
  }
  @override
  bool shouldRepaint(_FundoEscuroPainter old) => old.progress != progress;
}