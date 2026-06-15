// lib/services/story_service.dart
//
// CORREÇÃO DE VISIBILIDADE (mesmo padrão do post_service.dart):
//
//   PROBLEMA ANTERIOR:
//     fetchStoriesForUser recebia followingIds vindos de
//     FollowService.getFollowing() — que lê Users/{myUid}/following inteiro
//     e é bloqueado por permission-denied (regra: só o dono lê).
//     Quando falhava silenciosamente, followingIds ficava vazio e todos
//     os stories de "seguidores" sumiam.
//
//   CORREÇÃO:
//     • "seguidores" → lê Users/{ownerUid}/followers/{myUid} por dono único
//       (regra permite: auth.uid === $followerUid) — mesmo padrão do post_service
//     • "vip"        → lê Users/{ownerUid}/vip_friends/{myUid} por dono único
//       (regra permite: auth.uid === $friendUid) — já era correto, mantido
//     • Ambos com try/catch individual: falha em um dono não derruba o resto
//     • fetchStoriesForUser agora recebe só myUid e faz as leituras internamente
//     • _carregarStories no home_screen simplifica: não precisa mais construir
//       followingIds/vipIds antes de chamar o service
//
//   OTIMIZAÇÕES MANTIDAS:
//     • fetchActiveStories usa orderByChild('expires_at').startAt(now)
//     • streamActiveStories com filtro server-side
//     • fetchStoriesByUser com orderByChild('user_id').equalTo(userId)
//     • Correção de avatar via UserAvatarService

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tclub/features/feed/data/services/cloudinary_cleanup_helper.dart';
import 'package:tclub/features/story/data/models/story_model.dart';
import 'package:tclub/core/services/user_avatar_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ÍNDICE DE VISIBILIDADE — calculado uma vez por chamada de fetchStoriesForUser
// ══════════════════════════════════════════════════════════════════════════════

class _VisibilityIndex {
  /// postIds de stories de "seguidores" que myUid pode ver
  final Set<String> seguidoresPosts;

  /// postIds de stories de "vip" que myUid pode ver
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

// ══════════════════════════════════════════════════════════════════════════════
//  STORY SERVICE  —  Firebase Realtime Database
// ══════════════════════════════════════════════════════════════════════════════

class StoryService {
  StoryService._();
  static final StoryService instance = StoryService._();

  final _db = FirebaseDatabase.instance;

  DatabaseReference get _storiesRef => _db.ref('Posts/story');
  DatabaseReference _storyRef(String id) => _storiesRef.child(id);
  DatabaseReference _viewsRef(String storyId) =>
      _storyRef(storyId).child('views');
  DatabaseReference _viewerRef(String storyId, String viewerId) =>
      _viewsRef(storyId).child(viewerId);

  // ══════════════════════════════════════════════════════════════════════════
  //  CRIAR STORY
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createStory({
    required String userId,
    required String userName,
    String? userAvatar,
    required String type,
    String? mediaUrl,
    String? thumbUrl,
    String? background,
    String? centralText,
    String? centralEmoji,
    String? textStyle,
    int? videoDuration,
    List<StoryOverlay> overlays = const [],
    String visibilidade = 'publico',
  }) async {
    final newRef = _storiesRef.push();
    final id = newRef.key!;

    final now = DateTime.now();
    final expires = now.add(const Duration(hours: 24));

    final currentAvatar =
        await UserAvatarService.instance.getAvatar(userId);
    final avatarToSave =
        currentAvatar.isNotEmpty ? currentAvatar : userAvatar;

    final story = StoryModel(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: avatarToSave,
      type: type,
      mediaUrl: mediaUrl,
      thumbUrl: thumbUrl,
      background: background,
      centralText: centralText,
      centralEmoji: centralEmoji,
      visibilidade: visibilidade,
      textStyle: textStyle,
      videoDuration: videoDuration,
      overlays: overlays,
      createdAt: now,
      expiresAt: expires,
    );

    await newRef.set(story.toMap());
    return id;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LER STORIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<StoryModel>> fetchActiveStories() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final snap = await _storiesRef
        .orderByChild('expires_at')
        .startAt(now)
        .get();

    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <StoryModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final id = entry.key as String;
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      list.add(StoryModel.fromMap(id, data));
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<StoryModel>> fetchStoriesByUser(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final snap = await _storiesRef
        .orderByChild('user_id')
        .equalTo(userId)
        .get();

    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <StoryModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final id = entry.key as String;
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      final exp = data['expires_at'] as int? ?? 0;
      if (exp > now) {
        list.add(StoryModel.fromMap(id, data));
      }
    }

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<StoryModel?> fetchStoryById(String storyId) async {
    final snap = await _storyRef(storyId).get();
    if (!snap.exists || snap.value == null) return null;
    return StoryModel.fromMap(
        storyId, Map<dynamic, dynamic>.from(snap.value as Map));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ÍNDICE DE VISIBILIDADE
  //
  //  Mesmo padrão do post_service:
  //    • seguidores → lê Users/{ownerUid}/followers/{myUid}  (permitido pela regra)
  //    • vip        → lê Users/{ownerUid}/vip_friends/{myUid} (permitido pela regra)
  //    • try/catch individual por dono: um erro não derruba os outros
  // ══════════════════════════════════════════════════════════════════════════

  Future<_VisibilityIndex> _buildVisibilityIndex({
    required List<StoryModel> stories,
    required String myUid,
  }) async {
    if (myUid.isEmpty) return _VisibilityIndex.empty();

    // Agrupa stories que precisam de verificação, por dono
    final ownerToSeguidoresStories = <String, List<String>>{};
    final ownerToVipStories = <String, List<String>>{};

    for (final story in stories) {
      if (story.userId == myUid) continue; // dono sempre vê

      if (story.visibilidade == 'seguidores') {
        ownerToSeguidoresStories
            .putIfAbsent(story.userId, () => [])
            .add(story.id);
      } else if (story.visibilidade == 'vip') {
        ownerToVipStories
            .putIfAbsent(story.userId, () => [])
            .add(story.id);
      }
    }

    final seguidoresPosts = <String>{};
    final vipPosts = <String>{};

    // ── seguidores: lê Users/{ownerUid}/followers/{myUid} ─────────────────
    // Regra: ".read": "auth != null && auth.uid === $followerUid"
    // myUid === $followerUid → permitido
    await Future.wait(
      ownerToSeguidoresStories.entries.map((entry) async {
        final ownerUid = entry.key;
        final storyIds = entry.value;
        try {
          final snap = await _db
              .ref('Users/$ownerUid/followers/$myUid')
              .get();
          if (snap.exists && snap.value == true) {
            seguidoresPosts.addAll(storyIds);
          }
        } catch (e) {
          debugPrint(
              '[StoryService] erro ao ler followers/$myUid de $ownerUid: $e');
          // Falha segura: story não aparece
        }
      }),
    );

    // ── vip: lê Users/{ownerUid}/vip_friends/{myUid} ──────────────────────
    // Regra: ".read": "auth != null && auth.uid === $friendUid"
    // myUid === $friendUid → permitido
    await Future.wait(
      ownerToVipStories.entries.map((entry) async {
        final ownerUid = entry.key;
        final storyIds = entry.value;
        try {
          final snap = await _db
              .ref('Users/$ownerUid/vip_friends/$myUid')
              .get();
          if (snap.exists && snap.value == true) {
            vipPosts.addAll(storyIds);
          }
        } catch (e) {
          debugPrint(
              '[StoryService] erro ao ler vip_friends/$myUid de $ownerUid: $e');
          // Falha segura: story não aparece
        }
      }),
    );

    return _VisibilityIndex(
      seguidoresPosts: seguidoresPosts,
      vipPosts: vipPosts,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FILTRO DE VISIBILIDADE
  // ══════════════════════════════════════════════════════════════════════════

  bool _podeVerStory({
    required StoryModel story,
    required String myUid,
    required _VisibilityIndex index,
  }) {
    if (story.userId == myUid) return true; // dono sempre vê

    switch (story.visibilidade) {
      case 'publico':
        return true;

      case 'seguidores':
        return index.seguidoresPosts.contains(story.id);

      case 'vip':
        return index.vipPosts.contains(story.id);

      default:
        // Visibilidade desconhecida ou null → trata como público
        return true;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM (tempo real)
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<StoryModel>> streamActiveStories() {
    final now = DateTime.now().millisecondsSinceEpoch;

    return _storiesRef
        .orderByChild('expires_at')
        .startAt(now)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final currentNow = DateTime.now().millisecondsSinceEpoch;
      final list = <StoryModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        final id = entry.key as String;
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        final exp = data['expires_at'] as int? ?? 0;
        if (exp > currentNow) list.add(StoryModel.fromMap(id, data));
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<StoryModel>> streamStoriesByUser(String userId) {
    return _storiesRef
        .orderByChild('user_id')
        .equalTo(userId)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];

      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final list = <StoryModel>[];

      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        final id = entry.key as String;
        final data = Map<dynamic, dynamic>.from(entry.value as Map);
        final exp = data['expires_at'] as int? ?? 0;
        if (exp > now) list.add(StoryModel.fromMap(id, data));
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VISUALIZAÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markAsViewed({
    required String storyId,
    required String viewerId,
    bool fullyWatched = false,
  }) async {
    final view = StoryView(
      viewerId: viewerId,
      seenAt: DateTime.now(),
      fullyWatched: fullyWatched,
    );
    await _viewerRef(storyId, viewerId).set(view.toMap());
  }

  Future<void> updateFullyWatched({
    required String storyId,
    required String viewerId,
  }) async {
    await _viewerRef(storyId, viewerId).update({'fully_watched': true});
  }

  Future<List<StoryView>> fetchViews(String storyId) async {
    final snap = await _viewsRef(storyId).get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = raw.values
        .whereType<Map>()
        .map((v) => StoryView.fromMap(v as Map))
        .toList();

    list.sort((a, b) => b.seenAt.compareTo(a.seenAt));
    return list;
  }

  Future<bool> hasViewed(String storyId, String viewerId) async {
    final snap = await _viewerRef(storyId, viewerId).get();
    return snap.exists;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETAR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteStory({required String storyId}) async {
    final snap = await _storyRef(storyId).get();

    String? mediaUrl;
    String? thumbUrl;
    String resourceType = 'image';

    if (snap.exists && snap.value != null) {
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      mediaUrl = map['media_url'] as String?;
      thumbUrl = map['thumb_url'] as String?;
      final type = map['type'] as String? ?? '';
      resourceType = type == 'video' ? 'video' : 'image';
    }

    await _db.ref('Posts/story/$storyId').remove();

    await CloudinaryCleanupHelper.instance.deleteAll([
      (mediaUrl, resourceType),
      (thumbUrl, 'image'),
    ]);
  }

  Future<int> purgeExpiredStories() async {
    final snap = await _storiesRef.get();
    if (!snap.exists || snap.value == null) return 0;

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanup = CloudinaryCleanupHelper.instance;
    int removed = 0;

    for (final entry in raw.entries) {
      final data = Map<dynamic, dynamic>.from(entry.value as Map);
      final exp = data['expires_at'] as int? ?? 0;
      if (exp <= now) {
        final mediaUrl = data['media_url'] as String?;
        final thumbUrl = data['thumb_url'] as String?;
        final type = data['type'] as String? ?? '';
        final resourceType = type == 'video' ? 'video' : 'image';

        await _storyRef(entry.key as String).remove();

        await cleanup.deleteAll([
          (mediaUrl, resourceType),
          (thumbUrl, 'image'),
        ]);

        removed++;
      }
    }

    return removed;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS DE AGRUPAMENTO
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, List<StoryModel>>> fetchStoriesGroupedByUser() async {
    final all = await fetchActiveStories();
    final map = <String, List<StoryModel>>{};
    for (final s in all) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }

  /// Busca os stories visíveis para [myUid], agrupados por autor.
  ///
  /// MUDANÇA: não recebe mais followingIds/vipIds — faz as verificações
  /// internamente via _buildVisibilityIndex, lendo os caminhos que as
  /// regras do Firebase permitem (followers/{myUid}, vip_friends/{myUid}).
  ///
  /// CORREÇÃO DE AVATAR: após agrupar, substitui o user_avatar de cada story
  /// pelo avatar atual do usuário (Users/{uid}/avatar).
  Future<Map<String, List<StoryModel>>> fetchStoriesForUser({
    required String myUid,
  }) async {
    if (myUid.isEmpty) return {};

    final all = await fetchActiveStories();
    if (all.isEmpty) return {};

    final index = await _buildVisibilityIndex(stories: all, myUid: myUid);

    final map = <String, List<StoryModel>>{};
    for (final story in all) {
      if (_podeVerStory(story: story, myUid: myUid, index: index)) {
        map.putIfAbsent(story.userId, () => []).add(story);
      }
    }

    // ── Corrige avatares desatualizados ──────────────────────────────────
    final avatarService = UserAvatarService.instance;
    for (final uid in map.keys) {
      final currentAvatar = await avatarService.getAvatar(uid);
      if (currentAvatar.isEmpty) continue;
      map[uid] = map[uid]!
          .map((story) => story.copyWith(userAvatar: currentAvatar))
          .toList();
    }

    return map;
  }

  Stream<Map<String, List<StoryModel>>> streamStoriesGroupedByUser() {
    return streamActiveStories().map((list) {
      final map = <String, List<StoryModel>>{};
      for (final s in list) {
        map.putIfAbsent(s.userId, () => []).add(s);
      }
      return map;
    });
  }
}

