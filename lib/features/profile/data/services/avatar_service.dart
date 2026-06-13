// lib/features/profile/data/services/avatar_service.dart

import 'dart:io';
import 'package:tabuapp/features/profile/data/models/avatar_model.dart';
import 'package:tabuapp/features/profile/data/repositories/avatar_repository.dart';

class AvatarService {
  AvatarService({required IAvatarRepository repository})
      : _repository = repository;

  final IAvatarRepository _repository;

  /// Faz upload do avatar, persiste em `Users/{uid}` e sincroniza
  /// `Matchs/{uid}/avatar`.
  ///
  /// Lança [AvatarServiceException] em caso de falha.
  Future<AvatarModel> uploadAvatar({
    required String uid,
    required File imageFile,
    required String currentAvatarUrl,
    void Function(double progress)? onProgress,
  }) async {
    if (uid.trim().isEmpty) {
      throw const AvatarServiceException('UID inválido.');
    }
    if (!imageFile.existsSync()) {
      throw const AvatarServiceException('Arquivo de imagem não encontrado.');
    }

    try {
      return await _repository.uploadAvatar(
        uid:               uid,
        imageFile:         imageFile,
        currentAvatarUrl:  currentAvatarUrl,
        onProgress:        onProgress,
      );
    } on AvatarRepositoryException catch (e) {
      throw AvatarServiceException(e.message);
    } catch (e) {
      throw AvatarServiceException('Falha ao enviar foto: $e');
    }
  }

  /// Remove o avatar do usuário em `Users/{uid}` e `Matchs/{uid}`.
  ///
  /// Lança [AvatarServiceException] em caso de falha.
  Future<void> removeAvatar({
    required String uid,
    required String currentAvatarUrl,
  }) async {
    if (uid.trim().isEmpty) {
      throw const AvatarServiceException('UID inválido.');
    }

    try {
      await _repository.removeAvatar(
        uid:               uid,
        currentAvatarUrl:  currentAvatarUrl,
      );
    } on AvatarRepositoryException catch (e) {
      throw AvatarServiceException(e.message);
    } catch (e) {
      throw AvatarServiceException('Falha ao remover foto: $e');
    }
  }
}

class AvatarServiceException implements Exception {
  const AvatarServiceException(this.message);
  final String message;

  @override
  String toString() => 'AvatarServiceException: $message';
}