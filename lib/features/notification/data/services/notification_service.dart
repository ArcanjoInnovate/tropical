// lib/services/services_app/notification_service.dart
//
// ATENÇÃO: As notificações de follow, like, comment e party
// são criadas exclusivamente por Cloud Functions (triggers RTDB).
// Este serviço é responsável apenas por LEITURA e gerenciamento
// das notificações já existentes no banco.
//
// NÍVEL 1.8 — streamNotifications com limitToLast(50)
// NÍVEL 2.7 — markAllAsRead só baixa não-lidas via orderByChild('read').equalTo(false)
// ALTERAÇÃO  — badge movido de Users/{uid}/unreadNotificationsCount
//              para UserBadges/{uid}/unreadNotificationsCount

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/notification/data/models/notification_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _db = FirebaseDatabase.instance;

  DatabaseReference _notificationsRef(String uid) =>
      _db.ref('Notifications/$uid');

  // ✅ Nó dedicado para badge
  DatabaseReference _badgeRef(String uid) =>
      _db.ref('UserBadges/$uid/unreadNotificationsCount');

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCAR NOTIFICAÇÕES (paginado)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<NotificationModel>> fetchNotifications(
    String uid, {
    int limit = 50,
  }) async {
    final snap = await _notificationsRef(uid)
        .orderByChild('created_at')
        .limitToLast(limit)
        .get();

    if (!snap.exists) return [];

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <NotificationModel>[];

    for (final entry in data.entries) {
      if (entry.value is! Map) continue;
      try {
        list.add(NotificationModel.fromMap(
          entry.key as String,
          Map<dynamic, dynamic>.from(entry.value as Map),
        ));
      } catch (e) {
        debugPrint('Erro ao parsear notificacao: $e');
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM DE NOTIFICAÇÕES (tempo real) — NÍVEL 1.8
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _notificationsRef(uid)
        .orderByChild('created_at')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <NotificationModel>[];

      for (final entry in data.entries) {
        if (entry.value is! Map) continue;
        try {
          list.add(NotificationModel.fromMap(
            entry.key as String,
            Map<dynamic, dynamic>.from(entry.value as Map),
          ));
        } catch (_) {}
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MARCAR COMO LIDA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAsRead(String uid, String notificationId) async {
    await _notificationsRef(uid)
        .child(notificationId)
        .update({'read': true});
    await _updateBadgeCount(uid);
  }

  /// NÍVEL 2.7 — Só baixa notificações não lidas em vez de TODAS.
  Future<void> markAllAsRead(String uid) async {
    final snap = await _notificationsRef(uid)
        .orderByChild('read')
        .equalTo(false)
        .get();

    if (!snap.exists) return;

    final updates = <String, dynamic>{};
    final data = Map<dynamic, dynamic>.from(snap.value as Map);

    for (final key in data.keys) {
      updates['$key/read'] = true;
    }

    if (updates.isNotEmpty) {
      await _notificationsRef(uid).update(updates);
      // ✅ Zera badge em UserBadges/{uid}
      await _badgeRef(uid).set(0);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETAR NOTIFICAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteNotification(String uid, String notificationId) async {
    await _notificationsRef(uid).child(notificationId).remove();
    await _updateBadgeCount(uid);
  }

  Future<void> deleteAllNotifications(String uid) async {
    await _notificationsRef(uid).remove();
    // ✅ Zera badge em UserBadges/{uid}
    await _badgeRef(uid).set(0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BADGE — CONTAGEM DE NÃO LIDAS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> getUnreadCount(String uid) async {
    // ✅ Lê de UserBadges/{uid}
    final snap = await _badgeRef(uid).get();
    return snap.value as int? ?? 0;
  }

  Stream<int> streamUnreadCount(String uid) {
    // ✅ Lê de UserBadges/{uid}
    return _badgeRef(uid)
        .onValue
        .map((event) => event.snapshot.value as int? ?? 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INTERNO — RECALCULA BADGE APÓS AÇÃO LOCAL
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _updateBadgeCount(String uid) async {
    final snap = await _notificationsRef(uid)
        .orderByChild('read')
        .equalTo(false)
        .get();

    final unreadCount = snap.exists ? (snap.value as Map).length : 0;

    // ✅ Escreve em UserBadges/{uid}
    await _badgeRef(uid).set(unreadCount);
  }
}

