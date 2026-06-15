// lib/services/services_app/video_preload_service.dart
//
// FIX: adicionado VideoPlayerOptions(mixWithOthers: true) na criação do
// controller. Sem essa flag, no Android dois controllers simultâneos se
// bloqueiam — o segundo não renderiza (tela cinza) mesmo com áudio.

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoPreloadService {
  VideoPreloadService._();
  static final VideoPreloadService instance = VideoPreloadService._();

  static const int _maxCached = 6;

  final Map<String, VideoPlayerController> _ready = {};
  final Set<String> _inProgress = {};
  final List<String> _order = [];

  VideoPlayerController? getController(String postId) => _ready[postId];
  bool isReady(String postId) => _ready.containsKey(postId);

  Future<void> preload(String postId, String videoUrl) async {
    if (_ready.containsKey(postId) || _inProgress.contains(postId)) return;
    _inProgress.add(postId);

    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        // FIX: sem mixWithOthers=true o Android bloqueia renderização
        // de controllers simultâneos — resultado: tela cinza com áudio.
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);
      await ctrl.pause();

      _ready[postId] = ctrl;
      _order.add(postId);
      _evictOldest();

      debugPrint('[VideoPreload] ✅ Pronto: $postId');
    } catch (e) {
      debugPrint('[VideoPreload] ❌ Erro ao pré-carregar $postId: $e');
    } finally {
      _inProgress.remove(postId);
    }
  }

  Future<void> evict(String postId) async {
    final ctrl = _ready.remove(postId);
    _order.remove(postId);
    await ctrl?.dispose();
  }

  Future<void> disposeAll() async {
    for (final ctrl in _ready.values) {
      await ctrl.dispose();
    }
    _ready.clear();
    _order.clear();
    _inProgress.clear();
  }

  void _evictOldest() {
    while (_order.length > _maxCached) {
      final oldest = _order.removeAt(0);
      final ctrl = _ready.remove(oldest);
      ctrl?.dispose();
      debugPrint('[VideoPreload] 🗑️ Evicted: $oldest');
    }
  }
}

