// lib/features/chat/data/models/chat_model.dart

// ════════════════════════════════════════════════════════════════════════════
//  TabuChat
// ════════════════════════════════════════════════════════════════════════════
class TabuChat {
  const TabuChat({
    required this.chatId,
    required this.user1Id,
    required this.user2Id,
    required this.metadata,
    required this.unreadCount,
    required this.participants,
    this.blockDialog = false,
    this.origin = '',
  });

  final String chatId;
  final String user1Id;
  final String user2Id;
  final ChatMetadata metadata;
  final Map<String, int> unreadCount;
  final Map<String, ParticipantStatus> participants;

  /// Quando `true`, o chat está bloqueado e não deve aceitar novas mensagens.
  final bool blockDialog;

  /// Origem do chat: `'match'` ou `''` (solicitação normal).
  final String origin;

  bool get isFromMatch => origin == 'match';

  /// chatId é sempre os dois UIDs ordenados: menor_maior
  static String buildChatId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String otherUserId(String myUid) =>
      user1Id == myUid ? user2Id : user1Id;

  int myUnreadCount(String myUid) => unreadCount[myUid] ?? 0;

  // ── Desserialização ───────────────────────────────────────────────────────

  factory TabuChat.fromMap(String chatId, Map<dynamic, dynamic> map) {
    final metaMap        = map['metadata']     as Map<dynamic, dynamic>?;
    final unreadRaw      = map['unreadCount']  as Map<dynamic, dynamic>? ?? {};
    final participantRaw = map['participants'] as Map<dynamic, dynamic>? ?? {};

    final participants = <String, ParticipantStatus>{};
    participantRaw.forEach((uid, val) {
      if (val is Map) {
        participants[uid.toString()] = ParticipantStatus.fromMap(val);
      }
    });

    final unread = <String, int>{};
    unreadRaw.forEach((uid, val) {
      unread[uid.toString()] = (val as num?)?.toInt() ?? 0;
    });

    return TabuChat(
      chatId:      chatId,
      user1Id:     map['user1']       as String? ?? '',
      user2Id:     map['user2']       as String? ?? '',
      metadata:    metaMap != null
          ? ChatMetadata.fromMap(metaMap)
          : ChatMetadata.empty(),
      unreadCount: unread,
      participants: participants,
      blockDialog: (map['block_dialog'] as bool?) ?? false,
      origin:      map['origin']      as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'user1':        user1Id,
    'user2':        user2Id,
    'metadata':     metadata.toMap(),
    'unreadCount':  unreadCount,
    'participants': participants.map((uid, p) => MapEntry(uid, p.toMap())),
    'block_dialog': blockDialog,
    if (origin.isNotEmpty) 'origin': origin,
  };

  static Map<String, dynamic> createInitialStructure(String uid1, String uid2) {
    final now    = DateTime.now().millisecondsSinceEpoch;
    final sorted = [uid1, uid2]..sort();
    return {
      'user1': sorted[0],
      'user2': sorted[1],
      'metadata': {
        'last_message':  '',
        'last_sender':   '',
        'last_timestamp': 0,
        'created_at':    now,
      },
      'unreadCount': {uid1: 0, uid2: 0},
      'participants': {
        uid1: {'status': 'offline', 'last_seen': now},
        uid2: {'status': 'offline', 'last_seen': now},
      },
      'block_dialog': false,
    };
  }

  TabuChat copyWith({
    ChatMetadata?             metadata,
    Map<String, int>?         unreadCount,
    Map<String, ParticipantStatus>? participants,
    bool?                     blockDialog,
    String?                   origin,
  }) =>
      TabuChat(
        chatId:       chatId,
        user1Id:      user1Id,
        user2Id:      user2Id,
        metadata:     metadata     ?? this.metadata,
        unreadCount:  unreadCount  ?? this.unreadCount,
        participants: participants ?? this.participants,
        blockDialog:  blockDialog  ?? this.blockDialog,
        origin:       origin       ?? this.origin,
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  ChatMetadata
// ════════════════════════════════════════════════════════════════════════════
class ChatMetadata {
  const ChatMetadata({
    required this.lastMessage,
    required this.lastSender,
    required this.lastTimestamp,
    this.createdAt,
  });

  final String lastMessage;
  final String lastSender;
  final int    lastTimestamp;
  final int?   createdAt;

  factory ChatMetadata.fromMap(Map<dynamic, dynamic> map) => ChatMetadata(
    lastMessage:   map['last_message']  as String? ?? '',
    lastSender:    map['last_sender']   as String? ?? '',
    lastTimestamp: (map['last_timestamp'] as num?)?.toInt() ?? 0,
    createdAt:     (map['created_at']   as num?)?.toInt(),
  );

  factory ChatMetadata.empty() =>
      const ChatMetadata(lastMessage: '', lastSender: '', lastTimestamp: 0);

  Map<String, dynamic> toMap() => {
    'last_message':  lastMessage,
    'last_sender':   lastSender,
    'last_timestamp': lastTimestamp,
    if (createdAt != null) 'created_at': createdAt,
  };
}

// ════════════════════════════════════════════════════════════════════════════
//  ParticipantStatus
// ════════════════════════════════════════════════════════════════════════════
class ParticipantStatus {
  const ParticipantStatus({required this.status, required this.lastSeen});

  final String status;   // 'online' | 'offline'
  final int    lastSeen;

  bool get isOnline => status == 'online';

  factory ParticipantStatus.fromMap(Map<dynamic, dynamic> map) =>
      ParticipantStatus(
        status:   map['status']    as String? ?? 'offline',
        lastSeen: (map['last_seen'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toMap() => {
    'status':    status,
    'last_seen': lastSeen,
  };
}

// ════════════════════════════════════════════════════════════════════════════
//  ChatMessage
// ════════════════════════════════════════════════════════════════════════════
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.readBy,
    this.readAt = const {},
  });

  final String           id;
  final String           text;
  final String           senderId;
  final int              timestamp;
  final Map<String, bool> readBy;
  final Map<String, int>  readAt;

  bool isReadBy(String uid)  => readBy[uid] == true;
  int? readAtBy(String uid)  => readAt[uid];

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    final readByRaw = map['read_by'] as Map<dynamic, dynamic>? ?? {};
    final readBy    = <String, bool>{};
    readByRaw.forEach((uid, val) => readBy[uid.toString()] = val == true);

    final readAtRaw = map['read_at'] as Map<dynamic, dynamic>? ?? {};
    final readAt    = <String, int>{};
    readAtRaw.forEach((uid, val) {
      final ts = (val as num?)?.toInt();
      if (ts != null) readAt[uid.toString()] = ts;
    });

    return ChatMessage(
      id:        id,
      text:      map['text']       as String? ?? '',
      senderId:  map['sender_id']  as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      readBy:    readBy,
      readAt:    readAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'text':       text,
    'sender_id':  senderId,
    'timestamp':  timestamp,
    'read_by':    readBy,
    if (readAt.isNotEmpty) 'read_at': readAt,
  };
}