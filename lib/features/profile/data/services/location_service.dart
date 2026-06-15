// lib/features/profile/data/services/location_service.dart

import 'package:tclub/features/profile/data/models/location_model.dart';
import 'package:tclub/features/profile/data/repositories/location_repository.dart';

class LocationService {
  LocationService({required ILocationRepository repository})
      : _repository = repository;

  final ILocationRepository _repository;

  /// Geocodifica [city] + [stateCode] via Geocoding API e retorna coordenadas.
  Future<({double lat, double lng})> geocodeCity({
    required String city,
    required String stateCode,
  }) async {
    if (city.isEmpty || stateCode.isEmpty) {
      throw const LocationServiceException('Cidade ou estado inválido.');
    }
    try {
      return await _repository.geocodeCity(city: city, stateCode: stateCode);
    } on LocationRepositoryException catch (e) {
      throw LocationServiceException(e.message);
    } catch (e) {
      throw LocationServiceException(
          'Não foi possível obter coordenadas: $e');
    }
  }

  /// Valida o [bairro] dentro da cidade e retorna coordenadas refinadas.
  Future<({double lat, double lng})> validateBairro({
    required String bairro,
    required String city,
    required String stateCode,
    required double cityLat,
    required double cityLng,
  }) async {
    if (bairro.trim().isEmpty) {
      throw const LocationServiceException('Endereço não pode ser vazio.');
    }
    if (city.isEmpty || stateCode.isEmpty) {
      throw const LocationServiceException('Cidade inválida.');
    }
    try {
      return await _repository.validateBairro(
        bairro:    bairro.trim(),
        city:      city,
        stateCode: stateCode,
        cityLat:   cityLat,
        cityLng:   cityLng,
      );
    } on LocationRepositoryException catch (e) {
      throw LocationServiceException(e.message);
    } catch (e) {
      throw LocationServiceException(
          'Não foi possível verificar o endereço: $e');
    }
  }

  /// Busca sugestões de endereços completos via Places Autocomplete.
  Future<List<BairroSuggestion>> searchBairros({
    required String query,
    required String city,
    required String stateCode,
    required double cityLat,
    required double cityLng,
  }) async {
    if (query.trim().isEmpty || city.isEmpty || stateCode.isEmpty) return [];
    try {
      return await _repository.searchBairros(
        query:     query.trim(),
        city:      city,
        stateCode: stateCode,
        cityLat:   cityLat,
        cityLng:   cityLng,
      );
    } catch (_) {
      return [];
    }
  }

  /// Resolve lat/lng precisos de um [placeId] via Places Details.
  /// Chamado ao clicar numa sugestão de endereço.
  Future<({double lat, double lng})> resolvePlaceCoords(String placeId) async {
    if (placeId.trim().isEmpty) {
      throw const LocationServiceException('place_id inválido.');
    }
    try {
      // Cast necessário pois ILocationRepository não expõe resolvePlaceCoords —
      // LocationRepository concreto o implementa.
      return await (_repository as LocationRepository)
          .resolvePlaceCoords(placeId);
    } on LocationRepositoryException catch (e) {
      throw LocationServiceException(e.message);
    } catch (e) {
      throw LocationServiceException(
          'Não foi possível obter coordenadas do endereço: $e');
    }
  }

  /// Persiste localização validada em Users/{uid} e Matchs/{uid}.
  Future<void> saveLocation(
      {required String uid, required LocationModel data}) async {
    if (uid.trim().isEmpty) {
      throw const LocationServiceException('UID inválido.');
    }
    if (data.state.isEmpty || data.city.isEmpty || data.bairro.isEmpty) {
      throw const LocationServiceException(
          'Todos os campos de localização são obrigatórios.');
    }
    try {
      await _repository.saveLocation(uid: uid, data: data);
    } catch (e) {
      throw LocationServiceException('Falha ao salvar localização: $e');
    }
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);
  final String message;

  @override
  String toString() => 'LocationServiceException: $message';
}

/// Lançada quando a cidade resolvida pertence a um estado diferente do selecionado.
class LocationStateMismatchException implements Exception {
  const LocationStateMismatchException(this.actualState);
  final String actualState;

  @override
  String toString() =>
      'LocationStateMismatchException: cidade pertence a $actualState';
}

