// lib/screens/screens_home/home_screen/festas/create_festa_screen.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/core/helpers/media_permission_helper.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/admin/data/services/party_service.dart';
import 'package:tabuapp/core/services/user_data_notifier.dart';
import 'package:tabuapp/features/party/controller/party_address_controller.dart';

class CreatePartyScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CreatePartyScreen({super.key, required this.userData});

  @override
  State<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends State<CreatePartyScreen> {
  final _nomeCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _enderecoCtrl  = TextEditingController();

  final _nomeFocus     = FocusNode();
  final _descFocus     = FocusNode();
  final _enderecoFocus = FocusNode();

  late final PartyAddressController _addrCtrl;

  DateTime? _dataInicio;
  DateTime? _dataFim;
  File?     _banner;
  bool      _salvando   = false;
  bool      _uploading  = false;
  double    _uploadProg = 0;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid
      ?? widget.userData['uid'] as String? ?? '';

  String get _userName =>
      UserDataNotifier.instance.name.isNotEmpty
          ? UserDataNotifier.instance.name
          : widget.userData['name'] as String? ?? '';

  String? get _userAvatar =>
      UserDataNotifier.instance.avatar.isNotEmpty
          ? UserDataNotifier.instance.avatar
          : widget.userData['avatar'] as String?;

  bool get _enderecoOk => _addrCtrl.status == AddressStatus.ok;

  @override
  void initState() {
    super.initState();
    _addrCtrl = PartyAddressController(httpClient: http.Client());
    _addrCtrl.addListener(_onAddrChange);
    _enderecoFocus.addListener(_onEnderecoFocus);
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
    setState(() => _enderecoCtrl.clear());
    _addrCtrl.clear();
  }

  // ── Picker de banner ────────────────────────────────────────────────────
  Future<void> _pickBanner() async {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: TabuColors.border,
              borderRadius: BorderRadius.circular(2))),
          const Text('BANNER DA FESTA',
            style: TextStyle(fontFamily: TabuTypography.displayFont,
                fontSize: 18, letterSpacing: 5,
                color: TabuColors.textoPrincipal)),
          const SizedBox(height: 16),
          Container(height: 0.5, color: TabuColors.border),
          _PickerTile(icon: Icons.photo_camera_outlined, label: 'CÂMERA',
            onTap: () async {
              Navigator.pop(context);
              if (!await requestMediaPermission(context, ImageSource.camera)) return;
              final f = await ImagePicker().pickImage(
                  source: ImageSource.camera, maxWidth: 1200, imageQuality: 88);
              if (f != null && mounted) setState(() => _banner = File(f.path));
            }),
          Container(height: 0.5, color: TabuColors.border),
          _PickerTile(icon: Icons.photo_library_outlined, label: 'GALERIA',
            onTap: () async {
              Navigator.pop(context);
              if (!await requestMediaPermission(context, ImageSource.gallery)) return;
              final f = await ImagePicker().pickImage(
                  source: ImageSource.gallery, maxWidth: 1200, imageQuality: 88);
              if (f != null && mounted) setState(() => _banner = File(f.path));
            }),
          if (_banner != null) ...[
            Container(height: 0.5, color: TabuColors.border),
            _PickerTile(icon: Icons.delete_outline, label: 'REMOVER',
              color: TabuColors.error,
              onTap: () {
                Navigator.pop(context);
                setState(() => _banner = null);
              }),
          ],
          const SizedBox(height: 16),
        ])));
  }

  // ── Date/Time pickers ───────────────────────────────────────────────────
  Future<void> _pickDataInicio() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _dataInicio ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: _datePickerTheme);
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataInicio ?? now),
      builder: _datePickerTheme);
    if (time == null || !mounted) return;

    setState(() {
      _dataInicio = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
      if (_dataFim == null || _dataFim!.isBefore(_dataInicio!)) {
        _dataFim = _dataInicio!.add(const Duration(hours: 4));
      }
    });
  }

  Future<void> _pickDataFim() async {
    if (_dataInicio == null) { _showSnack('Defina o início primeiro'); return; }

    final lastDate    = _dataInicio!.add(const Duration(days: 3));
    final initialDate = (_dataFim != null &&
            !_dataFim!.isBefore(_dataInicio!) &&
            !_dataFim!.isAfter(lastDate))
        ? _dataFim!
        : _dataInicio!.add(const Duration(hours: 4)).isAfter(lastDate)
            ? lastDate
            : _dataInicio!.add(const Duration(hours: 4));

    final date = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: initialDate,
      firstDate: _dataInicio!,
      lastDate: lastDate,
      builder: _datePickerTheme);
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
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
            primary:   TabuColors.rosaPrincipal,
            onPrimary: TabuColors.textoSobreRosa,
            surface:   TabuColors.bg,
            onSurface: TabuColors.textoPrincipal,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: TabuColors.bg),
        ),
        child: child!);

  // ── Publicar ────────────────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      _showSnack('Nome da festa obrigatório'); return;
    }
    if (_dataInicio == null) {
      _showSnack('Defina a data de início'); return;
    }
    if (_dataFim == null) {
      _showSnack('Defina o horário de fim'); return;
    }
    // Endereço digitado mas não confirmado via sugestão
    if (_enderecoCtrl.text.trim().isNotEmpty && !_enderecoOk) {
      _showSnack('Selecione um endereço da lista de sugestões'); return;
    }

    setState(() {
      _salvando   = true;
      _uploading  = _banner != null;
      _uploadProg = 0;
    });
    FocusScope.of(context).unfocus();

    try {
      String? bannerUrl;
      if (_banner != null) {
        final ref = FirebaseStorage.instance
            .ref('festas/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final task = ref.putFile(
            _banner!, SettableMetadata(contentType: 'image/jpeg'));
        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          setState(() => _uploadProg = snap.bytesTransferred /
              (snap.totalBytes == 0 ? 1 : snap.totalBytes));
        });
        await task;
        bannerUrl = await ref.getDownloadURL();
      }

      if (!mounted) return;
      setState(() => _uploading = false);

      final r = _addrCtrl.resolved;

      await PartyService.instance.createFesta(
        creatorId:     _uid,
        creatorName:   _userName,
        creatorAvatar: _userAvatar,
        nome:          _nomeCtrl.text.trim(),
        descricao:     _descCtrl.text.trim(),
        local:         r?.description,
        bairro:        r?.description, // campo 'bairro' por compatibilidade
        state:         r?.state,
        city:          r?.city,
        latitude:      r?.lat,
        longitude:     r?.lng,
        dataInicio:    _dataInicio!,
        dataFim:       _dataFim!,
        bannerUrl:     bannerUrl,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('createFesta error: $e');
      if (mounted) {
        setState(() { _salvando = false; _uploading = false; });
        _showSnack('Erro ao criar. Tente novamente.');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: TabuColors.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
          side: BorderSide(color: TabuColors.border, width: 0.8)),
      margin: const EdgeInsets.all(16),
      content: Text(msg, style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 12, letterSpacing: 1.5,
          color: TabuColors.textoPrincipal))));
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _CreateFestaBg())),
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TabuColors.rosaDeep, TabuColors.rosaPrincipal,
                TabuColors.rosaClaro,
                TabuColors.rosaPrincipal, TabuColors.rosaDeep,
                Colors.transparent,
              ])))),

        SafeArea(child: Column(children: [

          // ── App Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: TabuColors.dim, size: 16),
                onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('CRIAR FESTA',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: TabuTypography.displayFont,
                    fontSize: 20, letterSpacing: 5,
                    color: TabuColors.textoPrincipal))),
              GestureDetector(
                onTap: (_salvando || _uploading) ? null : _publicar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_salvando || _uploading)
                        ? TabuColors.bgCard
                        : TabuColors.rosaPrincipal,
                    border: Border.all(
                        color: TabuColors.rosaPrincipal, width: 0.8)),
                  child: _salvando || _uploading
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: TabuColors.rosaPrincipal,
                              strokeWidth: 1.5))
                      : const Text('PUBLICAR',
                          style: TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              color: TabuColors.textoSobreRosa)))),
            ])),

          Container(height: 0.5,
              margin: const EdgeInsets.only(top: 10),
              color: TabuColors.border),

          // ── Formulário ───────────────────────────────────────────────
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
                  _buildField(ctrl: _nomeCtrl, focus: _nomeFocus,
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
                        onTap: _pickDataFim,
                        disabled: _dataInicio == null)),
                  ]),
                  const SizedBox(height: 28),

                  // DESCRIÇÃO
                  _buildSectionLabel('DESCRIÇÃO',
                      Icons.edit_note_outlined),
                  const SizedBox(height: 8),
                  _buildField(ctrl: _descCtrl, focus: _descFocus,
                      hint: 'Conta como vai ser a noite...',
                      maxLines: 5, maxLength: 400,
                      action: TextInputAction.newline),

                  if (_uploading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ENVIANDO BANNER ${(_uploadProg * 100).toInt()}%',
                            style: const TextStyle(
                                fontFamily: TabuTypography.bodyFont,
                                fontSize: 9, letterSpacing: 2,
                                color: TabuColors.rosaPrincipal)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: LinearProgressIndicator(
                                value: _uploadProg,
                                backgroundColor: TabuColors.border,
                                color: TabuColors.rosaPrincipal,
                                minHeight: 2)),
                        ])),
                ])))),
        ])),
      ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOCAL — widgets
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLocalSectionLabel() {
    final temLocal = _enderecoOk;
    return Row(children: [
      Icon(Icons.location_on_outlined,
          color: temLocal ? TabuColors.rosaPrincipal : TabuColors.textoMuted,
          size: 12),
      const SizedBox(width: 7),
      Text('LOCAL', style: TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3,
          color: temLocal ? TabuColors.rosaPrincipal : TabuColors.textoMuted)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.6)),
        child: const Text('OPCIONAL', style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 7, fontWeight: FontWeight.w600,
            letterSpacing: 1.5, color: TabuColors.textoMuted))),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 0.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TabuColors.border, Colors.transparent])))),
      if (temLocal || _enderecoCtrl.text.isNotEmpty)
        GestureDetector(
          onTap: _limparLocal,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.close_rounded,
                  color: TabuColors.textoMuted, size: 12),
              SizedBox(width: 3),
              Text('LIMPAR', style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 8, letterSpacing: 1.5,
                  color: TabuColors.textoMuted)),
            ]))),
    ]);
  }

  Widget _buildEnderecoField() {
    final status  = _addrCtrl.status;
    final focused = _enderecoFocus.hasFocus;

    final borda = status == AddressStatus.ok
        ? TabuColors.rosaPrincipal
        : status == AddressStatus.error
            ? TabuColors.error
            : status == AddressStatus.loading
                ? TabuColors.rosaPrincipal.withOpacity(0.5)
                : focused ? TabuColors.rosaPrincipal : TabuColors.border;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Campo de texto
      Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: borda, width: 1)),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              color: TabuColors.textoMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _enderecoCtrl,
              focusNode:  _enderecoFocus,
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 15, fontWeight: FontWeight.w400,
                  color: TabuColors.textoPrincipal),
              cursorColor: TabuColors.rosaPrincipal,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                border: InputBorder.none, isDense: true,
                hintText: 'Buscar endereço do evento...',
                hintStyle: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 13, color: TabuColors.textoMuted),
                contentPadding: EdgeInsets.symmetric(vertical: 14)),
              onChanged: (v) => _addrCtrl.onChanged(v),
              onEditingComplete: () {
                FocusScope.of(context).unfocus();
                _addrCtrl.onUnfocused();
              },
            ),
          ),
          // Suffix de status
          if (status == AddressStatus.loading)
            const Padding(padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: TabuColors.rosaPrincipal, strokeWidth: 1.5)))
          else if (status == AddressStatus.ok)
            const Padding(padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.check_circle_rounded,
                  color: TabuColors.rosaPrincipal, size: 18))
          else if (status == AddressStatus.error)
            Padding(padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.cancel_rounded,
                  color: TabuColors.error, size: 18))
          else if (_addrCtrl.loadingSuggestions)
            const Padding(padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: TabuColors.rosaPrincipal, strokeWidth: 1.5)))
          else
            const SizedBox(width: 10),
        ]),
      ),

      // Feedback de status
      if (status == AddressStatus.error && _addrCtrl.errorMessage != null)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: TabuColors.error, size: 11),
            const SizedBox(width: 4),
            Expanded(child: Text(_addrCtrl.errorMessage!,
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8,
                  color: TabuColors.error))),
          ]))
      else if (status == AddressStatus.ok &&
               _addrCtrl.resolved != null)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: TabuColors.rosaPrincipal, size: 11),
            const SizedBox(width: 4),
            Expanded(child: Text(
              _addrCtrl.resolved!.city.isNotEmpty
                  ? 'Confirmado em ${_addrCtrl.resolved!.city}'
                  : 'Endereço confirmado',
              style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8,
                  color: TabuColors.rosaPrincipal))),
          ]))
      else if (status == AddressStatus.idle &&
               _enderecoCtrl.text.isNotEmpty &&
               !_addrCtrl.loadingSuggestions &&
               _addrCtrl.suggestions.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 5, left: 2),
          child: Row(children: const [
            Icon(Icons.touch_app_outlined,
                color: TabuColors.textoMuted, size: 11),
            SizedBox(width: 4),
            Text('Selecione um endereço da lista',
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.8,
                  color: TabuColors.textoMuted)),
          ])),

      // Coordenadas
      if (status == AddressStatus.ok && _addrCtrl.resolved != null)
        Padding(padding: const EdgeInsets.only(top: 4, left: 2),
          child: Row(children: [
            const Icon(Icons.my_location,
                color: TabuColors.textoMuted, size: 11),
            const SizedBox(width: 4),
            Text(
              '${_addrCtrl.resolved!.lat.toStringAsFixed(6)}, '
              '${_addrCtrl.resolved!.lng.toStringAsFixed(6)}',
              style: const TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.6,
                  color: TabuColors.textoMuted)),
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
        color: TabuColors.bgCard,
        border: Border.all(color: TabuColors.border, width: 0.8)),
      child: Column(children: suggestions.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Column(children: [
          if (i > 0)
            Container(height: 0.5,
                color: TabuColors.border.withOpacity(0.5)),
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
                    size: 16, color: TabuColors.rosaPrincipal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.mainText,
                        style: const TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: TabuColors.textoPrincipal)),
                      if (s.description != s.mainText)
                        Text(s.description
                            .replaceFirst('${s.mainText}, ', ''),
                          style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 11,
                              color: TabuColors.textoSecundario)),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: TabuColors.textoMuted),
              ])),
          ),
        ]);
      }).toList()),
    );
  }

  // ── Widgets genéricos ───────────────────────────────────────────────────

  Widget _buildBannerPicker() {
    return GestureDetector(
      onTap: _pickBanner,
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(
            color: _banner != null
                ? TabuColors.rosaPrincipal.withOpacity(0.5)
                : TabuColors.border,
            width: _banner != null ? 1 : 0.8)),
        child: _banner != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(_banner!, fit: BoxFit.cover),
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
                      color: Colors.black.withOpacity(0.45),
                      border: Border.all(
                          color: TabuColors.borderMid, width: 0.6)),
                    child: const Text('TROCAR', style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 9, letterSpacing: 2,
                        color: Colors.white)))),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(width: 44, height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: TabuColors.bgAlt,
                        border: Border.fromBorderSide(BorderSide(
                            color: TabuColors.border, width: 0.8))),
                      child: Icon(Icons.add_photo_alternate_outlined,
                          color: TabuColors.rosaPrincipal, size: 20))),
                  SizedBox(height: 12),
                  Text('ADICIONAR BANNER', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 3, color: TabuColors.textoMuted)),
                  SizedBox(height: 4),
                  Text('Recomendado: 1200 × 600px', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 9, letterSpacing: 0.5,
                      color: TabuColors.border)),
                ])));
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: TabuColors.rosaPrincipal, size: 12),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 9, fontWeight: FontWeight.w700,
          letterSpacing: 3, color: TabuColors.rosaPrincipal)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 0.5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [TabuColors.border, Colors.transparent])))),
    ]);
  }

  Widget _buildField({
    required TextEditingController ctrl,
    FocusNode? focus,
    required String hint,
    FocusNode? nextFocus,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization capitalize = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextFormField(
      controller: ctrl, focusNode: focus,
      maxLines: maxLines, maxLength: maxLength,
      textCapitalization: capitalize, textInputAction: action,
      onEditingComplete: nextFocus != null
          ? () => FocusScope.of(context).requestFocus(nextFocus)
          : () => FocusScope.of(context).unfocus(),
      style: const TextStyle(fontFamily: TabuTypography.bodyFont,
          fontSize: 15, fontWeight: FontWeight.w400,
          letterSpacing: 0.3, color: TabuColors.textoPrincipal),
      cursorColor: TabuColors.rosaPrincipal, cursorWidth: 1,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 13, color: TabuColors.textoMuted),
        filled: true, fillColor: TabuColors.bgCard,
        counterStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, color: TabuColors.textoMuted),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.border, width: 0.8)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      ));
  }

  Widget _buildDateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: disabled
              ? TabuColors.bgCard.withOpacity(0.5)
              : TabuColors.bgCard,
          border: Border.all(
            color: hasValue
                ? TabuColors.rosaPrincipal.withOpacity(0.5)
                : disabled
                    ? TabuColors.border.withOpacity(0.3)
                    : TabuColors.border,
            width: hasValue ? 1 : 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: hasValue
                    ? TabuColors.rosaPrincipal
                    : disabled ? TabuColors.border : TabuColors.textoMuted)),
            const SizedBox(height: 6),
            if (hasValue) ...[
              Text(_formatDate(value), style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: TabuColors.textoPrincipal, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(_formatTime(value), style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, color: TabuColors.rosaPrincipal)),
            ] else
              Row(children: [
                Icon(Icons.add_rounded, size: 12,
                  color: disabled ? TabuColors.border : TabuColors.textoMuted),
                const SizedBox(width: 4),
                Text('Definir', style: TextStyle(
                    fontFamily: TabuTypography.bodyFont, fontSize: 11,
                    color: disabled ? TabuColors.border : TabuColors.textoMuted)),
              ]),
          ])));
  }

  String _formatDate(DateTime dt) {
    const meses = ['Jan','Fev','Mar','Abr','Mai','Jun',
                   'Jul','Ago','Set','Out','Nov','Dez'];
    return '${dt.day.toString().padLeft(2,'0')} ${meses[dt.month-1]}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:'
      '${dt.minute.toString().padLeft(2,'0')}';
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _PickerTile extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap; final Color color;
  const _PickerTile({
    required this.icon, required this.label,
    required this.onTap, this.color = TabuColors.textoPrincipal});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        Icon(icon, color: color, size: 20), const SizedBox(width: 16),
        Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 14, fontWeight: FontWeight.w600,
            letterSpacing: 2.5, color: color)),
      ])));
}

class _CreateFestaBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.1), size.width * 0.65,
      Paint()..shader = RadialGradient(colors: [
        TabuColors.rosaPrincipal.withOpacity(0.06), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.1),
          radius: size.width * 0.65)));
  }
  @override bool shouldRepaint(_CreateFestaBg _) => false;
}