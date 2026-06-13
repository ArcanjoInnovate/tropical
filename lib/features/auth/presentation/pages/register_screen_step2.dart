// lib/screens/screens_auth/register_screen/register_step2_screen.dart
//
// STEP 2: data de nascimento + termos de uso + aviso de sistema de match.
//   • TextField com formatação automática DD/MM/AAAA (sem date picker).
//   • Validação em tempo real: dia, mês e ano válidos.
//   • Bloqueia menores de 18 anos com mensagem clara.
//   • Termos de uso e política de privacidade.
//   • Aviso explícito de participação no sistema de match.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/presentation/pages/register_screen.dart';
import 'package:tabuapp/features/auth/presentation/pages/register_screen_step3.dart';

class RegisterStep2Screen extends StatefulWidget {
  final String nome;
  final String email;
  final String senha;

  const RegisterStep2Screen({
    super.key,
    required this.nome,
    required this.email,
    required this.senha,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late Animation<double> _fade;

  DateTime? _birthDate;
  bool _acceptedTerms = false;
  bool _dateFocused   = false;
  String? _errorMsg;

  final _dateController = TextEditingController();
  final _dateFocus      = FocusNode();

  @override
  void initState() {
    super.initState();
    _bgController    = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fade            = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _dateFocus.addListener(() => setState(() => _dateFocused = _dateFocus.hasFocus));
    _dateController.addListener(_onDateChanged);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _dateController.removeListener(_onDateChanged);
    _dateController.dispose();
    _dateFocus.dispose();
    super.dispose();
  }

  // ── Formata e valida enquanto digita ───────────────────────────────────────
  void _onDateChanged() {
    // Extrai só dígitos e limita a 8
    final raw = _dateController.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, _dateController.text.replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, 8));

    // Reconstrói data formatada com as barras
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(raw[i]);
    }
    final formatted = buffer.toString();

    // Evita loop: só atualiza se o texto mudou
    if (_dateController.text != formatted) {
      _dateController.value = _dateController.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Tenta parsear quando tiver 8 dígitos
    if (raw.length == 8) {
      final dia  = int.tryParse(raw.substring(0, 2));
      final mes  = int.tryParse(raw.substring(2, 4));
      final ano  = int.tryParse(raw.substring(4, 8));

      if (dia != null && mes != null && ano != null &&
          dia >= 1 && dia <= 31 &&
          mes >= 1 && mes <= 12 &&
          ano >= 1920) {
        // Verifica se a data existe de verdade (ex: 31/02 não existe)
        try {
          final candidate = DateTime(ano, mes, dia);
          if (candidate.day == dia && candidate.month == mes && candidate.year == ano) {
            setState(() {
              _birthDate = candidate;
              _errorMsg  = null;
            });
            return;
          }
        } catch (_) {}
      }
      setState(() {
        _birthDate = null;
        _errorMsg  = 'Data inválida.';
      });
    } else {
      setState(() => _birthDate = null);
    }
  }

  // ── Idade ──────────────────────────────────────────────────────────────────
  bool _isMaiorDeIdade(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age >= 18;
  }

  int _calcularIdade(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age;
  }

  // ── Avançar ────────────────────────────────────────────────────────────────
  void _avancar() {
    final raw = _dateController.text.replaceAll('/', '');

    if (raw.length < 8 || _birthDate == null) {
      setState(() => _errorMsg = 'Informe sua data de nascimento completa.');
      HapticFeedback.mediumImpact();
      return;
    }
    if (!_isMaiorDeIdade(_birthDate!)) {
      setState(() => _errorMsg = 'Você precisa ter 18 anos ou mais para criar uma conta.');
      HapticFeedback.mediumImpact();
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _errorMsg = 'Aceite os termos de uso para continuar.');
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _errorMsg = null);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => RegisterStep3Screen(
          nome:      widget.nome,
          email:     widget.email,
          senha:     widget.senha,
          birthDate: _birthDate!,
          idade:     _calcularIdade(_birthDate!),
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
    final theme    = Theme.of(context);
    final size     = MediaQuery.of(context).size;
    final hasDate  = _birthDate != null;
    final idade    = hasDate ? _calcularIdade(_birthDate!) : null;
    final menorMsg = (hasDate && !_isMaiorDeIdade(_birthDate!))
        ? 'Você precisa ter 18 anos ou mais.'
        : null;

    return Scaffold(
      backgroundColor: TabuColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // ── Fundo animado ────────────────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(painter: RegisterBgPainter(progress: _bgController.value)),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              TabuColors.rosaDeep, TabuColors.rosaPrincipal, TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
            ]),
          ),
        )),
        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(children: [
              // ── Topo ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: TabuColors.bgCard, border: Border.all(color: TabuColors.border, width: 0.8)),
                      child: const Icon(Icons.arrow_back_ios_new, color: TabuColors.textoPrincipal, size: 16),
                    ),
                  ),
                  const Spacer(),
                  RegisterStepBar(currentStep: 1),
                  const Spacer(),
                  const SizedBox(width: 40),
                ]),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(height: size.height * 0.03),

                    // ── Título ─────────────────────────────────────────
                    Center(
                      child: Column(children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: TabuColors.bgCard,
                            border: Border.all(color: TabuColors.borderMid, width: 0.8),
                            boxShadow: [BoxShadow(color: TabuColors.glow.withOpacity(0.3), blurRadius: 20)],
                          ),
                          child: const Icon(Icons.cake_outlined, color: TabuColors.rosaPrincipal, size: 26),
                        ),
                        const SizedBox(height: 16),
                        Text('DATA DE NASCIMENTO', style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 13, letterSpacing: 5, color: TabuColors.textoPrincipal, fontWeight: FontWeight.w700,
                        )),
                        const SizedBox(height: 8),
                        Text('Você precisa ter 18 anos ou mais', style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12, color: TabuColors.dim, letterSpacing: 0.5,
                        )),
                      ]),
                    ),

                    SizedBox(height: size.height * 0.04),

                    // ── Campo de data digitável ─────────────────────────
                    RegisterTextField(
                      label: 'DATA DE NASCIMENTO',
                      hint: 'DD/MM/AAAA',
                      controller: _dateController,
                      focusNode: _dateFocus,
                      isFocused: _dateFocused,
                      prefixIcon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                    ),

                    // ── Feedback inline ────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: menorMsg != null
                          // Menor de idade
                          ? _InlineBadge(
                              key: const ValueKey('menor'),
                              icon: Icons.block_rounded,
                              text: menorMsg,
                              color: Colors.redAccent,
                            )
                          : hasDate
                              // Data válida e maior de idade
                              ? _InlineBadge(
                                  key: ValueKey('ok-$idade'),
                                  icon: Icons.check_circle_outline_rounded,
                                  text: '$idade anos confirmados',
                                  color: TabuColors.rosaPrincipal,
                                )
                              : const SizedBox(key: ValueKey('empty')),
                    ),

                    const SizedBox(height: 32),

                    // ── Aviso sistema de match ─────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TabuColors.bgCard,
                        border: Border.all(color: TabuColors.borderMid, width: 0.8),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.favorite_outline_rounded, color: TabuColors.rosaPrincipal, size: 16),
                          const SizedBox(width: 8),
                          Text('SISTEMA DE MATCH', style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9, letterSpacing: 3, color: TabuColors.rosaPrincipal, fontWeight: FontWeight.w700,
                          )),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          'Ao criar uma conta no Tabu, você participará automaticamente do nosso sistema de match — onde outros membros podem encontrar e conectar com o seu perfil.',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: TabuColors.dim, height: 1.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Você pode ajustar sua visibilidade a qualquer momento nas configurações.',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: TabuColors.subtle, height: 1.5),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // ── Termos de uso ──────────────────────────────────
                    GestureDetector(
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22, height: 22, margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: _acceptedTerms ? TabuColors.rosaPrincipal : Colors.transparent,
                            border: Border.all(color: _acceptedTerms ? TabuColors.rosaPrincipal : TabuColors.border, width: 1.5),
                            boxShadow: _acceptedTerms ? [BoxShadow(color: TabuColors.glow.withOpacity(0.5), blurRadius: 10)] : [],
                          ),
                          child: _acceptedTerms ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, letterSpacing: 0.3, color: TabuColors.dim, height: 1.6),
                              children: [
                                const TextSpan(text: 'Li e aceito os '),
                                TextSpan(text: 'Termos de Uso', style: TextStyle(
                                  color: TabuColors.rosaClaro, fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: TabuColors.rosaPrincipal.withOpacity(0.5),
                                )),
                                const TextSpan(text: ' e a '),
                                TextSpan(text: 'Política de Privacidade', style: TextStyle(
                                  color: TabuColors.rosaClaro, fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: TabuColors.rosaPrincipal.withOpacity(0.5),
                                )),
                                const TextSpan(text: ' do TABU Lounge, incluindo a participação no sistema de match.'),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // ── Erro ───────────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _errorMsg != null
                          ? Padding(
                              key: const ValueKey('err'),
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.8),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                  const SizedBox(width: 10),
                                  Flexible(child: Text(_errorMsg!, style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.redAccent, fontSize: 12, letterSpacing: 0.3,
                                  ))),
                                ]),
                              ),
                            )
                          : const SizedBox(key: ValueKey('no-err')),
                    ),

                    // ── Botão avançar ──────────────────────────────────
                    _Step2Button(onTap: _avancar),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Badge de feedback inline ─────────────────────────────────────────────────
class _InlineBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InlineBadge({super.key, required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3), width: 0.8),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 12, letterSpacing: 0.5, color: color,
          )),
        ]),
      ),
    );
  }
}

// ─── Botão do step 2 ──────────────────────────────────────────────────────────
class _Step2Button extends StatefulWidget {
  final VoidCallback onTap;
  const _Step2Button({required this.onTap});
  @override
  State<_Step2Button> createState() => _Step2ButtonState();
}

class _Step2ButtonState extends State<_Step2Button> with SingleTickerProviderStateMixin {
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
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          boxShadow: !_pressed ? [
            BoxShadow(color: TabuColors.glow, blurRadius: 20, offset: const Offset(0, 6)),
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