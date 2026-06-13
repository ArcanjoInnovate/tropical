// lib/features/match/data/services/match_filter_prefs.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_filter_model.dart';

class MatchFilterPrefs {
  static const _kKey = 'match_filter_v1';

  /// Salva o filtro no dispositivo.
  static Future<void> save(MatchFilterModel filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(filter.toMap()));
  }

  /// Carrega o filtro salvo. Retorna null se não houver nenhum salvo ainda.
  static Future<MatchFilterModel?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return null;
      return MatchFilterModel.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Dado corrompido ou versão incompatível — ignora e usa o padrão.
      return null;
    }
  }

  /// Remove o filtro salvo (útil para logout ou reset).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}