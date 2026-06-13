// lib/screens/admin/data/repositories/user_repository.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class UserRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static const int pageSize = 50;

  // Busca a primeira página de usuários.
  // Baixa tudo e ordena no cliente — funciona mesmo sem
  // ".indexOn": ["name"] nas regras. Quando adicionar o índice,
  // pode trocar por orderByChild('name').limitToFirst(pageSize).
  Future<List<UserModel>> fetchFirstPage() async {
    final snap = await _db.child('Users').get();
    final all  = _parseSnapshot(snap);
    return all.take(pageSize).toList();
  }

  // Busca a próxima página a partir do cursor (último nome da página anterior).
  Future<List<UserModel>> fetchNextPage(String lastUserName) async {
    final snap = await _db.child('Users').get();
    final all  = _parseSnapshot(snap);
    final idx  = all.indexWhere((u) => u.name == lastUserName);
    if (idx == -1 || idx + 1 >= all.length) return [];
    return all.skip(idx + 1).take(pageSize).toList();
  }

  // Busca um único usuário pelo uid
  Future<UserModel?> fetchById(String uid) async {
    final snap = await _db.child('Users/$uid').get();
    if (!snap.exists || snap.value == null) return null;
    return UserModel.fromMap(uid, _deepCast(snap.value as Map));
  }

  // Busca o snapshot bruto do nó Users (usado para stats sem paginação)
  Future<Map<String, dynamic>> fetchRawMap() async {
    final snap = await _db.child('Users').get();
    if (!snap.exists || snap.value == null) return {};
    // Cast profundo necessário: Firebase retorna Map<Object?, Object?>
    return _deepCast(snap.value as Map);
  }

  List<UserModel> _parseSnapshot(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return [];
    final map = snap.value as Map;
    return map.entries.map((e) {
      // Cast profundo para garantir Map<String, dynamic>
      final v = _deepCast(e.value as Map);
      return UserModel.fromMap(e.key.toString(), v);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Converte recursivamente Map<Object?, Object?> em Map<String, dynamic>
  Map<String, dynamic> _deepCast(Map m) {
    return m.map((k, v) {
      final key = k.toString();
      final val = v is Map ? _deepCast(v) : v;
      return MapEntry(key, val);
    });
  }
}