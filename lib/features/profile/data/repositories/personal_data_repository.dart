// lib/features/profile/data/repositories/personal_data_repository.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/features/profile/data/models/personal_data_model.dart';

abstract class IPersonalDataRepository {
  Future<void> savePersonalData({
    required String uid,
    required PersonalDataModel data,
    required Map<String, dynamic> fullUserData,
  });
}

class PersonalDataRepository implements IPersonalDataRepository {
  PersonalDataRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _usersRef       => _db.ref('Users');
  DatabaseReference get _usersPublicRef => _db.ref('UsersPublic');
  DatabaseReference get _matchsRef      => _db.ref('Matchs');

  @override
  Future<void> savePersonalData({
    required String uid,
    required PersonalDataModel data,
    required Map<String, dynamic> fullUserData,
  }) async {
    // ── 1. Atualiza Users/{uid} ───────────────────────────────────────────
    final dataMap = data.toMap();
    await _usersRef.child(uid).update(dataMap);

    // ── 2. Sincroniza UsersPublic/{uid} ───────────────────────────────────
    //
    // IMPORTANTE: inclui 'uid' obrigatório (regra valida newData.val() === $uid)
    // e todos os campos de identidade já existentes em Users para não
    // perder o que foi salvo pelo identify_repository.
    final publicFields = <String, dynamic>{
      'uid':  uid,
      'name': dataMap['name'],
      'bio':  dataMap['bio'],
    };

    // birth_date e age
    if (dataMap.containsKey('birth_date')) {
      publicFields['birth_date'] = dataMap['birth_date'];
    }
    if (dataMap.containsKey('age')) {
      publicFields['age'] = dataMap['age'];
    }

    // Preserva campos de identidade já existentes em Users
    // (gravados pelo identify_repository — não devem ser apagados aqui)
    final identityFields = [
      'gender_identity',
      'sexual_orientation',
      'relationship_type',
      'profile_type',
    ];
    for (final field in identityFields) {
      final val = fullUserData[field] as String?;
      if (val != null && val.isNotEmpty) {
        publicFields[field] = val;
      }
    }

    // Preserva partner se o usuário for casal
    final rawPartner = fullUserData['partner'];
    if (rawPartner is Map) {
      final p = <String, dynamic>{};
      void addP(String k) {
        final v = rawPartner[k];
        if (v != null && v.toString().isNotEmpty) p[k] = v;
      }
      addP('name');
      addP('gender_identity');
      addP('sexual_orientation');
      addP('birth_date');
      addP('avatar_url');
      if (p.isNotEmpty) publicFields['partner'] = p;
    }

    await _usersPublicRef.child(uid).update(publicFields);

    // ── 3. Sincroniza Matchs/{uid} ────────────────────────────────────────
    final matchProfile = MatchProfileModel.fromUserWithEdits(
      fullUserData: fullUserData,
      edits: data,
    );

    final matchRef  = _matchsRef.child(uid);
    final matchSnap = await matchRef.get();

    if (matchSnap.exists) {
      await matchRef.update(matchProfile.toPartialUpdateMap());
    } else {
      await matchRef.set(matchProfile.toMap());
    }
  }
}