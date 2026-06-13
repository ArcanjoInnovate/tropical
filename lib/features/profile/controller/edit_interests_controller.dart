// lib/features/profile/controller/edit_interests_controller.dart

import 'package:flutter/foundation.dart';
import 'package:tabuapp/features/profile/data/models/interests_model.dart';
import 'package:tabuapp/features/profile/data/services/interests_service.dart';

export 'package:tabuapp/features/profile/data/services/interests_service.dart'
    show kMaxInterests;

enum InterestsSaveStatus { idle, saving, success, error }

class EditInterestsController extends ChangeNotifier {
  EditInterestsController({
    required InterestsService service,
    required Map<String, dynamic> userData,
  })  : _service = service {
    _initFromUserData(userData);
  }

  final InterestsService _service;

  // ── Estado ────────────────────────────────────────────────────────────────

  final Set<String> _selected = {};

  InterestsSaveStatus _saveStatus = InterestsSaveStatus.idle;
  String?             _saveError;

  // ── Getters públicos ─────────────────────────────────────────────────────

  /// Cópia imutável dos interesses selecionados.
  Set<String> get selected => Set.unmodifiable(_selected);

  int  get count      => _selected.length;
  bool get isEmpty    => _selected.isEmpty;
  bool get isAtMax    => _selected.length >= kMaxInterests;

  InterestsSaveStatus get saveStatus => _saveStatus;
  String?             get saveError  => _saveError;
  bool                get isSaving   => _saveStatus == InterestsSaveStatus.saving;

  // ── Inicialização a partir do userData do Firebase ───────────────────────

  void _initFromUserData(Map<String, dynamic> d) {
    final raw = d['interests'];
    if (raw is List) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          _selected.add(item.trim());
        }
      }
    }
  }

  // ── Mutações ──────────────────────────────────────────────────────────────

  /// Adiciona ou remove [item] do conjunto. Retorna false se o limite foi
  /// atingido e o item não pôde ser adicionado.
  bool toggle(String item) {
    if (_selected.contains(item)) {
      _selected.remove(item);
      notifyListeners();
      return true;
    }
    if (isAtMax) return false;
    _selected.add(item);
    notifyListeners();
    return true;
  }

  bool isSelected(String item) => _selected.contains(item);

  void resetSaveStatus() {
    _saveStatus = InterestsSaveStatus.idle;
    _saveError  = null;
    notifyListeners();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> save(String uid) async {
    _saveStatus = InterestsSaveStatus.saving;
    _saveError  = null;
    notifyListeners();

    try {
      final model = InterestsModel(interests: _selected.toList());
      await _service.saveInterests(uid: uid, data: model);

      _saveStatus = InterestsSaveStatus.success;
      notifyListeners();
    } catch (e) {
      _saveStatus = InterestsSaveStatus.error;
      _saveError  = e.toString()
          .replaceFirst('InterestsServiceException: ', '')
          .replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }
}