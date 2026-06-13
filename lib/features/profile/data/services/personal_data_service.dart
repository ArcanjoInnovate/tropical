// lib/features/profile/data/services/personal_data_service.dart

import 'package:tabuapp/features/profile/data/models/personal_data_model.dart';
import 'package:tabuapp/features/profile/data/repositories/personal_data_repository.dart';

/// Camada de serviço — orquestra a operação de salvamento e trata erros
/// antes de expor o resultado para o controller.
class PersonalDataService {
  PersonalDataService({required IPersonalDataRepository repository})
      : _repository = repository;

  final IPersonalDataRepository _repository;

  /// Persiste os dados pessoais e mantém Matchs sincronizado.
  ///
  /// Lança [PersonalDataServiceException] em caso de falha, permitindo
  /// que o controller decida como apresentar o erro ao usuário.
  Future<void> savePersonalData({
    required String uid,
    required PersonalDataModel data,
    required Map<String, dynamic> fullUserData,
  }) async {
    if (uid.trim().isEmpty) {
      throw const PersonalDataServiceException('UID do usuário não pode ser vazio.');
    }
    if (data.name.trim().isEmpty) {
      throw const PersonalDataServiceException('O nome não pode ser vazio.');
    }
    if (data.birthDate != null) {
      final birth = DateTime.tryParse(data.birthDate!);
      if (birth == null) {
        throw const PersonalDataServiceException('Data de nascimento inválida.');
      }
      final age = PersonalDataModel.calculateAge(birth) ?? 0;
      if (age < 18) {
        throw const PersonalDataServiceException(
            'Você precisa ter pelo menos 18 anos.');
      }
    }

    try {
      await _repository.savePersonalData(
        uid:          uid,
        data:         data,
        fullUserData: fullUserData,
      );
    } on PersonalDataServiceException {
      rethrow;
    } catch (e) {
      throw PersonalDataServiceException(
        'Falha ao salvar dados pessoais: ${e.toString()}',
      );
    }
  }
}

/// Exceção tipada do serviço de dados pessoais.
class PersonalDataServiceException implements Exception {
  const PersonalDataServiceException(this.message);
  final String message;

  @override
  String toString() => 'PersonalDataServiceException: $message';
}