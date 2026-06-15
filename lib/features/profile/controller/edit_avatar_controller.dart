// lib/features/profile/presentation/controllers/edit_avatar_controller.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/profile/data/services/avatar_service.dart';

enum AvatarSaveStatus { idle, loading, success, error }

/// Controller do fluxo de troca / remoção de foto de perfil.
///
/// Responsabilidades:
///  - Rastrear o [File] selecionado localmente (preview imediato na UI)
///  - Expor progresso de upload (0.0 → 1.0)
///  - Chamar [AvatarService] para persistir e sincronizar
///  - Devolver a nova URL via [newAvatarUrl] após sucesso
class EditAvatarController extends ChangeNotifier {
  EditAvatarController({required AvatarService service})
      : _service = service;

  final AvatarService _service;

  // ── Estado ────────────────────────────────────────────────────────────────

  File?              _pendingFile;
  double             _uploadProgress  = 0;
  AvatarSaveStatus   _status          = AvatarSaveStatus.idle;
  String?            _errorMessage;
  String?            _newAvatarUrl;

  // ── Getters públicos ──────────────────────────────────────────────────────

  /// Arquivo selecionado aguardando upload (ou em upload). Nulo se não houver.
  File?            get pendingFile     => _pendingFile;

  /// Progresso do upload atual (0.0 a 1.0).
  double           get uploadProgress  => _uploadProgress;

  AvatarSaveStatus get status          => _status;
  String?          get errorMessage    => _errorMessage;

  /// URL do avatar após upload bem-sucedido. Disponível somente quando
  /// [status] == [AvatarSaveStatus.success].
  String?          get newAvatarUrl    => _newAvatarUrl;

  bool get isUploading => _status == AvatarSaveStatus.loading;
  bool get hasError    => _status == AvatarSaveStatus.error;

  // ── Ações ─────────────────────────────────────────────────────────────────

  /// Define o arquivo selecionado pelo usuário e dispara o upload imediatamente.
  Future<void> pickAndUpload({
    required String uid,
    required File imageFile,
    required String currentAvatarUrl,
  }) async {
    _pendingFile    = imageFile;
    _uploadProgress = 0;
    _newAvatarUrl   = null;
    _errorMessage   = null;
    _status         = AvatarSaveStatus.loading;
    notifyListeners();

    try {
      final result = await _service.uploadAvatar(
        uid:              uid,
        imageFile:        imageFile,
        currentAvatarUrl: currentAvatarUrl,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );
      _newAvatarUrl = result.url;
      _pendingFile  = null;
      _status       = AvatarSaveStatus.success;
    } on AvatarServiceException catch (e) {
      _errorMessage = e.message;
      _pendingFile  = null;
      _status       = AvatarSaveStatus.error;
    } catch (_) {
      _errorMessage = 'Erro inesperado ao enviar foto.';
      _pendingFile  = null;
      _status       = AvatarSaveStatus.error;
    }

    notifyListeners();
  }

  /// Remove o avatar atual.
  Future<void> removeAvatar({
    required String uid,
    required String currentAvatarUrl,
  }) async {
    _uploadProgress = 0;
    _newAvatarUrl   = null;
    _errorMessage   = null;
    _status         = AvatarSaveStatus.loading;
    notifyListeners();

    try {
      await _service.removeAvatar(
        uid:              uid,
        currentAvatarUrl: currentAvatarUrl,
      );
      _newAvatarUrl = '';   // URL vazia sinaliza "sem avatar"
      _status       = AvatarSaveStatus.success;
    } on AvatarServiceException catch (e) {
      _errorMessage = e.message;
      _status       = AvatarSaveStatus.error;
    } catch (_) {
      _errorMessage = 'Erro inesperado ao remover foto.';
      _status       = AvatarSaveStatus.error;
    }

    notifyListeners();
  }

  void resetStatus() {
    _status       = AvatarSaveStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}

