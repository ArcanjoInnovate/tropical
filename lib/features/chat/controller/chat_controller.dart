// lib/features/chat/controller/chat_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/chat_model.dart';
import '../data/services/chat_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({required ChatService service}) : _service = service;

  final ChatService _service;

  // ── Estado ────────────────────────────────────────────────────────────────
  TabuChat?         _chat;
  List<ChatMessage> _messages       = [];
  ParticipantStatus? _otherStatus;
  int               _unreadCount    = 0;
  bool              _isLoading      = true;
  bool              _isSending      = false;
  bool              _isLoadingMore  = false;
  bool              _hasMore        = true;
  bool              _isBlocked      = false;
  String?           _error;

  // Ids da sessão
  String? _chatId;
  String? _myUid;
  String? _otherUid;

  // Subscriptions
  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _unreadSub;
  StreamSubscription? _blockSub;

  // ── Getters ───────────────────────────────────────────────────────────────
  TabuChat?          get chat          => _chat;
  List<ChatMessage>  get messages      => _messages;
  ParticipantStatus? get otherStatus   => _otherStatus;
  int                get unreadCount   => _unreadCount;
  bool               get isLoading     => _isLoading;
  bool               get isSending     => _isSending;
  bool               get isLoadingMore => _isLoadingMore;
  bool               get hasMore       => _hasMore;
  bool               get isBlocked     => _isBlocked;
  String?            get error         => _error;
  bool               get hasChat       => _chat != null;

  ChatMessage? get lastMessage  => _messages.isEmpty ? null : _messages.last;
  ChatMessage? get firstMessage => _messages.isEmpty ? null : _messages.first;

  bool isMine(ChatMessage msg) => msg.senderId == _myUid;

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> initialize({
    required String myUid,
    required String otherUid,
  }) async {
    _myUid    = myUid;
    _otherUid = otherUid;
    _chatId   = TabuChat.buildChatId(myUid, otherUid);

    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      _chat = await _service.initializeChat(myUid, otherUid);

      // Chat já bloqueado: não inicializa streams
      if (_chat?.blockDialog == true) {
        _isBlocked = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _service.setOnline(_chatId!, myUid);
      await _service.setGlobalOnline(myUid);

      _msgSub = _service.messagesStream(_chatId!).listen((msgs) {
        _messages = msgs;
        notifyListeners();
      }, onError: (_) => _setError('Erro ao carregar mensagens'));

      _statusSub = _service
          .otherStatusStream(_chatId!, otherUid)
          .listen((s) {
        _otherStatus = s;
        notifyListeners();
      });

      _unreadSub = _service
          .unreadCountStream(_chatId!, myUid)
          .listen((n) {
        _unreadCount = n;
        notifyListeners();
      });

      // Monitora bloqueio em tempo real
      _blockSub = _service.blockDialogStream(_chatId!).listen((blocked) {
        if (blocked && !_isBlocked) {
          _isBlocked = true;
          // Cancela streams que não são mais necessários
          _msgSub?.cancel();
          _statusSub?.cancel();
          _unreadSub?.cancel();
          notifyListeners();
        }
      });

      await _service.markAsRead(_chatId!, myUid);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Erro ao inicializar: $e');
    }
  }

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<void> send(String text) async {
    if (text.trim().isEmpty     ||
        _chatId   == null       ||
        _myUid    == null       ||
        _otherUid == null       ||
        _isBlocked) return;

    _isSending = true;
    notifyListeners();

    try {
      await _service.sendMessage(
        chatId:      _chatId!,
        text:        text.trim(),
        senderId:    _myUid!,
        recipientId: _otherUid!,
      );
    } catch (e) {
      _setError('Erro ao enviar mensagem');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ── Paginação ─────────────────────────────────────────────────────────────

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final older = await _service.loadOlderMessages(_chatId!);
      if (older.isEmpty) {
        _hasMore = false;
      } else {
        _messages = [...older, ..._messages];
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Leitura ───────────────────────────────────────────────────────────────

  Future<void> markAsRead() async {
    if (_chatId == null || _myUid == null) return;
    await _service.markAsRead(_chatId!, _myUid!);
  }

  // ── Saída ─────────────────────────────────────────────────────────────────

  Future<void> leave() async {
    if (_chatId != null && _myUid != null) {
      await _service.setOffline(_chatId!, _myUid!);
    }
    _msgSub?.cancel();
    _statusSub?.cancel();
    _unreadSub?.cancel();
    _blockSub?.cancel();
    if (_chatId != null) _service.disposeChat(_chatId!);
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setError(String msg) {
    _error     = msg;
    _isLoading = false;
    notifyListeners();
    debugPrint('[ChatController] ❌ $msg');
  }
}

