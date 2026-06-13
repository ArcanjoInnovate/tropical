// lib/features/match/data/services/like_me_service.dart
//
// NÍVEL 3.0 — acceptLike movido para CF callable (acceptLike).
//   O cliente não escreve mais em Matchs/$uid/matched nem em Chats.
//   declineLike permanece no cliente (escreve apenas em paths permitidos).

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

class LikeMeService {
  static final LikeMeService _i = LikeMeService._();
  factory LikeMeService() => _i;
  LikeMeService._();

  final _db        = FirebaseDatabase.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM: lista de UIDs que curtiram [myUid]
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<String>> likeMeUidsStream(String myUid) {
    return _db.ref('Matchs/$myUid/like_me').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) {
        return <String>[];
      }
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.keys.cast<String>().toList();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CONTAGEM para badge
  // ══════════════════════════════════════════════════════════════════════════

  Stream<int> likeCountStream(String myUid) {
    return likeMeUidsStream(myUid).map((uids) => uids.length);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCAR DADOS DE UM USUÁRIO
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, String>> fetchUserBasicData(String uid) async {
    final snap = await _db.ref('UsersPublic/$uid').get();
    if (!snap.exists || snap.value is! Map) {
      return {'name': 'Usuário', 'avatar': ''};
    }
    final data = snap.value as Map<dynamic, dynamic>;
    return {
      'name':   data['name']   as String? ?? 'Usuário',
      'avatar': data['avatar'] as String? ?? '',
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERIFICAR SE FOI RECUSADO
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> hasBeenDislikedBy(String myUid, String targetUid) async {
    final snap = await _db
        .ref('Matchs/$myUid/dislikes_received/$targetUid')
        .get();
    return snap.exists;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RECUSAR LIKE — cliente escreve (paths permitidos pelas regras)
  //
  //  Paths escritos:
  //    Matchs/$myUid/like_me/$likerUid         ← remove (próprio uid)
  //    Matchs/$myUid/dislikes/$likerUid        ← próprio uid
  //    Matchs/$likerUid/dislikes_received/$myUid ← $myUid escreve no alheio (permitido)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> declineLike(String myUid, String likerUid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.ref().update({
      'Matchs/$myUid/like_me/$likerUid':                      null,
      'Matchs/$myUid/dislikes/$likerUid/created_at':          now,
      'Matchs/$likerUid/dislikes_received/$myUid/created_at': now,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ACEITAR LIKE — via CF callable
  //
  //  A CF escreve em:
  //    Matchs/$myUid/like_me/$likerUid    (remove)
  //    Matchs/$likerUid/like_me/$myUid   (remove)
  //    Matchs/$myUid/matched/$likerUid   (matched: .write false para cliente)
  //    Matchs/$likerUid/matched/$myUid   (matched: .write false para cliente)
  //    UserChatRequests/$myUid/$chatId
  //    UserChatRequests/$likerUid/$chatId
  //    Chats/$chatId/...                  (Chats raiz: .write false para cliente)
  //
  //  Retorna o chatId criado.
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> acceptLike(String myUid, String likerUid) async {
    try {
      final result = await _functions
          .httpsCallable('acceptLike')
          .call<Map<String, dynamic>>({
        'likerUid': likerUid,
      });
      return result.data['chatId'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception('acceptLike CF error: ${e.code} — ${e.message}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REMOVER LIKE (simples)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> removeLike(String myUid, String likerUid) async {
    await _db.ref('Matchs/$myUid/like_me/$likerUid').remove();
  }
}