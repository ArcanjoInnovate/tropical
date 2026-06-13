// lib/screens/admin/data/repositories/invite_repository.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/invite_model.dart';

class InviteRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<List<InviteModel>> fetchAll() async {
    final snap = await _db.child('InviteRequests').get();
    if (!snap.exists || snap.value == null) return [];

    final map = snap.value as Map;
    return map.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      return InviteModel.fromMap(e.key, v);
    }).toList()
      ..sort((a, b) =>
          (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
  }
}