// lib/features/profile/data/models/location_model.dart

/// Dados editáveis de localização.
class LocationModel {
  final String state;
  final String city;
  final String bairro;
  final double latitude;
  final double longitude;

  const LocationModel({
    required this.state,
    required this.city,
    required this.bairro,
    required this.latitude,
    required this.longitude,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) => LocationModel(
        state:     map['state']     as String? ?? '',
        city:      map['city']      as String? ?? '',
        bairro:    map['bairro']    as String? ?? '',
        latitude:  (map['latitude']  as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'state':     state,
        'city':      city,
        'bairro':    bairro,
        'latitude':  latitude,
        'longitude': longitude,
      };
}

/// Resultado da busca de sugestões de cidade via Places Autocomplete.
class CityPrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String description;

  const CityPrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.description,
  });

  factory CityPrediction.fromMap(Map<String, dynamic> map) {
    final fmt = map['structured_formatting'] as Map?;
    return CityPrediction(
      placeId:       map['place_id']   as String? ?? '',
      mainText:      fmt?['main_text'] as String? ?? map['description'] as String? ?? '',
      secondaryText: fmt?['secondary_text'] as String? ?? '',
      description:   map['description'] as String? ?? '',
    );
  }
}

/// Resultado da resolução de um placeId em coordenadas + dados de endereço.
class ResolvedCity {
  final String city;
  final String state;
  final double latitude;
  final double longitude;

  const ResolvedCity({
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
  });
}

/// Status de validação de um campo de localização.
enum LocationFieldStatus { idle, loading, ok, error }

/// Sugestão de endereço retornada pelo Places Autocomplete.
/// [placeId] é usado para resolver lat/lng precisos via Places Details
/// ao clicar na sugestão. Null apenas em seeds de edição (endereço já confirmado).
class BairroSuggestion {
  final String  nome;
  final String  enderecoCompleto;
  final double  lat;
  final double  lng;
  final String? placeId;

  const BairroSuggestion({
    required this.nome,
    required this.enderecoCompleto,
    required this.lat,
    required this.lng,
    this.placeId,
  });
}

