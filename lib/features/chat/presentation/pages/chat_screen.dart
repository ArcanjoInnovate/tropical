// lib/screens/screens_home/chat/chat_room_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/services/cached_avatar.dart';
import 'package:tclub/features/chat/controller/chat_controller.dart';
import 'package:tclub/core/providers/block_provider.dart';
import 'package:tclub/features/chat/data/repositories/chat_repository.dart';
import 'package:tclub/features/chat/data/services/chat_service.dart';
import 'package:tclub/features/chat/presentation/pages/chat_presence_manager.dart';
import 'package:tclub/features/user/moderation/moderation.dart';
import '../../../../core/theme/tclub_theme.dart';
import '../../data/models/chat_model.dart';
import 'package:tclub/features/profile/presentation/pages/profile/public_profile_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String myUid;
  final String otherUid;
  final String otherName;
  final String? otherAvatar;

  const ChatRoomScreen({
    super.key,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
    this.otherAvatar,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _showScrollBtn = false;
  bool _hasText = false;
  bool _isLoadingMore = false;
  bool _initialScrollDone = false;
  int _prevCount = 0;

  ChatPresenceManager? _presenceManager;

  String get _chatId {
    final ids = [widget.myUid, widget.otherUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scroll.hasClients) _scrollToBottom();
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scroll.hasClients) _scrollToBottom();
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _scroll.hasClients) _scrollToBottom();
        });
      }
    });

    _presenceManager = ChatPresenceManager(
      chatId: _chatId,
      myUid: widget.myUid,
      service: ChatService(repository: ChatRepository()),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
      _setupScrollListener();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _presenceManager?.resume();
        if (mounted) {
          context.read<ChatController>().markAsRead();
          _clearChatNotifications();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _presenceManager?.pause();
        break;
      case AppLifecycleState.detached:
        _presenceManager?.stop();
        break;
      case AppLifecycleState.hidden:
        _presenceManager?.pause();
        break;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scroll.hasClients) _scrollToBottom();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _scroll.hasClients) _scrollToBottom();
      });
    }
  }

  Future<void> _init() async {
    if (!mounted) return;
    await _presenceManager?.start();
    final ctrl = context.read<ChatController>();
    await ctrl.initialize(myUid: widget.myUid, otherUid: widget.otherUid);
    await _clearChatNotifications();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
        _initialScrollDone = true;
      });
    }
  }

  Future<void> _clearChatNotifications() async {
    try {
      final db = FirebaseDatabase.instance;
      final uid = widget.myUid;
      final ref = db.ref('Notifications/$uid');
      final snap = await ref.orderByChild('target_id').equalTo(_chatId).get();
      if (!snap.exists) return;
      final updates = <String, Object?>{};
      for (var child in snap.children) {
        final val = child.value as Map<dynamic, dynamic>?;
        if (val != null && val['type'] == 'chat_message') {
          updates['Notifications/$uid/${child.key}'] = null;
        }
      }
      if (updates.isEmpty) return;
      await db.ref().update(updates);
      await _recalcNotifBadge(uid);
    } catch (e) {
      debugPrint('[ChatRoomScreen] _clearChatNotifications error: $e');
    }
  }

  Future<void> _recalcNotifBadge(String uid) async {
    try {
      final snap =
          await FirebaseDatabase.instance.ref('Notifications/$uid').get();
      int count = 0;
      if (snap.exists) {
        for (final child in snap.children) {
          final val = child.value as Map<dynamic, dynamic>?;
          if (val != null && val['read'] == false) count++;
        }
      }
      await FirebaseDatabase.instance
          .ref('Users/$uid/unreadNotificationsCount')
          .set(count);
    } catch (e) {
      debugPrint('[ChatRoomScreen] _recalcNotifBadge error: $e');
    }
  }

  void _setupScrollListener() {
    _scroll.addListener(() {
      if (!mounted) return;
      final atBottom =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
      if (_showScrollBtn == atBottom) {
        setState(() => _showScrollBtn = !atBottom);
      }
      if (_scroll.position.pixels <= 80 && !_isLoadingMore) {
        _isLoadingMore = true;
        context
            .read<ChatController>()
            .loadMore()
            .then((_) => _isLoadingMore = false);
      }
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(max,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(max);
    }
  }

  bool get _isNearBottom {
    if (!_scroll.hasClients) return true;
    return (_scroll.position.maxScrollExtent - _scroll.position.pixels) <= 160;
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    _textCtrl.clear();
    setState(() => _hasText = false);
    await context.read<ChatController>().send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scroll.hasClients) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scroll.hasClients) _scrollToBottom();
    });
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TClubColors.bg,
        shape: const RoundedRectangleBorder(),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: TClubColors.errorPale,
              border: Border.all(color: TClubColors.errorBorder, width: 0.8),
            ),
            child: Icon(Icons.lock_outline_rounded,
                color: TClubColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Bloquear Usuário',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: TClubColors.textoPrincipal,
              )),
        ]),
        content: Text(
          'Você tem certeza que deseja bloquear este usuário? '
          'Ele não poderá mais interagir com você.',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 13,
            height: 1.5,
            color: TClubColors.textoSecundario,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    color: TClubColors.textoMuted,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeBlock();
            },
            child: Text('Bloquear',
                style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    color: TClubColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBlock() async {
    final blockProvider = context.read<BlockProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    await blockProvider.blockUser(widget.otherUid);
    if (mounted) Navigator.of(context).pop();
  }

  void _abrirMenuOpcoes() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _ChatOptionsSheet(
        otherName: widget.otherName,
        onDenunciar: () {
          Navigator.pop(context);
          ReportPage.push(
            context,
            config: ReportPageConfig.chat(
              chatId: _chatId,
              reportedUid: widget.otherUid,
              reportedName: widget.otherName,
            ),
          );
        },
        onBloquear: () {
          Navigator.pop(context);
          _showBlockDialog();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: TClubColors.bg,
      body: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TClubColors.redDeep,
                TClubColors.redPrincipal,
                TClubColors.redClaro,
                TClubColors.redPrincipal,
                TClubColors.redDeep,
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            _buildAppBar(),
            Expanded(child: Consumer<ChatController>(
              builder: (context, ctrl, _) {
                if (ctrl.isLoading) return _buildLoading();
                if (ctrl.error != null) return _buildError(ctrl.error!);
                final count = ctrl.messages.length;
                if (_initialScrollDone && count > _prevCount) {
                  _prevCount = count;
                  if (_isNearBottom) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                  }
                } else {
                  _prevCount = count;
                }
                return Stack(children: [
                  ctrl.messages.isEmpty ? _buildEmpty() : _buildList(ctrl),
                  if (_showScrollBtn) _buildScrollBtn(),
                ]);
              },
            )),
            _buildInput(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAppBar() {
    return Consumer<ChatController>(builder: (_, ctrl, __) {
      final status = ctrl.otherStatus;
      final isOnline = status?.isOnline ?? false;

      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: TClubColors.bg,
          border: Border(
            bottom: BorderSide(color: TClubColors.border, width: 0.5),
          ),
        ),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: TClubColors.dim, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(
                    userId: widget.otherUid,
                    userName: widget.otherName,
                  ),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  CachedAvatar(
                      uid: widget.otherUid,
                      name: widget.otherName,
                      size: 40,
                      radius: 6),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: TClubColors.bg, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.otherName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: TClubColors.textoPrincipal,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      isOnline ? 'ONLINE AGORA' : _lastSeenText(status),
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color:
                            isOnline ? const Color(0xFF22C55E) : TClubColors.subtle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _abrirMenuOpcoes,
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: TClubColors.border, width: 0.8),
              ),
              child: const Icon(Icons.more_horiz,
                  color: TClubColors.subtle, size: 15),
            ),
          ),
        ]),
      );
    });
  }

  String _lastSeenText(ParticipantStatus? status) {
    if (status == null) return 'OFFLINE';
    final diff = DateTime.now().millisecondsSinceEpoch - status.lastSeen;
    final minutes = diff ~/ 60000;
    if (minutes < 1) return 'VIU AGORA';
    if (minutes < 60) return 'VIU HÁ ${minutes}MIN';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'VIU HÁ ${hours}H';
    return 'OFFLINE';
  }

  Widget _buildList(ChatController ctrl) {
    final msgs = ctrl.messages;
    int lastMineIdx = -1;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (ctrl.isMine(msgs[i])) {
        lastMineIdx = i;
        break;
      }
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: msgs.length + (ctrl.isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (ctrl.isLoadingMore && i == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: TClubColors.redPrincipal),
              ),
            ),
          );
        }
        final idx = ctrl.isLoadingMore ? i - 1 : i;
        final msg = msgs[idx];
        final mine = ctrl.isMine(msg);
        Widget? sep;
        if (idx == 0 || _differentDay(msgs[idx - 1].timestamp, msg.timestamp)) {
          sep = _buildDateSeparator(msg.timestamp);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sep != null) sep,
            _MessageBubble(
              message: msg,
              isMine: mine,
              otherUid: widget.otherUid,
              isLast: mine && idx == lastMineIdx,
            ),
          ],
        );
      },
    );
  }

  bool _differentDay(int a, int b) {
    final da = DateTime.fromMillisecondsSinceEpoch(a);
    final db = DateTime.fromMillisecondsSinceEpoch(b);
    return da.day != db.day || da.month != db.month || da.year != db.year;
  }

  Widget _buildDateSeparator(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    String label;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      label = 'HOJE';
    } else if (dt.day == now.day - 1 &&
        dt.month == now.month &&
        dt.year == now.year) {
      label = 'ONTEM';
    } else {
      label =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.transparent, TClubColors.border]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label,
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 8,
                letterSpacing: 2.5,
                color: TClubColors.subtle,
              )),
        ),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [TClubColors.border, Colors.transparent]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildInput() {
    return Consumer<ChatController>(builder: (_, ctrl, __) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: TClubColors.bg,
          border: Border(
            top: BorderSide(color: TClubColors.border, width: 0.5),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: TClubColors.bgCard,
                border: Border.all(
                  color: _hasText
                      ? TClubColors.redPrincipal.withOpacity(0.5)
                      : TClubColors.border,
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                enabled: !ctrl.isSending,
                maxLines: null,
                style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 14,
                  color: TClubColors.textoPrincipal,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Mensagem...',
                  hintStyle: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: TClubColors.subtle,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _hasText && !ctrl.isSending ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _hasText
                    ? const LinearGradient(
                        colors: [TClubColors.redDeep, TClubColors.redPrincipal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _hasText ? null : TClubColors.bgCard,
                border: Border.all(
                  color: _hasText
                      ? TClubColors.redPrincipal.withOpacity(0.3)
                      : TClubColors.border,
                  width: 0.8,
                ),
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: TClubColors.glow.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ctrl.isSending
                  ? const Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: TClubColors.redPrincipal),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: _hasText ? Colors.white : TClubColors.subtle,
                    ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildLoading() => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: TClubColors.redPrincipal),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.3), width: 0.8),
            ),
            child: const Icon(Icons.mark_chat_unread_outlined,
                color: TClubColors.redPrincipal, size: 26),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TClubColors.redPrincipal.withOpacity(0.08),
              border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.3), width: 0.7),
            ),
            child: const Text('CHAT AINDA NÃO ABERTO',
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: TClubColors.redPrincipal,
                )),
          ),
          const SizedBox(height: 14),
          Text(
            'Seja o primeiro a dizer oi para\n${widget.otherName.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 12,
              letterSpacing: 0.3,
              color: TClubColors.dim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: TClubColors.subtle, size: 20),
        ]),
      );

  Widget _buildError(String msg) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded,
              color: TClubColors.redPrincipal, size: 32),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 12,
                color: TClubColors.dim,
              )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _init,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: TClubColors.redPrincipal.withOpacity(0.5),
                    width: 0.8),
              ),
              child: const Text('TENTAR NOVAMENTE',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 9,
                    letterSpacing: 2.5,
                    color: TClubColors.redPrincipal,
                  )),
            ),
          ),
        ]),
      );

  Widget _buildScrollBtn() => Positioned(
        right: 16,
        bottom: 16,
        child: GestureDetector(
          onTap: _scrollToBottom,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.4), width: 0.8),
              boxShadow: [
                BoxShadow(
                    color: TClubColors.glow.withOpacity(0.15), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                color: TClubColors.redPrincipal, size: 20),
          ),
        ),
      );

  @override
  void dispose() {
    _presenceManager?.stop();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHEET DE OPÇÕES
// ══════════════════════════════════════════════════════════════════════════════
class _ChatOptionsSheet extends StatelessWidget {
  final String otherName;
  final VoidCallback onDenunciar;
  final VoidCallback onBloquear;

  const _ChatOptionsSheet({
    required this.otherName,
    required this.onDenunciar,
    required this.onBloquear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: TClubColors.bgAlt),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32,
            height: 2,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: TClubColors.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Container(
            height: 1.5,
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TClubColors.redDeep,
                TClubColors.redPrincipal,
                TClubColors.redClaro,
                TClubColors.redPrincipal,
                TClubColors.redDeep,
                Colors.transparent,
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TClubColors.bgCard,
                  border: Border.all(color: TClubColors.border, width: 0.8),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    color: TClubColors.subtle, size: 13),
              ),
              const SizedBox(width: 10),
              Text(otherName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: TClubColors.subtle,
                  )),
            ]),
          ),
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                TClubColors.border,
                Colors.transparent,
              ]),
            ),
          ),
          // ── Denunciar ─────────────────────────────────────────────────────
          _OptionTile(
            icon: Icons.flag_outlined,
            label: 'DENUNCIAR CONVERSA',
            sublabel: 'Assédio, conteúdo impróprio, ameaças ou golpe',
            onTap: onDenunciar,
          ),
          const SizedBox(height: 4),
          // ── Bloquear ──────────────────────────────────────────────────────
          _OptionTile(
            icon: Icons.block_rounded,
            label: 'BLOQUEAR USUÁRIO',
            sublabel: 'Impede toda interação com este usuário',
            onTap: onBloquear,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              height: 44,
              decoration: BoxDecoration(
                color: TClubColors.bgCard,
                border: Border.all(color: TClubColors.border, width: 0.8),
              ),
              child: const Center(
                child: Text('CANCELAR',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: TClubColors.subtle,
                    )),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TClubColors.errorPale,
          border: Border.all(color: TClubColors.errorBorder, width: 0.7),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: TClubColors.bg,
              border: Border.all(color: TClubColors.errorBorder, width: 0.7),
            ),
            child: Icon(icon, color: TClubColors.error, size: 14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: TClubColors.errorDeep,
                    )),
                const SizedBox(height: 2),
                Text(sublabel,
                    style: const TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: TClubColors.subtle,
                    )),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: TClubColors.error, size: 16),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MESSAGE BUBBLE
// ══════════════════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final String otherUid;
  final bool isLast;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.otherUid,
    this.isLast = false,
  });

  String _formatHour(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _readAgoText(int readAtMs) {
    final diff = DateTime.now().millisecondsSinceEpoch - readAtMs;
    final seconds = diff ~/ 1000;
    if (seconds < 60) return 'visto agora';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return 'visto há ${minutes}min';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'visto há ${hours}h';
    return 'visto há ${hours ~/ 24}d';
  }

  @override
  Widget build(BuildContext context) {
    final isRead = message.isReadBy(otherUid);
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
                  // Minha mensagem: gradiente vinho escuro
                  // Mensagem do outro: bgCard (blush suave do tema)
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [TClubColors.redDeep, Color(0xFF8B1A4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMine ? null : TClubColors.bgCard,
                  border: Border.all(
                    color: isMine
                        ? TClubColors.redPrincipal.withOpacity(0.25)
                        : TClubColors.border,
                    width: 0.6,
                  ),
                  boxShadow: isMine
                      ? [
                          BoxShadow(
                            color: TClubColors.glow.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message.text,
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 14,
                          height: 1.45,
                          // Minha msg: branco sobre fundo escuro
                          // Outra msg: textoPrincipal sobre bgCard claro
                          color:
                              isMine ? Colors.white : TClubColors.textoPrincipal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _formatHour(message.timestamp),
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: isMine
                              ? Colors.white.withOpacity(0.55)
                              : TClubColors.subtle,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 12,
                          color: isRead
                              ? const Color(0xFF60A5FA)
                              : Colors.white.withOpacity(0.45),
                        ),
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
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRead) ...[
                    const Icon(Icons.done_all_rounded,
                        size: 10, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 4),
                    Text(
                      readAtMs != null ? _readAgoText(readAtMs) : 'visto',
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.done_rounded,
                        size: 10, color: TClubColors.subtle),
                    const SizedBox(width: 4),
                    Text('enviado',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: TClubColors.subtle,
                        )),
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

