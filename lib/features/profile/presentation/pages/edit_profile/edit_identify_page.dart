// lib/screens/screens_home/perfil_screen/edit_perfil/edit_identidade_page.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/helpers/media_permission_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/profile/controller/edit_identify_controller.dart';
import 'package:tclub/features/profile/data/repositories/identify_repository.dart';
import 'package:tclub/features/profile/data/services/identify_service.dart';
import 'package:tclub/features/profile/presentation/widgets/edit_profile_enums.dart';
import 'package:tclub/features/profile/presentation/widgets/edit_profile_shareds.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditIdentifyPage extends StatefulWidget {
  const EditIdentifyPage({super.key, required this.userData});
  final Map<String, dynamic> userData;

  @override
  State<EditIdentifyPage> createState() => _EditIdentifyPageState();
}

class _EditIdentifyPageState extends State<EditIdentifyPage> {
  final _formKey = GlobalKey<FormState>();

  late final EditIdentityController _controller;
  late final TextEditingController  _partnerNameCtrl;

  // ── FIX 1: skipTraversal=true impede que o campo volte a receber foco
  // automaticamente durante o traversal do teclado.
  final FocusNode _partnerNameFocus = FocusNode(skipTraversal: false);
  bool _partnerNameDone = false; // flag: usuário já confirmou o campo

  @override
  void initState() {
    super.initState();

    _controller = EditIdentityController(
      service: IdentityService(
        repository: IdentityRepository(db: FirebaseDatabase.instance),
      ),
      userData: widget.userData,
    );

    _partnerNameCtrl = TextEditingController(text: _controller.partnerName)
      ..addListener(() => _controller.setPartnerName(_partnerNameCtrl.text));

    // ── FIX 1: quando o campo perde foco, marcamos como "done"
    // e impedimos que qualquer scroll/rebuild devolva o foco a ele.
    _partnerNameFocus.addListener(() {
      if (!_partnerNameFocus.hasFocus && !_partnerNameDone) {
        _partnerNameDone = true;
      }
    });

    _controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _partnerNameCtrl.dispose();
    _partnerNameFocus.dispose();
    super.dispose();
  }

  // ── Listener ──────────────────────────────────────────────────────────────

  void _onControllerChange() {
    if (!mounted) return;

    if (_controller.saveStatus == SaveStatus.success) {
      Navigator.pop(context, _buildReturnPayload());
      return;
    }
    if (_controller.saveStatus == SaveStatus.error) {
      _snack(_controller.saveError ?? 'Erro ao salvar');
      _controller.resetSaveStatus();
    }

    setState(() {});
  }

  // ── Payload de retorno ────────────────────────────────────────────────────

  Map<String, dynamic> _buildReturnPayload() {
    final c = _controller;
    return {
      'gender_identity':    c.tipoPerfil?.name         ?? '',
      'sexual_orientation': c.orientacao?.name         ?? '',
      'relationship_type':  c.tipoRelacionamento?.name ?? '',
      'profile_type':       c.isCasal ? 'couple' : 'single',

      'tipoPerfil':         c.tipoPerfil?.name         ?? '',
      'tipoRelacionamento': c.tipoRelacionamento?.name ?? '',
      'orientacaoSexual':   c.orientacao?.name         ?? '',

      // ── FIX 3: inclui partner no payload mesmo quando não é casal
      // (null para limpar dados de um casal que virou solteiro)
      'partner': (c.isCasal && c.partnerValid)
          ? {
              'name':               c.partnerName,
              'birth_date':         _isoDate(c.partnerBirthDate!),
              'gender_identity':    c.partnerGender?.name       ?? '',
              'sexual_orientation': c.partnerOrientation?.name  ?? '',
              'avatar_url':         c.partnerAvatarUrl,
            }
          : null,
    };
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Save ──────────────────────────────────────────────────────────────────

  void _salvar() {
    // ── FIX 2: enquanto estiver fazendo upload ou salvando, bloqueia
    if (_controller.isSaving) return;

    if (!(_formKey.currentState?.validate() ?? true)) return;

    if (_controller.tipoPerfil == null) {
      _snack('Selecione seu gênero');
      return;
    }
    if (_controller.tipoRelacionamento == null) {
      _snack('Selecione seu relacionamento');
      return;
    }
    if (_controller.orientacao == null) {
      _snack('Selecione sua orientação sexual');
      return;
    }
    if (_controller.isCasal && !_controller.partnerValid) {
      _snack('Complete os dados do parceiro(a) — foto obrigatória');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { _snack('Usuário não autenticado'); return; }

    _controller.save(uid);
  }

  // ── FIX 2: intercepta o botão voltar enquanto salva
  Future<bool> _onWillPop() async {
    if (_controller.isSaving) {
      _snack('Aguarde o salvamento terminar...');
      return false;
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      content: Text(
        msg.toUpperCase(),
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 2, color: TClubColors.textoPrincipal,
        ),
      ),
    ));
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickTipo() async {
    final v = await OptionsSheet.show<TipoPerfil>(
      context: context, title: 'GÊNERO',
      options: TipoPerfil.values,
      current: _controller.tipoPerfil,
      label: (e) => e.label,
    );
    if (v != null) _controller.selectTipoPerfil(v);
  }

  Future<void> _pickRelacionamento() async {
    final v = await OptionsSheet.show<TipoRelacionamento>(
      context: context, title: 'TIPO DE RELACIONAMENTO',
      options: TipoRelacionamento.values,
      current: _controller.tipoRelacionamento,
      label: (e) => e.label,
    );
    if (v != null) _controller.selectTipoRelacionamento(v);
  }

  Future<void> _pickOrientacao() async {
    final v = await OptionsSheet.show<OrientacaoSexual>(
      context: context, title: 'ORIENTAÇÃO SEXUAL',
      options: OrientacaoSexual.values,
      current: _controller.orientacao,
      label: (e) => e.label,
    );
    if (v != null) _controller.selectOrientacao(v);
  }

  Future<void> _pickPartnerGender() async {
    final v = await OptionsSheet.show<TipoPerfil>(
      context: context, title: 'GÊNERO DO PARCEIRO(A)',
      options: TipoPerfil.values,
      current: _controller.partnerGender,
      label: (e) => e.label,
    );
    if (v != null) _controller.setPartnerGender(v);
  }

  Future<void> _pickPartnerOrientation() async {
    final v = await OptionsSheet.show<OrientacaoSexual>(
      context: context, title: 'ORIENTAÇÃO DO PARCEIRO(A)',
      options: OrientacaoSexual.values,
      current: _controller.partnerOrientation,
      label: (e) => e.label,
    );
    if (v != null) _controller.setPartnerOrientation(v);
  }

  Future<void> _pickPartnerAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AvatarSourceSheet(),
    );
    if (source == null || !mounted) return;
    if (!await requestMediaPermission(context, source)) return;

    final picked = await ImagePicker().pickImage(
      source:       source,
      maxWidth:     800,
      maxHeight:    800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    _controller.setPartnerAvatarFile(File(picked.path));
  }

  Future<void> _pickPartnerBirthDate() async {
    final escolhida = await showModalBottomSheet<DateTime>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AniversarioSheet(
        initialDate: _controller.partnerBirthDate,
      ),
    );
    if (escolhida != null) _controller.setPartnerBirthDate(escolhida);
  }

  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // ── FIX 2: overlay de loading durante o save
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          EditPageScaffold(
            title:  'IDENTIDADE',
            onSave: _controller.isSaving ? null : _salvar,
            busy:   _controller.isSaving,
            child: GestureDetector(
              onTap: () {
                // ── FIX 1: ao tocar fora, remove foco e marca como done
                _partnerNameDone = true;
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.translucent,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BlocoFormulario(
                        titulo: 'SOBRE VOCÊ',
                        campos: [
                          _CampoSelecao(
                            rotulo:  'GÊNERO',
                            icone:   Icons.person_outline,
                            valor:   _controller.tipoPerfil?.label,
                            dica:    'Selecione seu gênero',
                            aoTocar: _pickTipo,
                          ),
                          _CampoSelecao(
                            rotulo:  'RELACIONAMENTO',
                            icone:   Icons.favorite_outline_rounded,
                            valor:   _controller.tipoRelacionamento?.label,
                            dica:    'Solteiro, Casal, etc.',
                            aoTocar: _pickRelacionamento,
                          ),
                          _CampoSelecao(
                            rotulo:  'ORIENTAÇÃO SEXUAL',
                            icone:   Icons.diversity_1_outlined,
                            valor:   _controller.orientacao?.label,
                            dica:    'Selecione sua orientação',
                            aoTocar: _pickOrientacao,
                          ),
                        ],
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve:    Curves.easeOut,
                        child: _controller.isCasal
                            ? Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: _BlocoParceiro(
                                  partnerNameCtrl:   _partnerNameCtrl,
                                  partnerNameFocus:  _partnerNameFocus,
                                  controller:        _controller,
                                  onPickGender:      _pickPartnerGender,
                                  onPickOrientation: _pickPartnerOrientation,
                                  onPickBirthDate:   _pickPartnerBirthDate,
                                  onPickAvatar:      _pickPartnerAvatar,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── FIX 2: overlay bloqueante com loading durante upload/save
          if (_controller.isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: TClubColors.bgCard,
                      border: Border.all(color: TClubColors.border, width: 0.8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: TClubColors.redPrincipal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SALVANDO...',
                          style: TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: TClubColors.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _controller.isCasal
                              ? 'Enviando foto do parceiro(a)'
                              : 'Aguarde um momento',
                          style: const TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 11,
                            color: TClubColors.subtle,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BLOCO DE FORMULÁRIO
// ════════════════════════════════════════════════════════════════════════════
class _BlocoFormulario extends StatelessWidget {
  const _BlocoFormulario({required this.titulo, required this.campos});
  final String       titulo;
  final List<Widget> campos;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [TClubColors.redPrincipal, TClubColors.redDeep],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(titulo, style: const TextStyle(
          fontFamily: TClubTypography.bodyFont, fontSize: 9,
          fontWeight: FontWeight.w800, letterSpacing: 3.5,
          color: TClubColors.redPrincipal,
        )),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color:  TClubColors.bgCard,
          border: Border.all(color: TClubColors.border, width: 0.8),
        ),
        child: Column(
          children: campos.asMap().entries.map((e) {
            final ultimo = e.key == campos.length - 1;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              e.value,
              if (!ultimo) Container(height: 0.5, color: TClubColors.border),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CAMPO DE SELEÇÃO
// ════════════════════════════════════════════════════════════════════════════
class _CampoSelecao extends StatelessWidget {
  const _CampoSelecao({
    required this.rotulo, required this.icone,
    required this.dica,   required this.aoTocar,
    this.valor,
  });
  final String       rotulo;
  final IconData     icone;
  final String       dica;
  final String?      valor;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tem = valor != null && valor!.isNotEmpty;
    return InkWell(
      onTap:          aoTocar,
      splashColor:    TClubColors.redPrincipal.withOpacity(0.06),
      highlightColor: TClubColors.redPrincipal.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icone, size: 16,
              color: tem ? TClubColors.redPrincipal : TClubColors.subtle),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo, style: const TextStyle(
                fontFamily: TClubTypography.bodyFont, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 2.5,
                color: TClubColors.subtle,
              )),
              const SizedBox(height: 2),
              Text(tem ? valor! : dica, style: TextStyle(
                fontFamily: TClubTypography.bodyFont, fontSize: 14,
                fontWeight: tem ? FontWeight.w600 : FontWeight.w400,
                color: tem ? TClubColors.textoPrincipal : TClubColors.subtle,
              )),
            ],
          )),
          Icon(Icons.chevron_right_rounded, size: 18,
              color: tem
                  ? TClubColors.redPrincipal.withOpacity(0.6)
                  : TClubColors.subtle.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BLOCO PARCEIRO(A)
// ════════════════════════════════════════════════════════════════════════════
class _BlocoParceiro extends StatelessWidget {
  const _BlocoParceiro({
    required this.partnerNameCtrl,
    required this.partnerNameFocus,
    required this.controller,
    required this.onPickGender,
    required this.onPickOrientation,
    required this.onPickBirthDate,
    required this.onPickAvatar,
  });

  final TextEditingController  partnerNameCtrl;
  final FocusNode              partnerNameFocus;
  final EditIdentityController controller;
  final VoidCallback           onPickGender;
  final VoidCallback           onPickOrientation;
  final VoidCallback           onPickBirthDate;
  final VoidCallback           onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final aniLabel    = controller.partnerBirthDateLabel;
    final avatarFile  = controller.partnerAvatarFile;
    final avatarUrl   = controller.partnerAvatarUrl;
    final hasAvatar   = avatarFile != null || avatarUrl.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TClubColors.redPrincipal.withOpacity(0.07),
          border: Border.all(
            color: TClubColors.redPrincipal.withOpacity(0.25),
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded,
              color: TClubColors.redPrincipal.withOpacity(0.75), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize:   11,
                  height:     1.55,
                  color:      TClubColors.dim,
                ),
                children: const [
                  TextSpan(text: 'A foto do(a) parceiro(a) '),
                  TextSpan(
                    text: 'aparecerá no card de match',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:      TClubColors.textoPrincipal,
                    ),
                  ),
                  TextSpan(text: ' junto com a sua foto, identificando que vocês são um casal.'),
                ],
              ),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              TClubColors.redDeep.withOpacity(0.60),
              TClubColors.redDeep.withOpacity(0.30),
            ],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          border: Border.all(color: TClubColors.borderMid, width: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        child: Row(children: [
          const Icon(Icons.people_alt_outlined,
              color: TClubColors.redPrincipal, size: 16),
          const SizedBox(width: 10),
          const Expanded(child: Text('DADOS DO PARCEIRO(A)',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 3,
              color: TClubColors.redPrincipal,
            ),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:  TClubColors.redPrincipal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: TClubColors.border, width: 0.6),
            ),
            child: const Text('OBRIGATÓRIO', style: TextStyle(
              fontFamily: TClubTypography.bodyFont, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 2,
              color: TClubColors.redClaro,
            )),
          ),
        ]),
      ),

      Container(
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border(
            left:   BorderSide(color: TClubColors.borderMid, width: 0.8),
            right:  BorderSide(color: TClubColors.borderMid, width: 0.8),
            bottom: BorderSide(color: TClubColors.borderMid, width: 0.8),
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        ),
        child: Column(children: [

          InkWell(
            onTap:          onPickAvatar,
            splashColor:    TClubColors.redPrincipal.withOpacity(0.06),
            highlightColor: TClubColors.redPrincipal.withOpacity(0.03),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Stack(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color:  TClubColors.bg,
                      shape:  BoxShape.circle,
                      border: Border.all(
                        color: hasAvatar
                            ? TClubColors.redPrincipal.withOpacity(0.5)
                            : TClubColors.border,
                        width: hasAvatar ? 1.5 : 0.8,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarFile != null
                          ? Image.file(avatarFile, fit: BoxFit.cover)
                          : avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: CloudinaryHelper.avatarUrl(avatarUrl),
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 200),
                                  placeholder: (_, __) => _avatarPlaceholder(),
                                  errorWidget: (_, __, ___) => _avatarPlaceholder())
                              : _avatarPlaceholder(),
                    ),
                  ),
                  if (!hasAvatar)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color:  const Color(0xFFE05A5A),
                          shape:  BoxShape.circle,
                          border: Border.all(color: TClubColors.bgCard, width: 1.5),
                        ),
                        child: const Icon(Icons.priority_high_rounded,
                            size: 11, color: Colors.white),
                      ),
                    ),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('FOTO', style: TextStyle(
                        fontFamily: TClubTypography.bodyFont, fontSize: 9,
                        fontWeight: FontWeight.w700, letterSpacing: 2.5,
                        color: TClubColors.subtle,
                      )),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFE05A5A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFE05A5A).withOpacity(0.35),
                            width: 0.6,
                          ),
                        ),
                        child: const Text('OBRIGATÓRIA', style: TextStyle(
                          fontFamily: TClubTypography.bodyFont, fontSize: 7,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5,
                          color: Color(0xFFE05A5A),
                        )),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      hasAvatar ? 'Toque para alterar a foto' : 'Adicionar foto do(a) parceiro(a)',
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize:   14,
                        fontWeight: hasAvatar ? FontWeight.w600 : FontWeight.w400,
                        color: hasAvatar ? TClubColors.textoPrincipal : TClubColors.subtle,
                      ),
                    ),
                  ],
                )),
                Icon(Icons.chevron_right_rounded, size: 18,
                    color: hasAvatar
                        ? TClubColors.redPrincipal.withOpacity(0.6)
                        : TClubColors.subtle.withOpacity(0.5)),
              ]),
            ),
          ),

          Container(height: 0.5, color: TClubColors.border),

          // ── FIX 1: campo de nome com textInputAction.done
          // e onFieldSubmitted que remove o foco definitivamente
          _CampoTextoInterno(
            controlador:       partnerNameCtrl,
            foco:              partnerNameFocus,
            rotulo:            'NOME DE USUÁRIO',
            dica:              'Nome do(a) parceiro(a)',
            icone:             Icons.person_outline,
            textInputAction:   TextInputAction.done,
            onFieldSubmitted:  (_) {
              partnerNameFocus.unfocus();
            },
            validador: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Nome obrigatório' : null,
          ),

          Container(height: 0.5, color: TClubColors.border),
          _CampoSelecao(
            rotulo:  'GÊNERO',
            icone:   Icons.person_outline,
            valor:   controller.partnerGender?.label,
            dica:    'Selecione o gênero',
            aoTocar: onPickGender,
          ),
          Container(height: 0.5, color: TClubColors.border),
          _CampoSelecao(
            rotulo:  'ANIVERSÁRIO',
            icone:   Icons.cake_outlined,
            valor:   aniLabel.isEmpty ? null : aniLabel,
            dica:    'Selecione — maior de 18 anos',
            aoTocar: onPickBirthDate,
          ),
          Container(height: 0.5, color: TClubColors.border),
          _CampoSelecao(
            rotulo:  'ORIENTAÇÃO SEXUAL',
            icone:   Icons.favorite_border_rounded,
            valor:   controller.partnerOrientation?.label,
            dica:    'Selecione a orientação',
            aoTocar: onPickOrientation,
          ),
        ]),
      ),

      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.lock_outline_rounded,
            color: TClubColors.subtle, size: 12),
        const SizedBox(width: 6),
        Text(
          'Os dados pessoais do parceiro(a) são privados.',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont, fontSize: 10,
            color: TClubColors.subtle.withOpacity(0.7), letterSpacing: 0.3,
          ),
        ),
      ]),
    ]);
  }

  Widget _avatarPlaceholder() => Container(
    color: const Color(0xFF1A1A1A),
    child: Icon(Icons.person_outline_rounded,
        size: 26, color: Colors.white.withOpacity(0.15)),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SHEET — ORIGEM DA FOTO
// ════════════════════════════════════════════════════════════════════════════
class _AvatarSourceSheet extends StatelessWidget {
  const _AvatarSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        TClubColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: TClubColors.borderMid, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color:        TClubColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _SheetSourceOption(
            icon:  Icons.photo_library_outlined,
            label: 'Galeria',
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          Container(height: 0.5, color: TClubColors.borderMid),
          _SheetSourceOption(
            icon:  Icons.camera_alt_outlined,
            label: 'Câmera',
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  color:        TClubColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: TClubColors.borderMid, width: 0.7),
                ),
                child: Center(child: Text('Cancelar', style: TextStyle(
                  fontFamily: TClubTypography.bodyFont, fontSize: 15,
                  fontWeight: FontWeight.w500, color: TClubColors.subtle,
                ))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SheetSourceOption extends StatelessWidget {
  const _SheetSourceOption({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        TClubColors.redPrincipal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(
                color: TClubColors.redPrincipal.withOpacity(0.25),
                width: 0.7,
              ),
            ),
            child: Icon(icon, color: TClubColors.redPrincipal, size: 18),
          ),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(
            fontFamily: TClubTypography.bodyFont, fontSize: 15,
            fontWeight: FontWeight.w500, color: TClubColors.textoPrincipal,
          )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SELETOR DE ANIVERSÁRIO
// ════════════════════════════════════════════════════════════════════════════
class _AniversarioSheet extends StatefulWidget {
  const _AniversarioSheet({this.initialDate});
  final DateTime? initialDate;

  @override
  State<_AniversarioSheet> createState() => _AniversarioSheetState();
}

class _AniversarioSheetState extends State<_AniversarioSheet> {
  static const _meses = [
    'Jan','Fev','Mar','Abr','Mai','Jun',
    'Jul','Ago','Set','Out','Nov','Dez',
  ];
  static const _itemExtent  = 44.0;
  static const _alturaRoda  = 220.0;

  final int _anoMin = 1940;
  late final int _anoMax;

  late int _dia;
  late int _mes;
  late int _ano;

  late final FixedExtentScrollController _ctrlDia;
  late final FixedExtentScrollController _ctrlMes;
  late final FixedExtentScrollController _ctrlAno;

  int get _maxDias => DateTime(_ano, _mes + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _anoMax = DateTime.now().year - 18;
    final ref = widget.initialDate ?? DateTime(_anoMax - 5, 6, 15);
    _ano = ref.year.clamp(_anoMin, _anoMax);
    _mes = ref.month;
    _dia = ref.day.clamp(1, DateTime(_ano, _mes + 1, 0).day);
    _ctrlDia = FixedExtentScrollController(initialItem: _dia - 1);
    _ctrlMes = FixedExtentScrollController(initialItem: _mes - 1);
    _ctrlAno = FixedExtentScrollController(initialItem: _ano - _anoMin);
  }

  @override
  void dispose() {
    _ctrlDia.dispose(); _ctrlMes.dispose(); _ctrlAno.dispose();
    super.dispose();
  }

  void _onDiaChanged(int i) { HapticFeedback.selectionClick(); setState(() => _dia = i + 1); }
  void _onMesChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _mes = i + 1;
      final max = _maxDias;
      if (_dia > max) {
        _dia = max;
        Future.microtask(() => _ctrlDia.animateToItem(_dia - 1,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
      }
    });
  }
  void _onAnoChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _ano = _anoMin + i;
      final max = _maxDias;
      if (_dia > max) {
        _dia = max;
        Future.microtask(() => _ctrlDia.animateToItem(_dia - 1,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
      }
    });
  }

  void _confirmar() => Navigator.pop(context, DateTime(_ano, _mes, _dia));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TClubColors.bgAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(width: 36, height: 3,
                decoration: BoxDecoration(color: TClubColors.borderMid,
                    borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(children: [
              Container(width: 3, height: 14,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [TClubColors.redPrincipal, TClubColors.redDeep]),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('ANIVERSÁRIO DO PARCEIRO(A)', style: TextStyle(
                fontFamily: TClubTypography.bodyFont, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 3,
                color: TClubColors.redPrincipal)),
            ]),
          ),
          Container(height: 0.5, color: TClubColors.border),
          SizedBox(
            height: _alturaRoda,
            child: Stack(alignment: Alignment.center, children: [
              IgnorePointer(child: Container(height: _itemExtent,
                  decoration: BoxDecoration(
                    color: TClubColors.redPrincipal.withOpacity(0.07),
                    border: Border.symmetric(horizontal: BorderSide(
                      color: TClubColors.redPrincipal.withOpacity(0.25), width: 0.8))))),
              Positioned(top: 0, left: 0, right: 0, height: 70,
                  child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [TClubColors.bgAlt, TClubColors.bgAlt.withOpacity(0)]))))),
              Positioned(bottom: 0, left: 0, right: 0, height: 70,
                  child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [TClubColors.bgAlt, TClubColors.bgAlt.withOpacity(0)]))))),
              Row(children: [
                Expanded(flex: 2, child: _buildRoda(controller: _ctrlDia, count: _maxDias,
                    labelOf: (i) => '${i+1}'.padLeft(2,'0'), onChanged: _onDiaChanged, label: 'DIA')),
                Container(width: 0.5, height: _alturaRoda, color: TClubColors.border),
                Expanded(flex: 3, child: _buildRoda(controller: _ctrlMes, count: 12,
                    labelOf: (i) => _meses[i], onChanged: _onMesChanged, label: 'MÊS')),
                Container(width: 0.5, height: _alturaRoda, color: TClubColors.border),
                Expanded(flex: 3, child: _buildRoda(controller: _ctrlAno, count: _anoMax - _anoMin + 1,
                    labelOf: (i) => '${_anoMin+i}', onChanged: _onAnoChanged, label: 'ANO')),
              ]),
            ]),
          ),
          Container(height: 0.5, color: TClubColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: GestureDetector(
              onTap: _confirmar,
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  color: TClubColors.redPrincipal,
                  boxShadow: [BoxShadow(color: TClubColors.glow.withOpacity(0.35),
                      blurRadius: 16, offset: const Offset(0, 4))]),
                child: const Center(child: Text('CONFIRMAR', style: TextStyle(
                  fontFamily: TClubTypography.bodyFont, fontSize: 13,
                  fontWeight: FontWeight.w800, letterSpacing: 3,
                  color: TClubColors.textoPrincipal))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRoda({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) labelOf,
    required ValueChanged<int> onChanged,
    required String label,
  }) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(label, style: TextStyle(fontFamily: TClubTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: TClubColors.redPrincipal.withOpacity(0.6))),
      ),
      Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller, itemExtent: _itemExtent,
          physics: const FixedExtentScrollPhysics(),
          perspective: 0.003, diameterRatio: 1.6,
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (_, i) {
              final isCenter = i == (controller.hasClients
                  ? controller.selectedItem : controller.initialItem);
              return Center(child: Text(labelOf(i), style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize:   isCenter ? 24 : 16,
                fontWeight: isCenter ? FontWeight.w700 : FontWeight.w400,
                color:      isCenter ? TClubColors.textoPrincipal : TClubColors.subtle,
              )));
            },
          ),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CAMPO DE TEXTO — FIX 1: expõe textInputAction e onFieldSubmitted
// ════════════════════════════════════════════════════════════════════════════
class _CampoTextoInterno extends StatefulWidget {
  const _CampoTextoInterno({
    required this.controlador,
    required this.foco,
    required this.rotulo,
    required this.dica,
    required this.icone,
    this.validador,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });
  final TextEditingController      controlador;
  final FocusNode                  foco;
  final String                     rotulo;
  final String                     dica;
  final IconData                   icone;
  final String? Function(String?)? validador;
  final TextInputAction             textInputAction;
  final ValueChanged<String>?      onFieldSubmitted;

  @override
  State<_CampoTextoInterno> createState() => _CampoTextoInternoEstado();
}

class _CampoTextoInternoEstado extends State<_CampoTextoInterno> {
  bool _focado = false;

  @override
  void initState() {
    super.initState();
    widget.foco.addListener(() {
      if (mounted) setState(() => _focado = widget.foco.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(widget.icone, size: 16,
            color: _focado ? TClubColors.redPrincipal : TClubColors.subtle),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(
          controller:         widget.controlador,
          focusNode:          widget.foco,
          validator:          widget.validador,
          maxLength:          40,
          textCapitalization: TextCapitalization.words,
          textInputAction:    widget.textInputAction,   // ← FIX 1
          onFieldSubmitted:   widget.onFieldSubmitted,  // ← FIX 1
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 14, fontWeight: FontWeight.w500,
            color: TClubColors.textoPrincipal,
          ),
          cursorColor: TClubColors.redPrincipal,
          decoration: InputDecoration(
            labelText:     widget.rotulo,
            hintText:      widget.dica,
            counterText:   '',
            border:        InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder:   InputBorder.none,
            filled:        false,
            labelStyle: TextStyle(
              fontFamily: TClubTypography.bodyFont, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 2.5,
              color: _focado ? TClubColors.redPrincipal : TClubColors.subtle,
            ),
            hintStyle: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 14, color: TClubColors.subtle,
            ),
            errorStyle: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10, letterSpacing: 0.8,
              color: Color(0xFFE85D5D),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        )),
      ]),
    );
  }
}

