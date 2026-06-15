// lib/services/services_app/post_service.dart
//
// NÍVEL 2.15 — CORREÇÃO DE LIKES E COMENTÁRIOS:
//
//   Problema: as regras do Firebase têm ".write": false em
//   Posts/post/{postId}/likes e comment_count, e liked_by caía em $other.
//   O cliente não pode escrever nesses campos diretamente.
//
//   Solução:
//     • liked_by → adicionado nas regras com .write: auth.uid === $likerUid
//     • likes    → atualizado pela CF notificarNovaCurtida / onLikeRemoved
//     • comment_count → atualizado pela CF notificarNovoComentario / onCommentRemoved
//
//   No Dart: removidas as escritas diretas em likes e comment_count.
//   As CFs fazem transaction() garantindo consistência mesmo com concorrência.
//
// FILTRO DE VISIBILIDADE (nível 2.14):
//   "seguidores" → lê Users/{ownerUid}/followers/{myUid} por dono único
//   "vip"        → lê Users/{ownerUid}/vip_friends/{myUid} por dono único
//   Ambos respeitam as regras (.read: auth.uid === $followerUid / $friendUid).
//
// ADMIN DELETE (nível 2.16):
//   deleteComment aceita flag isAdmin. Quando true, deleta via CF
//   adminDeleteComment para contornar as regras que só permitem ao dono do
//   comentário remover o próprio nó.
//
// FILTRO DE BLOQUEADOS (nível 2.17):
//   fetchComments recebe myUid e filtra comentários de/para usuários bloqueados.
//   Bidirecional: consulta Users/{myUid}/blocked_users e blocked_by/{myUid}.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/feed/data/services/cloudinary_cleanup_helper.dart';
import 'package:tclub/features/post/data/models/comment_model.dart';
import 'package:tclub/features/post/data/models/post_model.dart';

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final _db = FirebaseDatabase.instance;

  // ── Referências principais ────────────────────────────────────────────────

  DatabaseReference get _postsRef => _db.ref('Posts/post');
  DatabaseReference _postRef(String id) => _postsRef.child(id);

  DatabaseReference _likedByRef(String postId) =>
      _postRef(postId).child('liked_by');

  DatabaseReference _postLikesRef(String postId, String userId) =>
      _db.ref('PostLikes/$postId/$userId');

  DatabaseReference _commentsRootRef(String postId) =>
      _db.ref('Comments/$postId');

  // ══════════════════════════════════════════════════════════════════════════
  //  CRIAR POST
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createPost({
    required String userId,
    required String userName,
    String? userAvatar,
    required String titulo,
    String? descricao,
    required String tipo,
    required String visibilidade,
    String? mediaUrl,
    String? thumbUrl,
    String? emoji,
    int? videoDuration,
  }) async {
    final ref = _postsRef.push();
    final id = ref.key!;

    final post = PostModel(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      titulo: titulo,
      descricao: descricao,
      tipo: tipo,
      visibilidade: visibilidade,
      mediaUrl: mediaUrl,
      thumbUrl: thumbUrl,
      emoji: emoji,
      videoDuration: videoDuration,
      createdAt: DateTime.now(),
    );

    await ref.set(post.toMap());
    return id;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTRO DE VISIBILIDADE
  // ══════════════════════════════════════════════════════════════════════════

  bool _podeVerPost({
    required PostModel post,
    required String myUid,
    required _VisibilityIndex index,
  }) {
    if (post.userId == myUid) return true;

    switch (post.visibilidade) {
      case 'publico':
        return true;
      case 'seguidores':
        return index.seguidoresPosts.contains(post.id);
      case 'vip':
        return index.vipPosts.contains(post.id);
      default:
        return true;
    }
  }

  Future<_VisibilityIndex> _buildVisibilityIndex({
    required List<PostModel> posts,
    required String myUid,
  }) async {
    if (myUid.isEmpty) return _VisibilityIndex.empty();

    final postsSeguidores = posts
        .where((p) => p.userId != myUid && p.visibilidade == 'seguidores')
        .toList();
    final postsVip = posts
        .where((p) => p.userId != myUid && p.visibilidade == 'vip')
        .toList();

    if (postsSeguidores.isEmpty && postsVip.isEmpty) {
      return _VisibilityIndex.empty();
    }

    final Set<String> seguidoresPosts = {};
    if (postsSeguidores.isNotEmpty) {
      final Map<String, List<String>> postsPorDonoSeg = {};
      for (final p in postsSeguidores) {
        postsPorDonoSeg.putIfAbsent(p.userId, () => []).add(p.id);
      }

      await Future.wait(
        postsPorDonoSeg.entries.map((entry) async {
          final ownerUid = entry.key;
          final postIds  = entry.value;
          try {
            final snap = await _db
                .ref('Users/$ownerUid/followers/$myUid')
                .get();
            if (snap.exists && snap.value == true) {
              seguidoresPosts.addAll(postIds);
            }
          } catch (e) {
            debugPrint(
                '[PostService] erro ao ler followers/$ownerUid/$myUid: $e');
          }
        }),
      );
    }

    final Set<String> vipPosts = {};
    if (postsVip.isNotEmpty) {
      final Map<String, List<String>> postsPorDono = {};
      for (final p in postsVip) {
        postsPorDono.putIfAbsent(p.userId, () => []).add(p.id);
      }

      await Future.wait(
        postsPorDono.entries.map((entry) async {
          final ownerUid = entry.key;
          final postIds  = entry.value;
          try {
            final snap = await _db
                .ref('Users/$ownerUid/vip_friends/$myUid')
                .get();
            if (snap.exists && snap.value == true) {
              vipPosts.addAll(postIds);
            }
          } catch (e) {
            debugPrint(
                '[PostService] erro ao ler vip_friends/$ownerUid/$myUid: $e');
          }
        }),
      );
    }

    return _VisibilityIndex(
      seguidoresPosts: seguidoresPosts,
      vipPosts: vipPosts,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BLOQUEADOS — helper bidirecional
  // ══════════════════════════════════════════════════════════════════════════

  /// Retorna o conjunto de UIDs bloqueados pelo usuário [myUid] e também
  /// os UIDs que bloquearam [myUid] (bidirecional).
  ///
  /// Leituras permitidas pelas regras:
  ///   • Users/{myUid}/blocked_users  → .write: auth.uid === $uid  (myUid pode ler)
  ///   • blocked_by/{myUid}           → .read:  auth.uid === $uid  (myUid pode ler)
  Future<Set<String>> _fetchBlockedUids(String myUid) async {
    if (myUid.isEmpty) return {};

    try {
      final results = await Future.wait([
        _db.ref('Users/$myUid/blocked_users').get(),
        _db.ref('blocked_by/$myUid').get(),
      ]);

      final blocked = <String>{};
      for (final snap in results) {
        if (!snap.exists || snap.value == null) continue;
        final raw = Map<dynamic, dynamic>.from(snap.value as Map);
        for (final entry in raw.entries) {
          if (entry.value == true) blocked.add(entry.key as String);
        }
      }
      return blocked;
    } catch (e) {
      debugPrint('[PostService] erro ao ler blocked_uids de $myUid: $e');
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LER — COM PAGINAÇÃO REAL (server-side) + FILTRO DE VISIBILIDADE
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<PostModel>> fetchPosts({
    required String myUid,
    int limit = 10,
    DateTime? startAfter,
  }) async {
    Query query = _postsRef.orderByChild('created_at');

    if (startAfter != null) {
      query = query
          .endBefore(startAfter.millisecondsSinceEpoch)
          .limitToLast(limit * 3);
    } else {
      query = query.limitToLast(limit * 3);
    }

    final snap = await query.get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final allPosts = <PostModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        if (data['user_id'] == null || data['created_at'] == null) continue;
        allPosts.add(PostModel.fromMap(entry.key as String, data));
      } catch (_) {
        continue;
      }
    }

    allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final index = await _buildVisibilityIndex(
      posts: allPosts,
      myUid: myUid,
    );

    final filtered = <PostModel>[];
    for (final post in allPosts) {
      if (_podeVerPost(post: post, myUid: myUid, index: index)) {
        filtered.add(post);
        if (filtered.length >= limit) break;
      }
    }

    return filtered;
  }

  Future<List<PostModel>> fetchPostsByUser(
    String userId, {
    int limit = 3,
    DateTime? startAfter,
  }) async {
    Query query = _postsRef.orderByChild('user_id').equalTo(userId);

    final snap = await query.get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PostModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        if (data['created_at'] == null) continue;

        final post = PostModel.fromMap(entry.key as String, data);
        if (startAfter != null && !post.createdAt.isBefore(startAfter)) {
          continue;
        }
        list.add(post);
      } catch (e) {
        debugPrint('[PostService] parse error: $e');
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  Future<PostModel?> fetchPostById(String postId) async {
    final snap = await _postRef(postId).get();
    if (!snap.exists || snap.value == null) return null;
    return PostModel.fromMap(
      postId,
      Map<dynamic, dynamic>.from(snap.value as Map),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM TEMPO REAL
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<PostModel>> streamPosts({int limit = 30}) {
    return _postsRef
        .orderByChild('created_at')
        .limitToLast(limit)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <PostModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        try {
          final data = Map<dynamic, dynamic>.from(entry.value as Map);
          if (data['user_id'] == null || data['created_at'] == null) continue;
          list.add(PostModel.fromMap(entry.key as String, data));
        } catch (_) {
          continue;
        }
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CURTIR / DESCURTIR
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> toggleLike(String postId, String userId) async {
    final likedByRef  = _likedByRef(postId).child(userId);
    final postLikeRef = _postLikesRef(postId, userId);

    final snap     = await likedByRef.get();
    final jaLikado = snap.exists && snap.value == true;

    if (jaLikado) {
      await Future.wait([
        postLikeRef.remove(),
        likedByRef.remove(),
      ]);
      return false;
    } else {
      await Future.wait([
        likedByRef.set(true),
        postLikeRef.set(true),
      ]);
      return true;
    }
  }

  Future<bool> isLikedBy(String postId, String userId) async {
    final snap = await _likedByRef(postId).child(userId).get();
    return snap.exists && snap.value == true;
  }

  Stream<bool> streamIsLiked(String postId, String userId) {
    return _likedByRef(postId).child(userId).onValue.map(
          (e) => e.snapshot.exists && e.snapshot.value == true,
        );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMENTÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userAvatar,
    required String texto,
  }) async {
    final ref = _commentsRootRef(postId).push();
    final id  = ref.key!;

    final comment = CommentModel(
      id: id,
      postId: postId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      texto: texto,
      createdAt: DateTime.now(),
    );

    await ref.set(comment.toMap());
    return comment;
  }

  /// Busca comentários do post [postId], filtrando comentários de/para
  /// usuários bloqueados quando [myUid] é informado.
  Future<List<CommentModel>> fetchComments(
    String postId, {
    String myUid = '',
  }) async {
    final snap = await _commentsRootRef(postId).get();

    if (!snap.exists || snap.value == null) return [];

    final raw = Map<String, dynamic>.from(snap.value as Map);

    final legacyUids = <String>{};
    for (final entry in raw.entries) {
      final data    = Map<dynamic, dynamic>.from(entry.value as Map);
      final hasName = (data['user_name'] as String?)?.isNotEmpty == true;
      if (!hasName) {
        final uid = data['user_id'] as String? ?? '';
        if (uid.isNotEmpty) legacyUids.add(uid);
      }
    }

    final Map<String, _ResolvedUser> userCache = {};

    if (legacyUids.isNotEmpty) {
      final futures = legacyUids.map((uid) async {
        try {
          final userSnap =
              await FirebaseDatabase.instance.ref('UsersPublic/$uid').get();
          if (!userSnap.exists || userSnap.value == null) {
            userCache[uid] = const _ResolvedUser(exists: false);
          } else {
            final u = Map<dynamic, dynamic>.from(userSnap.value as Map);
            userCache[uid] = _ResolvedUser(
              exists: true,
              name:   u['name'] as String? ?? u['Name'] as String? ?? '',
              avatar: u['avatar'] as String? ?? '',
            );
          }
        } catch (_) {
          userCache[uid] = const _ResolvedUser(exists: true);
        }
      });
      await Future.wait(futures);
    }

    // Carrega bloqueados em paralelo enquanto resolve usuários legados
    final blocked = await _fetchBlockedUids(myUid);

    final list = <CommentModel>[];
    for (final entry in raw.entries) {
      final commentId   = entry.key;
      final data        = Map<dynamic, dynamic>.from(entry.value as Map);
      final uid         = data['user_id'] as String? ?? '';

      // Ignora comentários de/para usuários bloqueados
      if (blocked.contains(uid)) continue;

      final savedName   = data['user_name'] as String?;
      final savedAvatar = data['user_avatar'] as String?;
      final hasName     = savedName?.isNotEmpty == true;

      bool    deleted        = false;
      String  resolvedName   = savedName ?? '';
      String? resolvedAvatar = savedAvatar;

      if (!hasName && uid.isNotEmpty) {
        final resolved = userCache[uid];
        if (resolved != null) {
          deleted        = !resolved.exists;
          resolvedName   = resolved.name ?? uid.substring(0, 6);
          resolvedAvatar =
              resolved.avatar?.isNotEmpty == true ? resolved.avatar : null;
        }
      }

      list.add(CommentModel.fromMap(
        commentId,
        data,
        resolvedName:   resolvedName,
        resolvedAvatar: resolvedAvatar,
        userDeleted:    deleted,
      ));
    }

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Stream<List<CommentModel>> streamComments(String postId) {
    return _commentsRootRef(postId).onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final raw  = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <CommentModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        try {
          final data = Map<dynamic, dynamic>.from(entry.value as Map);
          if (data['user_id'] == null || data['created_at'] == null) continue;
          list.add(CommentModel.fromMap(entry.key as String, data));
        } catch (_) {
          continue;
        }
      }

      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  /// Remove um comentário.
  ///
  /// • [isAdmin] = false (padrão): remove diretamente via RTDB.
  ///   Funciona porque as regras permitem ao dono do comentário deletar o próprio nó.
  ///
  /// • [isAdmin] = true: deleta via Cloud Function `adminDeleteComment`.
  ///   Necessário porque as regras bloqueiam escrita de terceiros no nó do comentário,
  ///   então apenas uma CF com privilégio de Admin SDK consegue fazer a remoção.
  Future<void> deleteComment(
    String postId,
    String commentId, {
    bool isAdmin = false,
  }) async {
    if (isAdmin) {
      try {
        final callable = FirebaseFunctions.instance
            .httpsCallable('adminDeleteComment');
        await callable.call<Map<String, dynamic>>({
          'postId': postId,
          'commentId': commentId,
        });
        debugPrint(
            '✅ [deleteComment] Comentário $commentId deletado pelo admin via CF');
      } on FirebaseFunctionsException catch (e) {
        debugPrint(
            '❌ [deleteComment] CF error: [${e.code}] ${e.message}');
        rethrow;
      }
    } else {
      await _commentsRootRef(postId).child(commentId).remove();
    }
    // comment_count decrementado pela CF onCommentRemoved
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETAR POST
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deletePost(String postId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('deletePostComplete');
      final result = await callable.call<Map<String, dynamic>>({
        'postId': postId,
      });

      final data         = result.data;
      final mediaUrl     = data['mediaUrl'] as String?;
      final thumbUrl     = data['thumbUrl'] as String?;
      final resourceType = data['resourceType'] as String? ?? 'image';

      await CloudinaryCleanupHelper.instance.deleteAll([
        (mediaUrl, resourceType),
        (thumbUrl, 'image'),
      ]);

      debugPrint('✅ [deletePost] Post $postId deletado com sucesso');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [deletePost] CF error: [${e.code}] ${e.message}');
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _VisibilityIndex {
  final Set<String> seguidoresPosts;
  final Set<String> vipPosts;

  const _VisibilityIndex({
    required this.seguidoresPosts,
    required this.vipPosts,
  });

  factory _VisibilityIndex.empty() => const _VisibilityIndex(
        seguidoresPosts: {},
        vipPosts: {},
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _ResolvedUser {
  final bool exists;
  final String? name;
  final String? avatar;
  const _ResolvedUser({required this.exists, this.name, this.avatar});
}

