// lib/features/profile/controller/edit_identify_controller.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/profile/data/models/identify_model.dart';
import 'package:tclub/features/profile/data/services/identify_service.dart';
import 'package:tclub/features/profile/data/services/profile_service.dart'; // ← adicionado
import 'package:tclub/features/profile/presentation/widgets/edit_profile_enums.dart';

enum SaveStatus { idle, saving, success, error }

class EditIdentityController extends ChangeNotifier {
  EditIdentityController({
    required IdentityService service,
    required Map<String, dynamic> userData,
  })  : _service = service,
        _userData = userData {
    _initFromUserData();
  }

  final IdentityService      _service;
  final Map<String, dynamic> _userData;

  // ── Estado dos campos ────────────────────────────────────────────────────

  TipoPerfil?         _tipoPerfil;
  TipoRelacionamento? _tipoRelacionamento;
  OrientacaoSexual?   _orientacao;
  bool                _isCasal = false;

  // parceiro
  String            _partnerName        = '';
  TipoPerfil?       _partnerGender;
  OrientacaoSexual? _partnerOrientation;
  DateTime?         _partnerBirthDate;
  String            _partnerAvatarUrl   = '';
  File?             _partnerAvatarFile;

  // save
  SaveStatus _saveStatus = SaveStatus.idle;
  String?    _saveError;

  // ── Getters públicos ─────────────────────────────────────────────────────

  TipoPerfil?         get tipoPerfil        => _tipoPerfil;
  TipoRelacionamento? get tipoRelacionamento => _tipoRelacionamento;
  OrientacaoSexual?   get orientacao         => _orientacao;
  bool                get isCasal            => _isCasal;

  String            get partnerName        => _partnerName;
  TipoPerfil?       get partnerGender      => _partnerGender;
  OrientacaoSexual? get partnerOrientation => _partnerOrientation;
  DateTime?         get partnerBirthDate   => _partnerBirthDate;
  String            get partnerAvatarUrl   => _partnerAvatarUrl;
  File?             get partnerAvatarFile  => _partnerAvatarFile;

  SaveStatus get saveStatus => _saveStatus;
  String?    get saveError  => _saveError;
  bool       get isSaving   => _saveStatus == SaveStatus.saving;

  bool get partnerValid =>
      _partnerName.trim().isNotEmpty &&
      _partnerGender != null &&
      _partnerOrientation != null &&
      _partnerBirthDate != null &&
      (_partnerAvatarFile != null || _partnerAvatarUrl.isNotEmpty);

  String get partnerBirthDateLabel {
    if (_partnerBirthDate == null) return '';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    final d = _partnerBirthDate!;
    return '${d.day} de ${meses[d.month - 1]}, ${d.year}';
  }

  // ── Inicialização ─────────────────────────────────────────────────────────

  void _initFromUserData() {
    final d = _userData;

    final generoRaw =
        (d['gender_identity'] as String?)?.trim().isNotEmpty == true
            ? d['gender_identity'] as String
            : (d['tipoPerfil'] as String?)?.trim() ?? '';
    _tipoPerfil = _enumByName(TipoPerfil.values, generoRaw);

    final orientacaoRaw =
        (d['sexual_orientation'] as String?)?.trim().isNotEmpty == true
            ? d['sexual_orientation'] as String
            : (d['orientacaoSexual'] as String?)?.trim() ?? '';
    _orientacao = _enumByName(OrientacaoSexual.values, orientacaoRaw);

    final relRaw =
        (d['relationship_type'] as String?)?.trim().isNotEmpty == true
            ? d['relationship_type'] as String
            : (d['tipoRelacionamento'] as String?)?.trim() ?? '';
    _tipoRelacionamento = _enumByName(TipoRelacionamento.values, relRaw);

    final profileTypeRaw = (d['profile_type'] as String?)?.trim() ?? '';
    _isCasal = profileTypeRaw == 'couple';

    if (_isCasal) {
      final p    = d['partner'];
      final pMap = p is Map ? Map<String, dynamic>.from(p) : null;
      if (pMap != null) {
        _partnerName = (pMap['name'] as String?)?.trim() ?? '';
        _partnerGender = _enumByName(
          TipoPerfil.values,
          (pMap['gender_identity'] as String?)?.trim() ?? '',
        );
        _partnerOrientation = _enumByName(
          OrientacaoSexual.values,
          (pMap['sexual_orientation'] as String?)?.trim() ?? '',
        );
        final bd = (pMap['birth_date'] as String?)?.trim() ?? '';
        if (bd.isNotEmpty) _partnerBirthDate = _parseIsoDate(bd);
        _partnerAvatarUrl = (pMap['avatar_url'] as String?)?.trim() ?? '';
      }
    }
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  void selectTipoPerfil(TipoPerfil v) {
    _tipoPerfil = v;
    notifyListeners();
  }

  void selectTipoRelacionamento(TipoRelacionamento v) {
    _tipoRelacionamento = v;
    _isCasal = v.name == 'casal' || v.name == 'casalLiberal';
    if (!_isCasal) _clearPartner();
    notifyListeners();
  }

  void selectOrientacao(OrientacaoSexual v) {
    _orientacao = v;
    notifyListeners();
  }

  void setPartnerName(String v) {
    _partnerName = v;
    notifyListeners();
  }

  void setPartnerGender(TipoPerfil v) {
    _partnerGender = v;
    notifyListeners();
  }

  void setPartnerOrientation(OrientacaoSexual v) {
    _partnerOrientation = v;
    notifyListeners();
  }

  void setPartnerBirthDate(DateTime v) {
    _partnerBirthDate = v;
    notifyListeners();
  }

  void setPartnerAvatarFile(File file) {
    _partnerAvatarFile = file;
    notifyListeners();
  }

  void resetSaveStatus() {
    _saveStatus = SaveStatus.idle;
    _saveError  = null;
    notifyListeners();
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  //
  // Fluxo:
  //   1. IdentityService.saveIdentity → grava em Users/{uid}
  //   2. ProfileService.syncToPublic  → propaga para UsersPublic/{uid}  ← NOVO
  //   3. SaveStatus.success → tela fecha e retorna payload
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> save(String uid) async {
    _saveStatus = SaveStatus.saving;
    _saveError  = null;
    notifyListeners();

    try {
      List<int>? partnerImageBytes;
      if (_isCasal && _partnerAvatarFile != null) {
        partnerImageBytes = await _partnerAvatarFile!.readAsBytes();
      }

      PartnerModel? partner;
      if (_isCasal && partnerValid) {
        partner = PartnerModel(
          name:              _partnerName.trim(),
          birthDate:         _isoDate(_partnerBirthDate!),
          genderIdentity:    _partnerGender!.name,
          sexualOrientation: _partnerOrientation!.name,
          avatarUrl:         _partnerAvatarUrl,
        );
      }

      final model = IdentityModel(
        genderIdentity:    _tipoPerfil!.name,
        sexualOrientation: _orientacao!.name,
        relationshipType:  _tipoRelacionamento!.name,
        profileType:       _isCasal ? 'couple' : 'single',
        partner:           partner,
      );

      // 1. Grava em Users/{uid}
      await _service.saveIdentity(
        uid:               uid,
        data:              model,
        partnerImageBytes: partnerImageBytes,
      );

      _partnerAvatarFile = null;

      // 2. Propaga imediatamente para UsersPublic/{uid}
      //    Fire-and-forget: não bloqueia o retorno da tela.
      //    Se falhar, o log mostra — o próximo loadFullProfile corrige.
      ProfileService.instance.syncToPublic(uid);

      // 3. Sucesso → tela fecha
      _saveStatus = SaveStatus.success;
      notifyListeners();
    } catch (e) {
      _saveStatus = SaveStatus.error;
      _saveError  = e
          .toString()
          .replaceFirst('IdentityServiceException: ', '')
          .replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _clearPartner() {
    _partnerName        = '';
    _partnerGender      = null;
    _partnerOrientation = null;
    _partnerBirthDate   = null;
    _partnerAvatarUrl   = '';
    _partnerAvatarFile  = null;
  }

  T? _enumByName<T extends Enum>(List<T> values, String name) {
    if (name.isEmpty) return null;
    try {
      return values.firstWhere(
        (e) => e.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseIsoDate(String iso) {
    try {
      final parts = iso.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}

