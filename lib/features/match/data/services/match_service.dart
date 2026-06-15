// lib/features/match/data/services/match_service.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../models/match_profile_model.dart';
import '../models/match_filter_model.dart';
import '../repositories/match_repository.dart';

// Cooldown de dislike: 60 dias em milissegundos
const int _kDislikeCooldownMs = 60 * 24 * 60 * 60 * 1000;

class MatchService {
  MatchService({required IMatchRepository repository})
      : _repository = repository;

  final IMatchRepository _repository;

  // ── loadProfiles ──────────────────────────────────────────────────────────

  Future<List<MatchProfileModel>> loadProfiles({
    required String myUid,
    required MatchFilterModel filter,
    required double myLat,
    required double myLng,
  }) async {
    debugPrint('[MatchService] ▶ loadProfiles chamado');
    debugPrint('[MatchService]   myUid=$myUid');
    debugPrint('[MatchService]   myLat=$myLat  myLng=$myLng');
    debugPrint('[MatchService]   onlyInDistance=${filter.onlyInDistance}  distanciaKm=${filter.distanciaKm}');
    debugPrint('[MatchService]   generos=${filter.generos}  orientacoes=${filter.orientacoes}  relacionamentos=${filter.relacionamentos}');

    if (myUid.trim().isEmpty) {
      debugPrint('[MatchService] ❌ myUid vazio — retornando []');
      return [];
    }

    // ── 1. Busca tudo em paralelo ─────────────────────────────────────────
    final results = await Future.wait([
      _repository.fetchCandidates(myUid: myUid, filter: filter),
      _repository.fetchDislikesGiven(myUid),
      _repository.fetchDislikesReceived(myUid),
      _repository.fetchLikesGiven(myUid),
      _repository.fetchMatchedUids(myUid),
      _repository.fetchChatPartnerUids(myUid), // ← novo: fallback garantido
      _repository.fetchTesterUids(),            // ← testers: nunca no feed
    ]);

    final all              = results[0] as List<MatchProfileModel>;
    final dislikesGiven    = results[1] as Map<String, int>;
    final dislikesReceived = results[2] as Map<String, int>;
    final likesGiven       = results[3] as Set<String>;
    final matchedUids      = results[4] as Set<String>;
    final chatPartnerUids  = results[5] as Set<String>; // ← novo
    final testerUids       = results[6] as Set<String>; // ← testers

    debugPrint('[MatchService] 📋 fetchCandidates retornou ${all.length} perfil(is)');
    debugPrint('[MatchService] 🚫 dislikes dados: ${dislikesGiven.length}  recebidos: ${dislikesReceived.length}');
    debugPrint('[MatchService] ❤️  likes já dados: ${likesGiven.length}');
    debugPrint('[MatchService] 💬 matches existentes: ${matchedUids.length}');
    debugPrint('[MatchService] 💬 chat partners: ${chatPartnerUids.length}');
    debugPrint('[MatchService] 🧪 testers excluídos: ${testerUids.length}');

    if (all.isEmpty) {
      debugPrint('[MatchService] ❌ Nenhum candidato vindo do repositório');
      return [];
    }

    // ── 2. Monta conjunto de UIDs excluídos ───────────────────────────────
    final now     = DateTime.now().millisecondsSinceEpoch;
    final blocked = <String>{};

    // Bloqueio pelos dislikes que EU dei (cooldown de 60 dias)
    for (final entry in dislikesGiven.entries) {
      final elapsed = now - entry.value;
      if (elapsed < _kDislikeCooldownMs) {
        blocked.add(entry.key);
        debugPrint('[MatchService] 🚫 bloqueado (eu dei dislike): ${entry.key} — faltam ${_remainingDays(elapsed)} dias');
      }
    }

    // Bloqueio pelos dislikes que EU RECEBI (essa pessoa não quer me ver)
    for (final entry in dislikesReceived.entries) {
      final elapsed = now - entry.value;
      if (elapsed < _kDislikeCooldownMs) {
        blocked.add(entry.key);
        debugPrint('[MatchService] 🚫 bloqueado (recebi dislike de): ${entry.key} — faltam ${_remainingDays(elapsed)} dias');
      }
    }

    // Bloqueio pelos likes que EU JÁ DEI
    blocked.addAll(likesGiven);
    if (likesGiven.isNotEmpty) {
      debugPrint('[MatchService] ❤️  bloqueados por like já dado: ${likesGiven.length} uid(s)');
    }

    // Bloqueio por matches já confirmados (Matchs/{myUid}/matched)
    blocked.addAll(matchedUids);
    if (matchedUids.isNotEmpty) {
      debugPrint('[MatchService] 💬 bloqueados por match existente: ${matchedUids.length} uid(s)');
    }

    // ← NOVO: Bloqueio por chats aceitos (UserChatRequests) — fallback
    // garantido para quando o nó /matched ainda não propagou
    blocked.addAll(chatPartnerUids);
    if (chatPartnerUids.isNotEmpty) {
      debugPrint('[MatchService] 💬 bloqueados por chat aceito: ${chatPartnerUids.length} uid(s)');
    }

    // Testers (Maintenance/Testers/{uid} == true) — nunca aparecem no feed
    blocked.addAll(testerUids);
    if (testerUids.isNotEmpty) {
      debugPrint('[MatchService] 🧪 bloqueados por tester: ${testerUids.join(', ')}');
    }

    // Garante que o próprio usuário nunca apareça no deck
    blocked.add(myUid);

    debugPrint('[MatchService] 🔒 total de UIDs excluídos: ${blocked.length}');

    // ── 3. Referência de localização ──────────────────────────────────────
    final refLat = filter.tipoLocalizacao == TipoLocalizacao.personalizada &&
            filter.lat != null
        ? filter.lat!
        : myLat;
    final refLng = filter.tipoLocalizacao == TipoLocalizacao.personalizada &&
            filter.lng != null
        ? filter.lng!
        : myLng;

    debugPrint('[MatchService]   refLat=$refLat  refLng=$refLng');

    // ── 4. Calcula distâncias ─────────────────────────────────────────────
    final withDistance = all.map((profile) {
      final km = _haversineKm(refLat, refLng, profile.lat, profile.lng);
      return profile.withDistance(km);
    }).toList();

    // ── 5. Aplica filtros ─────────────────────────────────────────────────
    final filtered = withDistance.where((profile) {
      if (blocked.contains(profile.uid)) {
        debugPrint('[MatchService]   ❌ ${profile.name} excluído');
        return false;
      }

      final pass = _matchesFilter(profile, filter);
      debugPrint('[MatchService]   filtro ${profile.name}: ${pass ? "✅ passou" : "❌ bloqueado"}');
      return pass;
    }).toList();

    debugPrint('[MatchService] ✅ ${filtered.length} perfil(is) após filtros');

    // ── 6. Ordena por distância ───────────────────────────────────────────
    filtered.sort((a, b) {
      final dA = a.distanceKm ?? double.infinity;
      final dB = b.distanceKm ?? double.infinity;
      return dA.compareTo(dB);
    });

    return filtered;
  }

  // ── recordLike ────────────────────────────────────────────────────────────

  Future<void> recordLike({
    required String myUid,
    required String targetUid,
  }) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await _repository.recordLike(myUid: myUid, targetUid: targetUid);
    debugPrint('[MatchService] ❤️ like gravado: $myUid → $targetUid');
  }

  // ── recordDislike ─────────────────────────────────────────────────────────

  Future<void> recordDislike({
    required String myUid,
    required String targetUid,
  }) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await _repository.recordDislike(myUid: myUid, targetUid: targetUid);
    debugPrint('[MatchService] 👎 dislike gravado: $myUid → $targetUid');
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  bool _matchesFilter(MatchProfileModel profile, MatchFilterModel filter) {
    // Distância
    if (filter.onlyInDistance) {
      final km = profile.distanceKm;
      if (km != null && km > filter.distanciaKm) {
        debugPrint('[MatchService]     bloqueado por distância: ${km.toStringAsFixed(1)} km > ${filter.distanciaKm} km');
        return false;
      }
    }

    // Gênero
    if (filter.generos.isNotEmpty) {
      final g     = profile.genderIdentity.toLowerCase();
      final match = filter.generos.any((e) => e.name.toLowerCase() == g);
      if (!match) {
        debugPrint('[MatchService]     bloqueado por gênero: "$g"');
        return false;
      }
    }

    // Orientação
    if (filter.orientacoes.isNotEmpty) {
      final o     = profile.sexualOrientation.toLowerCase();
      final match = filter.orientacoes.any((e) => e.name.toLowerCase() == o);
      if (!match) {
        debugPrint('[MatchService]     bloqueado por orientação: "$o"');
        return false;
      }
    }

    // Tipo de relacionamento
    if (filter.relacionamentos.isNotEmpty) {
      final r     = profile.relationshipType.toLowerCase();
      final match = filter.relacionamentos.any((e) => e.name.toLowerCase() == r);
      if (!match) {
        debugPrint('[MatchService]     bloqueado por relacionamento: "$r"');
        return false;
      }
    }

    // Faixa etária
    if (filter.onlyInAge) {
      final age = profile.age;
      if (age == null) {
        debugPrint('[MatchService]     bloqueado por faixa etária: sem data de nascimento');
        return false;
      }
      if (age < filter.idadeMin || age > filter.idadeMax) {
        debugPrint('[MatchService]     bloqueado por faixa etária: $age anos fora de [${filter.idadeMin}, ${filter.idadeMax}]');
        return false;
      }
    }

    return true;
  }

  int _remainingDays(int elapsedMs) =>
      ((_kDislikeCooldownMs - elapsedMs) / (24 * 60 * 60 * 1000)).ceil();

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r    = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}

