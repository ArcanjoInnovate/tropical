// lib/features/chat/presentation/widgets/chat_tile_list.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/chat/data/models/chat_model.dart';
import 'package:tabuapp/features/chat/data/repositories/chat_repository.dart';
import 'package:tabuapp/features/chat/data/services/chat_service.dart';
import 'package:tabuapp/features/chat/presentation/widgets/chat_tile.dart';

class ChatTileList extends StatefulWidget {
  final List<String> chatIds;
  final String myUid;
  final void Function(TabuChat chat, String otherUid) onTap;

  const ChatTileList({
    super.key,
    required this.chatIds,
    required this.myUid,
    required this.onTap,
  });

  @override
  State<ChatTileList> createState() => _ChatTileListState();
}

class _ChatTileListState extends State<ChatTileList> {
  final Map<String, TabuChat> _chats = {};
  final Map<String, StreamSubscription<TabuChat?>> _subs = {};
  late final ChatService _chatService;

  bool _blockedExpanded = false;
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(repository: ChatRepository());
    _subscribeAll(widget.chatIds);
    _startTimeout();
  }

  @override
  void didUpdateWidget(ChatTileList old) {
    super.didUpdateWidget(old);
    final removed = old.chatIds.toSet().difference(widget.chatIds.toSet());
    final added = widget.chatIds.toSet().difference(old.chatIds.toSet());

    for (final id in removed) {
      _subs[id]?.cancel();
      _subs.remove(id);
      _chats.remove(id);
    }

    if (added.isNotEmpty) {
      _subscribeAll(added.toList());
      if (_chats.isEmpty) {
        _timedOut = false;
        _startTimeout();
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted && _chats.isEmpty) {
        setState(() => _timedOut = true);
      }
    });
  }

  void _subscribeAll(List<String> ids) {
    for (final id in ids) {
      if (_subs.containsKey(id)) continue;
      _subs[id] = _chatService.singleChatStream(id).listen((chat) {
        if (chat != null && mounted) {
          _timeoutTimer?.cancel();
          setState(() {
            _chats[id] = chat;
            _timedOut = false;
          });
        }
      });
    }
  }

  List<TabuChat> get _matchChats => _chats.values
      .where((c) => !c.blockDialog && c.isFromMatch)
      .toList()
    ..sort((a, b) => b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp));

  List<TabuChat> get _normalChats => _chats.values
      .where((c) => !c.blockDialog && !c.isFromMatch)
      .toList()
    ..sort((a, b) => b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp));

  List<TabuChat> get _blockedChats => _chats.values
      .where((c) => c.blockDialog)
      .toList()
    ..sort((a, b) => b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp));

  @override
  Widget build(BuildContext context) {
    final all = _chats.values.toList();

    if (all.isEmpty && !_timedOut) return const _ChatListLoading();
    if (all.isEmpty && _timedOut) return const _ChatListEmpty();

    final activeChats = [..._matchChats, ..._normalChats];

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (_matchChats.isNotEmpty) ...[
          const _SectionLabel(
            icon: Icons.favorite_rounded,
            label: 'MATCHS',
          ),
          ..._matchChats.map((chat) => ChatTile(
                key: ValueKey(chat.chatId),
                chat: chat,
                myUid: widget.myUid,
                onTap: () => widget.onTap(chat, chat.otherUserId(widget.myUid)),
              )),
        ],

        if (_normalChats.isNotEmpty) ...[
          if (_matchChats.isNotEmpty)
            const _SectionLabel(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'CONVERSAS',
            ),
          ..._normalChats.map((chat) => ChatTile(
                key: ValueKey(chat.chatId),
                chat: chat,
                myUid: widget.myUid,
                onTap: () => widget.onTap(chat, chat.otherUserId(widget.myUid)),
              )),
        ],

        if (activeChats.isEmpty && _blockedChats.isNotEmpty)
          const _NoActiveChatsMessage(),

        if (_blockedChats.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BlockedSectionHeader(
            count: _blockedChats.length,
            expanded: _blockedExpanded,
            onToggle: () =>
                setState(() => _blockedExpanded = !_blockedExpanded),
          ),
          if (_blockedExpanded) ...[
            ..._blockedChats.map((chat) => ChatTile(
                  key: ValueKey('blocked_${chat.chatId}'),
                  chat: chat,
                  myUid: widget.myUid,
                  onTap: () =>
                      widget.onTap(chat, chat.otherUserId(widget.myUid)),
                )),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ChatListLoading extends StatelessWidget {
  const _ChatListLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: TabuColors.rosaPrincipal,
        ),
      ),
    );
  }
}

class _ChatListEmpty extends StatelessWidget {
  const _ChatListEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: TabuColors.border, width: 0.8),
              color: TabuColors.bgCard,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: TabuColors.border,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'NENHUMA CONVERSA AINDA',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.5,
              color: TabuColors.subtle,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Visite perfis e envie mensagens',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12,
              letterSpacing: 0.3,
              color: TabuColors.dim,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveChatsMessage extends StatelessWidget {
  const _NoActiveChatsMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 40,
          color: TabuColors.border,
        ),
        const SizedBox(height: 12),
        const Text(
          'NENHUMA CONVERSA ATIVA',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: TabuColors.subtle,
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        Icon(icon, size: 12, color: TabuColors.rosaPrincipal),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: TabuColors.subtle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                TabuColors.border.withOpacity(0.5),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BlockedSectionHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  const _BlockedSectionHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.05),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFDC2626).withOpacity(0.2),
              width: 0.6,
            ),
            bottom: BorderSide(
              color: expanded
                  ? const Color(0xFFDC2626).withOpacity(0.15)
                  : Colors.transparent,
              width: 0.6,
            ),
          ),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.10),
              border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.35),
                width: 0.7,
              ),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 14,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              const Text(
                'BLOQUEADOS',
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.12),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.4),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ]),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFFDC2626).withOpacity(0.6),
              size: 18,
            ),
          ),
        ]),
      ),
    );
  }
}