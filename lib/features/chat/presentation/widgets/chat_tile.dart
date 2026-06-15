// lib/features/chat/presentation/widgets/chat_tile.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/chat/data/models/chat_model.dart';
import 'package:tclub/features/chat/data/repositories/chat_repository.dart';
import 'package:tclub/features/chat/data/services/chat_service.dart';
import 'package:tclub/core/services/cached_avatar.dart';

class ChatTile extends StatefulWidget {
  final TabuChat chat;
  final String myUid;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.chat,
    required this.myUid,
    required this.onTap,
  });

  @override
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile> {
  late final ChatService _chatService;
  late final Stream<bool> _onlineStream;
  late final Stream<bool> _lastMsgReadStream;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(repository: ChatRepository());
    final otherUid = widget.chat.otherUserId(widget.myUid);
    _onlineStream = _chatService.userOnlineStream(otherUid);
    _lastMsgReadStream = _buildLastMsgReadStream(
      widget.chat.chatId,
      otherUid,
    );
  }

  /// Ouve a última mensagem do chat e retorna se o destinatário já leu.
  Stream<bool> _buildLastMsgReadStream(String chatId, String otherUid) {
    return FirebaseDatabase.instance
        .ref('ChatMessages/$chatId')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return false;
      final msgs = event.snapshot.value as Map<dynamic, dynamic>;
      for (final val in msgs.values) {
        if (val is! Map) continue;
        if (val['_init'] == true) return false;
        final senderId = val['sender_id'] as String? ?? '';
        if (senderId != widget.myUid) return false;
        final readBy = val['read_by'] as Map<dynamic, dynamic>?;
        return readBy?[otherUid] == true;
      }
      return false;
    });
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'ONTEM';
    if (diff.inDays < 7) {
      const days = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
      return days[dt.weekday % 7];
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chat.blockDialog) {
      return _BlockedChatTile(
        chat: widget.chat,
        myUid: widget.myUid,
        onTap: widget.onTap,
        formatTime: _formatTime,
      );
    }

    return _ActiveChatTile(
      chat: widget.chat,
      myUid: widget.myUid,
      onTap: widget.onTap,
      onlineStream: _onlineStream,
      lastMsgReadStream: _lastMsgReadStream,
      formatTime: _formatTime,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  TILE ATIVO
// ──────────────────────────────────────────────────────────────────────────────

class _ActiveChatTile extends StatelessWidget {
  final TabuChat chat;
  final String myUid;
  final VoidCallback onTap;
  final Stream<bool> onlineStream;
  final Stream<bool> lastMsgReadStream;
  final String Function(int) formatTime;

  const _ActiveChatTile({
    required this.chat,
    required this.myUid,
    required this.onTap,
    required this.onlineStream,
    required this.lastMsgReadStream,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.otherUserId(myUid);
    final unread = chat.myUnreadCount(myUid);
    final iLastSender = chat.metadata.lastSender == myUid;

    return Column(children: [
      StreamBuilder<bool>(
        stream: onlineStream,
        initialData: false,
        builder: (_, onlineSnap) {
          final isOnline = onlineSnap.data ?? false;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: TClubColors.redPrincipal.withOpacity(0.05),
              highlightColor: TClubColors.bgCard.withOpacity(0.5),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _AvatarWithPresence(
                    uid: otherUid,
                    isOnline: isOnline,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TileTopRow(
                          otherUid: otherUid,
                          unread: unread,
                          isOnline: isOnline,
                          timestamp: chat.metadata.lastTimestamp,
                          formatTime: formatTime,
                        ),
                        const SizedBox(height: 6),
                        _TileBottomRow(
                          lastMessage: chat.metadata.lastMessage,
                          iLastSender: iLastSender,
                          unread: unread,
                          lastMsgReadStream: lastMsgReadStream,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
      _TileDivider(leftPadding: 80),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  TILE BLOQUEADO
// ──────────────────────────────────────────────────────────────────────────────

class _BlockedChatTile extends StatelessWidget {
  final TabuChat chat;
  final String myUid;
  final VoidCallback onTap;
  final String Function(int) formatTime;

  const _BlockedChatTile({
    required this.chat,
    required this.myUid,
    required this.onTap,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.otherUserId(myUid);

    return Column(children: [
      Opacity(
        opacity: 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: const Color(0xFFDC2626).withOpacity(0.05),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Stack(children: [
                  CachedAvatar(uid: otherUid, name: otherUid, size: 50, radius: 8),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        border: Border.all(color: TClubColors.bg, width: 2),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: _OtherUserName(uid: otherUid, bold: false),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTime(chat.metadata.lastTimestamp),
                          style: const TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 9,
                            letterSpacing: 1,
                            color: TClubColors.subtle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _BlockedBadge(),
                      ]),
                      const SizedBox(height: 4),
                      const Text(
                        'Conversa bloqueada',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11,
                          letterSpacing: 0.2,
                          color: TClubColors.subtle,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      _TileDivider(leftPadding: 80),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  SUB-WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _AvatarWithPresence extends StatelessWidget {
  final String uid;
  final bool isOnline;

  const _AvatarWithPresence({required this.uid, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      CachedAvatar(uid: uid, name: uid, size: 50, radius: 8),
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: isOnline ? 13 : 10,
          height: isOnline ? 13 : 10,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF22C55E) : TClubColors.bgCard,
            shape: BoxShape.circle,
            border: Border.all(
              color: isOnline ? TClubColors.bg : TClubColors.border.withOpacity(0.5),
              width: isOnline ? 2 : 1.5,
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
      ),
    ]);
  }
}

class _TileTopRow extends StatelessWidget {
  final String otherUid;
  final int unread;
  final bool isOnline;
  final int timestamp;
  final String Function(int) formatTime;

  const _TileTopRow({
    required this.otherUid,
    required this.unread,
    required this.isOnline,
    required this.timestamp,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OtherUserName(uid: otherUid, bold: unread > 0),
            const SizedBox(height: 2),
            isOnline
                ? const Text(
                    'online agora',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: Color(0xFF22C55E),
                    ),
                  )
                : _LastSeenText(uid: otherUid),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Text(
        formatTime(timestamp),
        style: TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9,
          letterSpacing: 1,
          color: unread > 0 ? TClubColors.redPrincipal : TClubColors.subtle,
        ),
      ),
    ]);
  }
}

class _TileBottomRow extends StatelessWidget {
  final String lastMessage;
  final bool iLastSender;
  final int unread;
  final Stream<bool> lastMsgReadStream;

  const _TileBottomRow({
    required this.lastMessage,
    required this.iLastSender,
    required this.unread,
    required this.lastMsgReadStream,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = lastMessage.isEmpty;

    return Row(children: [
      if (iLastSender && !isEmpty)
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: StreamBuilder<bool>(
            stream: lastMsgReadStream,
            initialData: false,
            builder: (_, snap) {
              final isRead = snap.data ?? false;
              return Icon(
                isRead ? Icons.done_all_rounded : Icons.done_rounded,
                size: 13,
                color: isRead
                    ? const Color(0xFF60A5FA)
                    : TClubColors.subtle,
              );
            },
          ),
        ),
      Expanded(
        child: Text(
          isEmpty ? 'Chat ainda não aberto' : lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 12,
            letterSpacing: 0.2,
            color: isEmpty
                ? TClubColors.border
                : unread > 0
                    ? TClubColors.dim
                    : TClubColors.subtle,
            fontWeight:
                unread > 0 ? FontWeight.w600 : FontWeight.normal,
            fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
      if (unread > 0) ...[
        const SizedBox(width: 8),
        _UnreadBadge(count: unread),
      ],
    ]);
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: TClubColors.redPrincipal.withOpacity(0.15),
        border: Border.all(
          color: TClubColors.redPrincipal.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: TClubColors.redPrincipal,
        ),
      ),
    );
  }
}

class _BlockedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.12),
        border: Border.all(
          color: const Color(0xFFDC2626).withOpacity(0.4),
          width: 0.7,
        ),
      ),
      child: const Text(
        'BLOQUEADO',
        style: TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Color(0xFFDC2626),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  final double leftPadding;
  const _TileDivider({required this.leftPadding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Container(
        height: 0.5,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TClubColors.border, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _OtherUserName extends StatelessWidget {
  final String uid;
  final bool bold;
  const _OtherUserName({required this.uid, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('UsersPublic/$uid/name').onValue,
      builder: (_, snap) {
        final name = snap.data?.snapshot.value as String? ?? '...';
        return Text(
          name.toUpperCase(),
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 1.5,
            color: TClubColors.textoPrincipal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _LastSeenText extends StatefulWidget {
  final String uid;
  const _LastSeenText({required this.uid});

  @override
  State<_LastSeenText> createState() => _LastSeenTextState();
}

class _LastSeenTextState extends State<_LastSeenText> {
  late final Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream =
        ChatService(repository: ChatRepository()).userLastSeenStream(widget.uid);
  }

  String _format(int lastSeenMs) {
    if (lastSeenMs == 0) return 'offline';
    final diff = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
    final minutes = diff ~/ 60000;
    if (minutes < 2) return 'visto agora';
    if (minutes < 60) return 'visto há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'visto há ${hours}h';
    return 'visto há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      initialData: 0,
      builder: (_, snap) => Text(
        _format(snap.data ?? 0),
        style: TextStyle(
          fontFamily: TClubTypography.bodyFont,
          fontSize: 9,
          letterSpacing: 0.5,
          color: TClubColors.subtle.withOpacity(0.7),
        ),
      ),
    );
  }
}

