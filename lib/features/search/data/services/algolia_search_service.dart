// lib/services/services_app/algolia_search_service.dart
//
// NÍVEL 3.1 — Busca de usuários via Algolia em vez de RTDB.
// Zero leituras no RTDB para busca. Suporta full-text + geo filtering.
//
// Requer adicionar no pubspec.yaml:
//   dependencies:
//     http: ^1.2.0  (provavelmente já existe)
//
// Configuração:
//   Setar ALGOLIA_APP_ID e ALGOLIA_SEARCH_KEY no app (ex: via .env ou const).
//   A search key é DIFERENTE da admin key — é read-only e segura para client-side.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AlgoliaSearchService {
  AlgoliaSearchService._();
  static final AlgoliaSearchService instance = AlgoliaSearchService._();

  // ══════════════════════════════════════════════════════════════════════════
  //  CONFIGURAÇÃO — Substituir pelos seus valores
  // ══════════════════════════════════════════════════════════════════════════
  static const String _appId     = 'SEU_ALGOLIA_APP_ID';
  static const String _searchKey = 'SEU_ALGOLIA_SEARCH_KEY';
  static const String _indexName = 'users';

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCA DE USUÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  /// Busca por texto (nome, username, bio, bairro).
  /// Se [latitude] e [longitude] forem fornecidos, ordena por proximidade.
  Future<List<AlgoliaUserResult>> searchUsers(
    String query, {
    double? latitude,
    double? longitude,
    int radiusKm = 50,
    int hitsPerPage = 20,
    int page = 0,
  }) async {
    try {
      final params = <String, dynamic>{
        'query':       query,
        'hitsPerPage': hitsPerPage,
        'page':        page,
        'attributesToRetrieve': [
          'objectID', 'name', 'username', 'bio',
          'avatar', 'gender', 'bairro', 'cidade', 'estado',
          '_geoloc',
        ],
      };

      if (latitude != null && longitude != null) {
        params['aroundLatLng'] = '$latitude,$longitude';
        params['aroundRadius'] = radiusKm * 1000; // metros
      }

      final response = await http.post(
        Uri.parse('https://$_appId-dsn.algolia.net/1/indexes/$_indexName/query'),
        headers: {
          'X-Algolia-Application-Id': _appId,
          'X-Algolia-API-Key':        _searchKey,
          'Content-Type':             'application/json',
        },
        body: jsonEncode(params),
      );

      if (response.statusCode != 200) {
        debugPrint('Algolia error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = (data['hits'] as List?) ?? [];

      return hits.map((hit) => AlgoliaUserResult.fromAlgolia(
        hit as Map<String, dynamic>,
      )).toList();
    } catch (e) {
      debugPrint('AlgoliaSearchService.searchUsers error: $e');
      return [];
    }
  }

  /// Busca por proximidade sem texto (lista usuários perto).
  Future<List<AlgoliaUserResult>> searchNearby({
    required double latitude,
    required double longitude,
    int radiusKm = 30,
    int hitsPerPage = 30,
    String? genderFilter,
  }) async {
    try {
      final params = <String, dynamic>{
        'query':          '',
        'aroundLatLng':   '$latitude,$longitude',
        'aroundRadius':   radiusKm * 1000,
        'hitsPerPage':    hitsPerPage,
        'attributesToRetrieve': [
          'objectID', 'name', 'username', 'avatar',
          'gender', 'bairro', 'cidade', '_geoloc',
        ],
      };

      if (genderFilter != null && genderFilter.isNotEmpty) {
        params['filters'] = 'gender:$genderFilter';
      }

      final response = await http.post(
        Uri.parse('https://$_appId-dsn.algolia.net/1/indexes/$_indexName/query'),
        headers: {
          'X-Algolia-Application-Id': _appId,
          'X-Algolia-API-Key':        _searchKey,
          'Content-Type':             'application/json',
        },
        body: jsonEncode(params),
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = (data['hits'] as List?) ?? [];

      return hits.map((hit) => AlgoliaUserResult.fromAlgolia(
        hit as Map<String, dynamic>,
      )).toList();
    } catch (e) {
      debugPrint('AlgoliaSearchService.searchNearby error: $e');
      return [];
    }
  }
}

/// Modelo de resultado de busca Algolia.
class AlgoliaUserResult {
  final String uid;
  final String name;
  final String username;
  final String bio;
  final String avatar;
  final String gender;
  final String bairro;
  final String cidade;
  final String estado;
  final double? latitude;
  final double? longitude;

  AlgoliaUserResult({
    required this.uid,
    required this.name,
    required this.username,
    this.bio = '',
    this.avatar = '',
    this.gender = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    this.latitude,
    this.longitude,
  });

  factory AlgoliaUserResult.fromAlgolia(Map<String, dynamic> hit) {
    final geoloc = hit['_geoloc'] as Map<String, dynamic>?;
    return AlgoliaUserResult(
      uid:       (hit['objectID'] as String?) ?? '',
      name:      (hit['name'] as String?) ?? '',
      username:  (hit['username'] as String?) ?? '',
      bio:       (hit['bio'] as String?) ?? '',
      avatar:    (hit['avatar'] as String?) ?? '',
      gender:    (hit['gender'] as String?) ?? '',
      bairro:    (hit['bairro'] as String?) ?? '',
      cidade:    (hit['cidade'] as String?) ?? '',
      estado:    (hit['estado'] as String?) ?? '',
      latitude:  geoloc != null ? (geoloc['lat'] as num?)?.toDouble() : null,
      longitude: geoloc != null ? (geoloc['lng'] as num?)?.toDouble() : null,
    );
  }
}
