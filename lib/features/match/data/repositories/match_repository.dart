// lib/features/match/data/repositories/match_repository.dart
//
// NÍVEL 2.0 — fetchCandidates usa MatchIndex em vez de Matchs.
//   MatchIndex contém apenas campos públicos do deck (~200 bytes/user).
//   Matchs permanece privado — só o próprio uid lê.
//
//   Campos sensíveis (lat/lng, likes, dislikes) nunca saem de Matchs/$myUid.
//   A CF syncMatchIndex mantém o MatchIndex sincronizado.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/match_profile_model.dart';
import '../models/match_filter_model.dart';

abstract class IMatchRepository {
  Future<List<MatchProfileModel>> fetchCandidates({
    required String myUid,
    required MatchFilterModel filter,
  });

  Future<void> recordDislike({
    required String myUid,
    required String targetUid,
  });

  Future<void> recordLike({
    required String myUid,
    required String targetUid,
  });

  Future<Set<String>> fetchLikesGiven(String myUid);
  Future<Map<String, int>> fetchDislikesGiven(String myUid);
  Future<Map<String, int>> fetchDislikesReceived(String myUid);
  Future<Set<String>> fetchMatchedUids(String myUid);
  Future<Set<String>> fetchChatPartnerUids(String myUid);

  /// UIDs marcados como testers em Maintenance/Testers — nunca aparecem no feed.
  Future<Set<String>> fetchTesterUids();
}

// ════════════════════════════════════════════════════════════════════════════

class MatchRepository implements IMatchRepository {
  MatchRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  // ── fetchCandidates ───────────────────────────────────────────────────────
  //
  // NÍVEL 4.0 — Busca via Cloud Function server-side.
  // Antes: baixava MatchIndex inteiro (~20 MB a 100k users).
  // Agora: chama CF `getMatchCandidates` que filtra no servidor.
  // Fallback para busca local se a CF falhar.

  @override
  Future<List<MatchProfileModel>> fetchCandidates({
    required String myUid,
    required MatchFilterModel filter,
  }) async {
    try {
      return await _fetchCandidatesFromCF(myUid: myUid, filter: filter);
    } catch (e) {
      debugPrint('[MatchRepository] CF getMatchCandidates falhou: $e — usando fallback');
      return _fetchCandidatesFallback(myUid: myUid, filter: filter);
    }
  }

  Future<List<MatchProfileModel>> _fetchCandidatesFromCF({
    required String myUid,
    required MatchFilterModel filter,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('getMatchCandidates');
    final response = await callable.call<Map<String, dynamic>>({
      'latitude': filter.tipoLocalizacao == TipoLocalizacao.personalizada
          ? (filter.lat ?? 0.0) : 0.0,
      'longitude': filter.tipoLocalizacao == TipoLocalizacao.personalizada
          ? (filter.lng ?? 0.0) : 0.0,
      'distanciaKm': filter.distanciaKm,
      'onlyInDistance': filter.onlyInDistance,
      'generos': filter.generos.map((e) => e.name).toList(),
      'orientacoes': filter.orientacoes.map((e) => e.name).toList(),
      'relacionamentos': filter.relacionamentos.map((e) => e.name).toList(),
      'idadeMin': filter.idadeMin,
      'idadeMax': filter.idadeMax,
      'onlyInAge': filter.onlyInAge,
      'tipoLocalizacao': filter.tipoLocalizacao == TipoLocalizacao.personalizada
          ? 'personalizada' : 'atual',
      if (filter.lat != null) 'latCustom': filter.lat,
      if (filter.lng != null) 'lngCustom': filter.lng,
    });

    final data = response.data;
    final candidatesRaw = (data['candidates'] as List?) ?? [];

    return candidatesRaw.map((c) {
      final map = Map<String, dynamic>.from(c as Map);
      return MatchProfileModel(
        uid: map['uid'] as String? ?? '',
        name: map['name'] as String? ?? '',
        avatarUrl: map['avatar'] as String? ?? '',
        bio: map['bio'] as String? ?? '',
        bairro: map['bairro'] as String? ?? '',
        city: map['city'] as String? ?? '',
        state: map['state'] as String? ?? '',
        interests: (map['interests'] is List)
            ? (map['interests'] as List).map((e) => e.toString()).toList()
            : <String>[],
        genderIdentity: map['gender_identity'] as String? ?? '',
        sexualOrientation: map['sexual_orientation'] as String? ?? '',
        relationshipType: map['relationship_type'] as String? ?? '',
        profileType: map['profile_type'] as String? ?? '',
        lat: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        lng: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        ageFromDb: map['age'] as int?,
        partner: map['partner'] is Map
            ? MatchPartnerModel.fromMap(map['partner'] as Map)
            : null,
      ).withDistance((map['distanceKm'] as num?)?.toDouble() ?? 0.0);
    }).toList();
  }

  // ── Fallback local (legado) ─────────────────────────────────────────────

  Future<List<MatchProfileModel>> _fetchCandidatesFallback({
    required String myUid,
    required MatchFilterModel filter,
  }) async {
    // 1. UIDs a excluir — lê só do próprio perfil
    final excludeUids = <String>{myUid};

    final myData = await Future.wait([
      _db.ref('Matchs/$myUid/likes_given').get(),
      _db.ref('Matchs/$myUid/dislikes').get(),
      _db.ref('Matchs/$myUid/matched').get(),
    ]);

    for (final snap in myData) {
      if (snap.exists && snap.value is Map) {
        excludeUids.addAll(
          Map<String, dynamic>.from(snap.value as Map).keys,
        );
      }
    }

    // 2. Tenta MatchIndex primeiro
    final indexSnap = await _db.ref('MatchIndex').get();
    final hasMatchIndex = indexSnap.exists && indexSnap.value != null;

    if (hasMatchIndex) {
      return _candidatesFromMatchIndex(
        indexSnap: indexSnap,
        excludeUids: excludeUids,
      );
    }

    // 3. Fallback: MatchIndex não existe → tenta UserIndex
    final userIndexSnap = await _db.ref('UserIndex').get();
    final hasUserIndex = userIndexSnap.exists && userIndexSnap.value != null;

    if (hasUserIndex) {
      return _candidatesFromUserIndex(
        userIndexSnap: userIndexSnap,
        excludeUids: excludeUids,
      );
    }

    // 4. Fallback final: lê Matchs inteiro (comportamento legado)
    return _candidatesFromMatchsFallback(excludeUids: excludeUids);
  }

  // ── _candidatesFromMatchIndex ─────────────────────────────────────────────

  Future<List<MatchProfileModel>> _candidatesFromMatchIndex({
    required DataSnapshot indexSnap,
    required Set<String> excludeUids,
  }) async {
    final raw = Map<String, dynamic>.from(indexSnap.value as Map);
    final candidates = <MatchProfileModel>[];

    for (final entry in raw.entries) {
      final uid = entry.key;
      if (excludeUids.contains(uid)) continue;
      if (entry.value is! Map) continue;

      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      candidates.add(MatchProfileModel.fromMap(uid, data));
    }

    // Enriquece com dados sensíveis que só existem em Users
    return _enrichWithUserData(candidates);
  }

  // ── _candidatesFromUserIndex ──────────────────────────────────────────────
  // Fallback quando MatchIndex não existe mas UserIndex sim.
  // Lê Matchs/$uid individualmente para cada candidato.

  Future<List<MatchProfileModel>> _candidatesFromUserIndex({
    required DataSnapshot userIndexSnap,
    required Set<String> excludeUids,
  }) async {
    final indexRaw = Map<String, dynamic>.from(userIndexSnap.value as Map);
    final candidateUids = <String>[];

    for (final uid in indexRaw.keys) {
      if (excludeUids.contains(uid)) continue;
      final data = indexRaw[uid];
      if (data is! Map) continue;
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      candidateUids.add(uid);
    }

    final candidates = <MatchProfileModel>[];
    await Future.wait(candidateUids.map((uid) async {
      final snap = await _db.ref('Matchs/$uid').get();
      if (!snap.exists || snap.value == null) return;
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) return;
      candidates.add(MatchProfileModel.fromMap(uid, data));
    }));

    // Enriquece com dados sensíveis que só existem em Users
    return _enrichWithUserData(candidates);
  }

  // ── _candidatesFromMatchsFallback ─────────────────────────────────────────
  // Fallback legado: lê Matchs inteiro.
  // Usado apenas quando nem MatchIndex nem UserIndex existem.

  Future<List<MatchProfileModel>> _candidatesFromMatchsFallback({
    required Set<String> excludeUids,
  }) async {
    final snap = await _db.ref('Matchs').get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<String, dynamic>.from(snap.value as Map);
    final candidates = <MatchProfileModel>[];

    for (final entry in raw.entries) {
      final uid = entry.key;
      if (excludeUids.contains(uid)) continue;
      if (entry.value is! Map) continue;

      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      candidates.add(MatchProfileModel.fromMap(uid, data));
    }

    // Enriquece com dados sensíveis que só existem em Users
    return _enrichWithUserData(candidates);
  }

  // ── _enrichWithUserData ───────────────────────────────────────────────────
  // Enriquece candidatos com lat/lng, gender_identity e sexual_orientation
  // lidos de MatchIndex/{uid} (sincronizado pela CF a partir de Users).
  // Usado apenas nos fallbacks (Matchs e UserIndex) — o path principal
  // (MatchIndex) já retorna esses campos diretamente.
  Future<List<MatchProfileModel>> _enrichWithUserData(
    List<MatchProfileModel> candidates,
  ) async {
    if (candidates.isEmpty) return candidates;

    final enriched = <MatchProfileModel>[];
    await Future.wait(candidates.map((profile) async {
      try {
        final snap = await _db.ref('MatchIndex/${profile.uid}').get();
        if (!snap.exists || snap.value == null) {
          enriched.add(profile);
          return;
        }
        final idx = Map<String, dynamic>.from(snap.value as Map);
        enriched.add(MatchProfileModel(
          uid:               profile.uid,
          name:              profile.name,
          avatarUrl:         profile.avatarUrl,
          bio:               profile.bio,
          bairro:            profile.bairro,
          interests:         profile.interests,
          city:              profile.city,
          state:             profile.state,
          lat:               (idx['latitude']  as num?)?.toDouble() ?? profile.lat,
          lng:               (idx['longitude'] as num?)?.toDouble() ?? profile.lng,
          genderIdentity:    (idx['gender_identity']    as String?) ?? profile.genderIdentity,
          sexualOrientation: (idx['sexual_orientation'] as String?) ?? profile.sexualOrientation,
          relationshipType:  profile.relationshipType,
          profileType:       profile.profileType,
          birthDate:         profile.birthDate,
          ageFromDb:         profile.ageFromDb,
          partner:           profile.partner,
        ));
      } catch (_) {
        enriched.add(profile);
      }
    }));

    return enriched;
  }

  // ── recordLike ────────────────────────────────────────────────────────────

  @override
  Future<void> recordLike({
    required String myUid,
    required String targetUid,
  }) async {
    await _db.ref().update({
      'Matchs/$targetUid/like_me/$myUid':     true,
      'Matchs/$myUid/likes_given/$targetUid': true,
    });
  }

  // ── recordDislike ─────────────────────────────────────────────────────────

  @override
  Future<void> recordDislike({
    required String myUid,
    required String targetUid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.ref().update({
      'Matchs/$myUid/dislikes/$targetUid/created_at':          now,
      'Matchs/$targetUid/dislikes_received/$myUid/created_at': now,
    });
  }

  // ── fetchLikesGiven ───────────────────────────────────────────────────────

  @override
  Future<Set<String>> fetchLikesGiven(String myUid) async {
    final snap = await _db.ref('Matchs/$myUid/likes_given').get();
    if (!snap.exists || snap.value == null) return {};
    return Map<String, dynamic>.from(snap.value as Map).keys.toSet();
  }

  // ── fetchDislikesGiven ────────────────────────────────────────────────────

  @override
  Future<Map<String, int>> fetchDislikesGiven(String myUid) async {
    final snap = await _db.ref('Matchs/$myUid/dislikes').get();
    if (!snap.exists || snap.value == null) return {};

    final raw = Map<String, dynamic>.from(snap.value as Map);
    final result = <String, int>{};
    for (final e in raw.entries) {
      if (e.value is Map) {
        final ts = (e.value as Map)['created_at'];
        if (ts is int) result[e.key] = ts;
      }
    }
    return result;
  }

  // ── fetchDislikesReceived ─────────────────────────────────────────────────

  @override
  Future<Map<String, int>> fetchDislikesReceived(String myUid) async {
    final snap = await _db.ref('Matchs/$myUid/dislikes_received').get();
    if (!snap.exists || snap.value == null) return {};

    final raw = Map<String, dynamic>.from(snap.value as Map);
    final result = <String, int>{};
    for (final e in raw.entries) {
      if (e.value is Map) {
        final ts = (e.value as Map)['created_at'];
        if (ts is int) result[e.key] = ts;
      }
    }
    return result;
  }

  // ── fetchMatchedUids ──────────────────────────────────────────────────────

  @override
  Future<Set<String>> fetchMatchedUids(String myUid) async {
    final snap = await _db.ref('Matchs/$myUid/matched').get();
    if (!snap.exists || snap.value == null) return {};
    return Map<String, dynamic>.from(snap.value as Map).keys.toSet();
  }

  // ── fetchChatPartnerUids ──────────────────────────────────────────────────

  @override
  Future<Set<String>> fetchChatPartnerUids(String myUid) async {
    final snap = await _db.ref('UserChatRequests/$myUid').get();
    if (!snap.exists || snap.value == null) return {};

    final raw = Map<String, dynamic>.from(snap.value as Map);
    final result = <String>{};

    for (final entry in raw.entries) {
      if (entry.value != 'accepted') continue;
      final parts = (entry.key as String).split('_');
      if (parts.length != 2) continue;
      result.add(parts[0] == myUid ? parts[1] : parts[0]);
    }

    return result;
  }

  // ── fetchTesterUids ───────────────────────────────────────────────────────
  // Lê Maintenance/Testers e retorna os UIDs com valor == true.
  // Esses perfis são excluídos do feed de todos os usuários.

  @override
  Future<Set<String>> fetchTesterUids() async {
    try {
      final snap = await _db.ref('Maintenance/Testers').get();
      if (!snap.exists || snap.value == null) return {};
      final raw = Map<String, dynamic>.from(snap.value as Map);
      return raw.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toSet();
    } catch (e) {
      debugPrint('[MatchRepository] ⚠️ fetchTesterUids falhou: $e');
      return {};
    }
  }
}