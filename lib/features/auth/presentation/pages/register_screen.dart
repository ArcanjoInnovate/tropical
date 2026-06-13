// lib/screens/screens_auth/register_screen/register_screen.dart
//
// STEP 1 do fluxo de cadastro multi-etapas:
//   Step 1 → dados básicos (nome, e-mail, senha)          ← este arquivo
//   Step 2 → data de nascimento + termos de uso           → register_step2_screen.dart
//   Step 3 → foto de perfil                               → register_step3_screen.dart
//   Step 4 → criando conta (upload + Firebase)            → register_creating_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/presentation/pages/register_screen_step2.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _nameFocused     = false;
  bool _emailFocused    = false;
  bool _passwordFocused = false;
  bool _confirmFocused  = false;
  String? _errorMsg;

  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  final _nameFocus     = FocusNode();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus  = FocusNode();

  String _password = '';
  bool get _passwordHasLength => _password.length >= 8;
  bool get _passwordHasUpper  => _password.contains(RegExp(r'[A-Z]'));
  bool get _passwordHasNumber => _password.contains(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();
    _bgController    = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _fade  = CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)),
    );
    _nameFocus.addListener(()     => setState(() => _nameFocused     = _nameFocus.hasFocus));
    _emailFocus.addListener(()    => setState(() => _emailFocused    = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _confirmFocus.addListener(()  => setState(() => _confirmFocused  = _confirmFocus.hasFocus));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _avancar() {
    final nome     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final senha    = _passwordController.text;
    final confirma = _confirmController.text;

    if (nome.isEmpty || email.isEmpty || senha.isEmpty || confirma.isEmpty) {
      setState(() => _errorMsg = 'Preencha todos os campos.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMsg = 'E-mail inválido.');
      return;
    }
    if (senha != confirma) {
      setState(() => _errorMsg = 'As senhas não coincidem.');
      return;
    }
    if (!_passwordHasLength || !_passwordHasUpper || !_passwordHasNumber) {
      setState(() => _errorMsg = 'A senha não atende aos requisitos.');
      return;
    }

    setState(() => _errorMsg = null);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => RegisterStep2Screen(
          nome:  nome,
          email: email,
          senha: senha,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: TabuColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // ── Fundo animado ──────────────────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(painter: RegisterBgPainter(progress: _bgController.value)),
          ),
        ),
        // ── Linha de destaque superior ─────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                TabuColors.rosaDeep, TabuColors.rosaPrincipal, TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // ── Topo: voltar + steps ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: TabuColors.textoPrincipal, size: 16),
                  ),
                ),
                const Spacer(),
                RegisterStepBar(currentStep: 0),
                const Spacer(),
                const SizedBox(width: 40),
              ]),
            ),

            Expanded(
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
                        SizedBox(height: size.height * 0.03),
                        const _HeaderSection(),
                        SizedBox(height: size.height * 0.04),

                        RegisterTextField(
                          label: 'NOME COMPLETO',
                          hint: 'como quer ser chamado',
                          keyboardType: TextInputType.name,
                          controller: _nameController,
                          focusNode: _nameFocus,
                          isFocused: _nameFocused,
                          prefixIcon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),

                        RegisterTextField(
                          label: 'E-MAIL',
                          hint: 'seu@email.com',
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                          focusNode: _emailFocus,
                          isFocused: _emailFocused,
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 16),

                        RegisterTextField(
                          label: 'SENHA',
                          hint: 'mínimo 8 caracteres',
                          obscureText: _obscurePassword,
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          isFocused: _passwordFocused,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          onChanged: (v) => setState(() => _password = v),
                        ),

                        if (_passwordFocused || _password.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          RegisterPasswordStrengthBar(password: _password),
                          const SizedBox(height: 8),
                          RegisterPasswordRules(hasLength: _passwordHasLength, hasUpper: _passwordHasUpper, hasNumber: _passwordHasNumber),
                        ],
                        const SizedBox(height: 16),

                        RegisterTextField(
                          label: 'CONFIRMAR SENHA',
                          hint: 'repita a senha',
                          obscureText: _obscureConfirm,
                          controller: _confirmController,
                          focusNode: _confirmFocus,
                          isFocused: _confirmFocused,
                          prefixIcon: Icons.lock_outline,
                          suffixIcon: _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        const SizedBox(height: 32),

                        // Mensagem de erro
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _errorMsg != null
                              ? Padding(
                                  key: const ValueKey('error'),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(_errorMsg!, style: theme.textTheme.bodySmall?.copyWith(color: TabuColors.rosaPrincipal, fontSize: 11, letterSpacing: 1))),
                                    const SizedBox(width: 8),
                                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
                                  ]),
                                )
                              : const SizedBox(key: ValueKey('no-error')),
                        ),

                        // Botão avançar
                        _AvancarButton(onTap: _avancar),

                        const SizedBox(height: 24),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Já tem conta?  ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: TabuColors.dim)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Text('Entrar', style: theme.textTheme.labelLarge?.copyWith(color: TabuColors.rosaPrincipal, letterSpacing: 1, fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 40),
                        Text('— TABU BAR & LOUNGE —', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 4, color: TabuColors.subtle, fontSize: 8)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      SizedBox(width: 52, height: 52, child: CustomPaint(painter: RegisterGlowIconPainter())),
      const SizedBox(height: 16),
      Text('TABU', style: theme.textTheme.displaySmall?.copyWith(
        fontSize: 42, letterSpacing: 18, fontWeight: FontWeight.w400, color: TabuColors.textoPrincipal, height: 1,
        shadows: [Shadow(color: TabuColors.rosaPrincipal.withOpacity(0.5), offset: Offset.zero, blurRadius: 20)],
      )),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Container(width: 16, height: 1.5, color: TabuColors.rosaPrincipal),
        const SizedBox(width: 8),
        Text('LOUNGE', style: theme.textTheme.labelSmall?.copyWith(color: TabuColors.rosaPrincipal, letterSpacing: 6, fontSize: 9, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(width: 16, height: 1.5, color: TabuColors.rosaPrincipal),
      ]),
      const SizedBox(height: 20),
      Text('Crie sua conta exclusiva', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, letterSpacing: 1.5, fontSize: 13, color: TabuColors.dim)),
    ]);
  }
}

// ─── Botão avançar ─────────────────────────────────────────────────────────────
class _AvancarButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AvancarButton({required this.onTap});
  @override
  State<_AvancarButton> createState() => _AvancarButtonState();
}

class _AvancarButtonState extends State<_AvancarButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _shimmer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity, height: 56,
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _pressed
                ? [TabuColors.rosaDeep, TabuColors.rosaPrincipal]
                : [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: !_pressed ? [
            BoxShadow(color: TabuColors.glow, blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: TabuColors.rosaPrincipal.withOpacity(0.3), blurRadius: 32, offset: const Offset(0, 12)),
          ] : [],
        ),
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _shimmer,
            builder: (_, __) => CustomPaint(
              painter: RegisterShimmerPainter(progress: _shimmer.value, color: Colors.white.withOpacity(0.2)),
              size: const Size(double.infinity, 56),
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('PRÓXIMO', style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 14, letterSpacing: 5, fontWeight: FontWeight.w700, color: TabuColors.textoPrincipal,
            )),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: TabuColors.textoPrincipal, size: 18),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS COMPARTILHADOS (usados em vários steps)
// ══════════════════════════════════════════════════════════════════════════════

/// Barra de progresso com 4 steps.
class RegisterStepBar extends StatelessWidget {
  final int currentStep; // 0-based
  const RegisterStepBar({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const total = 4;
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(total, (i) {
      final done    = i < currentStep;
      final active  = i == currentStep;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:  active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: done
                ? TabuColors.rosaPrincipal.withOpacity(0.6)
                : active
                    ? TabuColors.rosaPrincipal
                    : TabuColors.border,
            boxShadow: active ? [BoxShadow(color: TabuColors.glow, blurRadius: 8)] : [],
          ),
        ),
        if (i < total - 1) const SizedBox(width: 4),
      ]);
    }));
  }
}

/// Campo de texto no estilo Tabu.
class RegisterTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isFocused;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  const RegisterTextField({
    super.key,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
    this.focusNode,
    required this.isFocused,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.labelSmall?.copyWith(
        fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.w700,
        color: isFocused ? TabuColors.rosaPrincipal : TabuColors.subtle,
      )),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isFocused ? const Color(0x14E85D8A) : TabuColors.bgCard,
          border: Border.all(
            color: isFocused ? TabuColors.borderMid : TabuColors.border,
            width: isFocused ? 1.5 : 0.8,
          ),
          boxShadow: isFocused ? [
            BoxShadow(color: TabuColors.glow.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14, letterSpacing: 0.3, color: TabuColors.textoPrincipal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.inputDecorationTheme.hintStyle,
            prefixIcon: Icon(prefixIcon, color: isFocused ? TabuColors.rosaPrincipal : TabuColors.subtle, size: 18),
            suffixIcon: suffixIcon != null
                ? GestureDetector(onTap: onSuffixTap, child: Icon(suffixIcon, color: TabuColors.subtle, size: 18))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          ),
        ),
      ),
    ]);
  }
}

/// Barra de força da senha.
class RegisterPasswordStrengthBar extends StatelessWidget {
  final String password;
  const RegisterPasswordStrengthBar({super.key, required this.password});

  int get _strength {
    int s = 0;
    if (password.length >= 8) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  Color get _color {
    switch (_strength) {
      case 0: case 1: return TabuColors.rosaDeep;
      case 2: return TabuColors.rosaPrincipal;
      case 3: return TabuColors.rosaClaro;
      case 4: return TabuColors.rosaPale;
      default: return TabuColors.border;
    }
  }

  String get _label {
    switch (_strength) {
      case 0: case 1: return 'FRACA';
      case 2: return 'MÉDIA';
      case 3: return 'BOA';
      case 4: return 'FORTE';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Row(children: List.generate(4, (i) {
          final filled = i < _strength;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(color: filled ? _color : Colors.white.withOpacity(0.08)),
            ),
          );
        })),
      ),
      const SizedBox(width: 12),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(_label, key: ValueKey(_label), style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700, color: _color)),
      ),
    ]);
  }
}

/// Regras de senha.
class RegisterPasswordRules extends StatelessWidget {
  final bool hasLength, hasUpper, hasNumber;
  const RegisterPasswordRules({super.key, required this.hasLength, required this.hasUpper, required this.hasNumber});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _Rule(label: '8+ caracteres', ok: hasLength),
      const SizedBox(width: 12),
      _Rule(label: 'Maiúscula', ok: hasUpper),
      const SizedBox(width: 12),
      _Rule(label: 'Número', ok: hasNumber),
    ]);
  }
}

class _Rule extends StatelessWidget {
  final String label;
  final bool ok;
  const _Rule({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 12, height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ok ? TabuColors.rosaPrincipal : Colors.transparent,
          border: Border.all(color: ok ? TabuColors.rosaPrincipal : TabuColors.subtle, width: 1),
        ),
        child: ok ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont, fontSize: 9, letterSpacing: 0.5, color: ok ? TabuColors.rosaClaro : TabuColors.subtle)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAINTERS COMPARTILHADOS
// ══════════════════════════════════════════════════════════════════════════════

class RegisterBgPainter extends CustomPainter {
  final double progress;
  const RegisterBgPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = TabuColors.bg);
    final r1 = size.width * (0.9 + progress * 0.15);
    canvas.drawCircle(
      Offset(size.width * 0.65, -size.height * 0.06), r1,
      Paint()..shader = RadialGradient(
        colors: [TabuColors.rosaPrincipal.withOpacity(0.18 - progress * 0.05), TabuColors.rosaDeep.withOpacity(0.07), Colors.transparent],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.65, -size.height * 0.06), radius: r1)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = RadialGradient(
        center: const Alignment(0.0, 0.1), radius: 0.65,
        colors: [TabuColors.rosaDeep.withOpacity(0.12 + progress * 0.05), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(RegisterBgPainter old) => old.progress != progress;
}

class RegisterGlowIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), cx, Paint()
      ..color = TabuColors.rosaPrincipal.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    final rosa = Paint()..color = TabuColors.rosaPrincipal;
    canvas.drawCircle(Offset(cx, cy + 3), 10, rosa);
    canvas.drawCircle(Offset(cx - 8, cy + 6), 7, rosa);
    canvas.drawCircle(Offset(cx + 8, cy + 6), 7, rosa);
    canvas.drawCircle(Offset(cx - 4, cy), 8.5, rosa);
    canvas.drawCircle(Offset(cx + 4, cy), 8.5, rosa);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 15, cy + 3, 30, 11), const Radius.circular(3)), rosa);
    final glow = Paint()
      ..color = TabuColors.glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(cx - 4, cy), 8.5, glow);
    canvas.drawCircle(Offset(cx + 4, cy), 8.5, glow);
    canvas.drawCircle(Offset(cx, cy + 3), 10, glow);
  }
  @override
  bool shouldRepaint(RegisterGlowIconPainter old) => false;
}

class RegisterShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;
  const RegisterShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (progress * 1.6 - 0.3);
    canvas.drawRect(
      Rect.fromLTWH(x - 70, 0, 140, size.height),
      Paint()..shader = LinearGradient(
        colors: [Colors.transparent, color, color.withOpacity(0.5), color, Colors.transparent],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: GradientRotation(math.pi / 6),
      ).createShader(Rect.fromLTWH(x - 70, 0, 140, size.height)),
    );
  }

  @override
  bool shouldRepaint(RegisterShimmerPainter old) => old.progress != progress;
}