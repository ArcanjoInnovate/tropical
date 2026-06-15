// lib/features/profile/data/repositories/location_repository.dart

import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tclub/features/profile/data/models/location_model.dart';

const _kApiKey = 'AIzaSyDCtecstIb_eu3cSEdlwW2PdEgCWCzfcVo';

abstract class ILocationRepository {
  /// Geocodifica o nome da cidade + estado e retorna coordenadas.
  Future<({double lat, double lng})> geocodeCity({
    required String city,
    required String stateCode,
  });

  /// Valida se [bairro] pertence a [city]/[stateCode] e retorna coordenadas refinadas.
  Future<({double lat, double lng})> validateBairro({
    required String bairro,
    required String city,
    required String stateCode,
    required double cityLat,
    required double cityLng,
  });

  /// Persiste [LocationModel] em Users/{uid} e sincroniza Matchs/{uid}.
  Future<void> saveLocation({required String uid, required LocationModel data});

  /// Busca sugestões de endereços completos na cidade/estado selecionados.
  Future<List<BairroSuggestion>> searchBairros({
    required String query,
    required String city,
    required String stateCode,
    required double cityLat,
    required double cityLng,
  });
}

class LocationRepository implements ILocationRepository {
  LocationRepository({FirebaseDatabase? db, http.Client? httpClient})
      : _db = db ?? FirebaseDatabase.instance,
        _httpClient = httpClient ?? http.Client();

  final FirebaseDatabase _db;
  final http.Client _httpClient;

  DatabaseReference get _usersRef => _db.ref('Users');
  DatabaseReference get _matchsRef => _db.ref('Matchs');

  // ── Geocode de cidade ──────────────────────────────────────────────────

  @override
  Future<({double lat, double lng})> geocodeCity({
    required String city,
    required String stateCode,
  }) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent('$city, $stateCode, Brasil')}'
      '&components=country:BR'
      '&language=pt-BR'
      '&key=$_kApiKey',
    );

    final response = await _httpClient.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final status = body['status'] as String?;
    final results =
        ((body['results'] as List?) ?? []).cast<Map<String, dynamic>>();

    if (results.isEmpty) {
      throw LocationRepositoryException(
        'Não foi possível localizar "$city, $stateCode" (status: $status)',
      );
    }

    final loc = (results.first['geometry'] as Map?)?['location'] as Map?;
    return (
      lat: (loc?['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (loc?['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ── Geocode (validação de endereço) ────────────────────────────────────

  @override
  Future<({double lat, double lng})> validateBairro({
    required String bairro,
    required String city,
    required String stateCode,
    required double cityLat,
    required double cityLng,
  }) async {
    const d = 0.3;
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent('$bairro, $city, $stateCode, Brasil')}'
      '&bounds=${cityLat - d},${cityLng - d}|${cityLat + d},${cityLng + d}'
      '&components=country:BR'
      '&language=pt-BR'
      '&key=$_kApiKey',
    );

    final body =
        jsonDecode((await _httpClient.get(uri)).body) as Map<String, dynamic>;
    final results =
        ((body['results'] as List?) ?? []).cast<Map<String, dynamic>>();

    if (results.isEmpty) {
      throw const LocationRepositoryException('Endereço não encontrado');
    }

    final normCity  = _normalize(city);
    final normState = stateCode.toUpperCase();

    for (final r in results) {
      final comps =
          (r['address_components'] as List? ?? []).cast<Map<String, dynamic>>();
      String? cidC, estC;
      for (final c in comps) {
        final types = (c['types'] as List).cast<String>();
        if (types.contains('administrative_area_level_2')) {
          cidC = _normalize(c['long_name'] as String? ?? '');
        }
        if (types.contains('administrative_area_level_1')) {
          estC = (c['short_name'] as String? ?? '').toUpperCase();
        }
      }
      if (cidC == normCity && estC == normState) {
        final loc = (r['geometry'] as Map?)?['location'] as Map?;
        return (
          lat: (loc?['lat'] as num?)?.toDouble() ?? cityLat,
          lng: (loc?['lng'] as num?)?.toDouble() ?? cityLng,
        );
      }
    }

    throw LocationRepositoryException(
        'Endereço não pertence a $city/$stateCode');
  }

  // ── Firebase persistence ───────────────────────────────────────────────

  @override
  Future<void> saveLocation(
      {required String uid, required LocationModel data}) async {
    await _usersRef.child(uid).update(data.toMap());

    final matchSnap = await _matchsRef.child(uid).get();
    final locationFields = {
      'city':   data.city,
      'state':  data.state,
      'bairro': data.bairro,
    };

    if (matchSnap.exists) {
      await _matchsRef.child(uid).update(locationFields);
    } else {
      await _matchsRef.child(uid).set({'uid': uid, ...locationFields});
    }
  }

  // ── Sugestões de endereço via Places Autocomplete ──────────────────────
  //
  // Substituição do Geocoding API por Places Autocomplete:
  //   • Retorna endereços reais e completos ("Rua X, 123, Bairro Y")
  //   • locationbias=circle:raio@lat,lng limita ao raio em torno da cidade
  //   • components=country:br filtra só Brasil
  //   • Após a lista, cada item tem apenas place_id + description —
  //     para obter lat/lng exatos chamamos Places Details no clique
  //     via resolvePlaceCoords().

  @override
  Future<List<BairroSuggestion>> searchBairros({
    required String query,
    required String city,
    required String stateCode,
    required double cityLat,
    required double cityLng,
  }) async {
    // Raio de 30 km em torno do centro da cidade para limitar sugestões
    const radiusMeters = 30000;

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&components=country:br'
      '&locationbias=circle:$radiusMeters@$cityLat,$cityLng'
      '&language=pt-BR'
      '&key=$_kApiKey',
    );

    final body =
        jsonDecode((await _httpClient.get(uri)).body) as Map<String, dynamic>;
      
      

    final predictions =
        ((body['predictions'] as List?) ?? []).cast<Map<String, dynamic>>();

    debugPrint('=== PLACES STATUS: ${body['status']}');
    debugPrint('=== PLACES ERROR: ${body['error_message']}');
    debugPrint('=== PREDICTIONS COUNT: ${predictions.length}');
    if (predictions.isNotEmpty) debugPrint('=== FIRST: ${predictions.first}');
    final suggestions = <BairroSuggestion>[];
    final seen        = <String>{};

    for (final p in predictions) {
      final description = p['description'] as String? ?? '';
      if (description.isEmpty) continue;

      // Normaliza para dedup
      final key = _normalize(description);
      if (seen.contains(key)) continue;
      seen.add(key);

      final placeId = p['place_id'] as String? ?? '';

      suggestions.add(BairroSuggestion(
        nome:             description,
        enderecoCompleto: description,
        // lat/lng = 0 temporariamente; resolvidos ao clicar via resolvePlaceCoords
        lat:     cityLat,
        lng:     cityLng,
        placeId: placeId,
      ));
    }

    return suggestions;
  }

  // ── Places Details: resolve lat/lng de um place_id ─────────────────────
  //
  // Chamado pelo controller ao clicar numa sugestão.
  // Retorna coordenadas precisas do local selecionado.

  Future<({double lat, double lng})> resolvePlaceCoords(String placeId) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(placeId)}'
      '&fields=geometry'
      '&language=pt-BR'
      '&key=$_kApiKey',
    );

    final body =
        jsonDecode((await _httpClient.get(uri)).body) as Map<String, dynamic>;

    final loc = ((body['result'] as Map?)?['geometry'] as Map?)?['location']
        as Map?;

    if (loc == null) {
      throw const LocationRepositoryException(
          'Não foi possível obter coordenadas do endereço');
    }

    return (
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  static String _normalize(String s) {
    const from = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';
    const to   = 'aaaaaaa ceeeeiiiidnoooooouuuuypy';
    var r = s.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }
}

class LocationRepositoryException implements Exception {
  const LocationRepositoryException(this.message);
  final String message;

  @override
  String toString() => 'LocationRepositoryException: $message';
}

