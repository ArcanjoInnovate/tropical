// lib/features/profile/data/repositories/identity_repository.dart

import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tabuapp/features/profile/data/models/identify_model.dart';

abstract class IIdentityRepository {
  Future<void> saveIdentity({
    required String uid,
    required IdentityModel data,
    List<int>? partnerImageBytes,
  });
}

class IdentityRepository implements IIdentityRepository {
  IdentityRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _usersRef       => _db.ref('Users');
  DatabaseReference get _usersPublicRef => _db.ref('UsersPublic');
  DatabaseReference get _matchsRef      => _db.ref('Matchs');

  // Caminho fixo no Storage — sempre o mesmo por usuário.
  Reference _partnerAvatarRef(String uid) =>
      FirebaseStorage.instance.ref('partner_avatars/$uid/partner.jpg');

  @override
  Future<void> saveIdentity({
    required String uid,
    required IdentityModel data,
    List<int>? partnerImageBytes,
  }) async {
    IdentityModel finalData = data;

    // ── Caso 1: Voltou para solteiro ──────────────────────────────────────
    if (data.profileType != 'couple') {
      await _deletePartnerAvatar(uid);
    }
    // ── Caso 2: Trocou a foto do parceiro ─────────────────────────────────
    else if (partnerImageBytes != null && partnerImageBytes.isNotEmpty) {
      await _deletePartnerAvatar(uid);
      final avatarUrl = await _uploadPartnerAvatar(
        uid:        uid,
        imageBytes: partnerImageBytes,
      );
      finalData = IdentityModel(
        profileType:       data.profileType,
        genderIdentity:    data.genderIdentity,
        relationshipType:  data.relationshipType,
        sexualOrientation: data.sexualOrientation,
        partner: PartnerModel(
          name:              data.partner!.name,
          birthDate:         data.partner!.birthDate,
          genderIdentity:    data.partner!.genderIdentity,
          sexualOrientation: data.partner!.sexualOrientation,
          avatarUrl:         avatarUrl,
        ),
      );
    }

    // ── Atualiza Users/{uid} ──────────────────────────────────────────────
    final userMap = finalData.toMap();
    await _usersRef.child(uid).update(userMap);

    if (finalData.profileType != 'couple') {
      await _usersRef.child(uid).child('partner').remove();
    }

    // ── Sincroniza identidade completa em UsersPublic/{uid} ───────────────
    //
    // Inclui uid obrigatório (validado pela regra newData.val() === $uid),
    // todos os campos de identidade e partner quando aplicável.
    // Calculamos age aqui para não depender do syncToPublic posterior.
    final publicIdentity = <String, dynamic>{
      'uid':                uid,
      'gender_identity':    finalData.genderIdentity,
      'sexual_orientation': finalData.sexualOrientation,
      'relationship_type':  finalData.relationshipType,
      'profile_type':       finalData.profileType,
    };

    // age calculado a partir de birth_date já gravado em Users
    final birthSnap = await _usersRef.child(uid).child('birth_date').get();
    final birthStr  = birthSnap.value as String?;
    if (birthStr != null && birthStr.isNotEmpty) {
      final birth = DateTime.tryParse(birthStr);
      if (birth != null) {
        final now = DateTime.now();
        int age = now.year - birth.year;
        if (now.month < birth.month ||
            (now.month == birth.month && now.day < birth.day)) age--;
        if (age >= 0) {
          publicIdentity['birth_date'] = birthStr;
          publicIdentity['age']        = age;
        }
      }
    }

    if (finalData.profileType == 'couple' && finalData.partner != null) {
      publicIdentity['partner'] = {
        'name':              finalData.partner!.name,
        'birth_date':        finalData.partner!.birthDate,
        'gender_identity':   finalData.partner!.genderIdentity,
        'sexual_orientation':finalData.partner!.sexualOrientation,
        'avatar_url':        finalData.partner!.avatarUrl,
      };
    } else {
      // Remove partner de UsersPublic quando volta para solteiro
      publicIdentity['partner'] = null;
    }

    await _usersPublicRef.child(uid).update(publicIdentity);

    // ── Upsert Matchs/{uid} ───────────────────────────────────────────────
    final matchFields = <String, dynamic>{
      'profile_type':      finalData.profileType,
      'relationship_type': finalData.relationshipType,
      if (finalData.profileType == 'couple' && finalData.partner != null)
        'partner': {
          'name':       finalData.partner!.name,
          'birth_date': finalData.partner!.birthDate,
          'avatar_url': finalData.partner!.avatarUrl,
        },
    };

    final matchSnap = await _matchsRef.child(uid).get();
    if (matchSnap.exists) {
      if (finalData.profileType != 'couple') {
        await _matchsRef.child(uid).child('partner').remove();
      }
      await _matchsRef.child(uid).update(matchFields);
    } else {
      await _matchsRef.child(uid).set({'uid': uid, ...matchFields});
    }
  }

  // ── Privado: upload ───────────────────────────────────────────────────────

  Future<String> _uploadPartnerAvatar({
    required String uid,
    required List<int> imageBytes,
  }) async {
    try {
      final task = await _partnerAvatarRef(uid).putData(
        Uint8List.fromList(imageBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await task.ref.getDownloadURL();
    } catch (e) {
      throw IdentityRepositoryException(
          'Falha ao enviar foto do parceiro: $e');
    }
  }

  // ── Privado: delete ───────────────────────────────────────────────────────

  Future<void> _deletePartnerAvatar(String uid) async {
    try {
      await _partnerAvatarRef(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw IdentityRepositoryException(
          'Falha ao remover foto do parceiro: ${e.message}');
    }
  }
}

class IdentityRepositoryException implements Exception {
  const IdentityRepositoryException(this.message);
  final String message;

  @override
  String toString() => 'IdentityRepositoryException: $message';
}