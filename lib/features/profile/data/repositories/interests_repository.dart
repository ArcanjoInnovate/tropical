// lib/features/profile/data/repositories/interests_repository.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/features/profile/data/models/interests_model.dart';

abstract class IInterestsRepository {
  /// Persiste [InterestsModel] em Users/{uid} e sincroniza Matchs/{uid}.
  Future<void> saveInterests({
    required String uid,
    required InterestsModel data,
  });
}

class InterestsRepository implements IInterestsRepository {
  InterestsRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _usersRef  => _db.ref('Users');
  DatabaseReference get _matchsRef => _db.ref('Matchs');

  @override
  Future<void> saveInterests({
    required String uid,
    required InterestsModel data,
  }) async {
    final list = data.interests;

    // 1 — Atualiza Users/{uid}/interests
    await _usersRef.child(uid).child('interests').set(list);

    // 2 — Upsert Matchs/{uid}/interests
    final matchSnap = await _matchsRef.child(uid).get();
    if (matchSnap.exists) {
      await _matchsRef.child(uid).child('interests').set(list);
    } else {
      // Cria nó mínimo para não deixar órfão
      await _matchsRef.child(uid).set({'uid': uid, 'interests': list});
    }
  }
}

class InterestsRepositoryException implements Exception {
  const InterestsRepositoryException(this.message);
  final String message;

  @override
  String toString() => 'InterestsRepositoryException: $message';
}