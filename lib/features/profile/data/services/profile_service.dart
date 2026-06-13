// features/profile/data/services/profile_service.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/profile_user_model.dart';
import '../repositories/profile_repository.dart';

class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  final _repo = ProfileRepository.instance;
  final _db   = FirebaseDatabase.instance;

  // ── Próprio perfil ────────────────────────────────────────────────────────

  Future<ProfileUserModel?> loadFullProfile(String uid) async {
    final results = await Future.wait([
      _repo.fetchUser(uid),
      _repo.fetchFollowersCount(uid),
      _repo.fetchFollowingCount(uid),
    ]);

    final user = results[0] as ProfileUserModel?;
    if (user == null) return null;

    syncToPublic(uid);

    return user.copyWith(
      followers: results[1] as int,
      following: results[2] as int,
    );
  }

  // ── Perfil público ────────────────────────────────────────────────────────

  Future<ProfileUserModel?> loadPublicProfile(String uid) async {
    final results = await Future.wait([
      _repo.fetchPublicUser(uid),
      _repo.fetchFollowersCount(uid),
      _repo.fetchFollowingCount(uid),
    ]);

    final user = results[0] as ProfileUserModel?;
    if (user == null) return null;

    if (user.genderLabel.isEmpty && user.relationshipLabel.isEmpty) {
      _log('⚠️  UsersPublic/$uid sem identidade — '
          'usuário precisa abrir o próprio perfil para sincronizar.');
    }

    return user.copyWith(
      followers: results[1] as int,
      following: results[2] as int,
    );
  }

  // ── Sync completo Users → UsersPublic ─────────────────────────────────────
  //
  // Usa .update() — nunca apaga campos controlados por Cloud Functions
  // (followers_count, following_count, is_verified).
  //
  // CRÍTICO: 'uid' deve sempre ser incluído — a regra de UsersPublic
  // valida "newData.val() === $uid" e sem ele o .update() inteiro
  // é rejeitado silenciosamente pelo Firebase quando o nó ainda não
  // possui o campo uid.

  Future<void> syncToPublic(String uid) async {
    try {
      final snap = await _db.ref('Users/$uid').get();
      if (!snap.exists || snap.value == null) return;

      final raw = _deepConvert(snap.value) as Map<dynamic, dynamic>;

      final fields = <String, dynamic>{};

      // ── uid obrigatório ──────────────────────────────────────────────────
      // Sem este campo o Firebase rejeita o update inteiro (regra valida
      // newData.val() === $uid). É a causa raiz do sync silencioso quebrado.
      fields['uid'] = uid;

      // ── Campos base ──────────────────────────────────────────────────────
      void addBase(String key) {
        final val = raw[key];
        if (val != null && val.toString().isNotEmpty) fields[key] = val;
      }
      addBase('name');
      addBase('avatar');
      addBase('bio');
      addBase('bairro');
      addBase('city');
      addBase('state');

      // ── Campos de identidade ─────────────────────────────────────────────
      void addIdentity(String key) {
        final val = raw[key];
        if (val != null && val.toString().isNotEmpty) fields[key] = val;
      }
      addIdentity('gender_identity');
      addIdentity('sexual_orientation');
      addIdentity('relationship_type');
      addIdentity('profile_type');
      addIdentity('birth_date');

      // ── Idade calculada ──────────────────────────────────────────────────
      final birthStr = raw['birth_date'] as String?;
      if (birthStr != null && birthStr.isNotEmpty) {
        final birth = DateTime.tryParse(birthStr);
        if (birth != null) {
          final now = DateTime.now();
          int age = now.year - birth.year;
          if (now.month < birth.month ||
              (now.month == birth.month && now.day < birth.day)) age--;
          if (age > 0) fields['age'] = age;
        }
      }

      // ── Interesses ───────────────────────────────────────────────────────
      final rawInterests = raw['interests'];
      if (rawInterests is List && rawInterests.isNotEmpty) {
        fields['interests'] = rawInterests;
      }

      // ── Parceiro ─────────────────────────────────────────────────────────
      final rawPartner = raw['partner'];
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
        if (p.isNotEmpty) fields['partner'] = p;
      } else {
        // Usuário voltou para single — remove partner de UsersPublic
        fields['partner'] = null;
      }

      if (fields.isEmpty) {
        _log('⚠️  nenhum campo para sincronizar para $uid');
        return;
      }

      await _db.ref('UsersPublic/$uid').update(fields);
      _log('✅ sync OK para $uid: ${fields.keys.join(', ')}');
    } catch (e) {
      _log('❌ sync falhou para $uid: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return Map<dynamic, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(e.key, _deepConvert(e.value))),
      );
    }
    if (value is List) return value.map(_deepConvert).toList();
    return value;
  }

  void _log(String msg) {
    // ignore: avoid_print
    assert(() { print('[ProfileService] $msg'); return true; }());
  }

  // ── Delegações para o repository ──────────────────────────────────────────

  Future<List<String>> fetchFollowersList(String uid) =>
      _repo.fetchFollowersList(uid);

  Future<int> fetchFollowersCount(String uid) =>
      _repo.fetchFollowersCount(uid);

  Future<List<String>> filterExistingUsers(List<String> uids) =>
      _repo.filterExistingUsers(uids);

  Future<List<String>> fetchVipFriends(String uid) =>
      _repo.fetchVipFriends(uid);

  Future<bool> isFollowing(String myUid, String targetUid) =>
      _repo.isFollowing(myUid, targetUid);

  Future<bool> isVip(String myUid, String targetUid) =>
      _repo.isVip(myUid, targetUid);

  Future<bool> checkStoryVisibility({
    required String viewerUid,
    required String ownerUid,
    required String visibilidade,
  }) async {
    switch (visibilidade) {
      case 'publico':    return true;
      case 'seguidores': return _repo.isFollowing(viewerUid, ownerUid);
      case 'vip':        return _repo.isVip(ownerUid, viewerUid);
      default:           return true;
    }
  }
}