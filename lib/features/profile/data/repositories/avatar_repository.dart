// lib/features/profile/data/repositories/avatar_repository.dart

import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tabuapp/features/profile/data/models/avatar_model.dart';

abstract class IAvatarRepository {
  /// Faz upload de [imageFile] para o Storage, persiste a URL em
  /// `Users/{uid}/avatar` e sincroniza `Matchs/{uid}/avatar`.
  ///
  /// [onProgress] é chamado com valores de 0.0 a 1.0 durante o upload.
  Future<AvatarModel> uploadAvatar({
    required String uid,
    required File imageFile,
    required String currentAvatarUrl,
    void Function(double progress)? onProgress,
  });

  /// Remove a foto de perfil: apaga do Storage (se existir) e limpa o campo
  /// `avatar` em `Users/{uid}` e `Matchs/{uid}`.
  Future<void> removeAvatar({
    required String uid,
    required String currentAvatarUrl,
  });
}

class AvatarRepository implements IAvatarRepository {
  AvatarRepository({
    FirebaseDatabase? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseDatabase.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseDatabase _db;
  final FirebaseStorage  _storage;

  DatabaseReference get _usersRef  => _db.ref('Users');
  DatabaseReference get _matchsRef => _db.ref('Matchs');

  // ── Upload ────────────────────────────────────────────────────────────────

  @override
  Future<AvatarModel> uploadAvatar({
    required String uid,
    required File imageFile,
    required String currentAvatarUrl,
    void Function(double progress)? onProgress,
  }) async {
    // 1 — Remove avatar anterior do Storage (silencioso se não existir)
    if (currentAvatarUrl.isNotEmpty) {
      await _tryDeleteFromStorage(currentAvatarUrl);
    }

    // 2 — Upload do novo arquivo
    final ref = _storage
        .ref('avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await uploadTask;
    final url = await ref.getDownloadURL();
    final model = AvatarModel(url: url);

    // 3 — Persiste em Users/{uid}
    await _usersRef.child(uid).update(model.toMap());

    // 4 — Sincroniza Matchs/{uid}/avatar (upsert)
    await _syncMatchAvatar(uid: uid, url: url);

    return model;
  }

  // ── Remove ────────────────────────────────────────────────────────────────

  @override
  Future<void> removeAvatar({
    required String uid,
    required String currentAvatarUrl,
  }) async {
    // 1 — Apaga do Storage (silencioso se não existir)
    if (currentAvatarUrl.isNotEmpty) {
      await _tryDeleteFromStorage(currentAvatarUrl);
    }

    // 2 — Limpa em Users/{uid}
    await _usersRef.child(uid).update({'avatar': ''});

    // 3 — Limpa em Matchs/{uid}
    await _syncMatchAvatar(uid: uid, url: '');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Sincroniza apenas o campo `avatar` em Matchs/{uid}.
  /// Se o nó não existir ainda, cria com uid mínimo para não deixar órfão.
  Future<void> _syncMatchAvatar({
    required String uid,
    required String url,
  }) async {
    final matchSnap = await _matchsRef.child(uid).get();
    if (matchSnap.exists) {
      await _matchsRef.child(uid).update({'avatar': url});
    } else {
      await _matchsRef.child(uid).set({'uid': uid, 'avatar': url});
    }
  }

  /// Tenta deletar a URL do Storage sem lançar exceção caso já não exista.
  Future<void> _tryDeleteFromStorage(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Arquivo pode não existir mais — ignora silenciosamente
    }
  }
}

class AvatarRepositoryException implements Exception {
  const AvatarRepositoryException(this.message);
  final String message;

  @override
  String toString() => 'AvatarRepositoryException: $message';
}