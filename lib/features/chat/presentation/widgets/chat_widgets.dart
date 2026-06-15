// lib/features/chat/presentation/widgets/chat_widgets.dart
//
// Widgets reutilizáveis do sistema de chat.
// Importados por chat_list_page.dart e chat_room_page.dart.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/chat/data/models/chat_model.dart';
import 'package:tclub/features/chat/data/services/chat_service.dart';
import 'package:tclub/core/services/cached_avatar.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GradientTopLine — linha decorativa rosa no topo das telas
// ════════════════════════════════════════════════════════════════════════════
class GradientTopLine extends StatelessWidget {
  const GradientTopLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.transparent, TClubColors.redDeep,
          TClubColors.redPrincipal, TClubColors.redClaro,
          TClubColors.redPrincipal, TClubColors.redDeep,
          Colors.transparent,
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TabBtn — aba da ChatListPage
// ════════════════════════════════════════════════════════════════════════════
class ChatTabBtn extends StatelessWidget {
  const ChatTabBtn({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeStream,
  });

  final String       label;
  final bool         isActive;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:    onTap,
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: TextStyle(
                    fontFamily:    TClubTypography.bodyFont,
                    fontSize:      10,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2.5,
                    color: isActive
                        ? TClubColors.redPrincipal
                        : TClubColors.subtle)),
                if (badgeStream != null)
                  StreamBuilder<int>(
                    stream: badgeStream,
                    builder: (_, snap) {
                      final n = snap.data ?? 0;
                      if (n == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color:  TClubColors.redPrincipal,
                            shape:  BoxShape.circle,
                            border: Border.all(
                                color: TClubColors.bg, width: 1.5)),
                          child: Center(child: Text('$n',
                              style: const TextStyle(
                                  fontFamily:  TClubTypography.bodyFont,
                                  fontSize:    8,
                                  fontWeight:  FontWeight.w700,
                                  color:       Colors.white)))));
                    }),
              ]),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height:   1.5,
                width:    isActive ? 32 : 0,
                color:    TClubColors.redPrincipal),
            ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  UnreadBadgeTotal — badge de mensagens não lidas no header
// ════════════════════════════════════════════════════════════════════════════
class UnreadBadgeTotal extends StatelessWidget {
  const UnreadBadgeTotal({super.key, required this.myUid});
  final String myUid;

  @override
  Widget build(BuildContext context) {
    if (myUid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DatabaseEvent>(
      // ✅ TROCA CIRÚRGICA: Users → UserBadges
      stream: FirebaseDatabase.instance
          .ref('UserBadges/$myUid/unreadChatsCount')
          .onValue,
      builder: (_, snap) {
        final total = (snap.data?.snapshot.value as int?) ?? 0;
        if (total == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:  TClubColors.redPrincipal.withOpacity(0.15),
            border: Border.all(
                color: TClubColors.redPrincipal.withOpacity(0.4), width: 0.8)),
          child: Text('$total', style: const TextStyle(
              fontFamily:  TClubTypography.bodyFont,
              fontSize:    10,
              fontWeight:  FontWeight.w700,
              letterSpacing: 1,
              color:       TClubColors.redPrincipal)));
      });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BlockedBanner — banner de aviso de chat bloqueado
// ════════════════════════════════════════════════════════════════════════════
class BlockedBanner extends StatelessWidget {
  const BlockedBanner({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width:    double.infinity,
      padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.12),
        border: Border(bottom: BorderSide(
            color: const Color(0xFFDC2626).withOpacity(0.4), width: 0.8))),
      child: Row(children: [
        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFDC2626)),
        const SizedBox(width: 10),
        Expanded(child: Text('Esta conversa foi bloqueada.',
            style: TextStyle(
              fontFamily:  TClubTypography.bodyFont,
              fontSize:    11,
              letterSpacing: 0.4,
              color:       const Color(0xFFDC2626).withOpacity(0.9),
              fontWeight:  FontWeight.w600))),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close_rounded,
              size: 16, color: Color(0xFFDC2626))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ChatSectionLabel — separador de seção na lista (MATCHS / CONVERSAS)
// ════════════════════════════════════════════════════════════════════════════
class ChatSectionLabel extends StatelessWidget {
  const ChatSectionLabel({super.key, required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        Icon(icon, size: 12, color: TClubColors.redPrincipal),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            fontFamily:    TClubTypography.bodyFont,
            fontSize:      9,
            fontWeight:    FontWeight.w700,
            letterSpacing: 3,
            color:         TClubColors.subtle)),
        const SizedBox(width: 8),
        Expanded(child: Container(
          height: 0.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              TClubColors.border.withOpacity(0.5),
              Colors.transparent,
            ])))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BlockedSectionHeader — cabeçalho colapsável da seção de bloqueados
// ════════════════════════════════════════════════════════════════════════════
class BlockedSectionHeader extends StatelessWidget {
  const BlockedSectionHeader({
    super.key,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int          count;
  final bool         expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:     onToggle,
      behavior:  HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.05),
          border: Border(
            top:    BorderSide(color: const Color(0xFFDC2626).withOpacity(0.2),  width: 0.6),
            bottom: BorderSide(
                color: expanded
                    ? const Color(0xFFDC2626).withOpacity(0.15)
                    : Colors.transparent,
                width: 0.6))),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:  const Color(0xFFDC2626).withOpacity(0.10),
              border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.35), width: 0.7)),
            child: const Icon(Icons.lock_rounded,
                size: 14, color: Color(0xFFDC2626))),
          const SizedBox(width: 12),
          Expanded(child: Row(children: [
            const Text('BLOQUEADOS', style: TextStyle(
                fontFamily:    TClubTypography.bodyFont,
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                letterSpacing: 2.5,
                color:         Color(0xFFDC2626))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color:  const Color(0xFFDC2626).withOpacity(0.12),
                border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.4), width: 0.7)),
              child: Text('$count', style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize:   9,
                  fontWeight: FontWeight.w700,
                  color:      Color(0xFFDC2626)))),
          ])),
          AnimatedRotation(
            turns:    expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child:    Icon(Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFFDC2626).withOpacity(0.6), size: 18)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ChatTile — tile de conversa na lista
// ════════════════════════════════════════════════════════════════════════════
class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.myUid,
    required this.service,
    required this.onTap,
  });

  final TabuChat    chat;
  final String      myUid;
  final ChatService service;
  final VoidCallback onTap;

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final dt   = DateTime.fromMillisecondsSinceEpoch(ts);
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
    final otherUid = chat.otherUserId(myUid);
    if (chat.blockDialog) return _buildBlockedTile(context, otherUid);

    final unread       = chat.myUnreadCount(myUid);
    final iLastSender  = chat.metadata.lastSender == myUid;

    return Column(children: [
      StreamBuilder<bool>(
        stream:      service.userOnlineStream(otherUid),
        initialData: false,
        builder: (context, onlineSnap) {
          final isOnline = onlineSnap.data ?? false;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:          onTap,
              splashColor:    TClubColors.redPrincipal.withOpacity(0.05),
              highlightColor: TClubColors.bgCard.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _buildAvatar(otherUid, isOnline),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OtherUserName(uid: otherUid, bold: unread > 0),
                            const SizedBox(height: 2),
                            isOnline
                                ? const Text('online agora',
                                    style: TextStyle(
                                      fontFamily: TClubTypography.bodyFont,
                                      fontSize:   9,
                                      letterSpacing: 0.5,
                                      color:      Color(0xFF22C55E)))
                                : LastSeenText(uid: otherUid, service: service),
                          ])),
                        const SizedBox(width: 8),
                        Text(_formatTime(chat.metadata.lastTimestamp),
                            style: TextStyle(
                              fontFamily:    TClubTypography.bodyFont,
                              fontSize:      9,
                              letterSpacing: 1,
                              color: unread > 0
                                  ? TClubColors.redPrincipal
                                  : TClubColors.subtle)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        if (iLastSender && chat.metadata.lastMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: StreamBuilder<int>(
                              stream:      service.unreadCountStream(chat.chatId, otherUid),
                              initialData: 0,
                              builder: (_, snap) {
                                final recipientRead = (snap.data ?? 0) == 0;
                                return Icon(
                                  recipientRead
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size:  13,
                                  color: recipientRead
                                      ? const Color(0xFF60A5FA)
                                      : TClubColors.subtle);
                              })),
                        Expanded(child: Text(
                          chat.metadata.lastMessage.isEmpty
                              ? 'Chat ainda não aberto'
                              : chat.metadata.lastMessage,
                          maxLines:  1,
                          overflow:  TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize:   12,
                            letterSpacing: 0.2,
                            color: chat.metadata.lastMessage.isEmpty
                                ? TClubColors.border
                                : unread > 0
                                    ? TClubColors.dim
                                    : TClubColors.subtle,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontStyle: chat.metadata.lastMessage.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal))),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:  TClubColors.redPrincipal.withOpacity(0.15),
                              border: Border.all(
                                  color: TClubColors.redPrincipal.withOpacity(0.4),
                                  width: 0.8)),
                            child: Text(unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  fontFamily:    TClubTypography.bodyFont,
                                  fontSize:      10,
                                  fontWeight:    FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color:         TClubColors.redPrincipal))),
                        ],
                      ]),
                    ])),
                ]),
              ),
            ),
          );
        }),
      _buildDivider(),
    ]);
  }

  Widget _buildAvatar(String uid, bool isOnline) {
    return Stack(children: [
      CachedAvatar(uid: uid, name: uid, size: 50, radius: 8),
      Positioned(right: 0, bottom: 0,
        child: isOnline
            ? Container(
                width: 13, height: 13,
                decoration: BoxDecoration(
                  color:  const Color(0xFF22C55E),
                  shape:  BoxShape.circle,
                  border: Border.all(color: TClubColors.bg, width: 2),
                  boxShadow: [BoxShadow(
                      color:      const Color(0xFF22C55E).withOpacity(0.5),
                      blurRadius: 8, spreadRadius: 1)]))
            : Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color:  TClubColors.bgCard,
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: TClubColors.border.withOpacity(0.5), width: 1.5)))),
    ]);
  }

  Widget _buildBlockedTile(BuildContext context, String otherUid) {
    return Column(children: [
      Opacity(
        opacity: 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:       onTap,
            splashColor: const Color(0xFFDC2626).withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Stack(children: [
                  CachedAvatar(uid: otherUid, name: otherUid, size: 50, radius: 8),
                  Positioned(right: 0, bottom: 0,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color:  const Color(0xFFDC2626),
                        shape:  BoxShape.circle,
                        border: Border.all(color: TClubColors.bg, width: 2)),
                      child: const Icon(Icons.lock_rounded,
                          size: 8, color: Colors.white))),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: _OtherUserName(uid: otherUid, bold: false)),
                      const SizedBox(width: 8),
                      Text(_formatTime(chat.metadata.lastTimestamp),
                          style: const TextStyle(
                              fontFamily:    TClubTypography.bodyFont,
                              fontSize:      9,
                              letterSpacing: 1,
                              color:         TClubColors.subtle)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:  const Color(0xFFDC2626).withOpacity(0.12),
                          border: Border.all(
                              color: const Color(0xFFDC2626).withOpacity(0.4), width: 0.7)),
                        child: const Text('BLOQUEADO', style: TextStyle(
                            fontFamily:    TClubTypography.bodyFont,
                            fontSize:      7,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 1.5,
                            color:         Color(0xFFDC2626)))),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Conversa bloqueada', style: TextStyle(
                        fontFamily:  TClubTypography.bodyFont,
                        fontSize:    11,
                        letterSpacing: 0.2,
                        color:       TClubColors.subtle,
                        fontStyle:   FontStyle.italic)),
                  ])),
              ]),
            ),
          ),
        ),
      ),
      _buildDivider(),
    ]);
  }

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.only(left: 80),
    child: Container(
      height: 0.5,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [TClubColors.border, Colors.transparent]))));
}

// ════════════════════════════════════════════════════════════════════════════
//  LastSeenText — último visto via stream
// ════════════════════════════════════════════════════════════════════════════
class LastSeenText extends StatelessWidget {
  const LastSeenText({super.key, required this.uid, required this.service});
  final String      uid;
  final ChatService service;

  String _format(int lastSeenMs) {
    if (lastSeenMs == 0) return 'offline';
    final diff    = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
    final minutes = diff ~/ 60000;
    if (minutes < 2)  return 'visto agora';
    if (minutes < 60) return 'visto há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24)   return 'visto há ${hours}h';
    return 'visto há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream:      service.userLastSeenStream(uid),
      initialData: 0,
      builder:     (_, snap) => Text(
        _format(snap.data ?? 0),
        style: TextStyle(
          fontFamily:    TClubTypography.bodyFont,
          fontSize:      9,
          letterSpacing: 0.5,
          color:         TClubColors.subtle.withOpacity(0.7))));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _OtherUserName — nome via stream (privado, usado apenas neste arquivo)
// ════════════════════════════════════════════════════════════════════════════
class _OtherUserName extends StatelessWidget {
  const _OtherUserName({required this.uid, this.bold = false});
  final String uid;
  final bool   bold;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream:  FirebaseDatabase.instance.ref('UsersPublic/$uid/name').onValue,
      builder: (_, snap) {
        final name = snap.data?.snapshot.value as String? ?? '...';
        return Text(name.toUpperCase(),
          style: TextStyle(
            fontFamily:  TClubTypography.bodyFont,
            fontSize:    13,
            fontWeight:  bold ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 1.5,
            color:       TClubColors.textoPrincipal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
      });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MessageBubble — balão de mensagem
// ════════════════════════════════════════════════════════════════════════════
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.otherUid,
    this.isLast = false,
  });

  final ChatMessage message;
  final bool        isMine;
  final String      otherUid;
  final bool        isLast;

  String _formatHour(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _readAgoText(int readAtMs) {
    final diff    = DateTime.now().millisecondsSinceEpoch - readAtMs;
    final seconds = diff ~/ 1000;
    if (seconds < 60)  return 'visto agora';
    final minutes = seconds ~/ 60;
    if (minutes < 60)  return 'visto há ${minutes}min';
    final hours   = minutes ~/ 60;
    if (hours   < 24)  return 'visto há ${hours}h';
    return 'visto há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    final isRead   = message.isReadBy(otherUid);
    final readAtMs = message.readAtBy(otherUid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.74),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [TClubColors.redDeep, Color(0xFF8B1A4A)],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight)
                      : null,
                  color:  isMine ? null : TClubColors.bgCard,
                  border: Border.all(
                    color: isMine
                        ? TClubColors.redPrincipal.withOpacity(0.25)
                        : TClubColors.border.withOpacity(0.6),
                    width: 0.6),
                  boxShadow: isMine
                      ? [BoxShadow(
                          color:      TClubColors.glow.withOpacity(0.15),
                          blurRadius: 10,
                          offset:     const Offset(0, 3))]
                      : null),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(message.text,
                          style: TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize:   14,
                            height:     1.45,
                            color: isMine
                                ? Colors.white
                                : TClubColors.textoPrincipal.withOpacity(0.92)))),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_formatHour(message.timestamp),
                          style: TextStyle(
                            fontFamily:    TClubTypography.bodyFont,
                            fontSize:      9,
                            letterSpacing: 0.5,
                            color: isMine
                                ? Colors.white.withOpacity(0.55)
                                : TClubColors.subtle)),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size:  12,
                          color: isRead
                              ? const Color(0xFF60A5FA)
                              : Colors.white.withOpacity(0.45)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ),
          if (isMine && isLast) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize:      MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRead) ...[
                    const Icon(Icons.done_all_rounded,
                        size: 10, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 4),
                    Text(
                      readAtMs != null ? _readAgoText(readAtMs) : 'visto',
                      style: const TextStyle(
                          fontFamily:    TClubTypography.bodyFont,
                          fontSize:      9,
                          letterSpacing: 0.5,
                          color:         Color(0xFF60A5FA))),
                  ] else ...[
                    Icon(Icons.done_rounded,
                        size: 10, color: TClubColors.subtle.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    Text('enviado', style: TextStyle(
                        fontFamily:    TClubTypography.bodyFont,
                        fontSize:      9,
                        letterSpacing: 0.5,
                        color:         TClubColors.subtle.withOpacity(0.6))),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DateSeparator — separador de data entre mensagens
// ════════════════════════════════════════════════════════════════════════════
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.timestamp});
  final int timestamp;

  String _label() {
    final dt  = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'HOJE';
    }
    if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
      return 'ONTEM';
    }
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(children: [
        Expanded(child: Container(height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.transparent, TClubColors.border])))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child:   Text(_label(), style: const TextStyle(
              fontFamily:    TClubTypography.bodyFont,
              fontSize:      8,
              letterSpacing: 2.5,
              color:         TClubColors.subtle))),
        Expanded(child: Container(height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [TClubColors.border, Colors.transparent])))),
      ]));
  }
}

