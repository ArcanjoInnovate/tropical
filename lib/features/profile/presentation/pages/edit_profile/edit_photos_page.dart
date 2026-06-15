// lib/features/profile/presentation/pages/edit_photos_page.dart

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/helpers/media_permission_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';

import 'package:tclub/features/profile/controller/edit_photo_controller.dart';
import 'package:tclub/features/profile/data/repositories/photo_repository.dart';
import 'package:tclub/features/profile/data/services/photo_service.dart';
import 'package:tclub/features/profile/presentation/widgets/edit_profile_shareds.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════
class EditPhotosPage extends StatefulWidget {
  const EditPhotosPage({super.key, required this.userData});

  /// Snapshot completo de Users/{uid} vindo da tela anterior.
  final Map<String, dynamic> userData;

  @override
  State<EditPhotosPage> createState() => _EditPhotosPageState();
}

class _EditPhotosPageState extends State<EditPhotosPage> {
  late final EditPhotosController _ctrl;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    _ctrl = EditPhotosController(
      service: PhotosService(
        repository: PhotosRepository(db: FirebaseDatabase.instance),
      ),
      currentAvatarUrl: widget.userData['avatar'] as String? ?? '',
    )..addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChange);
    _ctrl.dispose();
    super.dispose();
  }

  // ── Reações ao controller ─────────────────────────────────────────────────

  void _onControllerChange() {
    if (!mounted) return;

    if (_ctrl.isSuccess) {
      // Captura a URL antes de resetar o status
      final novaUrl = _ctrl.avatarUrl;
      final temFoto = _ctrl.hasAvatar;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            temFoto ? 'Foto atualizada!' : 'Foto removida.',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 13,
              color: TClubColors.textoPrincipal,
            ),
          ),
          backgroundColor: TClubColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: TClubColors.redPrincipal.withOpacity(0.4)),
          ),
        ),
      );
      _ctrl.resetStatus();

      // Usa addPostFrameCallback para garantir que o pop ocorre
      // fora do ciclo de notifyListeners/rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, {'avatar': novaUrl});
      });
      return;
    }

    if (_ctrl.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _ctrl.errorMessage ?? 'Erro ao processar foto.',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 13,
              color: TClubColors.textoPrincipal,
            ),
          ),
          backgroundColor: const Color(0xFF3A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE85D5D), width: 0.6),
          ),
        ),
      );
      _ctrl.resetStatus();
    }
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  void _showPickSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickSheet(
        onGallery: () async {
          Navigator.pop(context);
          if (!await requestMediaPermission(context, ImageSource.gallery)) return;
          _ctrl.pickFromGallery(_uid);
        },
        onCamera: () async {
            Navigator.pop(context);
            if (!await requestMediaPermission(context, ImageSource.camera)) return;
            _ctrl.pickFromCamera(_uid);
          },
      ),
    );
  }

  void _confirmRemove() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmRemoveSheet(
        onConfirm: () {
          Navigator.pop(context);
          _ctrl.removeAvatar(_uid);
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return EditPageScaffold(
          title: 'FOTOS',
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── TÍTULO DA SEÇÃO ─────────────────────────────────────
                const SectionLabel(label: 'FOTO DE PERFIL'),
                const SizedBox(height: 20),

                // ── CARD PRINCIPAL ──────────────────────────────────────
                _MainPhotoCard(
                  ctrl:         _ctrl,
                  onTapChange:  _ctrl.isBusy ? null : _showPickSheet,
                  onTapRemove:  (_ctrl.isBusy || !_ctrl.hasAvatar)
                                    ? null
                                    : _confirmRemove,
                ),

                const SizedBox(height: 20),

                // ── INFO BOX ────────────────────────────────────────────
                const InfoBox(
                  text: 'Esta foto é usada como imagem principal no match — '
                      'é a primeira coisa que outras pessoas veem. '
                      'Escolha uma foto nítida e que represente você.',
                ),

                const SizedBox(height: 32),

                // ── FUTURAS OPÇÕES ──────────────────────────────────────
                const SectionLabel(label: 'MAIS FOTOS'),
                const SizedBox(height: 16),
                _ComingSoonGrid(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CARD PRINCIPAL DA FOTO
// ════════════════════════════════════════════════════════════════════════════
class _MainPhotoCard extends StatelessWidget {
  const _MainPhotoCard({
    required this.ctrl,
    required this.onTapChange,
    required this.onTapRemove,
  });

  final EditPhotosController ctrl;
  final VoidCallback?         onTapChange;
  final VoidCallback?         onTapRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Preview ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: onTapChange,
          child: Container(
            width:  double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color:  TClubColors.bgCard,
              border: Border.all(
                color: ctrl.hasAvatar
                    ? TClubColors.redPrincipal.withOpacity(0.5)
                    : TClubColors.border,
                width: ctrl.hasAvatar ? 1.5 : 0.8,
              ),
            ),
            child: _buildPreviewContent(),
          ),
        ),

        const SizedBox(height: 12),

        // ── Botões ───────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _PhotoActionBtn(
                icon:    Icons.add_a_photo_outlined,
                label:   ctrl.hasAvatar ? 'TROCAR FOTO' : 'ADICIONAR FOTO',
                primary: true,
                busy:    ctrl.isUploading,
                onTap:   onTapChange,
              ),
            ),
            if (ctrl.hasAvatar) ...[
              const SizedBox(width: 10),
              _PhotoActionBtn(
                icon:    Icons.delete_outline_rounded,
                label:   'REMOVER',
                primary: false,
                busy:    ctrl.isRemoving,
                onTap:   onTapRemove,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewContent() {
    // Uploading — mostra preview local + barra de progresso
    if (ctrl.isUploading && ctrl.pendingFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(localFile: ctrl.pendingFile),
          // Overlay escuro
          Container(color: Colors.black.withOpacity(0.55)),
          // Progresso
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width:  56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value:       ctrl.uploadProgress,
                    color:       TClubColors.redPrincipal,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white.withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ENVIANDO ${(ctrl.uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontFamily:    TClubTypography.bodyFont,
                    fontSize:      11,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2.5,
                    color:         Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Removing
    if (ctrl.isRemoving) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: TClubColors.redPrincipal, strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'REMOVENDO...',
              style: TextStyle(
                fontFamily:    TClubTypography.bodyFont,
                fontSize:      10,
                letterSpacing: 2.5,
                color:         TClubColors.subtle,
              ),
            ),
          ],
        ),
      );
    }

    // Tem avatar salvo
    if (ctrl.hasAvatar) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(url: ctrl.avatarUrl),
          // Badge "foto principal"
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:  Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.6),
                  width: 0.7,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: 11, color: TClubColors.redPrincipal),
                  const SizedBox(width: 5),
                  const Text(
                    'FOTO PRINCIPAL',
                    style: TextStyle(
                      fontFamily:    TClubTypography.bodyFont,
                      fontSize:      9,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 2,
                      color:         Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Ícone de editar no canto
          Positioned(
            bottom: 12, right: 12,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:  Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2), width: 0.6),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size:  16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Sem avatar — placeholder
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TClubColors.redPrincipal.withOpacity(0.08),
            border: Border.all(
              color: TClubColors.redPrincipal.withOpacity(0.3), width: 1),
          ),
          child: Icon(
            Icons.add_a_photo_outlined,
            size:  26,
            color: TClubColors.redPrincipal.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Toque para adicionar\numa foto',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize:   13,
            height:     1.6,
            color:      TClubColors.subtle,
          ),
        ),
      ],
    );
  }

  Widget _buildImage({String? url, XFile? localFile}) {
    if (localFile != null) {
      if (kIsWeb) {
        return Image.network(localFile.path, fit: BoxFit.cover);
      }
      return Image.file(File(localFile.path), fit: BoxFit.cover);
    }
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: CloudinaryHelper.optimizeImageUrl(url),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => _loadingPlaceholder(),
        errorWidget: (_, __, ___) => _errorPlaceholder(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _loadingPlaceholder() => Center(
    child: SizedBox(
      width: 24, height: 24,
      child: CircularProgressIndicator(
        color: TClubColors.redPrincipal.withOpacity(0.5),
        strokeWidth: 1.5,
      ),
    ),
  );

  Widget _errorPlaceholder() => Center(
    child: Icon(
      Icons.broken_image_outlined,
      size:  36,
      color: TClubColors.subtle,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTÃO DE AÇÃO DA FOTO
// ════════════════════════════════════════════════════════════════════════════
class _PhotoActionBtn extends StatelessWidget {
  const _PhotoActionBtn({
    required this.icon,
    required this.label,
    required this.primary,
    required this.busy,
    required this.onTap,
  });

  final IconData      icon;
  final String        label;
  final bool          primary;
  final bool          busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null && !busy;
    final Color fg = primary
        ? (active ? TClubColors.textoPrincipal      : TClubColors.subtle)
        : (active ? const Color(0xFFE85D5D) : TClubColors.subtle);
    final Color bg = primary
        ? (active ? TClubColors.redPrincipal : TClubColors.bgCard)
        : TClubColors.bgCard;
    final Color border = primary
        ? (active ? TClubColors.redPrincipal : TClubColors.border)
        : (active ? const Color(0xFFE85D5D).withOpacity(0.5) : TClubColors.border);

    return GestureDetector(
      onTap: active ? () {
        HapticFeedback.selectionClick();
        onTap!();
      } : null,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color:  bg,
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                  color: TClubColors.redPrincipal, strokeWidth: 1.5),
              )
            else
              Icon(icon, size: 14, color: fg),
            const SizedBox(width: 8),
            Text(
              busy ? '...' : label,
              style: TextStyle(
                fontFamily:    TClubTypography.bodyFont,
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                letterSpacing: 2,
                color:         busy ? TClubColors.subtle : fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GRADE "EM BREVE"
// ════════════════════════════════════════════════════════════════════════════
class _ComingSoonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aviso
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:  TClubColors.bgCard,
            border: Border.all(color: TClubColors.border, width: 0.8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size:  14,
                color: TClubColors.redPrincipal.withOpacity(0.7),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Em atualizações futuras você poderá adicionar mais fotos '
                  'ao seu perfil, criar álbuns e definir a ordem de exibição.',
                  style: TextStyle(
                    fontFamily:    TClubTypography.bodyFont,
                    fontSize:      11,
                    height:        1.6,
                    letterSpacing: 0.3,
                    color:         TClubColors.subtle,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Grid de slots bloqueados
        GridView.builder(
          shrinkWrap: true,
          physics:    const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing:  8,
            childAspectRatio: 0.85,
          ),
          itemCount: 6,
          itemBuilder: (_, i) => _LockedSlot(index: i + 2),
        ),
      ],
    );
  }
}

class _LockedSlot extends StatelessWidget {
  const _LockedSlot({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:  TClubColors.bgCard,
        border: Border.all(color: TClubColors.border, width: 0.6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size:  20,
            color: TClubColors.border,
          ),
          const SizedBox(height: 6),
          Text(
            'Foto $index',
            style: const TextStyle(
              fontFamily:    TClubTypography.bodyFont,
              fontSize:      9,
              letterSpacing: 1.5,
              color:         TClubColors.border,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'EM BREVE',
            style: TextStyle(
              fontFamily:    TClubTypography.bodyFont,
              fontSize:      8,
              letterSpacing: 1.5,
              color:         TClubColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SHEET — ESCOLHER ORIGEM DA FOTO
// ════════════════════════════════════════════════════════════════════════════
class _PickSheet extends StatelessWidget {
  const _PickSheet({required this.onGallery, this.onCamera});

  final VoidCallback  onGallery;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        TClubColors.bgAlt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: TClubColors.border, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 3,
                decoration: BoxDecoration(
                  color:        TClubColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const SectionLabel(label: 'ESCOLHER FOTO'),
              ),
            ),
            Container(height: 0.5, color: TClubColors.border),

            _SheetOption(
              icon:  Icons.photo_library_outlined,
              label: 'Galeria de fotos',
              onTap: onGallery,
            ),

            if (onCamera != null) ...[
              Container(height: 0.5, color: TClubColors.border),
              _SheetOption(
                icon:  Icons.camera_alt_outlined,
                label: 'Câmera',
                onTap: onCamera!,
              ),
            ],

            Container(height: 0.5, color: TClubColors.border),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width:  double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color:  TClubColors.bgCard,
                    border: Border.all(color: TClubColors.border, width: 0.7),
                  ),
                  child: const Center(
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize:   14,
                        color:      TClubColors.subtle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SHEET — CONFIRMAR REMOÇÃO
// ════════════════════════════════════════════════════════════════════════════
class _ConfirmRemoveSheet extends StatelessWidget {
  const _ConfirmRemoveSheet({required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        TClubColors.bgAlt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: TClubColors.border, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36, height: 3,
                decoration: BoxDecoration(
                  color: TClubColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Remover foto de perfil?',
                style: TextStyle(
                  fontFamily: TClubTypography.displayFont,
                  fontSize:   16,
                  color:      TClubColors.textoPrincipal,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Seu perfil ficará sem foto até você adicionar uma nova. '
                'Isso pode afetar sua visibilidade no match.',
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize:   13,
                  height:     1.6,
                  color:      TClubColors.subtle,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color:  TClubColors.bgCard,
                          border: Border.all(color: TClubColors.border, width: 0.7),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize:   14,
                              color:      TClubColors.subtle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color:  const Color(0xFF3A1A1A),
                          border: Border.all(
                            color: const Color(0xFFE85D5D).withOpacity(0.6),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'REMOVER',
                            style: TextStyle(
                              fontFamily:    TClubTypography.bodyFont,
                              fontSize:      12,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: 2.5,
                              color:         Color(0xFFE85D5D),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  OPÇÃO DO SHEET
// ════════════════════════════════════════════════════════════════════════════
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      highlightColor: TClubColors.redPrincipal.withOpacity(0.05),
      splashColor:    TClubColors.redPrincipal.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:  TClubColors.redPrincipal.withOpacity(0.10),
                border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.25), width: 0.7),
              ),
              child: Icon(icon, color: TClubColors.redPrincipal, size: 18),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize:   15,
                fontWeight: FontWeight.w500,
                color:      TClubColors.textoPrincipal,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: TClubColors.subtle,
              size:  20,
            ),
          ],
        ),
      ),
    );
  }
}

