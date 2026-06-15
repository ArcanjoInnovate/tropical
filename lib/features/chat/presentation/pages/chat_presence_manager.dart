// lib/features/chat/data/services/chat_presence_manager.dart
//
// Gerenciador dedicado de presença para o ChatRoom.
// Garante que o usuário seja marcado offline em qualquer cenário de saída:
// dispose, background, perda de conexão.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/features/chat/data/services/chat_service.dart';

class ChatPresenceManager {
  ChatPresenceManager({
    required this.chatId,
    required this.myUid,
    required ChatService service,
  }) : _service = service;

  final String      chatId;
  final String      myUid;
  final ChatService _service;

  Timer?              _heartbeatTimer;
  StreamSubscription? _connectivitySub;
  bool                _isActive = false;

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;
    await _setOnline();
    _startHeartbeat();
    _monitorConnectivity();
    debugPrint('[ChatPresence] ✅ Iniciado — uid=$myUid chat=$chatId');
  }

  // ── Finalização ───────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _setOffline();
    debugPrint('[ChatPresence] 🔴 Parado — uid=$myUid chat=$chatId');
  }

  // ── Pause / Resume (lifecycle do app) ─────────────────────────────────────

  Future<void> pause() async {
    _heartbeatTimer?.cancel();
    await _setOffline();
    debugPrint('[ChatPresence] ⏸ Pausado');
  }

  Future<void> resume() async {
    if (!_isActive) return;
    await _setOnline();
    _startHeartbeat();
    debugPrint('[ChatPresence] ▶ Resumido');
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _setOnline() async {
    try {
      await _service.setGlobalOnline(myUid);
      await _service.setOnline(chatId, myUid);
    } catch (e) {
      debugPrint('[ChatPresence] ❌ setOnline: $e');
    }
  }

  Future<void> _setOffline() async {
    try {
      await _service.setGlobalOffline(myUid);
      await _service.setOffline(chatId, myUid);
    } catch (e) {
      debugPrint('[ChatPresence] ❌ setOffline: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!_isActive) return;
      try {
        await _service.updateHeartbeat(chatId, myUid);
      } catch (e) {
        debugPrint('[ChatPresence] ⚠️ heartbeat: $e');
      }
    });
  }

  void _monitorConnectivity() {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        _setOffline();
      } else if (_isActive) {
        _setOnline();
      }
    });
  }
}

