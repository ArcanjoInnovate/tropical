// lib/features/party/controller/party_address_controller.dart
//
// Controller de endereço para criar/editar festas.
// Usa Places Autocomplete direto — sem estado, sem cidade, sem IBGE.
// O usuário digita qualquer endereço (rua, quadra, lote, nome do espaço)
// e escolhe na lista, igual ao 99 / iFood.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _kApiKey = 'AIzaSyDCtecstIb_eu3cSEdlwW2PdEgCWCzfcVo';

/// Sugestão retornada pelo Places Autocomplete.
class AddressSuggestion {
  final String placeId;
  final String description; // texto completo exibido na lista
  final String mainText;    // parte principal (nome do logradouro)

  const AddressSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
  });
}

/// Resultado após o usuário clicar numa sugestão.
class ResolvedAddress {
  final String description; // endereço completo
  final String city;
  final String state;       // sigla, ex: "GO"
  final double lat;
  final double lng;

  const ResolvedAddress({
    required this.description,
    required this.city,
    required this.state,
    required this.lat,
    required this.lng,
  });
}

enum AddressStatus { idle, loading, ok, error }

class PartyAddressController extends ChangeNotifier {
  PartyAddressController({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  // ── estado público ──────────────────────────────────────────────────────
  List<AddressSuggestion> suggestions = [];
  bool                    loadingSuggestions = false;
  AddressStatus           status             = AddressStatus.idle;
  String?                 errorMessage;
  ResolvedAddress?        resolved;

  // ── internos ────────────────────────────────────────────────────────────
  Timer? _debounce;

  // ── API ──────────────────────────────────────────────────────────────────

  /// Chamado a cada keystroke no campo de endereço.
  void onChanged(String query) {
    _debounce?.cancel();

    if (query.trim().length < 3) {
      _clear();
      return;
    }

    // Reseta status de ok se o usuário voltou a digitar
    if (status == AddressStatus.ok) {
      status   = AddressStatus.idle;
      resolved = null;
      notifyListeners();
    }

    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    loadingSuggestions = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:br'
        '&language=pt-BR'
        '&key=$_kApiKey',
      );

      final body =
          jsonDecode((await _http.get(uri)).body) as Map<String, dynamic>;

      debugPrint('[PartyAddr] status=${body['status']} '
          'predictions=${(body['predictions'] as List?)?.length ?? 0}');

      final predictions =
          ((body['predictions'] as List?) ?? []).cast<Map<String, dynamic>>();

      suggestions = predictions.map((p) {
        final fmt      = p['structured_formatting'] as Map? ?? {};
        return AddressSuggestion(
          placeId:     p['place_id']  as String? ?? '',
          description: p['description'] as String? ?? '',
          mainText:    fmt['main_text'] as String? ?? '',
        );
      }).where((s) => s.placeId.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[PartyAddr] _search error: $e');
      suggestions = [];
    } finally {
      loadingSuggestions = false;
      notifyListeners();
    }
  }

  /// Chamado ao clicar em uma sugestão.
  Future<void> selectSuggestion(AddressSuggestion s) async {
    suggestions = [];
    status      = AddressStatus.loading;
    notifyListeners();

    try {
      final detailsUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeComponent(s.placeId)}'
        '&fields=geometry,address_components'
        '&language=pt-BR'
        '&key=$_kApiKey',
      );

      final body =
          jsonDecode((await _http.get(detailsUri)).body) as Map<String, dynamic>;

      final result = body['result'] as Map? ?? {};
      var   loc    = (result['geometry'] as Map?)?['location'] as Map?;
      final comps  = ((result['address_components'] as List?) ?? [])
          .cast<Map<String, dynamic>>();

      // Fallback: se Places Details não retornou geometry (billing / key issue),
      // tenta resolver via Geocoding API que já estava habilitada.
      if (loc == null) {
        debugPrint('[PartyAddr] geometry nulo, tentando Geocoding fallback...');
        final geocodeUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(s.description)}'
          '&components=country:BR'
          '&language=pt-BR'
          '&key=$_kApiKey',
        );
        final gBody =
            jsonDecode((await _http.get(geocodeUri)).body) as Map<String, dynamic>;
        final gResults = ((gBody['results'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        if (gResults.isNotEmpty) {
          loc = (gResults.first['geometry'] as Map?)?['location'] as Map?;
          // Se address_components veio vazio do Details, pega do Geocoding
          if (comps.isEmpty) {
            comps.addAll(
              ((gResults.first['address_components'] as List?) ?? [])
                  .cast<Map<String, dynamic>>());
          }
        }
      }

      if (loc == null) throw Exception('Não foi possível obter coordenadas');

      String city  = '';
      String state = '';

      for (final c in comps) {
        final types = (c['types'] as List).cast<String>();
        if (types.contains('administrative_area_level_2') && city.isEmpty) {
          city = c['long_name'] as String? ?? '';
        }
        if (types.contains('administrative_area_level_1') && state.isEmpty) {
          state = c['short_name'] as String? ?? '';
        }
      }

      resolved = ResolvedAddress(
        description: s.description,
        city:        city,
        state:       state,
        lat:         (loc['lat'] as num).toDouble(),
        lng:         (loc['lng'] as num).toDouble(),
      );

      status       = AddressStatus.ok;
      errorMessage = null;
    } catch (e) {
      debugPrint('[PartyAddr] selectSuggestion error: $e');
      status       = AddressStatus.error;
      errorMessage = 'Não foi possível confirmar o endereço. Tente novamente.';
    }

    notifyListeners();
  }

  /// Limpa tudo (botão "LIMPAR" na seção de local).
  void clear() {
    _debounce?.cancel();
    _clear();
  }

  void _clear() {
    suggestions        = [];
    loadingSuggestions = false;
    status             = AddressStatus.idle;
    errorMessage       = null;
    resolved           = null;
    notifyListeners();
  }

  /// Chamado ao perder foco no campo — apenas fecha sugestões abertas.
  void onUnfocused() {
    _debounce?.cancel();
    if (suggestions.isNotEmpty) {
      suggestions = [];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _http.close();
    super.dispose();
  }
}

