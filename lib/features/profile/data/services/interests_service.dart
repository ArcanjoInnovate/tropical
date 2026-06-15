// lib/features/profile/data/services/interests_service.dart

import 'package:tclub/features/profile/data/models/interests_model.dart';
import 'package:tclub/features/profile/data/repositories/interests_repository.dart';

/// Número máximo de interesses permitidos.
const int kMaxInterests = 10;

class InterestsService {
  InterestsService({required IInterestsRepository repository})
      : _repository = repository;

  final IInterestsRepository _repository;

  /// Valida e persiste os interesses do usuário.
  /// Lança [InterestsServiceException] em caso de erro de validação ou persistência.
  Future<void> saveInterests({
    required String uid,
    required InterestsModel data,
  }) async {
    if (uid.trim().isEmpty) {
      throw const InterestsServiceException('UID inválido.');
    }
    if (data.interests.isEmpty) {
      throw const InterestsServiceException(
          'Selecione ao menos um interesse.');
    }
    if (data.interests.length > kMaxInterests) {
      throw InterestsServiceException(
          'Máximo de $kMaxInterests interesses permitidos.');
    }

    // Garante que não há duplicatas nem strings vazias
    final sanitized = data.interests
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    try {
      await _repository.saveInterests(
        uid:  uid,
        data: InterestsModel(interests: sanitized),
      );
    } on InterestsRepositoryException catch (e) {
      throw InterestsServiceException(e.message);
    } catch (e) {
      throw InterestsServiceException('Falha ao salvar interesses: $e');
    }
  }
}

class InterestsServiceException implements Exception {
  const InterestsServiceException(this.message);
  final String message;

  @override
  String toString() => 'InterestsServiceException: $message';
}

