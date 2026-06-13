// lib/features/profile/controller/edit_photos_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/core/services/user_avatar_service.dart';
import 'package:tabuapp/core/services/user_data_notifier.dart';
import 'package:tabuapp/core/services/user_profile_cache.dart';
import '../data/services/photo_service.dart';

enum PhotosStatus { idle, picking, uploading, removing, success, error }

class EditPhotosController extends ChangeNotifier {
  EditPhotosController({
    required PhotosService service,
    required String currentAvatarUrl,
  })  : _service       = service,
        _avatarUrl     = currentAvatarUrl;

  final PhotosService _service;

  // ── Estado ────────────────────────────────────────────────────────────────

  String         _avatarUrl      = '';
  XFile?         _pendingFile;
  double         _uploadProgress = 0;
  PhotosStatus   _status         = PhotosStatus.idle;
  String?        _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  String       get avatarUrl       => _avatarUrl;
  XFile?       get pendingFile     => _pendingFile;
  double       get uploadProgress  => _uploadProgress;
  PhotosStatus get status          => _status;
  String?      get errorMessage    => _errorMessage;

  bool get isIdle      => _status == PhotosStatus.idle;
  bool get isUploading => _status == PhotosStatus.uploading;
  bool get isRemoving  => _status == PhotosStatus.removing;
  bool get isBusy      => isUploading || isRemoving || _status == PhotosStatus.picking;
  bool get hasAvatar   => _avatarUrl.isNotEmpty;
  bool get isSuccess   => _status == PhotosStatus.success;
  bool get hasError    => _status == PhotosStatus.error;

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> pickFromGallery(String uid) async {
    await _pick(uid, fromCamera: false);
  }

  Future<void> pickFromCamera(String uid) async {
    await _pick(uid, fromCamera: true);
  }

  Future<void> _pick(String uid, {required bool fromCamera}) async {
    _status = PhotosStatus.picking;
    _errorMessage = null;
    notifyListeners();

    final xFile = fromCamera
        ? await _service.pickFromCamera()
        : await _service.pickFromGallery();

    if (xFile == null) {
      // Usuário cancelou
      _status = PhotosStatus.idle;
      notifyListeners();
      return;
    }

    _pendingFile    = xFile;
    _uploadProgress = 0;
    _status         = PhotosStatus.uploading;
    notifyListeners();

    try {
      final url = await _service.uploadAndSave(
        uid:              uid,
        xFile:            xFile,
        currentAvatarUrl: _avatarUrl,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );
      _avatarUrl    = url;
      _pendingFile  = null;
      _status       = PhotosStatus.success;
      _syncGlobal(url);
    } on PhotosServiceException catch (e) {
      _errorMessage = e.message;
      _pendingFile  = null;
      _status       = PhotosStatus.error;
    } catch (e) {
      _errorMessage = 'Erro inesperado ao enviar foto.';
      _pendingFile  = null;
      _status       = PhotosStatus.error;
    }

    notifyListeners();
  }

  Future<void> removeAvatar(String uid) async {
    if (!hasAvatar) return;

    _status       = PhotosStatus.removing;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.removeAndSave(
        uid:              uid,
        currentAvatarUrl: _avatarUrl,
      );
      _avatarUrl = '';
      _status    = PhotosStatus.success;
      _syncGlobal('');
    } on PhotosServiceException catch (e) {
      _errorMessage = e.message;
      _status       = PhotosStatus.error;
    } catch (e) {
      _errorMessage = 'Erro inesperado ao remover foto.';
      _status       = PhotosStatus.error;
    }

    notifyListeners();
  }

  // Invalida caches e atualiza o UserDataNotifier globalmente
  void _syncGlobal(String newUrl) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    UserAvatarService.instance.invalidate(uid);
    UserProfileCache.instance.invalidate(uid);
    UserDataNotifier.instance.update({'avatar': newUrl});
  }

  void resetStatus() {
    _status       = PhotosStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}