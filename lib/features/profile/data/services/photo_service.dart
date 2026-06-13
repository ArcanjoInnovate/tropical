// lib/features/profile/data/services/photos_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:tabuapp/features/profile/data/repositories/photo_repository.dart';

class PhotosServiceException implements Exception {
  PhotosServiceException(this.message);
  final String message;
  @override
  String toString() => 'PhotosServiceException: $message';
}

class PhotosService {
  PhotosService({
    required IPhotoRepository repository,
    FirebaseStorage? storage,
  })  : _repository = repository,
        _storage = storage ?? FirebaseStorage.instance;

  final IPhotoRepository _repository;
  final FirebaseStorage   _storage;
  final ImagePicker       _picker  = ImagePicker();

  // ── Pick ──────────────────────────────────────────────────────────────────

  /// Abre a galeria e retorna o arquivo selecionado, ou null se cancelado.
  Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source:    ImageSource.gallery,
      maxWidth:  1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
  }

  /// Abre a câmera e retorna o arquivo capturado, ou null se cancelado.
  Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(
      source:    ImageSource.camera,
      maxWidth:  1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Faz upload do [xFile] para o Storage e grava a URL resultante no
  /// Realtime Database (Users + Matchs).
  ///
  /// [onProgress] recebe valores de 0.0 a 1.0 durante o upload.
  Future<String> uploadAndSave({
    required String uid,
    required XFile  xFile,
    required String currentAvatarUrl,
    void Function(double)? onProgress,
  }) async {
    try {
      // Remove avatar anterior do Storage (se existir e for do mesmo bucket)
      await _deleteOldAvatar(currentAvatarUrl);

      final ref = _storage
          .ref()
          .child('avatars')
          .child(uid)
          .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

      UploadTask task;

      if (kIsWeb) {
        final bytes = await xFile.readAsBytes();
        task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        task = ref.putFile(
          File(xFile.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Escuta progresso
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(snap.bytesTransferred / snap.totalBytes);
        }
      });

      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();

      // Persiste nos dois nós do Realtime Database
      await _repository.saveAvatarUrl(uid: uid, avatarUrl: url);

      return url;
    } on FirebaseException catch (e) {
      throw PhotosServiceException(e.message ?? 'Erro ao enviar foto.');
    } catch (e) {
      throw PhotosServiceException('Erro inesperado: $e');
    }
  }

  /// Remove o avatar atual e grava URL vazia no banco.
  Future<void> removeAndSave({
    required String uid,
    required String currentAvatarUrl,
  }) async {
    try {
      await _deleteOldAvatar(currentAvatarUrl);
      await _repository.saveAvatarUrl(uid: uid, avatarUrl: '');
    } on FirebaseException catch (e) {
      throw PhotosServiceException(e.message ?? 'Erro ao remover foto.');
    } catch (e) {
      throw PhotosServiceException('Erro inesperado: $e');
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Future<void> _deleteOldAvatar(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Ignora — arquivo pode não existir ou URL pode ser externa
    }
  }
}