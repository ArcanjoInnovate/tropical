// lib/services/chat_request_service.dart
//
// ESTRATÉGIA DE PATH:
//   Chave da solicitação = uid menor + "_" + uid maior (mesma lógica do chatId)
//   Isso permite leitura direta sem queries que exigem .indexOn no Firebase.
//
// NÍVEL 3.0 — Escrita centralizada em Cloud Functions (callables).
//   sendRequest, acceptRequest e declineRequest agora chamam CFs em vez de
//   escrever diretamente no Firebase. O cliente só lê — nunca escreve em
//   ChatRequests, UserChatRequests ou Chats.

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/features/chat/data/models/chat_request_model.dart';

class ChatRequestService {
  static final ChatRequestService _i = ChatRequestService._();
  factory ChatRequestService() => _i;
  ChatRequestService._();

  final _db        = FirebaseDatabase.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // ─── Chave determinística (igual ao chatId) ───────────────────────────────
  static String buildKey(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENVIAR SOLICITAÇÃO — via CF
  // Retorna: 'sent' | 'exists' | 'accepted' | 'error'
  // ══════════════════════════════════════════════════════════════════════════
  Future<String> sendRequest({
    required String fromUid,
    required String toUid,
    required String fromName,
    required String fromAvatar,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('sendChatRequest')
          .call<Map<String, dynamic>>({
        'toUid':       toUid,
        'fromName':    fromName,
        'fromAvatar':  fromAvatar,
      });
      return result.data['result'] as String? ?? 'error';
    } on FirebaseFunctionsException catch (e) {
      // Se a solicitação já existe e foi aceita, navega direto
      if (e.code == 'already-exists') return 'accepted';
      return 'error';
    } catch (_) {
      return 'error';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACEITAR — via CF
  // Retorna chatId em caso de sucesso.
  // ══════════════════════════════════════════════════════════════════════════
  Future<String?> acceptRequest(String requestKey, String myUid) async {
    try {
      final result = await _functions
          .httpsCallable('acceptChatRequest')
          .call<Map<String, dynamic>>({
        'requestKey': requestKey,
      });
      return result.data['chatId'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECUSAR — via CF
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> declineRequest(String requestKey, String myUid) async {
    try {
      await _functions
          .httpsCallable('declineChatRequest')
          .call<Map<String, dynamic>>({
        'requestKey': requestKey,
      });
    } catch (_) {
      // Ignora — o status pode não ter mudado, mas não quebra a UI
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSULTA PONTUAL — leitura direta (permitida pelas regras)
  // ══════════════════════════════════════════════════════════════════════════
  Future<ChatRequest?> getRequestBetween(String uid1, String uid2) async {
    try {
      final key  = buildKey(uid1, uid2);
      final snap = await _db
          .ref('ChatRequests/$key')
          .get()
          .timeout(const Duration(seconds: 8));

      if (!snap.exists || snap.value is! Map) return null;
      final req = ChatRequest.fromMap(key, snap.value as Map<dynamic, dynamic>);
      return req.isDeclined ? null : req;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMS — leitura direta (permitida pelas regras)
  // ══════════════════════════════════════════════════════════════════════════
  Stream<List<ChatRequest>> pendingRequestsStream(String myUid) {
    return _db
        .ref('UserChatRequests/$myUid')
        .onValue
        .asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return <ChatRequest>[];
      }

      final keys = <String>[];
      (event.snapshot.value as Map<dynamic, dynamic>).forEach((key, status) {
        if (status == 'pending') keys.add(key.toString());
      });

      if (keys.isEmpty) return <ChatRequest>[];

      final futures = keys.map((key) => _db.ref('ChatRequests/$key').get());
      final snaps   = await Future.wait(futures);

      final list = <ChatRequest>[];
      for (final s in snaps) {
        if (s.exists && s.value is Map) {
          try {
            final req = ChatRequest.fromMap(
                s.key!, s.value as Map<dynamic, dynamic>);
            if (req.toUid == myUid && req.isPending) {
              list.add(req);
            }
          } catch (_) {}
        }
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<int> unseenCountStream(String myUid) {
    return pendingRequestsStream(myUid)
        .map((list) => list.where((r) => !r.seen).length);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MARK AS SEEN — leitura + escrita permitida pelas regras (seen é campo
  // que o destinatário pode atualizar via ChatRequests/$requestId)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> markAllAsSeen(String myUid) async {
    try {
      final snap = await _db.ref('UserChatRequests/$myUid').get();
      if (!snap.exists || snap.value is! Map) return;

      final updates = <String, dynamic>{};
      (snap.value as Map<dynamic, dynamic>).forEach((key, status) {
        if (status == 'pending') {
          updates['ChatRequests/$key/seen'] = true;
        }
      });

      if (updates.isNotEmpty) await _db.ref().update(updates);
    } catch (_) {}
  }
}