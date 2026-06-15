// lib/features/chat/data/services/chat_service.dart
//
// Camada de serviço: orquestra o IChatRepository, mantém o cache de mensagens
// em memória e expõe streams compostos prontos para o controller consumir.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../repositories/chat_repository.dart';

class ChatService {
  ChatService({required IChatRepository repository})
      : _repository = repository;

  final IChatRepository _repository;

  static const int _initialLimit = 20;
  static const int _olderLimit   = 20;

  // Cache por chatId — mantido aqui para que o controller seja stateless
  // em relação ao histórico de mensagens.
  final Map<String, List<ChatMessage>> _cache         = {};
  final Map<String, int>               _lastTimestamp = {};

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<TabuChat> initializeChat(String myUid, String otherUid) =>
      _repository.initializeChat(myUid, otherUid);

  // ── Presença ──────────────────────────────────────────────────────────────

  Future<void> setGlobalOnline(String uid)  => _repository.setGlobalOnline(uid);
  Future<void> setGlobalOffline(String uid) => _repository.setGlobalOffline(uid);
  Future<void> setOnline(String chatId, String uid)  =>
      _repository.setOnline(chatId, uid);
  Future<void> setOffline(String chatId, String uid) =>
      _repository.setOffline(chatId, uid);
  Future<void> updateHeartbeat(String chatId, String uid) =>
      _repository.updateHeartbeat(chatId, uid);

  Stream<bool> userOnlineStream(String uid)    => _repository.userOnlineStream(uid);
  Stream<int>  userLastSeenStream(String uid)  => _repository.userLastSeenStream(uid);

  Stream<ParticipantStatus> otherStatusStream(String chatId, String otherUid) =>
      _repository.otherStatusStream(chatId, otherUid);

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String recipientId,
  }) =>
      _repository.sendMessage(
        chatId:      chatId,
        text:        text,
        senderId:    senderId,
        recipientId: recipientId,
      );

  // ── Stream de mensagens (com cache) ──────────────────────────────────────

  /// Retorna um stream de snapshots completos da lista de mensagens.
  /// O primeiro evento traz o histórico inicial; eventos seguintes
  /// refletem novas mensagens e atualizações de leitura.
  Stream<List<ChatMessage>> messagesStream(String chatId) {
    final controller = StreamController<List<ChatMessage>>.broadcast();
    final subs       = <StreamSubscription>[];

    _repository
        .loadInitialMessages(chatId, _initialLimit)
        .then((initial) {
      _cache[chatId]         = initial;
      _lastTimestamp[chatId] = initial.isNotEmpty ? initial.last.timestamp : 0;
      controller.add(List.from(initial));

      // Novas mensagens
      final addSub = _repository
          .newMessagesStream(chatId, _lastTimestamp[chatId] ?? 0)
          .listen((msg) {
        final list = _cache[chatId] ?? [];
        if (!list.any((m) => m.id == msg.id)) {
          list.add(msg);
          _cache[chatId]         = list;
          _lastTimestamp[chatId] = msg.timestamp;
          controller.add(List.from(list));
        }
      });

      // Atualizações (leitura)
      final changeSub = _repository
          .updatedMessagesStream(chatId)
          .listen((updated) {
        final list = _cache[chatId] ?? [];
        final idx  = list.indexWhere((m) => m.id == updated.id);
        if (idx != -1) {
          list[idx] = updated;
          _cache[chatId] = list;
          controller.add(List.from(list));
        }
      });

      subs.addAll([addSub, changeSub]);
    });

    // Fecha subscriptions quando o controller for cancelado
    controller.onCancel = () {
      for (final s in subs) { s.cancel(); }
    };

    return controller.stream;
  }

  // ── Paginação ─────────────────────────────────────────────────────────────

  /// Carrega mensagens mais antigas e atualiza o cache.
  /// Retorna lista vazia quando não há mais mensagens.
  Future<List<ChatMessage>> loadOlderMessages(String chatId) async {
    final cached   = _cache[chatId] ?? [];
    final oldest   = cached.isEmpty ? 0 : cached.first.timestamp;
    final older    = await _repository.loadOlderMessages(
        chatId, oldest, _olderLimit);
    if (older.isEmpty) return [];

    final existing  = cached.map((m) => m.id).toSet();
    final newOnes   = older.where((m) => !existing.contains(m.id)).toList();
    _cache[chatId]  = [...newOnes, ...cached];
    return newOnes;
  }

  // ── Leitura ───────────────────────────────────────────────────────────────

  Future<void> markAsRead(String chatId, String myUid) =>
      _repository.markAsRead(chatId, myUid);

  Stream<int> unreadCountStream(String chatId, String myUid) =>
      _repository.unreadCountStream(chatId, myUid);

  // ── Bloqueio ──────────────────────────────────────────────────────────────

  Stream<bool> blockDialogStream(String chatId) =>
      _repository.blockDialogStream(chatId);

  // ── Lista de chats ────────────────────────────────────────────────────────

  Stream<List<String>> chatIdsStream(String myUid) =>
      _repository.chatIdsStream(myUid);

  Stream<TabuChat?> singleChatStream(String chatId) =>
      _repository.singleChatStream(chatId);

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void disposeChat(String chatId) {
    _cache.remove(chatId);
    _lastTimestamp.remove(chatId);
    debugPrint('[ChatService] cache limpo: $chatId');
  }

  void disposeAll() {
    _cache.clear();
    _lastTimestamp.clear();
  }
}

