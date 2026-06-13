// lib/screens/screens_auth/register_screen/register_step3_screen.dart
//
// STEP 3 do fluxo de cadastro multi-etapas:
//   Step 1 → dados básicos (nome, e-mail, senha)
//   Step 2 → data de nascimento + termos de uso
//   Step 3 → foto de perfil (opcional)            ← este arquivo
//   Step 4 → criando conta (upload + Firebase)    → register_creating_screen.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/core/helpers/media_permission_helper.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/presentation/pages/register_creating_page.dart';
import 'package:tabuapp/features/auth/presentation/pages/register_screen.dart';

class RegisterStep3Screen extends StatefulWidget {
  final String nome;
  final String email;
  final String senha;
  final DateTime birthDate;
  final int idade;

  const RegisterStep3Screen({
    super.key,
    required this.nome,
    required this.email,
    required this.senha,
    required this.birthDate,
    required this.idade,
  });

  @override
  State<RegisterStep3Screen> createState() => _RegisterStep3ScreenState();
}

class _RegisterStep3ScreenState extends State<RegisterStep3Screen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _fade;
  late Animation<double> _pulse;

  File? _imageFile;
  bool _isPickingImage = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _bgController    = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _fade  = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    HapticFeedback.selectionClick();

    try {
      if (!await requestMediaPermission(context, source)) return;
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      debugPrint('[Step3] Erro ao selecionar imagem: $e');
    } finally {
      setState(() => _isPickingImage = false);
    }
  }

  void _showImagePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _PickerOption(
              icon: Icons.camera_alt_outlined,
              label: 'CÂMERA',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 2),
            _PickerOption(
              icon: Icons.photo_library_outlined,
              label: 'GALERIA',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 2),
              _PickerOption(
                icon: Icons.delete_outline_rounded,
                label: 'REMOVER FOTO',
                color: Colors.redAccent,
                onTap: () { Navigator.pop(context); setState(() => _imageFile = null); },
              ),
            ],
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _avancar() {
    if (_imageFile == null) {
      HapticFeedback.mediumImpact();
      setState(() => _errorMsg = 'Adicione uma foto para continuar.');
      return;
    }
    setState(() => _errorMsg = null);
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => RegisterCreatingScreen(
          nome:      widget.nome,
          email:     widget.email,
          senha:     widget.senha,
          birthDate: widget.birthDate,
          idade:     widget.idade,
          imageFile: _imageFile,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final hasPhoto = _imageFile != null;

    return Scaffold(
      backgroundColor: TabuColors.bg,
      resizeToAvoidBottomInset: false,
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
          child: FadeTransition(
            opacity: _fade,
            child: Column(children: [
              // ── Topo ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
                  RegisterStepBar(currentStep: 2),
                  const Spacer(),
                  const SizedBox(width: 40),
                ]),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.03),

                      // ── Cabeçalho ─────────────────────────────────────────
                      Text(
                        'SUA FOTO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10, letterSpacing: 5, color: TabuColors.rosaPrincipal, fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Como você\nquer aparecer?',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 28, fontWeight: FontWeight.w700,
                          color: TabuColors.textoPrincipal, height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escolha uma foto que represente você.\nObrigatória para participar do sistema de match.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13, color: TabuColors.dim, height: 1.6,
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),

                      // ── Avatar interativo ──────────────────────────────────
                      GestureDetector(
                        onTap: _showImagePicker,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Transform.scale(
                            scale: hasPhoto ? 1.0 : _pulse.value,
                            child: child,
                          ),
                          child: _AvatarWidget(
                            imageFile: _imageFile,
                            nome: widget.nome,
                            isLoading: _isPickingImage,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Texto de toque ─────────────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: hasPhoto
                            ? GestureDetector(
                                key: const ValueKey('change'),
                                onTap: _showImagePicker,
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.edit_outlined, color: TabuColors.rosaPrincipal, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TROCAR FOTO',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 11, letterSpacing: 3, color: TabuColors.rosaPrincipal,
                                    ),
                                  ),
                                ]),
                              )
                            : GestureDetector(
                                key: const ValueKey('add'),
                                onTap: _showImagePicker,
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.add_a_photo_outlined, color: TabuColors.rosaPrincipal, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ADICIONAR FOTO',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 11, letterSpacing: 3, color: TabuColors.rosaPrincipal,
                                    ),
                                  ),
                                ]),
                              ),
                      ),

                      SizedBox(height: size.height * 0.06),

                      // ── Dica de qualidade ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TabuColors.bgCard,
                          border: Border.all(color: TabuColors.border, width: 0.8),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.tips_and_updates_outlined, color: TabuColors.rosaPrincipal, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Perfis com foto recebem até 3× mais matches. Use uma foto nítida e de rosto para melhores resultados.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12, color: TabuColors.dim, height: 1.6,
                              ),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 32),

                      // ── Mensagem de erro ───────────────────────────────────
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

                      // ── Botão continuar ────────────────────────────────────
                      _Step3Button(onTap: _avancar, hasPhoto: hasPhoto),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Avatar Widget ─────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final File? imageFile;
  final String nome;
  final bool isLoading;
  const _AvatarWidget({required this.imageFile, required this.nome, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageFile != null;
    final initials = nome.trim().isNotEmpty
        ? nome.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : '?';

    return Container(
      width: 160, height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasPhoto ? TabuColors.rosaPrincipal : TabuColors.borderMid,
          width: hasPhoto ? 2.5 : 1.5,
        ),
        boxShadow: hasPhoto ? [
          BoxShadow(color: TabuColors.glow.withOpacity(0.4), blurRadius: 30, spreadRadius: 2),
        ] : [],
      ),
      child: ClipOval(
        child: isLoading
            ? Container(
                color: TabuColors.bgCard,
                child: const Center(
                  child: CircularProgressIndicator(color: TabuColors.rosaPrincipal, strokeWidth: 2),
                ),
              )
            : hasPhoto
                ? Image.file(imageFile!, fit: BoxFit.cover)
                : Container(
                    color: TabuColors.bgCard,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(
                        initials,
                        style: const TextStyle(
                          fontFamily: TabuTypography.displayFont,
                          fontSize: 48,
                          color: TabuColors.rosaPrincipal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.add_a_photo_outlined, color: TabuColors.subtle, size: 18),
                    ]),
                  ),
      ),
    );
  }
}

// ─── Opção do picker ───────────────────────────────────────────────────────────
class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _PickerOption({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? TabuColors.textoPrincipal;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 13,
              letterSpacing: 2,
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Botão do step 3 ───────────────────────────────────────────────────────────
class _Step3Button extends StatefulWidget {
  final VoidCallback onTap;
  final bool hasPhoto;
  const _Step3Button({required this.onTap, required this.hasPhoto});
  @override
  State<_Step3Button> createState() => _Step3ButtonState();
}

class _Step3ButtonState extends State<_Step3Button> with SingleTickerProviderStateMixin {
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
            Text(
              widget.hasPhoto ? 'CONTINUAR COM FOTO' : 'CONTINUAR',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w700, color: TabuColors.textoPrincipal,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: TabuColors.textoPrincipal, size: 18),
          ]),
        ]),
      ),
    );
  }
}