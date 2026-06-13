// lib/core/error/exceptions.dart

/// Exceção base para erros do servidor/remoto
class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Erro no servidor']);

  @override
  String toString() => 'ServerException: $message';
}

/// Exceção para erros de cache/local
class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Erro no cache']);

  @override
  String toString() => 'CacheException: $message';
}

/// Exceção para ausência de conexão com internet
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Sem conexão com a internet']);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exceção para erros de autenticação
class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Erro de autenticação']);

  @override
  String toString() => 'AuthException: $message';
}

/// Exceção para recurso não encontrado
class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Recurso não encontrado']);

  @override
  String toString() => 'NotFoundException: $message';
}

/// Exceção para erros de permissão
class PermissionException implements Exception {
  final String message;
  const PermissionException([this.message = 'Sem permissão para esta ação']);

  @override
  String toString() => 'PermissionException: $message';
}