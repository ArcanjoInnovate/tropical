// lib/screens/screens_home/perfil_screen/perfil/improved_delete_account_sheet.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/auth/presentation/pages/login_screen.dart';
import 'package:tclub/features/settings/controller/delete_controller.dart';

class ImprovedDeleteAccountSheet extends StatefulWidget {
  final String userName;

  const ImprovedDeleteAccountSheet({
    super.key,
    required this.userName,
  });

  @override
  State<ImprovedDeleteAccountSheet> createState() => _ImprovedDeleteAccountSheetState();
}

class _ImprovedDeleteAccountSheetState extends State<ImprovedDeleteAccountSheet>
    with TickerProviderStateMixin {
  late final DeleteController _controller;

  int _currentStep = 0;
  bool _showSuccess = false;
  bool _hasNavigated = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _successController;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successFadeAnimation;

  final List<String> _warnings = [
    'Todos os seus posts serão deletados permanentemente',
    'Suas conexões e amizades serão removidas',
    'Seu histórico de atividades será apagado',
    'Esta ação não pode ser desfeita',
  ];

  @override
  void initState() {
    super.initState();

    _controller = Get.put(DeleteController());

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOut,
    ));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _successScaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _successFadeAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeIn,
    );

    _transitionController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionController.dispose();
    _successController.dispose();
    Get.delete<DeleteController>();
    super.dispose();
  }

  // ── Navegação entre steps ─────────────────────────────────────────────────

  void _nextStep() {
    if (_currentStep < 2) {
      _transitionController.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep++);
          _transitionController.forward();
        }
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _transitionController.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep--);
          _controller.reset();
          _transitionController.forward();
        }
      });
    }
  }

  // ── Ação principal ────────────────────────────────────────────────────────

  Future<void> _handleDelete() async {
    if (_hasNavigated) return;

    final ok = await _controller.confirmDelete();

    if (!ok) return;

    if (mounted) {
      setState(() => _showSuccess = true);
      _successController.forward();
    }

    await Future.delayed(const Duration(milliseconds: 2800));

    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = _controller.isLoading;

      return LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: constraints.maxHeight * 0.85,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TClubColors.bgAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TClubColors.border, width: 0.8),
            ),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _showSuccess
                    ? _buildSuccessState()
                    : Column(
                        key: const ValueKey('form'),
                        children: [
                          _buildHandle(),
                          _buildHeader(isLoading),
                          Expanded(
                            child: isLoading
                                ? _buildDeletingState()
                                : FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: SlideTransition(
                                      position: _slideAnimation,
                                      child: _buildStepContent(),
                                    ),
                                  ),
                          ),
                          _buildFooter(isLoading),
                        ],
                      ),
              ),
            ),
          );
        },
      );
    });
  }

  // ── Tela de sucesso ───────────────────────────────────────────────────────

  Widget _buildSuccessState() {
    return FadeTransition(
      key: const ValueKey('success'),
      opacity: _successFadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone animado
            ScaleTransition(
              scale: _successScaleAnimation,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF4CAF50),
                  size: 48,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Título
            const Text(
              'Conta excluída',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 12),

            // Mensagem
            Text(
              'Seus dados foram removidos com sucesso.\nEsperamos te ver por aqui novamente um dia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TClubColors.subtle,
                fontSize: 14,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 28),

            // Chip de despedida
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: TClubColors.bgCard,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: TClubColors.border),
              ),
              child: const Text(
                'Até logo 👋',
                style: TextStyle(
                  color: TClubColors.subtle,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Indicador de redirecionamento
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: TClubColors.subtle.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Redirecionando para o login...',
                  style: TextStyle(
                    color: TClubColors.subtle.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Componentes do formulário ─────────────────────────────────────────────

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: TClubColors.border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE85D5D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE85D5D).withOpacity(_pulseAnimation.value),
                  ),
                ),
                child: const Icon(Icons.warning_rounded, color: Color(0xFFE85D5D), size: 20),
              );
            },
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'EXCLUIR CONTA',
              style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize: 14,
                letterSpacing: 2,
                color: Color(0xFFE85D5D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: TClubColors.subtle),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 32),
          if (_currentStep == 0) _buildWarningStep(),
          if (_currentStep == 1) _buildConsequencesStep(),
          if (_currentStep == 2) _buildConfirmationStep(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final active = index <= _currentStep;
        return Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? const Color(0xFFE85D5D) : TClubColors.bgCard,
                border: Border.all(
                  color: active ? const Color(0xFFE85D5D) : TClubColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : TClubColors.subtle,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (index < 2)
              Container(
                width: 30,
                height: 2,
                color: index < _currentStep
                    ? const Color(0xFFE85D5D)
                    : TClubColors.border,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildWarningStep() {
    return Column(
      children: [
        const Text(
          'Ação Irreversível',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Você está prestes a excluir a conta de ${widget.userName}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: TClubColors.subtle, fontSize: 14),
        ),
        const SizedBox(height: 24),
        ..._warnings.map((w) => _buildInfoItem(w, Icons.error_outline)),
      ],
    );
  }

  Widget _buildConsequencesStep() {
    return Column(
      children: [
        const Text(
          'O que será removido?',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ..._warnings.map((w) => _buildInfoItem(w, Icons.remove_circle_outline)),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return Obx(() {
      final canDelete = _controller.canDelete.value;
      final obscure   = _controller.obscurePass.value;
      final hasError  = _controller.hasError;
      final errorMsg  = _controller.errorMessage.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Confirmação Final',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Digite sua senha para confirmar a exclusão:',
              textAlign: TextAlign.center,
              style: TextStyle(color: TClubColors.subtle, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          Material(
            color: Colors.transparent,
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: Color(0xFFE85D5D),
                  selectionColor: Color(0x44E85D5D),
                  selectionHandleColor: Color(0xFFE85D5D),
                ),
              ),
              child: TextField(
                controller: _controller.passwordController,
                obscureText: obscure,
                style: const TextStyle(color: TClubColors.dim, letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: TextStyle(color: TClubColors.subtle.withOpacity(0.5)),
                  filled: true,
                  fillColor: TClubColors.bgCard,
                  prefixIcon: const Icon(Icons.lock_outline, color: TClubColors.subtle, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: TClubColors.subtle,
                      size: 20,
                    ),
                    onPressed: _controller.toggleObscure,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: hasError
                          ? const Color(0xFFE85D5D)
                          : canDelete
                              ? const Color(0xFF4CAF50)
                              : TClubColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: hasError
                          ? const Color(0xFFE85D5D)
                          : canDelete
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE85D5D),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          if (hasError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFE85D5D), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(color: Color(0xFFE85D5D), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          if (canDelete && !hasError) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 16),
                SizedBox(width: 6),
                Text(
                  'Senha preenchida',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _buildInfoItem(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TClubColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE85D5D), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: TClubColors.subtle, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFE85D5D)),
          SizedBox(height: 24),
          Text(
            'EXCLUINDO CONTA...',
            style: TextStyle(color: Color(0xFFE85D5D), fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Aguarde, isso pode levar alguns segundos',
            style: TextStyle(color: TClubColors.subtle, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isLoading) {
    if (isLoading) return const SizedBox.shrink();

    return Obx(() {
      final canDelete = _controller.canDelete.value;

      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: TClubColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('VOLTAR', style: TextStyle(color: TClubColors.subtle)),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _currentStep < 2
                    ? _nextStep
                    : (canDelete ? _handleDelete : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 2 && !canDelete
                      ? TClubColors.bgCard
                      : const Color(0xFFE85D5D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep < 2 ? 'CONTINUAR' : 'DELETAR AGORA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

