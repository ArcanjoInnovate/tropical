// lib/screens/admin/data/repositories/report_repository.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';

class ReportRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static const _tipos = ['posts', 'stories', 'users', 'chats'];

  // Busca reports de um tipo específico
  Future<List<ReportModel>> fetchByTipo(String tipo) async {
    final snap = await _db.child('Reports/$tipo').get();
    if (!snap.exists || snap.value == null) return [];

    final map = snap.value as Map;
    return map.entries.map((e) {
      final v = _deepCast(e.value as Map);
      return ReportModel.fromMap(e.key, v, tipo: tipo); // ← tipo passado
    }).toList()
      ..sort((a, b) =>
          (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
  }

  // Busca reports de todos os tipos de uma vez
  Future<Map<String, List<ReportModel>>> fetchAll() async {
    final snaps = await Future.wait(
      _tipos.map((t) => _db.child('Reports/$t').get()),
    );

    final result = <String, List<ReportModel>>{};
    for (var i = 0; i < _tipos.length; i++) {
      final tipo = _tipos[i];
      final snap = snaps[i];
      if (!snap.exists || snap.value == null) {
        result[tipo] = [];
        continue;
      }
      final map = snap.value as Map;
      result[tipo] = map.entries.map((e) {
        final v = _deepCast(e.value as Map);
        return ReportModel.fromMap(e.key, v, tipo: tipo); // ← tipo passado
      }).toList()
        ..sort((a, b) =>
            (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    }
    return result;
  }

  // Conta reports pendentes de todos os tipos
  Future<int> countPending() async {
    final all = await fetchAll();
    return all.values
        .expand((list) => list)
        .where((r) => r.isPending)
        .length;
  }

  Future<void> updateStatus(String tipo, String key, String status) async {
    await _db.child('Reports/$tipo/$key/status').set(status);
  }

  Future<void> deleteContent(String contentPath) async {
    await _db.child(contentPath).remove();
  }

  Future<void> resolveWithDeletion({
    required String tipo,
    required String key,
    required String contentPath,
  }) async {
    await Future.wait([
      deleteContent(contentPath),
      updateStatus(tipo, key, 'actioned'),
    ]);
  }

  // Busca conteúdo denunciado (post, story ou chat)
  Future<Map<String, dynamic>?> fetchContentData(ReportModel report) async {
    String? path;

    if (report.tipo == 'posts'   && report.postId  != null)
      path = 'Posts/post/${report.postId}';
    else if (report.tipo == 'stories' && report.storyId != null)
      path = 'Posts/story/${report.storyId}';
    else if (report.tipo == 'chats'   && report.chatId  != null)
      path = 'ChatMessages/${report.chatId}';

    if (path == null) return null;

    final snap = await _db.child(path).get();
    if (!snap.exists) return null;
    return _deepCast(snap.value as Map);
  }

  // Converte recursivamente Map<Object?, Object?> → Map<String, dynamic>
  // O Firebase Realtime Database retorna esse tipo nas queries de nó raiz.
  static Map<String, dynamic> _deepCast(Map source) {
    return source.map((k, v) {
      final key   = k.toString();
      final value = v is Map ? _deepCast(v) : v;
      return MapEntry(key, value);
    });
  }
}

