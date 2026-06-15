// lib/screens/admin/data/repositories/stats_repository.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/admin_stats_model.dart';
import '../models/user_model.dart';

class StatsRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<AdminStatsModel> fetchStats({
    required Map<String, dynamic> usersRaw,
  }) async {
    final results = await Future.wait([
      _db.child('Posts/post').get(),
      _db.child('Posts/story').get(),
      _db.child('Festas').get(),
      _db.child('Reports/posts').get(),
      _db.child('Reports/stories').get(),
      _db.child('Reports/users').get(),
      _db.child('Reports/chats').get(),
    ]);

    return AdminStatsModel(
      totalUsers:     _countValidUsers(usersRaw),
      totalPosts:     _countMap(results[0]),
      totalStories:   _countMap(results[1]),
      totalFestas:    _countMap(results[2]),
      pendingReports: _countPending(results[3]) +
                      _countPending(results[4]) +
                      _countPending(results[5]) +
                      _countPending(results[6]),
    );
  }

  int _countMap(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return 0;
    final v = snap.value;
    if (v is Map) return v.keys.where((k) => k != 'rs').length;
    return 0;
  }

  int _countValidUsers(Map<String, dynamic> raw) {
    int count = 0;
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is! Map) continue;

      // Cast profundo: garante Map<String, dynamic> mesmo vindo
      // do Firebase como Map<Object?, Object?>
      final map = _deepCast(v);
      final user = UserModel.fromMap(entry.key, map);
      if (_isValid(user)) count++;
    }
    return count;
  }

  /// Converte recursivamente Map<Object?, Object?> em Map<String, dynamic>
  Map<String, dynamic> _deepCast(Map m) {
    return m.map((k, v) {
      final key = k.toString();
      final val = v is Map ? _deepCast(v) : v;
      return MapEntry(key, val);
    });
  }

  bool _isValid(UserModel u) =>
      u.name.isNotEmpty  &&
      u.email.isNotEmpty &&
      u.uid.isNotEmpty   &&
      (u.city.isNotEmpty || u.state.isNotEmpty);

  int _countPending(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return 0;
    final v = snap.value;
    if (v is! Map) return 0;
    return v.values
        .whereType<Map>()
        .where((r) => r['status'] == 'pending')
        .length;
  }
}

