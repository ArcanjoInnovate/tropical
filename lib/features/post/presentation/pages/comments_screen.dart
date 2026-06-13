// lib/screens/screens_home/home_screen/posts/comments_screen.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/post/data/models/comment_model.dart';
import 'package:tabuapp/features/post/data/models/post_model.dart';
import 'package:tabuapp/features/profile/presentation/pages/profile/public_profile_screen.dart';
import 'package:tabuapp/core/services/cached_avatar.dart';
import 'package:tabuapp/features/post/data/services/post_service.dart';
import 'package:tabuapp/core/services/user_data_notifier.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  HELPER PÚBLICO
// ══════════════════════════════════════════════════════════════════════════════
Future<int?> showCommentsSheet(
  BuildContext context, {
  required PostModel post,
  required Map<String, dynamic> userData,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => _CommentsSheet(post: post, userData: userData),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHEET PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════
class _CommentsSheet extends StatefulWidget {
  final PostModel post;
  final Map<String, dynamic> userData;
  const _CommentsSheet({required this.post, required this.userData});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<CommentModel> _comments = [];
  bool _loadingComments = true;

  List<_LikeUser> _likers = [];
  bool _loadingLikers = true;
  int _likersVisible = 10;

  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;

  bool _isAdmin = false;

  String get _myUid =>
      widget.userData['uid'] as String? ??
      widget.userData['id'] as String? ??
      '';

  String get _myName => UserDataNotifier.instance.name.isNotEmpty
      ? UserDataNotifier.instance.name
      : (widget.userData['name'] as String? ?? 'Usuário');

  String? get _myAvatar => UserDataNotifier.instance.avatar.isNotEmpty
      ? UserDataNotifier.instance.avatar
      : widget.userData['avatar'] as String?;

  bool get _isOwnPost => _myUid.isNotEmpty && widget.post.userId == _myUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isOwnPost ? 2 : 1, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadComments();
    _checkAdmin();
    if (_isOwnPost) _loadLikers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    if (_myUid.isEmpty) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('Administratives/$_myUid')
          .get();
      if (mounted && snap.exists && snap.value == true) {
        setState(() => _isAdmin = true);
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final list = await PostService.instance.fetchComments(
        widget.post.id,
        myUid: _myUid,
      );
      if (mounted) {
        setState(() {
          _comments = list;
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _loadLikers() async {
    setState(() => _loadingLikers = true);
    try {
      DataSnapshot snap =
          await FirebaseDatabase.instance.ref('PostLikes/${widget.post.id}').get();

      if (!snap.exists || snap.value == null) {
        snap = await FirebaseDatabase.instance
            .ref('Posts/post/${widget.post.id}/liked_by')
            .get();
      }

      final list = <_LikeUser>[];
      if (snap.exists && snap.value is Map) {
        final raw = Map<dynamic, dynamic>.from(snap.value as Map);
        for (final entry in raw.entries) {
          if (entry.value == true) {
            list.add(_LikeUser(uid: entry.key as String));
          }
        }
      }
      if (mounted) {
        setState(() {
          _likers = list;
          _loadingLikers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLikers = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending || _myUid.isEmpty) return;
    setState(() => _sending = true);
    HapticFeedback.selectionClick();
    try {
      final comment = await PostService.instance.addComment(
        postId: widget.post.id,
        userId: _myUid,
        userName: _myName,
        userAvatar: _myAvatar,
        texto: text,
      );
      _textController.clear();
      FocusScope.of(context).unfocus();
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _abrirPerfil(String userId, String userName, String? userAvatar) {
    if (userId == _myUid) return;
    Navigator.pop(context, _comments.length);
    Future.microtask(() {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(
            userId: userId,
            userName: userName,
            userAvatar: userAvatar,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: TabuColors.bgAlt,
        border: Border(
            top: BorderSide(color: TabuColors.rosaPrincipal, width: 1.5)),
      ),
      child: Column(children: [
        Container(
          width: 36,
          height: 3,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
              color: TabuColors.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        _buildHeader(),
        if (_isOwnPost) _buildTabBar(),
        Expanded(
          child: _isOwnPost
              ? (_tabController.index == 0
                  ? _buildCommentsTab()
                  : _buildLikesTab())
              : _buildCommentsTab(),
        ),
        _buildCommentInput(bottom, keyboardHeight),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.post.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: TabuColors.textoPrincipal,
            ),
          ),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: TabuColors.subtle, size: 10),
            const SizedBox(width: 5),
            Text(
              '${_loadingComments ? '—' : _comments.length} comentários',
              style: const TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 10,
                letterSpacing: 0.5,
                color: TabuColors.subtle,
              ),
            ),
            if (_isOwnPost) ...[
              const SizedBox(width: 10),
              const Icon(Icons.favorite_border_rounded,
                  color: TabuColors.subtle, size: 10),
              const SizedBox(width: 5),
              Text(
                '${_loadingLikers ? '—' : _likers.length} curtidas',
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: TabuColors.subtle,
                ),
              ),
            ],
          ]),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context, _comments.length),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8),
            ),
            child:
                const Icon(Icons.close, color: TabuColors.subtle, size: 15),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: TabuColors.bgCard,
          border: Border.all(color: TabuColors.border, width: 0.8),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: TabuColors.rosaPrincipal,
          indicatorWeight: 2,
          labelColor: TabuColors.rosaPrincipal,
          unselectedLabelColor: TabuColors.subtle,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
              text:
                  'COMENTÁRIOS${_loadingComments ? '' : ' · ${_comments.length}'}',
            ),
            Tab(
              icon: const Icon(Icons.favorite_border_rounded, size: 14),
              text:
                  'CURTIDAS${_loadingLikers ? '' : ' · ${_likers.length}'}',
            ),
          ],
        ),
      ),
    );
  }

  // ── COMMENTS TAB ──────────────────────────────────────────────────────────

  Widget _buildCommentsTab() {
    if (_loadingComments) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              color: TabuColors.rosaPrincipal, strokeWidth: 1.5),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: TabuColors.border, size: 22),
          ),
          const SizedBox(height: 14),
          const Text('NENHUM COMENTÁRIO',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TabuColors.subtle,
              )),
          const SizedBox(height: 6),
          const Text('Seja o primeiro a comentar',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12,
                color: TabuColors.subtle,
              )),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      itemCount: _comments.length,
      separatorBuilder: (_, __) => Container(
        height: 0.5,
        color: TabuColors.border.withOpacity(0.5),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      itemBuilder: (_, i) => _CommentTile(
        comment: _comments[i],
        myUid: _myUid,
        postId: widget.post.id,
        isAdmin: _isAdmin,
        onDeleted: () => setState(() => _comments.removeAt(i)),
        onTapProfile: (uid, name, avatar) => _abrirPerfil(uid, name, avatar),
      ),
    );
  }

  // ── LIKES TAB ─────────────────────────────────────────────────────────────

  Widget _buildLikesTab() {
    if (_loadingLikers) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              color: TabuColors.rosaPrincipal, strokeWidth: 1.5),
        ),
      );
    }

    if (_likers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.8),
            ),
            child: const Icon(Icons.favorite_border_rounded,
                color: TabuColors.border, size: 22),
          ),
          const SizedBox(height: 14),
          const Text('NENHUMA CURTIDA',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: TabuColors.subtle,
              )),
          const SizedBox(height: 6),
          const Text('Ainda não há curtidas neste post',
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize: 12,
                color: TabuColors.subtle,
              )),
        ]),
      );
    }

    final visible = _likers.take(_likersVisible).toList();
    final hasMore = _likersVisible < _likers.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: visible.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          Container(height: 0.5, color: TabuColors.border.withOpacity(0.4)),
      itemBuilder: (_, i) {
        if (i == visible.length) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _likersVisible =
                    (_likersVisible + 10).clamp(0, _likers.length);
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              height: 44,
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.4),
                    width: 0.8),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.expand_more_rounded,
                    color: TabuColors.rosaPrincipal, size: 16),
                const SizedBox(width: 8),
                Text(
                  'VER MAIS ${(_likers.length - _likersVisible).clamp(0, 10)} DE ${_likers.length - _likersVisible}',
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: TabuColors.rosaPrincipal,
                  ),
                ),
              ]),
            ),
          );
        }

        return _LikeTile(
          uid: visible[i].uid,
          myUid: _myUid,
          onTap: (uid, name, avatar) => _abrirPerfil(uid, name, avatar),
        );
      },
    );
  }

  // ── COMMENT INPUT ─────────────────────────────────────────────────────────

  Widget _buildCommentInput(double safeBottom, double keyboardHeight) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
          bottom: keyboardHeight > 0 ? keyboardHeight : safeBottom),
      child: Container(
        decoration: const BoxDecoration(
          color: TabuColors.bgAlt,
          border:
              Border(top: BorderSide(color: TabuColors.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CachedAvatar(
            uid: _myUid,
            name: _myName,
            size: 34,
            radius: 9,
            isOwn: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: TabuColors.bgCard,
                border: Border.all(color: TabuColors.border, width: 0.8),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 13,
                  color: TabuColors.textoPrincipal,
                ),
                cursorColor: TabuColors.rosaPrincipal,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Adicionar comentário...',
                  hintStyle: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 13,
                    color: TabuColors.subtle,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _sendComment(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _sendComment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              color: _sending
                  ? TabuColors.rosaPrincipal.withOpacity(0.5)
                  : TabuColors.rosaPrincipal,
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 1.5),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 16),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMMENT TILE
//
//  Regras de permissão:
//   • Usuário comum  → só vê o "..." e pode excluir o PRÓPRIO comentário
//   • Admin          → vê o "..." em TODOS os comentários, com badge "AÇÃO ADMINISTRATIVA"
//
//  Estados visuais:
//   • _deleting     → semi-transparente + spinner (requisição em curso)
//   • _justDeleted  → visual "EXCLUÍDO" por 1.8s antes de sair da lista
// ══════════════════════════════════════════════════════════════════════════════
class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final String myUid;
  final String postId;
  final bool isAdmin;
  final VoidCallback onDeleted;
  final void Function(String uid, String name, String? avatar) onTapProfile;

  const _CommentTile({
    required this.comment,
    required this.myUid,
    required this.postId,
    required this.isAdmin,
    required this.onDeleted,
    required this.onTapProfile,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _deleting    = false;
  bool _justDeleted = false;

  bool get _isOwn => widget.comment.userId == widget.myUid;

  // ── Regra central de permissão ────────────────────────────────────────────
  // Um usuário comum só pode excluir o PRÓPRIO comentário.
  // Admin pode excluir qualquer um.
  bool get _canDelete =>
      !_deleting &&
      !_justDeleted &&
      !widget.comment.userDeleted &&
      (_isOwn || widget.isAdmin);

  bool get _isDeleted => widget.comment.userDeleted || _justDeleted;

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${(diff.inDays / 30).floor()}m';
  }

  Future<void> _executeDelete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    HapticFeedback.heavyImpact();

    try {
      await PostService.instance.deleteComment(
        widget.postId,
        widget.comment.id,
        // Passa isAdmin: true apenas quando é admin excluindo comentário ALHEIO.
        // Para o próprio comentário, sempre usa deleção direta (isAdmin: false),
        // pois as regras do Firebase já permitem ao dono deletar o próprio nó.
        isAdmin: widget.isAdmin && !_isOwn,
      );

      if (!mounted) return;

      setState(() {
        _deleting    = false;
        _justDeleted = true;
      });

      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) widget.onDeleted();
    } catch (e) {
      debugPrint('❌ [deleteComment] erro: $e');
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showDeleteConfirm(BuildContext context) {
    if (!_canDelete) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: TabuColors.bg,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Badge administrativo — visível apenas para admin em comentário alheio
          if (widget.isAdmin && !_isOwn)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: TabuColors.accent.withOpacity(0.6),
                      border: Border.all(
                          color: TabuColors.bg.withOpacity(0.5),
                          width: 0.8),
                    ),
                    child: const Text(
                      'AÇÃO ADMINISTRATIVA',
                      style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: TabuColors.branco,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(sheetCtx);
                _executeDelete();
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: TabuColors.bg.withOpacity(0.5),
                  border: Border.all(
                      color: TabuColors.accent.withOpacity(0.3),
                      width: 0.8),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFE85D5D), size: 16),
                      SizedBox(width: 8),
                      Text('EXCLUIR COMENTÁRIO',
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: Color(0xFFE85D5D),
                          )),
                    ]),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _isDeleted
        ? 'COMENTÁRIO EXCLUÍDO'
        : widget.comment.userName.toUpperCase();

    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Avatar ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _isOwn || _isDeleted
              ? null
              : () => widget.onTapProfile(
                  widget.comment.userId,
                  widget.comment.userName,
                  widget.comment.userAvatar),
          child: _isDeleted
              ? _buildDeletedAvatar()
              : CachedAvatar(
                  uid: widget.comment.userId,
                  name: widget.comment.userName,
                  size: 36,
                  radius: 9,
                  isOwn: _isOwn,
                  glowRing: _isOwn,
                ),
        ),
        const SizedBox(width: 12),

        // ── Bubble ──────────────────────────────────────────────────────
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              GestureDetector(
                onTap: _isOwn || _isDeleted
                    ? null
                    : () => widget.onTapProfile(
                        widget.comment.userId,
                        widget.comment.userName,
                        widget.comment.userAvatar),
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _isDeleted
                        ? TabuColors.subtle
                        : TabuColors.textoPrincipal,
                  ),
                ),
              ),

              // Badge "EXCLUÍDO"
              if (_isDeleted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D0A0A).withOpacity(0.5),
                    border: Border.all(
                        color: const Color(0xFFE85D5D).withOpacity(0.4),
                        width: 0.6),
                  ),
                  child: const Text('EXCLUÍDO',
                      style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xFFE85D5D),
                      )),
                ),
              ],

              // Badge "VOCÊ" (só quando não excluído)
              if (_isOwn && !_isDeleted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.12),
                    border: Border.all(
                        color: TabuColors.rosaPrincipal.withOpacity(0.4),
                        width: 0.6),
                  ),
                  child: const Text('VOCÊ',
                      style: TextStyle(
                        fontFamily: TabuTypography.bodyFont,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: TabuColors.rosaPrincipal,
                      )),
                ),
              ],

              const Spacer(),
              Text(
                _formatTime(widget.comment.createdAt),
                style: const TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 9,
                  color: TabuColors.subtle,
                ),
              ),

              // Botão "..." — visível apenas quando _canDelete = true
              // (próprio comentário OU admin)
              if (_canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showDeleteConfirm(context),
                  child: Icon(
                    Icons.more_horiz,
                    // Admin em comentário alheio → roxo; dono do próprio → cinza
                    color: widget.isAdmin && !_isOwn
                        ? const Color(0xFFB06AFF).withOpacity(0.7)
                        : TabuColors.border,
                    size: 14,
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _isDeleted
                    ? const Color(0xFF3D0A0A).withOpacity(0.3)
                    : _isOwn
                        ? TabuColors.rosaPrincipal.withOpacity(0.08)
                        : TabuColors.bgCard,
                border: Border.all(
                  color: _isDeleted
                      ? const Color(0xFFE85D5D).withOpacity(0.2)
                      : _isOwn
                          ? TabuColors.rosaPrincipal.withOpacity(0.2)
                          : TabuColors.border.withOpacity(0.6),
                  width: 0.6,
                ),
              ),
              child: Text(
                _justDeleted
                    ? 'Este comentário foi excluído.'
                    : widget.comment.texto,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 13,
                  color: _isDeleted
                      ? TabuColors.subtle.withOpacity(0.7)
                      : TabuColors.dim,
                  height: 1.45,
                  fontStyle:
                      _isDeleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );

    // ── Estado LOADING ────────────────────────────────────────────────────
    if (_deleting) {
      return GestureDetector(
        onLongPress: null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: 0.35, child: tile),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: TabuColors.bgCard.withOpacity(0.85),
                border: Border.all(
                    color: const Color(0xFFE85D5D).withOpacity(0.4),
                    width: 0.8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Color(0xFFE85D5D),
                    strokeWidth: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Estado NORMAL ou PÓS-DELETE ───────────────────────────────────────
    return GestureDetector(
      onLongPress: _canDelete ? () => _showDeleteConfirm(context) : null,
      child: tile,
    );
  }

  Widget _buildDeletedAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF3D0A0A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFE85D5D).withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: const Icon(
        Icons.person_off_outlined,
        color: Color(0xFFE85D5D),
        size: 18,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LIKE USER MODEL
// ══════════════════════════════════════════════════════════════════════════════
class _LikeUser {
  final String uid;
  const _LikeUser({required this.uid});
}

// ══════════════════════════════════════════════════════════════════════════════
//  LIKE TILE
// ══════════════════════════════════════════════════════════════════════════════
class _LikeTile extends StatefulWidget {
  final String uid;
  final String myUid;
  final void Function(String uid, String name, String? avatar) onTap;

  const _LikeTile({
    required this.uid,
    required this.myUid,
    required this.onTap,
  });

  @override
  State<_LikeTile> createState() => _LikeTileState();
}

class _LikeTileState extends State<_LikeTile> {
  String _name = '';
  String _avatar = '';
  String _bio = '';
  bool _loading = true;
  bool _userDeleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap =
          await FirebaseDatabase.instance.ref('UsersPublic/${widget.uid}').get();

      if (!snap.exists || snap.value == null) {
        if (mounted) {
          setState(() {
            _name = 'USUÁRIO EXCLUÍDO';
            _userDeleted = true;
            _loading = false;
          });
        }
        return;
      }

      if (mounted) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        setState(() {
          _name = data['name'] as String? ?? data['Name'] as String? ?? '';
          _avatar = data['avatar'] as String? ?? '';
          _bio = ((data['bio'] as String?) ?? '').trim();
          _userDeleted = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isMe => widget.uid == widget.myUid;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TabuColors.bgCard,
              border: Border.all(color: TabuColors.border, width: 0.6),
            ),
          ),
          const SizedBox(width: 14),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 11,
                  decoration: BoxDecoration(
                    color: TabuColors.border.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 9,
                  decoration: BoxDecoration(
                    color: TabuColors.border.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ]),
        ]),
      );
    }

    if (_name.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isMe || _userDeleted
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap(
                widget.uid,
                _name,
                _avatar.isNotEmpty ? _avatar : null,
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Stack(children: [
            _userDeleted
                ? Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D0A0A).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFE85D5D).withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      color: Color(0xFFE85D5D),
                      size: 20,
                    ),
                  )
                : CachedAvatar(
                    uid: widget.uid,
                    name: _name,
                    size: 42,
                    radius: 11,
                    isOwn: _isMe,
                  ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _userDeleted
                      ? const Color(0xFFE85D5D).withOpacity(0.8)
                      : TabuColors.rosaPrincipal,
                  shape: BoxShape.circle,
                  border: Border.all(color: TabuColors.bgAlt, width: 1.5),
                ),
                child: Icon(
                  _userDeleted ? Icons.close_rounded : Icons.favorite_rounded,
                  color: Colors.white,
                  size: 8,
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
                  child: Text(
                    _name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: _userDeleted
                          ? TabuColors.subtle
                          : TabuColors.textoPrincipal,
                    ),
                  ),
                ),
                if (_userDeleted) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D0A0A).withOpacity(0.5),
                      border: Border.all(
                          color: const Color(0xFFE85D5D).withOpacity(0.4),
                          width: 0.6),
                    ),
                    child: const Text('EXCLUÍDO',
                        style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Color(0xFFE85D5D),
                        )),
                  ),
                ],
                if (_isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: TabuColors.rosaPrincipal.withOpacity(0.12),
                      border: Border.all(
                          color: TabuColors.rosaPrincipal.withOpacity(0.4),
                          width: 0.6),
                    ),
                    child: const Text('VOCÊ',
                        style: TextStyle(
                          fontFamily: TabuTypography.bodyFont,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: TabuColors.rosaPrincipal,
                        )),
                  ),
                ],
              ]),
              if (_bio.isNotEmpty && !_userDeleted) ...[
                const SizedBox(height: 3),
                Text(
                  _bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 10,
                    color: TabuColors.subtle,
                  ),
                ),
              ],
              if (_userDeleted) ...[
                const SizedBox(height: 3),
                const Text(
                  'Este usuário não existe mais',
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFFE85D5D),
                  ),
                ),
              ],
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _userDeleted
                  ? const Color(0xFF3D0A0A).withOpacity(0.3)
                  : TabuColors.rosaPrincipal.withOpacity(0.08),
              border: Border.all(
                  color: _userDeleted
                      ? const Color(0xFFE85D5D).withOpacity(0.25)
                      : TabuColors.rosaPrincipal.withOpacity(0.25),
                  width: 0.6),
            ),
            child: Icon(
              _userDeleted ? Icons.close_rounded : Icons.favorite_rounded,
              color: _userDeleted
                  ? const Color(0xFFE85D5D)
                  : TabuColors.rosaPrincipal,
              size: 12,
            ),
          ),
        ]),
      ),
    );
  }
}