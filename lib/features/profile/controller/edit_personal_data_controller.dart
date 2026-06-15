// lib/features/profile/controller/edit_personal_data_controller.dart
//
// ARQUIVO DE REFERÊNCIA — atualize o seu controller existente com os
// parâmetros birthDate e age no método save().

import 'package:flutter/foundation.dart';
import 'package:tclub/features/profile/data/models/personal_data_model.dart';
import 'package:tclub/features/profile/data/services/personal_data_service.dart';

enum _Status { idle, loading, success, error }

class EditPersonalDataController extends ChangeNotifier {
  EditPersonalDataController({required PersonalDataService service})
      : _service = service;

  final PersonalDataService _service;

  _Status _status       = _Status.idle;
  String? _errorMessage;

  bool get isLoading => _status == _Status.loading;
  bool get isSuccess => _status == _Status.success;
  bool get hasError  => _status == _Status.error;
  String? get errorMessage => _errorMessage;

  /// Persiste os dados pessoais.
  ///
  /// [birthDate] → "yyyy-MM-dd" ou null (campo opcional).
  /// [age]       → inteiro calculado a partir de [birthDate] ou null.
  Future<void> save({
    required String uid,
    required String name,
    required String bio,
    required Map<String, dynamic> fullUserData,
    String? birthDate,
    int?    age,
  }) async {
    _status = _Status.loading;
    notifyListeners();

    try {
      await _service.savePersonalData(
        uid: uid,
        data: PersonalDataModel(
          name:      name,
          bio:       bio,
          birthDate: birthDate,
          age:       age,
        ),
        fullUserData: fullUserData,
      );
      _status = _Status.success;
    } on PersonalDataServiceException catch (e) {
      _status       = _Status.error;
      _errorMessage = e.message;
    } catch (e) {
      _status       = _Status.error;
      _errorMessage = 'Erro inesperado: $e';
    }

    notifyListeners();
  }

  void resetStatus() {
    _status       = _Status.idle;
    _errorMessage = null;
    notifyListeners();
  }
}

