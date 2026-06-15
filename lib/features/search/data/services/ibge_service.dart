// lib/services/ibge_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo leve para Estado (UF + nome).
class EstadoIbge {
  final String sigla;
  final String nome;

  const EstadoIbge({required this.sigla, required this.nome});

  factory EstadoIbge.fromJson(Map<String, dynamic> json) => EstadoIbge(
        sigla: json['sigla'] as String,
        nome: json['nome'] as String,
      );

  @override
  String toString() => nome;
}

/// Modelo leve para Município.
class CidadeIbge {
  final int id;
  final String nome;

  const CidadeIbge({required this.id, required this.nome});

  factory CidadeIbge.fromJson(Map<String, dynamic> json) => CidadeIbge(
        id: json['id'] as int,
        nome: json['nome'] as String,
      );

  @override
  String toString() => nome;
}

/// Serviço de consulta à API pública do IBGE (localidades).
///
/// Endpoints utilizados:
///   • Estados : GET https://servicodados.ibge.gov.br/api/v1/localidades/estados?orderBy=nome
///   • Cidades : GET https://servicodados.ibge.gov.br/api/v1/localidades/estados/{uf}/municipios?orderBy=nome
///
/// Cache in-memory:
///   • Estados são buscados uma única vez por sessão.
///   • Cidades são cacheadas por sigla de estado.
///
/// Uso:
/// ```dart
/// final ibge = IbgeService();
/// final estados = await ibge.fetchEstados();
/// final cidades = await ibge.fetchCidades('SP');
/// ```
class IbgeService {
  static const _baseUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';
  static const _timeout = Duration(seconds: 10);
  static const int _maxRetries = 2;

  // ── Cache in-memory ────────────────────────────────────────────────────────

  List<EstadoIbge>? _cachedEstados;
  final Map<String, List<CidadeIbge>> _cachedCidades = {};

  // ── Estados ────────────────────────────────────────────────────────────────

  /// Retorna a lista de estados brasileiros ordenados por nome.
  /// Lança [IbgeServiceException] em caso de falha após as tentativas.
  Future<List<EstadoIbge>> fetchEstados() async {
    if (_cachedEstados != null) return _cachedEstados!;

    final uri = Uri.parse('$_baseUrl/estados?orderBy=nome');
    final body = await _getWithRetry(uri);

    final raw = json.decode(body) as List<dynamic>;
    _cachedEstados = raw
        .map((e) => EstadoIbge.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return _cachedEstados!;
  }

  // ── Cidades ────────────────────────────────────────────────────────────────

  /// Retorna os municípios do estado [uf] (sigla, ex: "SP") ordenados por nome.
  /// Lança [IbgeServiceException] em caso de falha após as tentativas.
  Future<List<CidadeIbge>> fetchCidades(String uf) async {
    final key = uf.toUpperCase();
    if (_cachedCidades.containsKey(key)) return _cachedCidades[key]!;

    final uri = Uri.parse('$_baseUrl/estados/$key/municipios?orderBy=nome');
    final body = await _getWithRetry(uri);

    final raw = json.decode(body) as List<dynamic>;
    final cidades = raw
        .map((e) => CidadeIbge.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    _cachedCidades[key] = cidades;
    return cidades;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Executa GET com até [_maxRetries] tentativas e timeout de [_timeout].
  Future<String> _getWithRetry(Uri uri) async {
    Object? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode == 200) {
          return response.body;
        }

        throw IbgeServiceException(
          'Resposta inesperada do IBGE: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      } on IbgeServiceException {
        rethrow; // Erros HTTP explícitos não precisam de retry
      } catch (e) {
        lastError = e;

        if (attempt < _maxRetries) {
          // Backoff simples: 500ms, 1000ms
          await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }

    throw IbgeServiceException(
      'Falha ao consultar a API do IBGE após $_maxRetries tentativas: $lastError',
    );
  }

  // ── Invalidação manual (útil em testes) ───────────────────────────────────

  /// Limpa todo o cache em memória.
  void clearCache() {
    _cachedEstados = null;
    _cachedCidades.clear();
  }

  /// Remove o cache de cidades de um estado específico.
  void clearCidadesCache(String uf) => _cachedCidades.remove(uf.toUpperCase());
}

// ── Exceção tipada ─────────────────────────────────────────────────────────

class IbgeServiceException implements Exception {
  final String message;
  final int? statusCode;

  const IbgeServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'IbgeServiceException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

