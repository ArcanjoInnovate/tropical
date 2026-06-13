// lib/core/error/failures.dart

import 'package:equatable/equatable.dart';

/// Classe base para todas as falhas de domínio
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

/// Falha de servidor / Firebase
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro no servidor']);
}

/// Falha de cache / armazenamento local
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro no cache']);
}

/// Falha de conexão com a internet
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão com a internet']);
}

/// Falha de autenticação
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Erro de autenticação']);
}

/// Falha para recurso não encontrado
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso não encontrado']);
}

/// Falha de permissão
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Sem permissão para esta ação']);
}

/// Falha de validação de dados
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Dados inválidos']);
}