// lib/screens/screens_administrative/home_screen/edit_party_screen.dart
//
// Tela de edição de festa — endereço único via Places Autocomplete.
// Sem dropdowns de estado/cidade.
//
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/helpers/media_permission_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/party/data/models/party_model.dart';
import 'package:tclub/features/admin/data/services/party_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tclub/features/party/controller/party_address_controller.dart';

class EditPartyScreen extends StatefulWidget {
  final PartyModel festa;
  final Map<String, dynamic> userData;

  const EditPartyScreen({
    super.key,
    required this.festa,
    required this.userData,
  });

  @override
  State<EditPartyScreen> createState() => _EditPartyScreenState();
}

class _EditPartyScreenState extends State<EditPartyScreen> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _enderecoCtrl;

  final _nomeFocus     = FocusNode();
  final _descFocus     = FocusNode();
  final _enderecoFocus = FocusNode();

  late final PartyAddressController _addrCtrl;

  late DateTime _dataInicio;
  late DateTime _dataFim;

  File?   _novoBanner;
  String? _bannerUrlAtual;

  bool   _salvando   = false;
  bool   _uploading  = false;
  double _uploadProg = 0;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid
      ?? (widget.userData['uid'] as String? ?? '');

  bool get _enderecoOk => _addrCtrl.status == AddressStatus.ok;

  // Endereço original (pode ser o salvo no Firebase — não precisa re-confirmar)
  bool _enderecoOriginalMantido = false;

  @override
  void initState() {
    super.initState();

    final f = widget.festa;

    _nomeCtrl = TextEditingController(text: f.nome);
    _descCtrl = TextEditingController(text: f.descricao);

    // Preenche o campo com o endereço salvo (campo 'bairro' ou 'local')
    final enderecoSalvo = f.bairro?.isNotEmpty == true
        ? f.bairro!
        : f.local ?? '';
    _enderecoCtrl = TextEditingController(text: enderecoSalvo);

    _dataInicio     = f.dataInicio;
    _dataFim        = f.dataFim;
    _bannerUrlAtual = f.bannerUrl;

    _addrCtrl = PartyAddressController(httpClient: http.Client());
    _addrCtrl.addListener(_onAddrChange);
    _enderecoFocus.addListener(_onEnderecoFocus);

    // Se já havia endereço salvo, marca como "original mantido" para não
    // bloquear o salvar caso o usuário não mexa no campo.
    if (enderecoSalvo.isNotEmpty) {
      _enderecoOriginalMantido = true;
    }
  }

  @override
  void dispose() {
    _addrCtrl.removeListener(_onAddrChange);
    _addrCtrl.dispose();
    _enderecoFocus.removeListener(_onEnderecoFocus);
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _enderecoCtrl.dispose();
    _nomeFocus.dispose();
    _descFocus.dispose();
    _enderecoFocus.dispose();
    super.dispose();
  }

  void _onAddrChange() { if (mounted) setState(() {}); }

  void _onEnderecoFocus() {
    if (!_enderecoFocus.hasFocus) _addrCtrl.onUnfocused();
    setState(() {});
  }

  void _limparLocal() {
    setState(() {
      _enderecoCtrl.clear();
      _enderecoOriginalMantido = false;
    });
    _addrCtrl.clear();
  }

  // ── O endereço está válido para salvar? ─────────────────────────────────
  // Válido se: vazio (nenhum local), ou original mantido, ou confirmado via Places.
  bool get _enderecoValido {
    final texto = _enderecoCtrl.text.trim();
    if (texto.isEmpty) return true;                   // sem local
    if (_enderecoOriginalMantido && !_userEditedAddress) return true; // não tocou
    return _enderecoOk;                               // confirmado via sugestão
  }

  // Detecta se o usuário alterou o campo de endereço
  bool _userEditedAddress = false;

  // ── Banner picker ────────────────────────────────────────────────────────
  Future<void> _pickBanner() async {
    HapticFeedback.selectionClick();
    final temBannerAtual = _novoBanner != null ||
        (_bannerUrlAtual != null && _bannerUrlAtual!.isNotEmpty);

    showModalBottomSheet(
      context: context,
      backgroundColor: TClubColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: TClubColors.border,
              borderRadius: BorderRadius.circular(2))),
          const Text('BANNER DA FESTA', style: TextStyle(
              fontFamily: TClubTypography.displayFont,
              fontSize: 18, letterSpacing: 5,
              color: TClubColors.textoPrincipal)),
          const SizedBox(height: 16),
          Container(height: 0.5, color: TClubColors.border),
          _PickerTile(icon: Icons.photo_camera_outlined, label: 'CÂMERA',
            onTap: () async {
              Navigator.pop(context);
              if (!await requestMediaPermission(context, ImageSource.camera)) return;
              final file = await ImagePicker().pickImage(
                  source: ImageSource.camera, maxWidth: 1200, imageQuality: 88);
              if (file != null && mounted) setState(() => _novoBanner = File(file.path));
            }),
          Container(height: 0.5, color: TClubColors.border),
          _PickerTile(icon: Icons.photo_library_outlined, label: 'GALERIA',
            onTap: () async {
              Navigator.pop(context);
              if (!await requestMediaPermission(context, ImageSource.gallery)) return;
              final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery, maxWidth: 1200, imageQuality: 88);
              if (file != null && mounted) setState(() => _novoBanner = File(file.path));
            }),
          if (temBannerAtual) ...[
            Container(height: 0.5, color: TClubColors.border),
            _PickerTile(icon: Icons.delete_outline, label: 'REMOVER BANNER',
              color: TClubColors.error,
              onTap: () {
                Navigator.pop(context);
                setState(() { _novoBanner = null; _bannerUrlAtual = null; });
              }),
          ],
          const SizedBox(height: 16),
        ])));
  }

  // ── Date/Time pickers ────────────────────────────────────────────────────
  Future<void> _pickDataInicio() async {
    final now         = DateTime.now();
    final initialDate = _dataInicio.isBefore(now) ? now : _dataInicio;

    final date = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: _datePickerTheme);
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataInicio),
      builder: _datePickerTheme);
    if (time == null || !mounted) return;

    setState(() {
      _dataInicio = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
      if (_dataFim.isBefore(_dataInicio)) {
        _dataFim = _dataInicio.add(const Duration(hours: 4));
      }
    });
  }

  Future<void> _pickDataFim() async {
    final firstDate   = _dataInicio;
    final lastDate    = _dataInicio.add(const Duration(days: 3));
    DateTime initialDate = _dataFim;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate))   initialDate = lastDate;

    final date = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: _datePickerTheme);
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataFim),
      builder: _datePickerTheme);
    if (time == null || !mounted) return;

    setState(() =>
        _dataFim = DateTime(
            date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget Function(BuildContext, Widget?) get _datePickerTheme =>
      (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary:   TClubColors.redPrincipal,
            onPrimary: TClubColors.textoSobreRed,
            surface:   TClubColors.bg,
            onSurface: TClubColors.textoPrincipal,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: TClubColors.bg),
        ),
        child: child!);

  // ── Salvar ───────────────────────────────────────────────────────────────
  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      _showSnack('Nome da festa obrigatório'); return;
    }
    if (!_enderecoValido) {
      _showSnack('Selecione um endereço da lista de sugestões'); return;
    }

    setState(() { _salvando = true; _uploading = _novoBanner != null; _uploadProg = 0; });
    FocusScope.of(context).unfocus();

    try {
      String? bannerUrl = _bannerUrlAtual;
      if (_novoBanner != null) {
        final ref = FirebaseStorage.instance
            .ref('festas/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = ref.putFile(
            _novoBanner!, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          setState(() => _uploadProg =
              snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes));
        });
        await task;
        bannerUrl = await ref.getDownloadURL();
        if (mounted) setState(() => _uploading = false);
      }

      final updates = <String, dynamic>{
        'nome':        _nomeCtrl.text.trim(),
        'descricao':   _descCtrl.text.trim(),
        'data_inicio': _dataInicio.millisecondsSinceEpoch,
        'data_fim':    _dataFim.millisecondsSinceEpoch,
        'banner_url':  (bannerUrl != null && bannerUrl.isNotEmpty)
            ? bannerUrl
            : null,
      };

      final textoEndereco = _enderecoCtrl.text.trim();

      if (textoEndereco.isEmpty) {
        // Usuário limpou o local
        updates['local']     = null;
        updates['bairro']    = null;
        updates['state']     = null;
        updates['city']      = null;
        updates['latitude']  = null;
        updates['longitude'] = null;
      } else if (_enderecoOk && _addrCtrl.resolved != null) {
        // Novo endereço confirmado via Places
        final r = _addrCtrl.resolved!;
        updates['local']     = r.description;
        updates['bairro']    = r.description;
        updates['state']     = r.state.isNotEmpty ? r.state : null;
        updates['city']      = r.city.isNotEmpty  ? r.city  : null;
        updates['latitude']  = r.lat;
        updates['longitude'] = r.lng;
      } else {
        // Endereço original mantido — preserva valores do Firebase
        updates['local']  = textoEndereco;
        updates['bairro'] = textoEndereco;
        // state/city/lat/lng não são alterados
      }

      await PartyService.instance.updateFesta(widget.festa.id, updates);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('editFesta error: $e');
      if (mounted) {
        setState(() { _salvando = false; _uploading = false; });
        _showSnack('Erro ao salvar. Tente novamente.');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TClubColors.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: TClubColors.border, width: 0.8)),
      margin: const EdgeInsets.all(16),
      content: Text(msg, style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 12, letterSpacing: 1.5,
          color: TClubColors.textoPrincipal))));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _EditFestaBg())),
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TClubColors.redDeep, TClubColors.redPrincipal,
                TClubColors.redClaro,
                TClubColors.redPrincipal, TClubColors.redDeep,
                Colors.transparent,
              ])))),

        SafeArea(child: Column(children: [

          // ── App Bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: TClubColors.textoPrincipal, size: 16),
                onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('EDITAR FESTA',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: TClubTypography.displayFont,
                    fontSize: 20, letterSpacing: 5,
                    color: TClubColors.textoPrincipal))),
              GestureDetector(
                onTap: (_salvando || _uploading) ? null : _salvar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_salvando || _uploading)
                        ? TClubColors.bgCard
                        : TClubColors.redPrincipal,
                    border: Border.all(
                        color: TClubColors.redPrincipal, width: 0.8)),
                  child: (_salvando || _uploading)
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: TClubColors.redPrincipal,
                              strokeWidth: 1.5))
                      : const Text('SALVAR', style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: TClubColors.textoSobreRed)))),
            ])),

          Container(height: 0.5,
              margin: const EdgeInsets.only(top: 10),
              color: TClubColors.border),

          // Badge "EDITANDO"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: TClubColors.redPrincipal.withOpacity(0.06),
            child: Row(children: [
              const Icon(Icons.edit_rounded,
                  color: TClubColors.redPrincipal, size: 10),
              const SizedBox(width: 7),
              Expanded(child: Text(
                widget.festa.nome.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: TClubColors.redPrincipal))),
            ])),

          Container(height: 0.5, color: TClubColors.border),

          // ── Formulário ─────────────────────────────────────────────
          Expanded(child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // BANNER
                  _buildBannerPicker(),
                  const SizedBox(height: 28),

                  // NOME
                  _buildSectionLabel('NOME DA FESTA',
                      Icons.local_fire_department_outlined),
                  const SizedBox(height: 8),
                  _buildTextField(ctrl: _nomeCtrl, focus: _nomeFocus,
                      hint: 'Ex: Neon Shadows',
                      capitalize: TextCapitalization.words),
                  const SizedBox(height: 28),

                  // LOCAL
                  _buildLocalSectionLabel(),
                  const SizedBox(height: 12),
                  _buildEnderecoField(),
                  const SizedBox(height: 28),

                  // DATA & HORÁRIO
                  _buildSectionLabel('DATA & HORÁRIO',
                      Icons.schedule_outlined),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _buildDateTile(
                        label: 'INÍCIO', value: _dataInicio,
                        onTap: _pickDataInicio)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDateTile(
                        label: 'FIM', value: _dataFim,
                        onTap: _pickDataFim)),
                  ]),
                  const SizedBox(height: 28),

                  // DESCRIÇÃO
                  _buildSectionLabel('DESCRIÇÃO',
                      Icons.edit_note_outlined),
                  const SizedBox(height: 8),
                  _buildTextField(ctrl: _descCtrl, focus: _descFocus,
                      hint: 'Conta como vai ser a noite...',
                      maxLines: 5, maxLength: 400,
                      action: TextInputAction.newline),

                  if (_uploading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENVIANDO BANNER ${(_uploadProg * 100).toInt()}%',
                            style: const TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 9, letterSpacing: 2,
                                color: TClubColors.redPrincipal)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: LinearProgressIndicator(
                              value: _uploadProg,
                              backgroundColor: TClubColors.redPale,
                              color: TClubColors.redPrincipal,
                              minHeight: 2)),
                        ])),
                ])))),
        ])),
      ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLocalSectionLabel() {
    final temLocal = _enderecoCtrl.text.isNotEmpty;
    return Row(children: [
      Icon(Icons.location_on_outlined,
          color: temLocal ? TClubColors.redPrincipal : TClubColors.textoMuted,
          size: 12),
      const SizedBox(width: 7),
      Text('LOCAL', style: TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3,
          color: temLocal ? TClubColors.redPrincipal : TClubColors.textoMuted)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.border, width: 0.6)),
        child: const Text('OPCIONAL', style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 7, fontWeight: FontWeight.w600,
            letterSpacing: 1.5, color: TClubColors.textoMuted))),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 0.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TClubColors.border, Colors.transparent])))),
      if (temLocal)
        GestureDetector(
          onTap: _limparLocal,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.close_rounded,
                  color: TClubColors.textoMuted, size: 12),
              SizedBox(width: 3),
              Text('LIMPAR', style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 8, letterSpacing: 1.5,
                  color: TClubColors.textoMuted)),
            ]))),
    ]);
  }

  Widget _buildEnderecoField() {
    final status  = _addrCtrl.status;
    final focused = _enderecoFocus.hasFocus;

    // Campo com original mantido aparece como "ok" visualmente
    final isOriginalOk = _enderecoOriginalMantido && !_userEditedAddress;

    final borda = (isOriginalOk || status == AddressStatus.ok)
        ? TClubColors.redPrincipal
        : status == AddressStatus.error
            ? TClubColors.error
            : status == AddressStatus.loading
                ? TClubColors.redPrincipal.withOpacity(0.5)
                : focused ? TClubColors.redPrincipal : TClubColors.border;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Container(
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: borda, width: 1)),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              color: TClubColors.textoMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _enderecoCtrl,
              focusNode:  _enderecoFocus,
              style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 15, fontWeight: FontWeight.w400,
                  color: TClubColors.textoPrincipal),
              cursorColor: TClubColors.redPrincipal,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                border: InputBorder.none, isDense: true,
                hintText: 'Buscar ou alterar endereço do evento...',
                hintStyle: TextStyle(fontFamily: TClubTypography.bodyFont,
                    fontSize: 13, color: TClubColors.textoMuted),
                contentPadding: EdgeInsets.symmetric(vertical: 14)),
              onChanged: (v) {
                _userEditedAddress = true;
                _enderecoOriginalMantido = false;
                _addrCtrl.onChanged(v);
              },
              onEditingComplete: () {
                FocusScope.of(context).unfocus();
                _addrCtrl.onUnfocused();
              },
            ),
          ),
          // Suffix
          if (status == AddressStatus.loading)
            const Padding(padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: TClubColors.redPrincipal, strokeWidth: 1.5)))
          else if (status == AddressStatus.ok || isOriginalOk)
            const Padding(padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.check_circle_rounded,
                  color: TClubColors.redPrincipal, size: 18))
          else if (status == AddressStatus.error)
            Padding(padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.cancel_rounded,
                  color: TClubColors.error, size: 18))
          else if (_addrCtrl.loadingSuggestions)
            const Padding(padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: TClubColors.redPrincipal, strokeWidth: 1.5)))
          else
            const SizedBox(width: 10),
        ]),
      ),

      // Feedback
      if (status == AddressStatus.error && _addrCtrl.errorMessage != null)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: TClubColors.error, size: 11),
            const SizedBox(width: 4),
            Expanded(child: Text(_addrCtrl.errorMessage!,
              style: const TextStyle(fontFamily: TClubTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8,
                  color: TClubColors.error))),
          ]))
      else if (status == AddressStatus.ok && _addrCtrl.resolved != null)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: TClubColors.redPrincipal, size: 11),
            const SizedBox(width: 4),
            Expanded(child: Text(
              _addrCtrl.resolved!.city.isNotEmpty
                  ? 'Confirmado em ${_addrCtrl.resolved!.city}'
                  : 'Endereço confirmado',
              style: const TextStyle(fontFamily: TClubTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8,
                  color: TClubColors.redPrincipal))),
          ]))
      else if (isOriginalOk && _enderecoCtrl.text.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: TClubColors.redPrincipal, size: 11),
            const SizedBox(width: 4),
            const Text('Endereço atual', style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10, letterSpacing: 0.8,
                color: TClubColors.redPrincipal)),
          ]))
      else if (_userEditedAddress &&
               _enderecoCtrl.text.isNotEmpty &&
               !_addrCtrl.loadingSuggestions &&
               _addrCtrl.suggestions.isEmpty &&
               status == AddressStatus.idle)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: const [
            Icon(Icons.touch_app_outlined,
                color: TClubColors.textoMuted, size: 11),
            SizedBox(width: 4),
            Text('Selecione um endereço da lista',
              style: TextStyle(fontFamily: TClubTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8,
                  color: TClubColors.textoMuted)),
          ])),

      // Coordenadas
      if (status == AddressStatus.ok && _addrCtrl.resolved != null)
        Padding(padding: const EdgeInsets.only(top: 4, left: 2),
          child: Row(children: [
            const Icon(Icons.my_location,
                color: TClubColors.textoMuted, size: 11),
            const SizedBox(width: 4),
            Text(
              '${_addrCtrl.resolved!.lat.toStringAsFixed(6)}, '
              '${_addrCtrl.resolved!.lng.toStringAsFixed(6)}',
              style: const TextStyle(fontFamily: TClubTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.6,
                  color: TClubColors.textoMuted)),
          ])),

      // Lista de sugestões
      _buildSuggestions(),
    ]);
  }

  Widget _buildSuggestions() {
    final suggestions = _addrCtrl.suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(color: TClubColors.border, width: 0.8)),
      child: Column(children: suggestions.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Column(children: [
          if (i > 0)
            Container(height: 0.5,
                color: TClubColors.border.withOpacity(0.5)),
          InkWell(
            onTap: () async {
              _enderecoCtrl.text = s.description;
              _enderecoCtrl.selection =
                  TextSelection.collapsed(offset: s.description.length);
              FocusScope.of(context).unfocus();
              await _addrCtrl.selectSuggestion(s);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: TClubColors.redPrincipal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.mainText, style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: TClubColors.textoPrincipal)),
                      if (s.description != s.mainText)
                        Text(s.description
                            .replaceFirst('${s.mainText}, ', ''),
                          style: const TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 11,
                              color: TClubColors.textoSecundario)),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: TClubColors.textoMuted),
              ])),
          ),
        ]);
      }).toList()),
    );
  }

  // ── Widgets genéricos ────────────────────────────────────────────────────

  Widget _buildBannerPicker() {
    final temBannerLocal  = _novoBanner != null;
    final temBannerRemoto = _bannerUrlAtual != null && _bannerUrlAtual!.isNotEmpty;
    final temBanner       = temBannerLocal || temBannerRemoto;

    return GestureDetector(
      onTap: _pickBanner,
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(
            color: temBanner
                ? TClubColors.redPrincipal.withOpacity(0.5)
                : TClubColors.border,
            width: temBanner ? 1 : 0.8)),
        child: temBanner
            ? Stack(fit: StackFit.expand, children: [
                temBannerLocal
                    ? Image.file(_novoBanner!, fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: CloudinaryHelper.bannerUrl(_bannerUrlAtual!),
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => _bannerPlaceholder(),
                        errorWidget: (_, __, ___) => _bannerPlaceholder()),
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent,
                        Colors.black.withOpacity(0.35)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter)))),
                Positioned(bottom: 10, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: TClubColors.redDeep.withOpacity(0.85),
                      border: Border.all(
                          color: TClubColors.borderMid, width: 0.6)),
                    child: const Text('TROCAR', style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9, letterSpacing: 2,
                        color: TClubColors.textoSobreRed)))),
                if (temBannerLocal)
                  Positioned(top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      color: TClubColors.redPrincipal,
                      child: const Text('NOVO', style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 8, fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: TClubColors.textoSobreRed)))),
              ])
            : _bannerPlaceholder()));
  }

  Widget _bannerPlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: TClubColors.bgAlt,
          border: Border.all(color: TClubColors.border, width: 0.8)),
        child: const Icon(Icons.add_photo_alternate_outlined,
            color: TClubColors.redPrincipal, size: 20)),
      const SizedBox(height: 12),
      const Text('ADICIONAR BANNER', style: TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 3, color: TClubColors.textoMuted)),
      const SizedBox(height: 4),
      const Text('Recomendado: 1200 × 600px', style: TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9, letterSpacing: 0.5,
          color: TClubColors.border)),
    ]);

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: TClubColors.redPrincipal, size: 12),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9, fontWeight: FontWeight.w700,
          letterSpacing: 3, color: TClubColors.redPrincipal)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 0.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TClubColors.border, Colors.transparent])))),
    ]);
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    FocusNode? focus,
    FocusNode? nextFocus,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    TextCapitalization capitalize = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextFormField(
      controller: ctrl, focusNode: focus,
      maxLines: maxLines, maxLength: maxLength,
      enabled: enabled,
      textCapitalization: capitalize, textInputAction: action,
      onEditingComplete: nextFocus != null
          ? () => FocusScope.of(context).requestFocus(nextFocus)
          : () => FocusScope.of(context).unfocus(),
      style: TextStyle(fontFamily: TClubTypography.bodyFont,
          fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.3,
          color: enabled ? TClubColors.dim : TClubColors.textoMuted),
      cursorColor: TClubColors.redPrincipal, cursorWidth: 1,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: TClubTypography.bodyFont,
            fontSize: 13, color: TClubColors.textoMuted),
        filled: true,
        fillColor: enabled ? TClubColors.bgCard : TClubColors.bgAlt,
        counterStyle: const TextStyle(fontFamily: TClubTypography.bodyFont,
            fontSize: 9, color: TClubColors.textoMuted),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TClubColors.border, width: 0.8)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TClubColors.border, width: 0.8)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(
                color: TClubColors.redPrincipal, width: 1.5)),
        disabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TClubColors.border, width: 0.5))));
  }

  Widget _buildDateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(
              color: TClubColors.redPrincipal.withOpacity(0.4), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 2, color: TClubColors.redPrincipal)),
            const SizedBox(height: 6),
            Text(_formatDate(value), style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 13, fontWeight: FontWeight.w600,
                color: TClubColors.textoPrincipal, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(_formatTime(value), style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11, color: TClubColors.textoSecundario)),
          ])));
  }

  String _formatDate(DateTime dt) {
    const meses = ['Jan','Fev','Mar','Abr','Mai','Jun',
                   'Jul','Ago','Set','Out','Nov','Dez'];
    return '${dt.day.toString().padLeft(2, '0')} ${meses[dt.month - 1]}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Painters & helpers ───────────────────────────────────────────────────────

class _EditFestaBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TClubColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.08), size.width * 0.65,
      Paint()..shader = RadialGradient(colors: [
        TClubColors.redPrincipal.withOpacity(0.05), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.08),
          radius: size.width * 0.65)));
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.92), size.width * 0.5,
      Paint()..shader = RadialGradient(colors: [
        TClubColors.redClaro.withOpacity(0.04), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.92),
          radius: size.width * 0.5)));
  }
  @override bool shouldRepaint(_EditFestaBg _) => false;
}

class _PickerTile extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap; final Color color;
  const _PickerTile({
    required this.icon, required this.label,
    required this.onTap, this.color = TClubColors.textoPrincipal});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    splashColor: TClubColors.redPale,
    highlightColor: TClubColors.redPale.withOpacity(0.5),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        Icon(icon, color: color, size: 20), const SizedBox(width: 16),
        Text(label, style: TextStyle(fontFamily: TClubTypography.bodyFont,
            fontSize: 14, fontWeight: FontWeight.w600,
            letterSpacing: 2.5, color: color)),
      ])));
}

