// lib/features/profile/data/services/identity_service.dart

import 'package:tclub/features/profile/data/models/identify_model.dart';
import 'package:tclub/features/profile/data/repositories/identify_repository.dart';

class IdentityService {
  IdentityService({required IIdentityRepository repository})
      : _repository = repository;

  final IIdentityRepository _repository;

  /// Valida e persiste a identidade do usuário.
  ///
  /// [partnerImageBytes] → bytes da foto do parceiro pendente de upload.
  /// Passe null se não houve mudança de foto.
  ///
  /// Lança [IdentityServiceException] em caso de erro.
  Future<void> saveIdentity({
    required String uid,
    required IdentityModel data,
    List<int>? partnerImageBytes,
  }) async {
    if (uid.trim().isEmpty) {
      throw const IdentityServiceException('UID inválido.');
    }
    if (data.genderIdentity.isEmpty) {
      throw const IdentityServiceException('Gênero obrigatório.');
    }
    if (data.relationshipType.isEmpty) {
      throw const IdentityServiceException(
          'Tipo de relacionamento obrigatório.');
    }
    if (data.sexualOrientation.isEmpty) {
      throw const IdentityServiceException('Orientação sexual obrigatória.');
    }

    if (data.profileType == 'couple') {
      final p = data.partner;
      if (p == null || p.name.trim().isEmpty) {
        throw const IdentityServiceException(
            'Nome do(a) parceiro(a) obrigatório.');
      }
      if (p.birthDate.isEmpty) {
        throw const IdentityServiceException(
            'Aniversário do(a) parceiro(a) obrigatório.');
      }
      if (p.genderIdentity.isEmpty) {
        throw const IdentityServiceException(
            'Gênero do(a) parceiro(a) obrigatório.');
      }
      if (p.sexualOrientation.isEmpty) {
        throw const IdentityServiceException(
            'Orientação do(a) parceiro(a) obrigatória.');
      }
      // Foto obrigatória: ou já existe URL salva, ou bytes foram fornecidos
      final hasAvatar =
          p.avatarUrl.isNotEmpty || (partnerImageBytes?.isNotEmpty ?? false);
      if (!hasAvatar) {
        throw const IdentityServiceException(
            'Foto do(a) parceiro(a) obrigatória.');
      }
    }

    try {
      await _repository.saveIdentity(
        uid:               uid,
        data:              data,
        partnerImageBytes: partnerImageBytes,
      );
    } on IdentityRepositoryException catch (e) {
      throw IdentityServiceException(e.message);
    } catch (e) {
      throw IdentityServiceException('Falha ao salvar identidade: $e');
    }
  }
}

class IdentityServiceException implements Exception {
  const IdentityServiceException(this.message);
  final String message;

  @override
  String toString() => 'IdentityServiceException: $message';
}

