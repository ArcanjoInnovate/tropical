// lib/features/chat/data/repositories/chat_repository.dart
//
// NÍVEL 2.5 — Consolidar listeners: unreadCountStream, blockDialogStream e
//             otherStatusStream extraem dados de streams já existentes (singleChatStream
//             e presenceStream) em vez de abrir listeners separados.
// NÍVEL 2.9 — markAsRead: limita a últimas 100 mensagens em vez de baixar todas.
// NÍVEL 3.0 — initializeChat: não cria mais a estrutura do chat diretamente.
//             O chat só existe se foi criado pela CF acceptChatRequest.
//             Cliente apenas lê — nunca escreve em Chats/$chatId raiz.
// ALTERAÇÃO  — presence movido de Users/{uid}/presence para Presence/{uid}

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_model.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Interface
// ════════════════════════════════════════════════════════════════════════════
abstract class IChatRepository {
  Future<TabuChat> initializeChat(String myUid, String otherUid);

  Future<void> setGlobalOnline(String uid);
  Future<void> setGlobalOffline(String uid);
  Stream<bool> userOnlineStream(String uid);
  Stream<int>  userLastSeenStream(String uid);
  Future<void> updateHeartbeat(String chatId, String uid);

  Future<void> setOnline(String chatId, String uid);
  Future<void> setOffline(String chatId, String uid);
  Stream<ParticipantStatus> otherStatusStream(String chatId, String otherUid);

  Future<List<ChatMessage>> loadInitialMessages(String chatId, int limit);
  Future<List<ChatMessage>> loadOlderMessages(String chatId, int beforeTimestamp, int limit);
  Future<String> sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String recipientId,
  });
  Stream<ChatMessage> newMessagesStream(String chatId, int afterTimestamp);
  Stream<ChatMessage> updatedMessagesStream(String chatId);

  Future<void> markAsRead(String chatId, String myUid);
  Stream<int>  unreadCountStream(String chatId, String myUid);

  Stream<bool> blockDialogStream(String chatId);

  Stream<List<String>> chatIdsStream(String myUid);
  Stream<TabuChat?>    singleChatStream(String chatId);

  Stream<({bool online, int lastSeen})> presenceStream(String uid);
}

// ════════════════════════════════════════════════════════════════════════════
//  Implementação Firebase
// ════════════════════════════════════════════════════════════════════════════
class ChatRepository implements IChatRepository {
  ChatRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _chatRef(String chatId)     => _db.ref('Chats/$chatId');
  DatabaseReference _messagesRef(String chatId) => _db.ref('ChatMessages/$chatId');
  DatabaseReference _metaRef(String chatId)     => _db.ref('Chats/$chatId/metadata');

  // ✅ Nó dedicado para presence
  DatabaseReference _presenceRef(String uid) => _db.ref('Presence/$uid');

  // ── initializeChat ────────────────────────────────────────────────────────
  @override
  Future<TabuChat> initializeChat(String myUid, String otherUid) async {
    final chatId = TabuChat.buildChatId(myUid, otherUid);
    final snap   = await _chatRef(chatId).get();

    if (!snap.exists || snap.value == null) {
      return TabuChat(
        chatId:       chatId,
        user1Id:      [myUid, otherUid].first,
        user2Id:      [myUid, otherUid].last,
        metadata:     ChatMetadata.empty(),
        unreadCount:  {myUid: 0, otherUid: 0},
        participants: {},
        blockDialog:  false,
      );
    }

    return TabuChat.fromMap(chatId, snap.value as Map<dynamic, dynamic>);
  }

  // ── presença global ───────────────────────────────────────────────────────
  @override
  Future<void> setGlobalOnline(String uid) async {
    // ✅ Presence/{uid} em vez de Users/{uid}/presence
    final ref = _presenceRef(uid);
    await ref.update({'online': true, 'last_seen': ServerValue.timestamp});
    ref.onDisconnect().update({'online': false, 'last_seen': ServerValue.timestamp});
  }

  @override
  Future<void> setGlobalOffline(String uid) async {
    // ✅ Presence/{uid} em vez de Users/{uid}/presence
    await _presenceRef(uid).update({
      'online':    false,
      'last_seen': ServerValue.timestamp,
    });
  }

  @override
  Stream<({bool online, int lastSeen})> presenceStream(String uid) =>
      // ✅ Presence/{uid} em vez de Users/{uid}/presence
      _presenceRef(uid).onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value is! Map) {
          return (online: false, lastSeen: 0);
        }
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return (
          online: data['online'] == true,
          lastSeen: (data['last_seen'] as int?) ?? 0,
        );
      });

  @override
  Stream<bool> userOnlineStream(String uid) =>
      // ✅ Presence/{uid} em vez de Users/{uid}/presence
      _presenceRef(uid).child('online').onValue
          .map((e) => e.snapshot.value == true);

  @override
  Stream<int> userLastSeenStream(String uid) =>
      // ✅ Presence/{uid} em vez de Users/{uid}/presence
      _presenceRef(uid).child('last_seen').onValue
          .map((e) => (e.snapshot.value as int?) ?? 0);

  @override
  Future<void> updateHeartbeat(String chatId, String uid) async {
    // ✅ Presence/{uid} em vez de Users/{uid}/presence
    await _presenceRef(uid).child('last_seen').set(ServerValue.timestamp);
    await _db.ref('Chats/$chatId/participants/$uid/last_seen')
        .set(ServerValue.timestamp);
  }

  // ── presença por chat ─────────────────────────────────────────────────────
  @override
  Future<void> setOnline(String chatId, String uid) async {
    final ref = _db.ref('Chats/$chatId/participants/$uid');
    await ref.update({'status': 'online', 'last_seen': ServerValue.timestamp});
    ref.onDisconnect().update({'status': 'offline', 'last_seen': ServerValue.timestamp});
  }

  @override
  Future<void> setOffline(String chatId, String uid) async {
    await _db.ref('Chats/$chatId/participants/$uid').update({
      'status':    'offline',
      'last_seen': ServerValue.timestamp,
    });
  }

  @override
  Stream<ParticipantStatus> otherStatusStream(String chatId, String otherUid) =>
      _db.ref('Chats/$chatId/participants/$otherUid').onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value is! Map) {
          return ParticipantStatus(
            status:   'offline',
            lastSeen: DateTime.now().millisecondsSinceEpoch,
          );
        }
        return ParticipantStatus.fromMap(
            event.snapshot.value as Map<dynamic, dynamic>);
      });

  // ── mensagens ─────────────────────────────────────────────────────────────
  @override
  Future<List<ChatMessage>> loadInitialMessages(
      String chatId, int limit) async {
    try {
      final snap = await _messagesRef(chatId)
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();
      return _parseMsgs(snap);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<ChatMessage>> loadOlderMessages(
      String chatId, int beforeTimestamp, int limit) async {
    try {
      final snap = await _messagesRef(chatId)
          .orderByChild('timestamp')
          .endBefore(beforeTimestamp)
          .limitToLast(limit)
          .get();
      return _parseMsgs(snap);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String recipientId,
  }) async {
    if (text.trim().isEmpty) throw ArgumentError('Mensagem vazia');

    final now    = DateTime.now().millisecondsSinceEpoch;
    final msgRef = _messagesRef(chatId).push();
    final msgId  = msgRef.key!;

    final msg = ChatMessage(
      id:        msgId,
      text:      text.trim(),
      senderId:  senderId,
      timestamp: now,
      readBy:    {senderId: true, recipientId: false},
    );

    await msgRef.set(msg.toMap());

    await _metaRef(chatId).update({
      'last_message':   text.trim(),
      'last_sender':    senderId,
      'last_timestamp': now,
    });

    return msgId;
  }

  @override
  Stream<ChatMessage> newMessagesStream(String chatId, int afterTimestamp) =>
      _messagesRef(chatId)
          .orderByChild('timestamp')
          .startAfter(afterTimestamp)
          .onChildAdded
          .where((e) => e.snapshot.key != '_placeholder' && e.snapshot.value is Map)
          .map((e) => ChatMessage.fromMap(e.snapshot.key!, e.snapshot.value as Map));

  @override
  Stream<ChatMessage> updatedMessagesStream(String chatId) =>
      _messagesRef(chatId)
          .onChildChanged
          .where((e) => e.snapshot.key != '_placeholder' && e.snapshot.value is Map)
          .map((e) => ChatMessage.fromMap(e.snapshot.key!, e.snapshot.value as Map));

  // ── leitura ───────────────────────────────────────────────────────────────
  @override
  Future<void> markAsRead(String chatId, String myUid) async {
    await _db.ref('Chats/$chatId/unreadCount/$myUid').set(0);
    try {
      final snap = await _messagesRef(chatId)
          .orderByChild('timestamp')
          .limitToLast(100)
          .get();
      if (!snap.exists || snap.value is! Map) return;

      final now     = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{};

      (snap.value as Map<dynamic, dynamic>).forEach((msgId, val) {
        if (msgId == '_placeholder') return;
        if (val is Map) {
          final readBy = val['read_by'] as Map<dynamic, dynamic>?;
          if (readBy != null && readBy[myUid] == false) {
            updates['ChatMessages/$chatId/$msgId/read_by/$myUid'] = true;
            updates['ChatMessages/$chatId/$msgId/read_at/$myUid'] = now;
          }
        }
      });

      if (updates.isNotEmpty) await _db.ref().update(updates);
    } catch (_) {}
  }

  @override
  Stream<int> unreadCountStream(String chatId, String myUid) =>
      _db.ref('Chats/$chatId/unreadCount/$myUid').onValue
          .map((e) => (e.snapshot.value as int?) ?? 0);

  // ── bloqueio ──────────────────────────────────────────────────────────────
  @override
  Stream<bool> blockDialogStream(String chatId) =>
      _db.ref('Chats/$chatId/block_dialog').onValue
          .map((e) => e.snapshot.value == true);

  // ── lista de chats ────────────────────────────────────────────────────────
  @override
  Stream<List<String>> chatIdsStream(String myUid) =>
      _db.ref('UserChatRequests/$myUid').onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value is! Map) {
          return <String>[];
        }
        final ids = <String>[];
        (event.snapshot.value as Map<dynamic, dynamic>).forEach((key, status) {
          if (status == 'accepted') ids.add(key.toString());
        });
        return ids;
      });

  @override
  Stream<TabuChat?> singleChatStream(String chatId) =>
      _db.ref('Chats/$chatId').onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
        try {
          return TabuChat.fromMap(
              chatId, event.snapshot.value as Map<dynamic, dynamic>);
        } catch (_) {
          return null;
        }
      });

  // ── helpers ───────────────────────────────────────────────────────────────
  List<ChatMessage> _parseMsgs(DataSnapshot snap) {
    if (!snap.exists || snap.value is! Map) return [];
    final msgs = <ChatMessage>[];
    (snap.value as Map<dynamic, dynamic>).forEach((key, val) {
      if (key == '_placeholder') return;
      if (val is Map) {
        try { msgs.add(ChatMessage.fromMap(key.toString(), val)); } catch (_) {}
      }
    });
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return msgs;
  }
}

