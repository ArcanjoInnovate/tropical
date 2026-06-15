// lib/core/providers/block_provider.dart
//
// MUDANÇAS vs versão anterior:
//   • Extraído _cancelSubscriptions() para cancelar os streams sem chamar
//     dispose() do ChangeNotifier, que não deve ser chamado enquanto há
//     listeners ativos. O reinitialize() usava dispose() diretamente, o que
//     causava assertion errors em debug quando o widget ainda estava na árvore.
//   • reinitialize() agora chama _cancelSubscriptions() + init(), nunca dispose().
//   • dispose() override mantido apenas para o ciclo de vida normal do Provider.

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:tclub/core/services/user_relationship_service.dart';

class BlockProvider extends ChangeNotifier {
  final UserRelationshipService _service;
  String _myUserId = '';

  // ── Getter público ────────────────────────────────────────────────────────
  String get myUserId => _myUserId;

  // ── Estado ────────────────────────────────────────────────────────────────
  Set<String> _iBlockedIds = {};
  Set<String> _blockedMeIds = {};
  bool _isLoading = false;
  String? _error;

  StreamSubscription<DatabaseEvent>? _iBlockedSub;
  StreamSubscription<DatabaseEvent>? _blockedMeSub;

  // ── Constructor ───────────────────────────────────────────────────────────
  BlockProvider({
    String myUserId = '',
    UserRelationshipService? service,
  }) : _service = service ?? UserRelationshipService() {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _myUserId = myUserId.isNotEmpty ? myUserId : firebaseUid;
    print('✅ BlockProvider criado: myUserId="$_myUserId"');
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  Set<String> get iBlockedIds => _iBlockedIds;
  Set<String> get blockedMeIds => _blockedMeIds;
  Set<String> get allBlockedIds => {..._iBlockedIds, ..._blockedMeIds};
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isBlocked(String userId) => allBlockedIds.contains(userId);
  bool iBlockedThem(String userId) => _iBlockedIds.contains(userId);
  bool theyBlockedMe(String userId) => _blockedMeIds.contains(userId);

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    print('🔄 BlockProvider.init() para UID: $_myUserId');

    if (_myUserId.isEmpty) {
      print('❌ BlockProvider.init(): UID vazio! Abortando...');
      _error = 'Usuário não autenticado';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📥 Carregando dados iniciais...');
      final iBlocked = await _service.fetchUsersIBlocked(_myUserId);
      final blockedMe = await _service.fetchUsersWhoBlockedMe(_myUserId);

      _iBlockedIds = iBlocked;
      _blockedMeIds = blockedMe;
      print('✅ Dados: ${iBlocked.length} bloqueados, ${blockedMe.length} me bloquearam');

      // Cancela subscriptions anteriores antes de criar novas
      await _cancelSubscriptions();

      _iBlockedSub = _service.watchIBlocked(_myUserId).listen(_onIBlockedChanged);
      _blockedMeSub = _service.watchBlockedMe(_myUserId).listen(_onBlockedMeChanged);
      print('✅ Listeners ativos');
    } catch (e) {
      _error = e.toString();
      print('❌ BlockProvider.init erro: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // FIX: método separado para cancelar subscriptions sem chamar dispose().
  // O dispose() do ChangeNotifier não deve ser chamado enquanto há listeners
  // ativos (como durante reinitialize() com o widget ainda na árvore).
  Future<void> _cancelSubscriptions() async {
    await _iBlockedSub?.cancel();
    await _blockedMeSub?.cancel();
    _iBlockedSub = null;
    _blockedMeSub = null;
  }

  @override
  void dispose() {
    print('🧹 BlockProvider.dispose()');
    _iBlockedSub?.cancel();
    _blockedMeSub?.cancel();
    super.dispose();
  }

  // ── Handlers de stream ────────────────────────────────────────────────────
  void _onIBlockedChanged(DatabaseEvent event) {
    final snap = event.snapshot;
    if (!snap.exists || snap.value == null) {
      _iBlockedIds = {};
    } else {
      final raw = snap.value;
      if (raw is Map) {
        _iBlockedIds = raw.entries
            .where((e) => _isTruthy(e.value))
            .map((e) => e.key.toString())
            .toSet();
      }
    }
    notifyListeners();
  }

  void _onBlockedMeChanged(DatabaseEvent event) {
    final snap = event.snapshot;
    if (!snap.exists || snap.value == null) {
      _blockedMeIds = {};
    } else {
      final raw = snap.value;
      if (raw is Map) {
        _blockedMeIds = raw.entries
            .where((e) => _isTruthy(e.value))
            .map((e) => e.key.toString())
            .toSet();
      }
    }
    notifyListeners();
  }

  // ── Ações ─────────────────────────────────────────────────────────────────
  Future<bool> blockUser(String targetUserId) async {
    print('🔒=== BLOCKPROVIDER DEBUG ===');
    print('   myUserId: "$_myUserId"');
    print('   target: "$targetUserId"');
    print('   Firebase: "${FirebaseAuth.instance.currentUser?.uid}"');

    if (_myUserId.isEmpty) {
      print('💥 CRÍTICO: myUserId VAZIO!');
      _error = 'Usuário não autenticado';
      notifyListeners();
      return false;
    }

    if (targetUserId.isEmpty) {
      print('💥 CRÍTICO: targetUserId VAZIO!');
      return false;
    }

    if (_myUserId == targetUserId) {
      print('⚠️ Auto-bloqueio ignorado');
      return false;
    }

    try {
      final ok = await _service.blockUser(_myUserId, targetUserId);
      print('   Service.blockUser(): $ok');

      if (ok) {
        _iBlockedIds = {..._iBlockedIds, targetUserId};
        notifyListeners();
      }
      return ok;
    } catch (e) {
      print('❌ blockUser erro: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unblockUser(String targetUserId) async {
    print('🔓 Unblock: $_myUserId → $targetUserId');

    if (_myUserId.isEmpty) return false;

    try {
      final ok = await _service.unblockUser(_myUserId, targetUserId);
      if (ok) {
        _iBlockedIds = _iBlockedIds.where((id) => id != targetUserId).toSet();
        notifyListeners();
      }
      return ok;
    } catch (e) {
      print('❌ unblockUser erro: $e');
      return false;
    }
  }

  // FIX: reinitialize agora usa _cancelSubscriptions() em vez de dispose(),
  // evitando assertion errors quando o widget ainda está na árvore de widgets.
  Future<void> reinitialize(String newUserId) async {
    print('🔄 Reinit: $_myUserId → $newUserId');
    _myUserId = newUserId;
    await _cancelSubscriptions();
    await init();
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }
}

