// lib/features/profile/controller/profile_controller.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/profile_user_model.dart';
import '../data/services/profile_service.dart';
import 'package:tabuapp/features/post/data/models/post_model.dart';
import 'package:tabuapp/features/story/data/models/story_model.dart';
import 'package:tabuapp/features/gallery/data/models/gallery_item_model.dart';
import 'package:tabuapp/features/post/data/services/post_service.dart';
import 'package:tabuapp/features/story/data/services/story_service.dart';
import 'package:tabuapp/features/gallery/data/services/gallery_service.dart';
import 'package:tabuapp/core/services/media/video_preload_service.dart';
import 'package:tabuapp/features/admin/data/services/adm_service.dart';

const int _kPageSize = 15;

class ProfileController extends ChangeNotifier {
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
  bool loadingStories = true;

  // ── Follow ─────────────────────────────────────────────────────────────────
  List<String> followers = [];
  int followersCount = 0;
  bool loadingFollowers = true;

  // ── VIP ────────────────────────────────────────────────────────────────────
  List<String> vipFriends = [];
  bool loadingVip = true;

  // ── Galeria ────────────────────────────────────────────────────────────────
  List<GalleryItem> galleryItems = [];
  bool hasGallery = false;

  /// true quando Gallery/{uid}/created == true, independente de ter itens.
  bool galleryCreated = false;
  bool loadingGallery = true;
  bool loadingMoreGallery = false;
  bool hasMoreGallery = true;
  DateTime? galleryCursor;

  // ── Admin ──────────────────────────────────────────────────────────────────
  bool isAdmin = false;
  bool loadingAdmin = true;

  // ── Tab index ──────────────────────────────────────────────────────────────
  int tabIndex = 0;

  // ── FIX: flag para evitar notifyListeners após dispose ────────────────────
  bool _disposed = false;

  final _service = ProfileService.instance;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── FIX: notifyListeners seguro — ignora se já foi disposed ──────────────
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════════════
  Future<void> init(Map<String, dynamic> initialData) async {
    await Future.wait([
      _loadUser(),
      _loadPosts(),
      _loadStories(),
      _loadFollowers(),
      _loadVip(),
      _loadGallery(),
      _checkAdmin(),
    ]);
  }

  Future<void> refresh() async {
    await Future.wait([
      _loadUser(),
      _loadPosts(),
      _loadStories(),
      _loadFollowers(),
      _loadVip(),
      _loadGallery(),
    ]);
  }

  // ── Carregamento ───────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    loadingUser = true;
    notifyListeners();
    try {
      user = await _service.loadFullProfile(uid);
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
      final result =
          await PostService.instance.fetchPostsByUser(uid, limit: _kPageSize);
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
        uid,
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
      stories = await StoryService.instance.fetchStoriesByUser(uid);
    } finally {
      loadingStories = false;
      notifyListeners();
    }
  }

  Future<void> refreshStories() => _loadStories();

  Future<void> _loadFollowers() async {
    loadingFollowers = true;
    notifyListeners();
    try {
      // Usa o contador atômico da CF para exibição
      followersCount = await _service.fetchFollowersCount(uid);
      // Lista filtrada — só UIDs que ainda existem
      final raw = await _service.fetchFollowersList(uid);
      followers = await _service.filterExistingUsers(raw);
    } finally {
      loadingFollowers = false;
      notifyListeners();
    }
  }

  Future<void> _loadVip() async {
    loadingVip = true;
    notifyListeners();
    try {
      final raw = await _service.fetchVipFriends(uid);
      vipFriends = await _service.filterExistingUsers(raw);
    } finally {
      loadingVip = false;
      notifyListeners();
    }
  }

  Future<void> _loadGallery() async {
    loadingGallery = true;
    hasMoreGallery = true;
    galleryCursor = null;
    notifyListeners();
    try {
      _evictGalleryPreloads();
      galleryCreated = await GalleryService.instance.isGalleryCreated(uid);
      final items =
          await GalleryService.instance.fetchItems(uid, limit: _kPageSize);
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
        uid,
        limit: _kPageSize,
        startAfter: galleryCursor,
      );
      galleryItems = [...galleryItems, ...mais];
      hasGallery = galleryItems.isNotEmpty;
      galleryCreated = galleryCreated || hasGallery;
      hasMoreGallery = mais.length >= _kPageSize;
      if (mais.isNotEmpty) galleryCursor = mais.last.createdAt;
      _preloadGalleryVideos(mais);
    } finally {
      loadingMoreGallery = false;
      notifyListeners();
    }
  }

  Future<void> refreshGallery() => _loadGallery();

  Future<void> _checkAdmin() async {
    loadingAdmin = true;
    notifyListeners();
    try {
      isAdmin = await AdminService.instance.isAdmin(uid);
    } finally {
      loadingAdmin = false;
      notifyListeners();
    }
  }

  // ── Ações ──────────────────────────────────────────────────────────────────

  void setTabIndex(int index) {
    tabIndex = index;
    notifyListeners();
  }

  // FIX: removidos 'partys', 'reservations', 'isPremium' e 'vip_lists' do map
  // — esses campos têm ".write": false nas regras do Firebase.
  // Enviar qualquer campo com write:false no mesmo .update() descarta o update
  // inteiro silenciosamente, impedindo salvar qualquer dado do perfil.
  void updateUserData(Map<String, dynamic> updates) {
    if (user == null) return;

    final base = <String, dynamic>{
      'name': user!.name,
      'email': user!.email,
      'avatar': user!.avatar ?? '',
      'bio': user!.bio,
      'bairro': user!.bairro,
      'city': user!.city,
      'state': user!.state,
      'gender_identity': user!.genderIdentity ?? '',
      'sexual_orientation': user!.sexualOrientation ?? '',
      'relationship_type': user!.relationshipType ?? '',
      'profile_type': user!.profileType ?? 'single',
      'birth_date': user!.birthDate ?? '',
      if (user!.partner != null)
        'partner': {
          'name': user!.partner!.name ?? '',
          'birth_date': user!.partner!.birthDate ?? '',
          'gender_identity': user!.partner!.genderIdentity ?? '',
          'sexual_orientation': user!.partner!.sexualOrientation ?? '',
        },
    };

    base.addAll(updates);

    user = ProfileUserModel.fromMap(uid, base).copyWith(
      followers: user!.followers,
      following: user!.following,
      postCount: user!.postCount,
    );

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
    _disposed = true;
    _evictGalleryPreloads();
    for (final p in posts) {
      if (p.tipo == 'video') VideoPreloadService.instance.evict(p.id);
    }
    super.dispose();
  }
}
