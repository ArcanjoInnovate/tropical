// lib/features/search/data/datasources/search_remote_datasource.dart
//
// NÍVEL 4.0 — Busca via Cloud Function server-side.
//
// ANTES: o cliente baixava UserIndex inteiro (~20 MB a 100k users) e filtrava
// em memória. Custo insustentável em egress RTDB.
//
// AGORA: chama a CF `searchUsers` que filtra, pagina e retorna ~20 resultados
// (~2 KB). Redução de ~99.99% em egress.
//
// Fallback: se a CF falhar, tenta busca local (legado) com cache.

import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/search/data/models/paginated_users_result.dart';
import 'package:tclub/features/search/data/models/user_search_model.dart';
import 'package:tclub/features/search/data/models/party_search_model.dart';
import 'package:tclub/core/services/cache_service.dart';

class SearchRemoteDataSource {
  final FirebaseDatabase _database;
  final CacheService _cache;

  static const int pageSize = 20;
  static const cacheTTL = Duration(minutes: 5);

  SearchRemoteDataSource({
    required FirebaseDatabase database,
    required CacheService cache,
  })  : _database = database,
        _cache = cache;

  // ══════════════════════════════════════════════════════════════════════════
  //  USUÁRIOS - VIA CLOUD FUNCTION (NOVO)
  // ══════════════════════════════════════════════════════════════════════════

  Future<PaginatedResultModel<UserSearchModel>> fetchUsers({
    required String myUid,
    required Set<String> followingIds,
    Set<String> blockedIds = const {},
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
  }) async {
    final cacheKey = _buildUsersCacheKey(
      myUid: myUid,
      page: page,
      query: query,
      estadoSigla: estadoSigla,
      cidadeNome: cidadeNome,
      blockedCount: blockedIds.length,
    );

    final cached = _cache.get<PaginatedResultModel<UserSearchModel>>(cacheKey);
    if (cached != null) return cached;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('searchUsers');
      final response = await callable.call<Map<String, dynamic>>({
        'query': query,
        'estadoSigla': estadoSigla,
        'cidadeNome': cidadeNome,
        'page': page,
      });

      final data = response.data;
      final usersRaw = (data['users'] as List?) ?? [];
      final hasMore = data['hasMore'] as bool? ?? false;
      final totalCount = data['totalCount'] as int? ?? 0;

      // Filtra admins e testers que a CF não conhece
      final excludedUids = await _fetchExcludedUids();

      final users = usersRaw
          .map((u) {
            final map = Map<String, dynamic>.from(u as Map);
            return UserSearchModel(
              uid: map['uid'] as String? ?? '',
              name: map['name'] as String? ?? '',
              avatar: map['avatar'] as String? ?? '',
              bio: map['bio'] as String? ?? '',
              city: map['city'] as String? ?? '',
              state: map['state'] as String? ?? '',
              followersCount: map['followers_count'] as int? ?? 0,
              followingCount: map['following_count'] as int? ?? 0,
              latitude: (map['latitude'] as num?)?.toDouble(),
              longitude: (map['longitude'] as num?)?.toDouble(),
            );
          })
          .where((u) => !excludedUids.contains(u.uid))
          .toList();

      final result = PaginatedResultModel<UserSearchModel>(
        items: users,
        page: page,
        pageSize: pageSize,
        totalCount: totalCount,
        hasMore: hasMore,
      );

      _cache.set(cacheKey, result, ttl: cacheTTL);
      return result;
    } catch (e) {
      debugPrint('[SearchRemoteDataSource] CF searchUsers falhou: $e — usando fallback local');
      return _fetchUsersFallback(
        myUid: myUid,
        followingIds: followingIds,
        blockedIds: blockedIds,
        page: page,
        query: query,
        estadoSigla: estadoSigla,
        cidadeNome: cidadeNome,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USUÁRIOS - PROXIMIDADE VIA CF
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<UserSearchModel>> fetchUsersByProximity({
    required String myUid,
    required Set<String> followingIds,
    Set<String> blockedIds = const {},
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    final cacheKey = 'users_prox_${myUid}_'
        '${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_'
        '${radiusKm}_${blockedIds.length}_$query';

    final cached = _cache.get<List<UserSearchModel>>(cacheKey);
    if (cached != null) return cached;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('searchUsers');
      final response = await callable.call<Map<String, dynamic>>({
        'query': query,
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        'page': 0,
      });

      final data = response.data;
      final usersRaw = (data['users'] as List?) ?? [];

      // Filtra admins e testers que a CF não conhece
      final excludedUids = await _fetchExcludedUids();

      final users = usersRaw
          .map((u) {
            final map = Map<String, dynamic>.from(u as Map);
            return UserSearchModel(
              uid: map['uid'] as String? ?? '',
              name: map['name'] as String? ?? '',
              avatar: map['avatar'] as String? ?? '',
              bio: map['bio'] as String? ?? '',
              city: map['city'] as String? ?? '',
              state: map['state'] as String? ?? '',
              followersCount: map['followers_count'] as int? ?? 0,
              followingCount: map['following_count'] as int? ?? 0,
              latitude: (map['latitude'] as num?)?.toDouble(),
              longitude: (map['longitude'] as num?)?.toDouble(),
            );
          })
          .where((u) => !excludedUids.contains(u.uid))
          .toList();

      _cache.set(cacheKey, users, ttl: const Duration(minutes: 2));
      return users;
    } catch (e) {
      debugPrint('[SearchRemoteDataSource] CF proximity falhou: $e — usando fallback');
      return _fetchUsersByProximityFallback(
        myUid: myUid,
        followingIds: followingIds,
        blockedIds: blockedIds,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        query: query,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FALLBACK LOCAL (legado — usado só se CF falhar)
  // ══════════════════════════════════════════════════════════════════════════

  Future<PaginatedResultModel<UserSearchModel>> _fetchUsersFallback({
    required String myUid,
    required Set<String> followingIds,
    Set<String> blockedIds = const {},
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
  }) async {
    final allUsers = await _fetchAllUsersFromFirebase(myUid, followingIds, blockedIds);

    var filtered = _applyUserFilters(
      users: allUsers,
      query: query,
      estadoSigla: estadoSigla,
      cidadeNome: cidadeNome,
    );

    final totalCount = filtered.length;
    final hasMore = page < (totalCount / pageSize).ceil() - 1;
    final startIndex = page * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageUsers = startIndex < totalCount
        ? filtered.sublist(startIndex, endIndex)
        : <UserSearchModel>[];

    return PaginatedResultModel<UserSearchModel>(
      items: pageUsers,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      hasMore: hasMore,
    );
  }

  Future<List<UserSearchModel>> _fetchUsersByProximityFallback({
    required String myUid,
    required Set<String> followingIds,
    Set<String> blockedIds = const {},
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    final allUsers = await _fetchAllUsersFromFirebase(myUid, followingIds, blockedIds);

    var nearby = allUsers.where((u) {
      if (u.latitude == null || u.longitude == null) return false;
      return _calculateDistance(latitude, longitude, u.latitude!, u.longitude!) <= radiusKm;
    }).toList();

    nearby.sort((a, b) {
      final distA = _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
      final distB = _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    if (query != null && query.trim().isNotEmpty) {
      nearby = _filterAndRankByQuery(nearby, query.trim());
    }

    return nearby;
  }

  // ── Cache de UIDs ocultos (admins + testers) ─────────────────────────────
  // Buscado uma vez por sessão e nunca expira (mudam raramente).
  Set<String>? _adminUids;
  Set<String>? _testerUids;

  Future<Set<String>> _fetchAdminUids() async {
    if (_adminUids != null) return _adminUids!;
    try {
      final snap = await _database.ref('Administratives').get();
      if (!snap.exists || snap.value == null) {
        _adminUids = {};
        return _adminUids!;
      }
      _adminUids = Map<dynamic, dynamic>.from(snap.value as Map)
          .keys
          .map((k) => k.toString())
          .toSet();
    } catch (_) {
      _adminUids = {};
    }
    return _adminUids!;
  }

  Future<Set<String>> _fetchTesterUids() async {
    if (_testerUids != null) return _testerUids!;
    try {
      final snap = await _database.ref('Maintenance/Testers').get();
      if (!snap.exists || snap.value == null) {
        _testerUids = {};
        return _testerUids!;
      }
      _testerUids = Map<dynamic, dynamic>.from(snap.value as Map)
          .keys
          .map((k) => k.toString())
          .toSet();
    } catch (_) {
      _testerUids = {};
    }
    return _testerUids!;
  }

  /// Retorna a união de UIDs de administradores e testers.
  /// Esses perfis nunca devem aparecer nos resultados de busca.
  Future<Set<String>> _fetchExcludedUids() async {
    final admins  = await _fetchAdminUids();
    final testers = await _fetchTesterUids();
    return {...admins, ...testers};
  }

  Future<List<UserSearchModel>> _fetchAllUsersFromFirebase(
    String myUid,
    Set<String> followingIds,
    Set<String> blockedIds,
  ) async {
    final excludedUids = await _fetchExcludedUids(); // admins + testers

    final cacheKey = 'users_all_${myUid}_${blockedIds.length}';
    final cached = _cache.get<List<UserSearchModel>>(cacheKey);
    if (cached != null) return cached;

    var snapshot = await _database.ref('UserIndex').get();
    bool usingIndex = snapshot.exists && snapshot.value != null;
    if (!usingIndex) {
      snapshot = await _database.ref('Users').get();
    }
    if (!snapshot.exists || snapshot.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final list = <UserSearchModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final uid = entry.key as String;
      if (uid == myUid) continue;
      if (blockedIds.contains(uid)) continue;
      if (excludedUids.contains(uid)) continue; // ← oculta admins e testers
      final data = Map<String, dynamic>.from(entry.value as Map);
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;

      if (usingIndex) {
        list.add(UserSearchModel(
          uid: uid,
          name: name,
          avatar: data['avatar'] as String? ?? '',
          bio: (data['bio'] as String? ?? '').trim(),
          city: data['city'] as String? ?? '',
          state: data['state'] as String? ?? '',
          followersCount: (data['followers_count'] as int?) ?? 0,
          followingCount: (data['following_count'] as int?) ?? 0,
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
        ));
      } else {
        list.add(UserSearchModel.fromFirebase(uid, data));
      }
    }

    list.sort((a, b) {
      final aFollow = followingIds.contains(a.uid) ? 0 : 1;
      final bFollow = followingIds.contains(b.uid) ? 0 : 1;
      if (aFollow != bFollow) return aFollow.compareTo(bFollow);
      return a.name.compareTo(b.name);
    });

    _cache.set(cacheKey, list, ttl: const Duration(minutes: 3));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FESTAS (mantido — volume baixo, sem necessidade de CF)
  // ══════════════════════════════════════════════════════════════════════════

  Future<PaginatedResultModel<PartySearchModel>> fetchParties({
    int page = 0,
    String? query,
    String? estadoSigla,
    String? cidadeNome,
    String? bairro,
  }) async {
    final cacheKey = _buildPartiesCacheKey(
      page: page, query: query, estadoSigla: estadoSigla,
      cidadeNome: cidadeNome, bairro: bairro,
    );

    final cached = _cache.get<PaginatedResultModel<PartySearchModel>>(cacheKey);
    if (cached != null) return cached;

    final allParties = await _fetchAllPartiesFromFirebase();

    var filtered = _applyPartyFilters(
      parties: allParties, query: query,
      estadoSigla: estadoSigla, cidadeNome: cidadeNome, bairro: bairro,
    );

    final totalCount = filtered.length;
    final hasMore = page < (totalCount / pageSize).ceil() - 1;
    final startIndex = page * pageSize;
    final endIndex = min(startIndex + pageSize, totalCount);
    final pageParties = startIndex < totalCount
        ? filtered.sublist(startIndex, endIndex)
        : <PartySearchModel>[];

    final result = PaginatedResultModel<PartySearchModel>(
      items: pageParties, page: page, pageSize: pageSize,
      totalCount: totalCount, hasMore: hasMore,
    );

    _cache.set(cacheKey, result, ttl: cacheTTL);
    return result;
  }

  Future<List<PartySearchModel>> fetchPartiesByProximity({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? query,
  }) async {
    final cacheKey = 'parties_prox_'
        '${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_'
        '${radiusKm}_$query';

    final cached = _cache.get<List<PartySearchModel>>(cacheKey);
    if (cached != null) return cached;

    final allParties = await _fetchAllPartiesFromFirebase();

    var nearby = allParties.where((p) {
      if (p.latitude == null || p.longitude == null) return false;
      return _calculateDistance(latitude, longitude, p.latitude!, p.longitude!) <= radiusKm;
    }).toList();

    nearby.sort((a, b) {
      final distA = _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
      final distB = _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    if (query != null && query.trim().isNotEmpty) {
      nearby = _filterAndRankPartiesByQuery(nearby, query.trim());
    }

    _cache.set(cacheKey, nearby, ttl: const Duration(minutes: 2));
    return nearby;
  }

  Future<List<PartySearchModel>> _fetchAllPartiesFromFirebase() async {
    const cacheKey = 'parties_all';
    final cached = _cache.get<List<PartySearchModel>>(cacheKey);
    if (cached != null) return cached;

    final snapshot = await _database.ref('Festas').get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snapshot.value as Map);
    final list = <PartySearchModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final id = entry.key as String;
      final data = Map<String, dynamic>.from(entry.value as Map);
      final nome = data['nome'] as String?;
      final creatorId = data['creator_id'] as String?;
      if (nome == null || nome.trim().isEmpty) continue;
      if (creatorId == null || creatorId.trim().isEmpty) continue;
      list.add(PartySearchModel.fromFirebase(id, data));
    }

    list.sort((a, b) => b.dataInicio.compareTo(a.dataInicio));
    _cache.set(cacheKey, list, ttl: const Duration(minutes: 3));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INVALIDAÇÃO DE CACHE
  // ══════════════════════════════════════════════════════════════════════════

  void invalidateUsersCache() => _cache.removeByPrefix('users_');
  void invalidateUserCache(String myUid) {
    _cache.removeByPrefix('users_all_$myUid');
    _cache.removeByPrefix('users_page_$myUid');
    _cache.removeByPrefix('users_prox_$myUid');
  }
  void invalidatePartiesCache() => _cache.removeByPrefix('parties_');

  /// Invalida todo o cache de festas (incluindo 'parties_all') ao mudar filtros,
  /// garantindo que a próxima busca busque dados frescos do Firebase.
  void invalidateFiltersCache() {
    _cache.removeByPrefix('users_page_');
    _cache.removeByPrefix('users_prox_');
    _cache.removeByPrefix('parties_'); // ← era 'parties_page_'; agora limpa tudo
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  String _buildUsersCacheKey({
    required String myUid, required int page,
    String? query, String? estadoSigla, String? cidadeNome, int blockedCount = 0,
  }) {
    return 'users_page_${myUid}_${page}_'
        '${query ?? 'null'}_${estadoSigla ?? 'null'}_${cidadeNome ?? 'null'}_b$blockedCount';
  }

  String _buildPartiesCacheKey({
    required int page, String? query,
    String? estadoSigla, String? cidadeNome, String? bairro,
  }) {
    return 'parties_page_${page}_'
        '${query ?? 'null'}_${estadoSigla ?? 'null'}_'
        '${cidadeNome ?? 'null'}_${bairro ?? 'null'}';
  }

  List<UserSearchModel> _applyUserFilters({
    required List<UserSearchModel> users,
    String? query, String? estadoSigla, String? cidadeNome,
  }) {
    var filtered = users;
    if (estadoSigla != null && estadoSigla.isNotEmpty) {
      final s = _normalize(estadoSigla);
      filtered = filtered.where((u) => _normalize(u.state) == s).toList();
    }
    if (cidadeNome != null && cidadeNome.isNotEmpty) {
      final c = _normalize(cidadeNome);
      filtered = filtered.where((u) => _normalize(u.city) == c).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      filtered = _filterAndRankByQuery(filtered, query.trim());
    }
    return filtered;
  }

  List<UserSearchModel> _filterAndRankByQuery(List<UserSearchModel> users, String query) {
    final q = query.trim();
    if (q.isEmpty) return users;
    final scored = <MapEntry<UserSearchModel, int>>[];
    for (final u in users) {
      final nameScore = _score(u.name, q) * 3;
      final bioScore = _score(u.bio, q);
      final total = nameScore + bioScore;
      if (total > 0) scored.add(MapEntry(u, total));
    }
    scored.sort((a, b) {
      if (b.value != a.value) return b.value.compareTo(a.value);
      return a.key.name.compareTo(b.key.name);
    });
    return scored.map((e) => e.key).toList();
  }

  List<PartySearchModel> _applyPartyFilters({
    required List<PartySearchModel> parties,
    String? query, String? estadoSigla, String? cidadeNome, String? bairro,
  }) {
    var filtered = parties;

    if (estadoSigla != null && estadoSigla.isNotEmpty) {
      final s = _normalize(estadoSigla);
      filtered = filtered.where((p) {
        // Compara com o campo state diretamente
        if (p.estado != null && _normalize(p.estado!) == s) return true;
        // Fallback: extrai sigla do campo local/bairro ("... - GO")
        final local = p.local ?? p.bairro ?? '';
        final match = RegExp(r'-\s*([A-Z]{2})\b').firstMatch(local);
        if (match != null && _normalize(match.group(1)!) == s) return true;
        return false;
      }).toList();
    }

    if (cidadeNome != null && cidadeNome.isNotEmpty) {
      final c = _normalize(cidadeNome);
      filtered = filtered.where((p) {
        // Compara com o campo city diretamente
        if (p.cidade != null && _normalize(p.cidade!) == c) return true;
        // Fallback: procura cidade no campo local/bairro
        final local = p.local ?? p.bairro ?? '';
        if (_normalize(local).contains(c)) return true;
        return false;
      }).toList();
    }

    if (bairro != null && bairro.isNotEmpty) {
      final b = _normalize(bairro);
      filtered = filtered.where((p) {
        if (p.bairro != null && _normalize(p.bairro!).contains(b)) return true;
        if (p.local  != null && _normalize(p.local!).contains(b))  return true;
        return false;
      }).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      filtered = _filterAndRankPartiesByQuery(filtered, query.trim());
    }

    return filtered;
  }

  List<PartySearchModel> _filterAndRankPartiesByQuery(List<PartySearchModel> parties, String query) {
    final q = query.trim();
    if (q.isEmpty) return parties;
    final scored = <MapEntry<PartySearchModel, int>>[];
    for (final p in parties) {
      final nomeScore  = _score(p.nome, q) * 3;
      final descScore  = p.descricao != null ? _score(p.descricao!, q) : 0;
      final localScore = p.local     != null ? _score(p.local!, q)     : 0;
      final total = nomeScore + descScore + localScore;
      if (total > 0) scored.add(MapEntry(p, total));
    }
    scored.sort((a, b) {
      if (b.value != a.value) return b.value.compareTo(a.value);
      return a.key.nome.compareTo(b.key.nome);
    });
    return scored.map((e) => e.key).toList();
  }

  static String _normalize(String s) {
    const accents = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';
    const normal  = 'aaaaaaeceeeeiiiidnoooooouuuuyby';
    var r = s.toLowerCase();
    for (int i = 0; i < accents.length; i++) {
      r = r.replaceAll(accents[i], i < normal.length ? normal[i] : '');
    }
    return r;
  }

  static int _score(String candidate, String query) {
    if (candidate.isEmpty || query.isEmpty) return 0;
    final c = _normalize(candidate);
    final q = _normalize(query);
    if (c == q) return 100;
    if (c.startsWith(q)) return 80;
    if (c.contains(q)) return 60;
    final queryTokens = q.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (queryTokens.isNotEmpty) {
      if (queryTokens.every((t) => c.contains(t))) return 50;
      if (queryTokens.any((t) => c.contains(t))) return 30;
    }
    final candidateWords = c.split(RegExp(r'\s+'));
    if (candidateWords.any((w) => w.startsWith(q))) return 40;
    return 0;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;
}

