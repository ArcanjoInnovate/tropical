// lib/features/profile/data/repositories/photos_repository.dart

import 'package:firebase_database/firebase_database.dart';

abstract class IPhotoRepository {
  /// Retorna a URL do avatar principal salva no nó Users/{uid}.
  Future<String> fetchAvatarUrl(String uid);

  /// Persiste a nova URL nos dois nós ao mesmo tempo:
  ///   Users/{uid}/avatar   — perfil principal do usuário
  ///   Matchs/{uid}/avatar  — nó usado pelo sistema de match
  Future<void> saveAvatarUrl({
    required String uid,
    required String avatarUrl,
  });
}

class PhotosRepository implements IPhotoRepository {
  PhotosRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  @override
  Future<String> fetchAvatarUrl(String uid) async {
    final snap = await _db.ref('Users/$uid/avatar').get();
    return snap.value as String? ?? '';
  }

  @override
  Future<void> saveAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) async {
    // Escrita atômica nos dois nós
    await _db.ref().update({
      'Users/$uid/avatar':  avatarUrl,
      'Matchs/$uid/avatar': avatarUrl,
    });
  }
}

