// lib/services/services_app/follow_service.dart
//
// OTIMIZAÇÃO NÍVEL 1:
//   • streamFollowersCount() — agora lê do campo atômico
//     Users/{userId}/followers_count (int) mantido pela CF updateFollowersCount,
//     em vez de fazer listener no nó inteiro Users/{userId}/followers
//     e contar .length do Map a cada evento.
//
//   • streamFollowingCount() — mesmo padrão, lê Users/{userId}/following_count.
//
//   • getFollowersCount() e getFollowingCount() — agora leem o campo atômico
//     quando disponível, com fallback para contagem do Map.
//
//   Requer: CF updateFollowersCount deployada (triggers em Followers/ e Following/).
//
// NOTIFICAÇÕES:
//   Novo seguidor → CF trigger em Followers/{followedUid}/{followerUid}
//   Nova festa    → CF trigger em Festas/{festaId} lê Followers/{creatorUid}
//   Disparadas automaticamente. Nenhuma chamada manual ao
//   NotificationService é necessária neste arquivo.
//
// Estrutura no RTDB:
//   Users/{meuUid}/following/{userId}:  true  → quem eu sigo  (estado local)
//   Users/{userId}/followers/{meuUid}:  true  → quem me segue (estado local)
//   Followers/{userId}/{meuUid}:        true  → dispara CF de seguidor
//   Users/{meuUid}/vip_friends/{userId}: true → amigos VIP
//
// Paginação:
//   Todas as listas de UIDs suportam cursor via [startAfterKey].
//   Tamanho padrão de página: [pageSize] = 10.

import 'package:firebase_database/firebase_database.dart';

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  final _db = FirebaseDatabase.instance;

  static const int pageSize = 10;

  // ── Referências — estado local ────────────────────────────────────────────

  DatabaseReference _followingRef(String myUid, String targetUid) =>
      _db.ref('Users/$myUid/following/$targetUid');

  DatabaseReference _followerRef(String targetUid, String myUid) =>
      _db.ref('Users/$targetUid/followers/$myUid');

  DatabaseReference _followersRef(String userId) =>
      _db.ref('Users/$userId/followers');

  DatabaseReference _followingAllRef(String userId) =>
      _db.ref('Users/$userId/following');

  // ── Referência do trigger ─────────────────────────────────────────────────

  /// Caminho que dispara notificarNovoSeguidor (e é lido por notificarNovaFesta).
  DatabaseReference _cfFollowerRef(String targetUid, String myUid) =>
      _db.ref('Followers/$targetUid/$myUid');

  DatabaseReference _cfFollowersAllRef(String userId) =>
      _db.ref('Followers/$userId');

  // ── Referências — VIP ─────────────────────────────────────────────────────

  DatabaseReference _vipRef(String myUid, String targetUid) =>
      _db.ref('Users/$myUid/vip_friends/$targetUid');

  DatabaseReference _vipAllRef(String myUid) =>
      _db.ref('Users/$myUid/vip_friends');

  // ══════════════════════════════════════════════════════════════════════════
  //  CONSULTAS SIMPLES
  // ══════════════════════════════════════════════════════════════════════════

  /// Verifica se [myUid] já segue [targetUid].
  Future<bool> isSeguindo(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return false;
    try {
      final snap = await _followerRef(targetUid, myUid).get();
      return snap.exists && snap.value == true;
    } catch (_) {
      return false;
    }
  }

  /// Alias em inglês para compatibilidade com as telas.
  Future<bool> isFollowing(String myUid, String targetUid) =>
      isSeguindo(myUid, targetUid);

  /// Stream em tempo real: true se [myUid] segue [targetUid].
  Stream<bool> streamIsSeguindo(String myUid, String targetUid) {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) {
      return Stream.value(false);
    }
    return _followerRef(targetUid, myUid)
        .onValue
        .map((e) => e.snapshot.exists && e.snapshot.value == true);
  }

  /// Número total de seguidores de [userId].
  /// Tenta ler o campo atômico followers_count primeiro (mantido pela CF).
  /// Se não existir, faz fallback para contagem do Map.
  Future<int> getFollowersCount(String userId) async {
    try {
      // Tenta campo atômico primeiro
      final countSnap = await _db.ref('UsersPublic/$userId/followers_count').get();
      if (countSnap.exists && countSnap.value is int) {
        return countSnap.value as int;
      }
      // Fallback: conta o Map
      final snap = await _followersRef(userId).get();
      if (!snap.exists || snap.value == null) return 0;
      if (snap.value is Map) return (snap.value as Map).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Número total de pessoas que [userId] segue.
  Future<int> getFollowingCount(String userId) async {
    try {
      final countSnap = await _db.ref('UsersPublic/$userId/following_count').get();
      if (countSnap.exists && countSnap.value is int) {
        return countSnap.value as int;
      }
      final snap = await _followingAllRef(userId).get();
      if (!snap.exists || snap.value == null) return 0;
      if (snap.value is Map) return (snap.value as Map).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Número total de amigos VIP de [myUid].
  Future<int> getVipFriendsCount(String myUid) async {
    try {
      final snap = await _vipAllRef(myUid).get();
      if (!snap.exists || snap.value == null) return 0;
      if (snap.value is Map) return (snap.value as Map).length;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Stream do contador de seguidores em tempo real.
  ///
  /// ANTES: listener em Users/{userId}/followers (Map inteiro) → contava .length.
  ///        Com 1.000 seguidores = 1.000 entradas re-enviadas a cada follow/unfollow.
  ///
  /// AGORA: listener em Users/{userId}/followers_count (campo int atômico).
  ///        Mantido pela CF updateFollowersCount.
  ///        Se o campo não existir (CF não deployada), faz fallback para o Map.
  Stream<int> streamFollowersCount(String userId) {
    final countRef = _db.ref('UsersPublic/$userId/followers_count');

    return countRef.onValue.map((e) {
      if (e.snapshot.exists && e.snapshot.value is int) {
        return e.snapshot.value as int;
      }
      return 0;
    });
  }

  /// Stream do contador de seguindo em tempo real.
  Stream<int> streamFollowingCount(String userId) {
    final countRef = _db.ref('UsersPublic/$userId/following_count');

    return countRef.onValue.map((e) {
      if (e.snapshot.exists && e.snapshot.value is int) {
        return e.snapshot.value as int;
      }
      return 0;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MUTAÇÕES DE SEGUIR
  //
  //  Escreve em TRÊS caminhos ao seguir:
  //    1. Users/{myUid}/following/{targetUid}  → estado local (quem eu sigo)
  //    2. Users/{targetUid}/followers/{myUid}  → estado local (quem me segue)
  //    3. Followers/{targetUid}/{myUid}         → dispara CF notificarNovoSeguidor
  //                                               e é lido por notificarNovaFesta
  // ══════════════════════════════════════════════════════════════════════════

  /// [myUid] passa a seguir [targetUid].
  Future<void> seguir(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return;
    await Future.wait([
      _followingRef(myUid, targetUid).set(true),
      _followerRef(targetUid, myUid).set(true),
      // Escrever em Followers/ dispara a CF que cria a notificação
      _cfFollowerRef(targetUid, myUid).set(true),
    ]);
  }

  /// Alias em inglês — assinatura simplificada (myName/myAvatar não são mais
  /// necessários aqui; a CF busca os dados diretamente no RTDB).
  Future<void> followUser(String myUid, String targetUid) =>
      seguir(myUid, targetUid);

  /// [myUid] deixa de seguir [targetUid].
  Future<void> deixarDeSeguir(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await Future.wait([
      _followingRef(myUid, targetUid).remove(),
      _followerRef(targetUid, myUid).remove(),
      _cfFollowerRef(targetUid, myUid).remove(),
      _db.ref('Users/$myUid/vip_friends/$targetUid').remove(),
    ]);
  }

  /// Alias em inglês.
  Future<void> unfollowUser(String myUid, String targetUid) =>
      deixarDeSeguir(myUid, targetUid);

  /// Toggle: segue se não seguia, deixa de seguir se seguia.
  Future<bool> toggle(String myUid, String targetUid) async {
    final jaSeguindo = await isSeguindo(myUid, targetUid);
    if (jaSeguindo) {
      await deixarDeSeguir(myUid, targetUid);
      return false;
    } else {
      await seguir(myUid, targetUid);
      return true;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LISTAS COMPLETAS (sem paginação — uso interno / contagem)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<String>> getFollowers(String userId) async {
    try {
      final snap = await _followersRef(userId).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Alias para compatibilidade com as telas.
  Future<List<String>?> getUserFollowers(String userId) =>
      getFollowers(userId);

  Future<List<String>> getFollowing(String userId) async {
    try {
      final snap = await _followingAllRef(userId).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LISTAS PAGINADAS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<String>> getFollowersPaginated(
    String userId, {
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      Query query = _followersRef(userId).orderByKey().limitToFirst(limit);
      if (startAfterKey != null && startAfterKey.isNotEmpty) {
        query = _followersRef(userId)
            .orderByKey()
            .startAfter(startAfterKey)
            .limitToFirst(limit);
      }
      final snap = await query.get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getFollowingPaginated(
    String userId, {
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      Query query = _followingAllRef(userId).orderByKey().limitToFirst(limit);
      if (startAfterKey != null && startAfterKey.isNotEmpty) {
        query = _followingAllRef(userId)
            .orderByKey()
            .startAfter(startAfterKey)
            .limitToFirst(limit);
      }
      final snap = await query.get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getVipFriendsPaginated(
    String myUid, {
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      Query query = _vipAllRef(myUid).orderByKey().limitToFirst(limit);
      if (startAfterKey != null && startAfterKey.isNotEmpty) {
        query = _vipAllRef(myUid)
            .orderByKey()
            .startAfter(startAfterKey)
            .limitToFirst(limit);
      }
      final snap = await query.get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AMIGOS VIP
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> isVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return false;
    try {
      final snap = await _vipRef(myUid, targetUid).get();
      return snap.exists && snap.value == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isVipFriend(String myUid, String targetUid) =>
      isVip(myUid, targetUid);

  Stream<bool> streamIsVip(String myUid, String targetUid) {
    if (myUid.isEmpty || targetUid.isEmpty) return Stream.value(false);
    return _vipRef(myUid, targetUid)
        .onValue
        .map((e) => e.snapshot.exists && e.snapshot.value == true);
  }

  /// Adiciona [targetUid] como amigo VIP de [myUid].
  /// Só funciona se [myUid] já segue [targetUid].
  Future<bool> adicionarVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty || myUid == targetUid) return false;
    final seguindo = await isSeguindo(myUid, targetUid);
    if (!seguindo) return false;
    await _vipRef(myUid, targetUid).set(true);
    return true;
  }

  Future<bool> addVipFriend(String myUid, String targetUid) =>
      adicionarVip(myUid, targetUid);

  Future<void> removerVip(String myUid, String targetUid) async {
    if (myUid.isEmpty || targetUid.isEmpty) return;
    await _vipRef(myUid, targetUid).remove();
  }

  Future<void> removeVipFriend(String myUid, String targetUid) =>
      removerVip(myUid, targetUid);

  Future<bool> toggleVip(String myUid, String targetUid) async {
    final jaVip = await isVip(myUid, targetUid);
    if (jaVip) {
      await removerVip(myUid, targetUid);
      return false;
    }
    return adicionarVip(myUid, targetUid);
  }

  Future<List<String>> getVipFriends(String myUid) async {
    try {
      final snap = await _vipAllRef(myUid).get();
      if (!snap.exists || snap.value is! Map) return [];
      return (snap.value as Map).keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>?> getUserVipFriends(String myUid) =>
      getVipFriends(myUid);
}