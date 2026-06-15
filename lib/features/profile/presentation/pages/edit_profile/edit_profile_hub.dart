// lib/screens/screens_home/perfil_screen/editar_perfil/pages/hub_editar_perfil.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/helpers/media_permission_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/profile/controller/edit_avatar_controller.dart';
import 'package:tclub/features/profile/presentation/pages/edit_profile/edit_identify_page.dart';
import 'package:tclub/features/profile/presentation/pages/edit_profile/edit_interests_page.dart';
import 'package:tclub/features/profile/presentation/pages/edit_profile/edit_location_page.dart';
import 'package:tclub/features/profile/presentation/pages/edit_profile/edit_personal_page.dart';
import 'package:tclub/features/profile/presentation/pages/edit_profile/edit_photos_page.dart';
import 'package:tclub/features/profile/presentation/widgets/edit_profile_enums.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tclub/features/profile/data/repositories/avatar_repository.dart';
import 'package:tclub/features/profile/data/services/avatar_service.dart';
import 'package:tclub/core/services/user_avatar_service.dart';
import 'package:tclub/core/services/user_data_notifier.dart';
import 'package:tclub/core/services/user_profile_cache.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileHub extends StatefulWidget {
  const EditProfileHub({
    super.key,
    required this.userData,
    this.onSave,
  });

  final Map<String, dynamic>                userData;
  final void Function(Map<String, dynamic>)? onSave;

  @override
  State<EditProfileHub> createState() => _HubEditarPerfilEstado();
}

class _HubEditarPerfilEstado extends State<EditProfileHub> {
  late Map<String, dynamic> _dados;
  late final EditAvatarController _avatarCtrl;

  File? _arquivoImagem;

  String get _nome    => _dados['name']   as String? ?? '';
  String get _avatar  => _dados['avatar'] as String? ?? '';
  String get _email   => _dados['email']  as String? ?? '';
  String get _cidade  => _dados['city']   as String? ?? '';
  String get _estado  => _dados['state']  as String? ?? '';
  String get _bairro  => _dados['bairro'] as String? ?? '';

  String get _legendaTipoPerfil {
    final bruto = (_dados['gender_identity'] as String?)?.trim().isNotEmpty == true
        ? _dados['gender_identity'] as String
        : (_dados['tipoPerfil'] as String?)?.trim() ?? '';
    if (bruto.isEmpty) return 'Não definido';
    try {
      return TipoPerfil.values
          .firstWhere((e) => e.name.toLowerCase() == bruto.toLowerCase())
          .label;
    } catch (_) { return 'Não definido'; }
  }

  String get _legendaOrientacao {
    final bruto = (_dados['sexual_orientation'] as String?)?.trim().isNotEmpty == true
        ? _dados['sexual_orientation'] as String
        : (_dados['orientacaoSexual'] as String?)?.trim() ?? '';
    if (bruto.isEmpty) return '';
    try {
      return OrientacaoSexual.values
          .firstWhere((e) => e.name.toLowerCase() == bruto.toLowerCase())
          .label;
    } catch (_) { return ''; }
  }

  String get _legendaRelacionamento {
    final bruto = (_dados['relationship_type'] as String?)?.trim().isNotEmpty == true
        ? _dados['relationship_type'] as String
        : (_dados['tipoRelacionamento'] as String?)?.trim() ?? '';
    if (bruto.isEmpty) return '';
    try {
      return TipoRelacionamento.values
          .firstWhere((e) => e.name.toLowerCase() == bruto.toLowerCase())
          .label;
    } catch (_) { return ''; }
  }

  String get _legendaLocalizacao {
    final partes = [_bairro, _cidade, _estado].where((s) => s.isNotEmpty);
    return partes.isEmpty ? 'Não definida' : partes.join(', ');
  }

  String get _legendaIdentidade {
    final partes = [
      _legendaTipoPerfil == 'Não definido' ? '' : _legendaTipoPerfil,
      _legendaOrientacao,
      _legendaRelacionamento,
    ].where((s) => s.isNotEmpty);
    return partes.isEmpty ? 'Não definido' : partes.join(' · ');
  }

  String get _legendaInteresses {
    final raw = _dados['interests'];
    if (raw is! List || raw.isEmpty) return 'Nenhum selecionado';
    final list = raw.cast<String>();
    if (list.length <= 3) return list.join(' · ');
    return '${list.take(3).join(' · ')} +${list.length - 3}';
  }

  // ── FIX 3: legenda do parceiro para exibição no hub
  String get _legendaParceiro {
    final partner = _dados['partner'];
    if (partner == null) return '';
    if (partner is Map) {
      final nome = partner['name'] as String? ?? '';
      return nome.isNotEmpty ? nome : '';
    }
    return '';
  }

  bool get _isCasal {
    final profileType = _dados['profile_type'] as String? ?? '';
    final rel = _dados['relationship_type'] as String? ??
                _dados['tipoRelacionamento'] as String? ?? '';
    return profileType == 'couple' ||
           rel == 'casal' ||
           rel == 'casalLiberal';
  }

  @override
  void initState() {
    super.initState();
    _dados = Map<String, dynamic>.from(widget.userData);

    _avatarCtrl = EditAvatarController(
      service: AvatarService(
        repository: AvatarRepository(
          db:      FirebaseDatabase.instance,
          storage: FirebaseStorage.instance,
        ),
      ),
    )..addListener(_onAvatarChange);
  }

  @override
  void dispose() {
    _avatarCtrl
      ..removeListener(_onAvatarChange)
      ..dispose();
    super.dispose();
  }

  void _onAvatarChange() {
    if (!mounted) return;
    final ctrl = _avatarCtrl;

    if (ctrl.status == AvatarSaveStatus.success) {
      final uid       = FirebaseAuth.instance.currentUser?.uid ?? '';
      final novaUrl   = ctrl.newAvatarUrl ?? '';
      final atualizado = {..._dados, 'avatar': novaUrl};

      UserDataNotifier.instance.update(atualizado);
      if (uid.isNotEmpty) {
        UserAvatarService.instance.invalidate(uid);
        UserProfileCache.instance.invalidate(uid);
      }
      setState(() {
        _dados         = atualizado;
        _arquivoImagem = null;
      });
      widget.onSave?.call(_dados);
      _avatarCtrl.resetStatus();
    } else if (ctrl.status == AvatarSaveStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF3D0A0A),
        behavior:        SnackBarBehavior.floating,
        shape:           const RoundedRectangleBorder(),
        content: Text(
          (ctrl.errorMessage ?? 'Erro ao salvar foto').toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Montserrat', fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ));
      _avatarCtrl.resetStatus();
    } else {
      setState(() {});
    }
  }

  // ── navegação ─────────────────────────────────────────────────────────────

  Future<void> _abrirDadosPessoais() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditPersonalPage(userData: _dados)),
    );
    if (resultado != null && mounted) {
      final atualizado = {..._dados, ...resultado};
      UserDataNotifier.instance.update(atualizado);
      setState(() => _dados = atualizado);
      widget.onSave?.call(atualizado);
    }
  }

  Future<void> _abrirIdentidade() async {
    // ── FIX 3: passa _dados completo (inclui 'partner' se existir)
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditIdentifyPage(userData: _dados)),
    );
    if (resultado != null && mounted) {
      // merge completo — inclui 'partner' (pode ser null se virou solteiro)
      final atualizado = Map<String, dynamic>.from(_dados)..addAll(resultado);

      // se partner veio null, remove a chave para não manter dados velhos
      if (resultado.containsKey('partner') && resultado['partner'] == null) {
        atualizado.remove('partner');
      }

      UserDataNotifier.instance.update(atualizado);
      setState(() => _dados = atualizado);
      widget.onSave?.call(atualizado);
    }
  }

  Future<void> _abrirInteresses() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditInterestsPage(userData: _dados)),
    );
    if (resultado != null && mounted) {
      final atualizado = {..._dados, ...resultado};
      UserDataNotifier.instance.update(atualizado);
      setState(() => _dados = atualizado);
      widget.onSave?.call(atualizado);
    }
  }

  Future<void> _abrirLocalizacao() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditLocationPage(userData: _dados)),
    );
    if (resultado != null && mounted) {
      final atualizado = {..._dados, ...resultado};
      UserDataNotifier.instance.update(atualizado);
      setState(() => _dados = atualizado);
      widget.onSave?.call(atualizado);
    }
  }

  Future<void> _exibirFolhaFoto() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditPhotosPage(userData: _dados)),
    );
    if (resultado != null && mounted) {
      final novaUrl    = resultado['avatar'] as String? ?? _avatar;
      final atualizado = {..._dados, 'avatar': novaUrl};

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        UserAvatarService.instance.invalidate(uid);
        UserProfileCache.instance.invalidate(uid);
      }
      UserDataNotifier.instance.update(atualizado);
      setState(() => _dados = atualizado);
      widget.onSave?.call(atualizado);
    }
  }

  Future<void> _selecionarImagem(ImageSource origem) async {
    Navigator.pop(context);
    if (!await requestMediaPermission(context, origem)) return;
    final selecionada = await ImagePicker().pickImage(
        source: origem, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (selecionada == null || !mounted) return;

    final arquivo = File(selecionada.path);
    setState(() => _arquivoImagem = arquivo);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await _avatarCtrl.pickAndUpload(
      uid:              uid,
      imageFile:        arquivo,
      currentAvatarUrl: _avatar,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Stack(children: [
        const Positioned.fill(child: _FundoDecorado()),
        Positioned(top: 0, left: 0, right: 0, child: Container(height: 3,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            TClubColors.redDeep, TClubColors.redPrincipal, TClubColors.redClaro,
            TClubColors.redPrincipal, TClubColors.redDeep,
          ])))),
        SafeArea(child: Column(children: [
          _CabecalhoHub(aoVoltar: () {
            UserDataNotifier.instance.update(_dados);
            Navigator.pop(context, _dados);
          }),
          Container(height: 0.5, color: TClubColors.border),
          Expanded(child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              _CartaoPerfil(
                nome:           _nome,
                urlAvatar:      _avatar,
                arquivoImagem:  _avatarCtrl.pendingFile ?? _arquivoImagem,
                enviando:       _avatarCtrl.isUploading,
                progressoEnvio: _avatarCtrl.uploadProgress,
                aoTocar:        _avatarCtrl.isUploading ? () {} : _exibirFolhaFoto,
              ),
              const SizedBox(height: 32),
              _RotuloGrupo(titulo: 'MEU PERFIL'),
              _GrupoConfiguracoes(linhas: [
                _LinhaConfiguracao(
                  icone:     Icons.person_outline,
                  titulo:    'Dados Pessoais',
                  subtitulo: _nome,
                  aoTocar:   _abrirDadosPessoais,
                ),
                _LinhaConfiguracao(
                  icone:     Icons.favorite_border_rounded,
                  titulo:    'Identidade',
                  // ── FIX 3: exibe parceiro na legenda quando é casal
                  subtitulo: _isCasal && _legendaParceiro.isNotEmpty
                      ? '$_legendaIdentidade · 👫 $_legendaParceiro'
                      : _legendaIdentidade,
                  aoTocar:   _abrirIdentidade,
                ),
              ]),
              const SizedBox(height: 24),
              _RotuloGrupo(titulo: 'LOCALIZAÇÃO'),
              _GrupoConfiguracoes(linhas: [
                _LinhaConfiguracao(
                  icone:     Icons.location_on_outlined,
                  titulo:    'Endereço',
                  subtitulo: _legendaLocalizacao,
                  aoTocar:   _abrirLocalizacao,
                ),
              ]),
              const SizedBox(height: 24),
              _RotuloGrupo(titulo: 'CONTA'),
              _GrupoConfiguracoes(linhas: [
                _LinhaConfiguracao(
                  icone:      Icons.mail_outline,
                  titulo:     'E-mail',
                  subtitulo:  _email,
                  aoTocar:    null,
                  exibirSeta: false,
                ),
              ]),
            ],
          )),
        ])),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS INTERNOS (inalterados exceto _CartaoPerfil)
// ════════════════════════════════════════════════════════════════════════════

class _CabecalhoHub extends StatelessWidget {
  const _CabecalhoHub({required this.aoVoltar});
  final VoidCallback aoVoltar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: TClubColors.dim, size: 18),
          onPressed: aoVoltar),
      const Expanded(child: Text('EDITAR PERFIL', textAlign: TextAlign.center,
        style: TextStyle(fontFamily: TClubTypography.displayFont,
            fontSize: 16, letterSpacing: 4, color: TClubColors.textoPrincipal))),
      const SizedBox(width: 48),
    ]),
  );
}

class _CartaoPerfil extends StatelessWidget {
  const _CartaoPerfil({
    required this.nome,       required this.urlAvatar,
    required this.arquivoImagem, required this.enviando,
    required this.progressoEnvio, required this.aoTocar,
  });

  final String       nome;
  final String       urlAvatar;
  final File?        arquivoImagem;
  final bool         enviando;
  final double       progressoEnvio;
  final VoidCallback aoTocar;

  Widget _semFoto() => Container(color: TClubColors.bgAlt,
      child: const Icon(Icons.person_outline, color: TClubColors.redPrincipal, size: 36));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: aoTocar,
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: TClubColors.glow, blurRadius: 24, spreadRadius: 2)],
              gradient: const LinearGradient(colors: [TClubColors.redDeep, TClubColors.redPrincipal],
                  begin: Alignment.topLeft, end: Alignment.bottomRight))),
          Container(width: 92, height: 92,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: TClubColors.bg, width: 3)),
            child: ClipOval(child: arquivoImagem != null
                ? Image.file(arquivoImagem!, fit: BoxFit.cover)
                : urlAvatar.isNotEmpty
                    ? CachedNetworkImage(imageUrl: CloudinaryHelper.avatarUrl(urlAvatar),
                        fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => _semFoto(),
                        errorWidget: (_, __, ___) => _semFoto())
                    : _semFoto())),
          Positioned.fill(child: ClipOval(child: Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(child: Icon(Icons.photo_camera,
                  color: TClubColors.textoPrincipal, size: 24))))),
          if (enviando)
            SizedBox(width: 100, height: 100,
              child: CircularProgressIndicator(value: progressoEnvio, strokeWidth: 3,
                  color: TClubColors.redPrincipal, backgroundColor: TClubColors.border)),
          if (!enviando)
            Positioned(bottom: 0, right: 0,
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: TClubColors.redPrincipal,
                    shape: BoxShape.circle,
                    border: Border.all(color: TClubColors.bg, width: 2)),
                child: const Icon(Icons.edit, color: TClubColors.textoPrincipal, size: 12))),
        ]),
        const SizedBox(height: 12),
        Text(nome.isNotEmpty ? nome : 'Seu nome',
          style: const TextStyle(fontFamily: TClubTypography.displayFont,
              fontSize: 20, fontWeight: FontWeight.w700,
              color: TClubColors.textoPrincipal, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(enviando ? 'Enviando foto...' : 'Toque para alterar a foto',
          style: TextStyle(fontFamily: TClubTypography.bodyFont, fontSize: 11,
              color: enviando ? TClubColors.redPrincipal : TClubColors.subtle,
              letterSpacing: 1)),
      ]),
    );
  }
}

class _RotuloGrupo extends StatelessWidget {
  const _RotuloGrupo({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Text(titulo, style: const TextStyle(fontFamily: TClubTypography.bodyFont,
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3,
        color: TClubColors.subtle)),
  );
}

class _GrupoConfiguracoes extends StatelessWidget {
  const _GrupoConfiguracoes({required this.linhas});
  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.border, width: 0.8)),
      child: Column(children: linhas.asMap().entries.map((entrada) {
        final ultimo = entrada.key == linhas.length - 1;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          entrada.value,
          if (!ultimo) Container(height: 0.5, color: TClubColors.border),
        ]);
      }).toList()),
    );
  }
}

class _LinhaConfiguracao extends StatelessWidget {
  const _LinhaConfiguracao({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.aoTocar,
    this.exibirSeta = true,
  });

  final IconData      icone;
  final String        titulo;
  final String        subtitulo;
  final VoidCallback? aoTocar;
  final bool          exibirSeta;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:          aoTocar,
      splashColor:    TClubColors.redPrincipal.withOpacity(0.06),
      highlightColor: TClubColors.redPrincipal.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(width: 34, height: 34,
            decoration: BoxDecoration(
              color: TClubColors.redPrincipal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: TClubColors.border, width: 0.6)),
            child: Icon(icone, color: TClubColors.redPrincipal, size: 16)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontFamily: TClubTypography.bodyFont,
                fontSize: 14, fontWeight: FontWeight.w600, color: TClubColors.textoPrincipal)),
            if (subtitulo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitulo, style: const TextStyle(fontFamily: TClubTypography.bodyFont,
                  fontSize: 12, color: TClubColors.subtle),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ])),
          if (exibirSeta) const Icon(Icons.chevron_right_rounded,
              color: TClubColors.dim, size: 20),
        ]),
      ),
    );
  }
}

class _FundoDecorado extends StatelessWidget {
  const _FundoDecorado();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PintorFundo());
}

class _PintorFundo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size tamanho) {
    canvas.drawRect(Rect.fromLTWH(0, 0, tamanho.width, tamanho.height),
        Paint()..color = TClubColors.bg);
    canvas.drawCircle(Offset(tamanho.width * 0.9, tamanho.height * 0.08), tamanho.width * 0.6,
      Paint()..shader = RadialGradient(colors: [
        TClubColors.redPrincipal.withOpacity(0.07), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(tamanho.width * 0.9, tamanho.height * 0.08),
          radius: tamanho.width * 0.6)));
  }
  @override
  bool shouldRepaint(_PintorFundo _) => false;
}

