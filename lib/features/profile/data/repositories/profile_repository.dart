// features/profile/data/repositories/profile_repository.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/profile_user_model.dart';

abstract class IProfileRepository {
  Future<ProfileUserModel?> fetchUser(String uid);
  Future<int> fetchFollowersCount(String uid);
  Future<int> fetchFollowingCount(String uid);
  Future<List<String>> fetchFollowersList(String uid);
  Future<List<String>> fetchVipFriends(String uid);
  Future<bool> isFollowing(String myUid, String targetUid);
  Future<bool> isVip(String myUid, String targetUid);
  Future<List<String>> filterExistingUsers(List<String> uids);
}

/// Converte recursivamente qualquer Map (incluindo Map<Object?,Object?>)
/// para Map<dynamic,dynamic>, e listas para List<dynamic>.
/// O Firebase RTDB retorna objetos aninhados com tipo Object? em todos
/// os níveis — Map.from() raso não converte os filhos.
dynamic _deepConvert(dynamic value) {
  if (value is Map) {
    return Map<dynamic, dynamic>.fromEntries(
      value.entries.map((e) => MapEntry(e.key, _deepConvert(e.value))),
    );
  }
  if (value is List) {
    return value.map(_deepConvert).toList();
  }
  return value;
}

class ProfileRepository implements IProfileRepository {
  ProfileRepository._();
  static final instance = ProfileRepository._();

  final _db = FirebaseDatabase.instance;

  @override
  Future<ProfileUserModel?> fetchUser(String uid) async {
    final snap = await _db.ref('Users/$uid').get();
    if (!snap.exists || snap.value == null) return null;
    final raw = _deepConvert(snap.value) as Map<dynamic, dynamic>;
    debugPrint('[Repo] fetchUser uid=$uid partner_raw=${raw['partner']}');
    return ProfileUserModel.fromMap(uid, raw);
  }

  Future<ProfileUserModel?> fetchPublicUser(String uid) async {
    final snap = await _db.ref('UsersPublic/$uid').get();
    if (!snap.exists || snap.value == null) return null;
    final raw = _deepConvert(snap.value) as Map<dynamic, dynamic>;
    debugPrint('[Repo] fetchPublicUser uid=$uid '
        'partner_raw=${raw['partner']} '
        'rel=${raw['relationship_type']} '
        'profileType=${raw['profile_type']}');
    return ProfileUserModel.fromMap(uid, raw);
  }

  @override
  Future<int> fetchFollowersCount(String uid) async {
    final snap = await _db.ref('UsersPublic/$uid/followers_count').get();
    if (snap.exists && snap.value is int) return snap.value as int;
    return 0;
  }

  @override
  Future<int> fetchFollowingCount(String uid) async {
    final snap = await _db.ref('UsersPublic/$uid/following_count').get();
    if (snap.exists && snap.value is int) return snap.value as int;
    return 0;
  }

  @override
  Future<List<String>> fetchFollowersList(String uid) async {
    final snap = await _db.ref('Users/$uid/followers').get();
    if (!snap.exists || snap.value is! Map) return [];
    return (snap.value as Map).keys.map((k) => k.toString()).toList();
  }

  @override
  Future<List<String>> fetchVipFriends(String uid) async {
    final snap = await _db.ref('Users/$uid/vip_friends').get();
    if (!snap.exists || snap.value is! Map) return [];
    return (snap.value as Map).keys.map((k) => k.toString()).toList();
  }

  @override
  Future<bool> isFollowing(String myUid, String targetUid) async {
    final snap = await _db.ref('Users/$myUid/following/$targetUid').get();
    return snap.exists && snap.value == true;
  }

  @override
  Future<List<String>> filterExistingUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    final checks = await Future.wait(
      uids.map((uid) => _db.ref('UsersPublic/$uid/name').get()),
    );
    final result = <String>[];
    for (var i = 0; i < uids.length; i++) {
      if (checks[i].exists && checks[i].value != null) result.add(uids[i]);
    }
    return result;
  }

  @override
  Future<bool> isVip(String myUid, String targetUid) async {
    final snap = await _db.ref('Users/$myUid/vip_friends/$targetUid').get();
    return snap.exists && snap.value == true;
  }

  Future<void> syncToPublic(String uid, Map<String, dynamic> fields) async {
    try {
      await _db.ref('UsersPublic/$uid').update(fields);
      debugPrint('[Repo] ✅ syncToPublic OK para $uid: ${fields.keys.join(', ')}');
    } catch (e) {
      debugPrint('[Repo] ❌ syncToPublic falhou para $uid: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchIdentityData(String uid) async {
    try {
      final snap = await _db.ref('Users/$uid').get();
      if (!snap.exists || snap.value == null) return null;
      final raw = _deepConvert(snap.value) as Map<dynamic, dynamic>;
      return {
        'gender_identity':    raw['gender_identity'],
        'sexual_orientation': raw['sexual_orientation'],
        'relationship_type':  raw['relationship_type'],
        'birth_date':         raw['birth_date'],
        'profile_type':       raw['profile_type'],
        'bio':                raw['bio'],
        'partner':            raw['partner'],
        'interests':          raw['interests'],
      };
    } catch (_) {
      return null;
    }
  }
}

