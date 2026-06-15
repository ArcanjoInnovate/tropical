// features/profile/controller/public_profile_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../data/models/profile_user_model.dart';
import '../data/services/profile_service.dart';
import 'package:tclub/features/post/data/models/post_model.dart';
import 'package:tclub/features/story/data/models/story_model.dart';
import 'package:tclub/features/gallery/data/models/gallery_item_model.dart';
import 'package:tclub/features/chat/data/models/chat_request_model.dart';
import 'package:tclub/features/post/data/services/post_service.dart';
import 'package:tclub/features/story/data/services/story_service.dart';
import 'package:tclub/features/gallery/data/services/gallery_service.dart';
import 'package:tclub/core/services/follow_service.dart';
import 'package:tclub/core/services/chat_request_service.dart';
import 'package:tclub/core/services/media/video_preload_service.dart';
import 'package:tclub/core/services/user_data_notifier.dart';

const int _kPageSize = 15;

class PublicProfileController extends ChangeNotifier {
  PublicProfileController({required this.targetUid});

  final String targetUid;

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get isMe => targetUid == myUid;

  // ── Usuário ────────────────────────────────────────────────────────────────
  ProfileUserModel? user;
  bool loadingUser = true;

  // ── Posts ──────────────────────────────────────────────────────────────────
  List<PostModel> posts = [];
  bool loadingPosts = true;
  bool loadingMorePosts = false;
  bool hasMorePosts = true;
  DateTime? postsCursor;

  // ── Stories ────────────────────────────────────────────────────────────────
  List<StoryModel> stories = [];
  bool hasUnviewedStory = false;
  bool loadingStories = true;

  // ── Follow / VIP ──────────────────────────────────────────────────────────
  bool following = false;
  bool loadingFollow = false;
  bool vip = false;
  bool loadingVip = false;

  // ── Chat ───────────────────────────────────────────────────────────────────
  ChatRequest? chatRequest;
  bool loadingChat = false;

  // ── Galeria ────────────────────────────────────────────────────────────────
  List<GalleryItem> galleryItems = [];
  bool loadingGallery = true;
  bool loadingMoreGallery = false;
  bool hasGallery = false;
  bool hasMoreGallery = true;
  DateTime? galleryCursor;

  // ── Tab ────────────────────────────────────────────────────────────────────
  int tabIndex = 0;

  final _service = ProfileService.instance;

  // ── Chat helpers ──────────────────────────────────────────────────────────
  String? get requestStatus => chatRequest?.status;
  bool get isPending => requestStatus == 'pending';
  bool get isAccepted => requestStatus == 'accepted';
  bool get iSent => chatRequest?.fromUid == myUid;
  bool get iReceived => chatRequest?.toUid == myUid;

  // ════════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    await Future.wait([
      _loadUser(),
      _loadPosts(),
      _loadStories(),
      _loadGallery(),
      if (!isMe) ...[
        _checkFollowing(),
        _checkVip(),
        _checkChatRequest(),
      ],
    ]);
  }

  // ── Carregamento ───────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    loadingUser = true;
    notifyListeners();
    try {
      user = isMe
          ? await _service.loadFullProfile(targetUid)
          : await _service.loadPublicProfile(targetUid);
    } finally {
      loadingUser = false;
      notifyListeners();
    }
  }

  Future<void> _loadPosts() async {
    loadingPosts = true;
    hasMorePosts = true;
    postsCursor = null;
    notifyListeners();
    try {
      final result = await PostService.instance
          .fetchPostsByUser(targetUid, limit: _kPageSize);
      posts = result;
      hasMorePosts = result.length >= _kPageSize;
      postsCursor = result.isNotEmpty ? result.last.createdAt : null;
      _preloadPostVideos(result);
    } finally {
      loadingPosts = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePosts() async {
    if (loadingMorePosts || !hasMorePosts || postsCursor == null) return;
    loadingMorePosts = true;
    notifyListeners();
    try {
      final mais = await PostService.instance.fetchPostsByUser(
        targetUid,
        limit: _kPageSize,
        startAfter: postsCursor,
      );
      posts = [...posts, ...mais];
      hasMorePosts = mais.length >= _kPageSize;
      if (mais.isNotEmpty) postsCursor = mais.last.createdAt;
      _preloadPostVideos(mais);
    } finally {
      loadingMorePosts = false;
      notifyListeners();
    }
  }

  Future<void> _loadStories() async {
    loadingStories = true;
    notifyListeners();
    try {
      final allStories =
          await StoryService.instance.fetchStoriesByUser(targetUid);

      bool iFollow = false;
      bool imVip = false;

      if (!isMe) {
        final followSnap = await FirebaseDatabase.instance
            .ref('Users/$myUid/following/$targetUid')
            .get();
        iFollow = followSnap.exists && followSnap.value == true;

        final vipSnap = await FirebaseDatabase.instance
            .ref('Users/$targetUid/vip_friends/$myUid')
            .get();
        imVip = vipSnap.exists && vipSnap.value == true;
      }

      final visible = allStories.where((s) {
        if (isMe) return true;
        switch (s.visibilidade) {
          case 'publico':
            return true;
          case 'seguidores':
            return iFollow;
          case 'vip':
            return imVip;
          default:
            return true;
        }
      }).toList();

      bool unviewed = false;
      for (final s in visible) {
        final seen = await StoryService.instance.hasViewed(s.id, myUid);
        if (!seen) {
          unviewed = true;
          break;
        }
      }

      stories = visible;
      hasUnviewedStory = unviewed;
    } finally {
      loadingStories = false;
      notifyListeners();
    }
  }

  Future<void> refreshStories() => _loadStories();

  Future<void> _loadGallery() async {
    loadingGallery = true;
    hasMoreGallery = true;
    galleryCursor = null;
    notifyListeners();
    try {
      final items = await GalleryService.instance
          .fetchItems(targetUid, limit: _kPageSize);
      _evictGalleryPreloads();
      galleryItems = items;
      hasGallery = items.isNotEmpty;
      hasMoreGallery = items.length >= _kPageSize;
      galleryCursor = items.isNotEmpty ? items.last.createdAt : null;
      _preloadGalleryVideos(items);
    } finally {
      loadingGallery = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreGallery() async {
    if (loadingMoreGallery || !hasMoreGallery || galleryCursor == null) return;
    loadingMoreGallery = true;
    notifyListeners();
    try {
      final mais = await GalleryService.instance.fetchItems(
        targetUid,
        limit: _kPageSize,
        startAfter: galleryCursor,
      );
      galleryItems = [...galleryItems, ...mais];
      hasGallery = galleryItems.isNotEmpty;
      hasMoreGallery = mais.length >= _kPageSize;
      if (mais.isNotEmpty) galleryCursor = mais.last.createdAt;
      _preloadGalleryVideos(mais);
    } finally {
      loadingMoreGallery = false;
      notifyListeners();
    }
  }

  // ── Follow / VIP ──────────────────────────────────────────────────────────

  Future<void> _checkFollowing() async {
    if (myUid.isEmpty) return;
    following = await FollowService.instance.isSeguindo(myUid, targetUid);
    notifyListeners();
  }

  Future<void> _checkVip() async {
    if (myUid.isEmpty) return;
    vip = await FollowService.instance.isVip(myUid, targetUid);
    notifyListeners();
  }

  Future<void> toggleFollow() async {
    if (loadingFollow || myUid.isEmpty) return;
    loadingFollow = true;
    notifyListeners();
    try {
      final novo = await FollowService.instance.toggle(myUid, targetUid);
      following = novo;
      if (user != null) {
        final delta = novo ? 1 : -1;
        user = user!.copyWith(
          followers: (user!.followers + delta).clamp(0, 999999),
        );
      }
      if (!novo) vip = false;
    } finally {
      loadingFollow = false;
      notifyListeners();
    }
  }

  Future<void> toggleVip() async {
    if (loadingVip || myUid.isEmpty) return;
    if (!following && !vip) return; // precisa seguir primeiro
    loadingVip = true;
    notifyListeners();
    try {
      vip = await FollowService.instance.toggleVip(myUid, targetUid);
    } finally {
      loadingVip = false;
      notifyListeners();
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<void> _checkChatRequest() async {
    if (myUid.isEmpty) return;
    try {
      chatRequest =
          await ChatRequestService().getRequestBetween(myUid, targetUid);
    } catch (_) {
      chatRequest = null;
    }
    notifyListeners();
  }

  Future<String?> sendOrHandleChat() async {
    if (loadingChat || myUid.isEmpty) return null;

    if (isAccepted) return 'navigate_chat';

    if (isPending && iReceived) {
      loadingChat = true;
      notifyListeners();
      try {
        await ChatRequestService()
            .acceptRequest(chatRequest!.id, myUid)
            .timeout(const Duration(seconds: 10));
        await _checkChatRequest();
        if (isAccepted) return 'navigate_chat';
      } on TimeoutException {
        return 'timeout';
      } catch (_) {
        return 'error';
      } finally {
        loadingChat = false;
        notifyListeners();
      }
    }

    if (isPending && iSent) return 'already_sent';

    loadingChat = true;
    notifyListeners();
    try {
      final myName = UserDataNotifier.instance.name;
      final myAvatar = UserDataNotifier.instance.avatar;
      final result = await ChatRequestService()
          .sendRequest(
            fromUid: myUid,
            toUid: targetUid,
            fromName: myName,
            fromAvatar: myAvatar,
          )
          .timeout(const Duration(seconds: 10));

      if (result == 'sent') {
        chatRequest = ChatRequest(
          id: ChatRequestService.buildKey(myUid, targetUid),
          fromUid: myUid,
          toUid: targetUid,
          fromName: myName,
          fromAvatar: myAvatar,
          status: 'pending',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          seen: false,
        );
        notifyListeners();
      } else if (result == 'accepted') {
        await _checkChatRequest();
        return 'navigate_chat';
      }
      return result;
    } on TimeoutException {
      return 'timeout';
    } catch (_) {
      return 'error';
    } finally {
      loadingChat = false;
      notifyListeners();
    }
  }

  // ── Tab ────────────────────────────────────────────────────────────────────

  void setTabIndex(int index) {
    tabIndex = index;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _preloadPostVideos(List<PostModel> list) {
    for (final p in list) {
      if (p.tipo == 'video' && p.mediaUrl != null) {
        VideoPreloadService.instance.preload(p.id, p.mediaUrl!);
      }
    }
  }

  void _preloadGalleryVideos(List<GalleryItem> list) {
    for (final item in list) {
      if (item.type == 'video') {
        VideoPreloadService.instance.preload(item.id, item.mediaUrl);
      }
    }
  }

  void _evictGalleryPreloads() {
    for (final item in galleryItems) {
      if (item.type == 'video') {
        VideoPreloadService.instance.evict(item.id);
      }
    }
  }

  @override
  void dispose() {
    _evictGalleryPreloads();
    for (final p in posts) {
      if (p.tipo == 'video') VideoPreloadService.instance.evict(p.id);
    }
    super.dispose();
  }
}

