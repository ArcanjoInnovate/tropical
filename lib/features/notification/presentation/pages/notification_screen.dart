// lib/screens/screens_home/notifications_screen/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/notification/data/models/notification_model.dart';
import 'package:tabuapp/core/services/cached_avatar.dart';
import 'package:tabuapp/features/notification/data/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String myUid;

  const NotificationsScreen({super.key, required this.myUid});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list =
        await NotificationService.instance.fetchNotifications(widget.myUid);
    if (mounted) setState(() { _notifications = list; _loading = false; });
    // Marca todas como lidas ao abrir
    await NotificationService.instance.markAllAsRead(widget.myUid);
  }

  Future<void> _delete(NotificationModel n) async {
    HapticFeedback.selectionClick();
    await NotificationService.instance
        .deleteNotification(widget.myUid, n.id);
    if (mounted) setState(() => _notifications.remove(n));
  }

  Future<void> _deleteAll() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 3,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
                color: TabuColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Text('LIMPAR TUDO?', style: TextStyle(
            fontFamily: TabuTypography.displayFont, fontSize: 14,
            letterSpacing: 4, color: TabuColors.textoPrincipal,
          )),
          const SizedBox(height: 8),
          const Text('Remove todas as notificações permanentemente.',
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: 12, color: TabuColors.subtle)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(height: 46,
                  decoration: BoxDecoration(color: TabuColors.bgCard,
                      border: Border.all(color: TabuColors.border, width: 0.8)),
                  child: const Center(child: Text('CANCELAR',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5, color: TabuColors.dim)))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(height: 46, color: const Color(0xFFE85D5D),
                  child: const Center(child: Text('LIMPAR',
                      style: TextStyle(fontFamily: TabuTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5, color: Colors.white)))),
              )),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      await NotificationService.instance.deleteAllNotifications(widget.myUid);
      if (mounted) setState(() => _notifications.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        // Linha neon no topo
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, TabuColors.rosaDeep,
                TabuColors.rosaPrincipal, TabuColors.rosaClaro,
                TabuColors.rosaPrincipal, TabuColors.rosaDeep, Colors.transparent,
              ])))),
        SafeArea(child: Column(children: [
          // ── App Bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: TabuColors.dim, size: 16),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('NOTIFICAÇÕES', style: TextStyle(
                fontFamily: TabuTypography.bodyFont, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 3,
                color: TabuColors.subtle,
              )),
              const Spacer(),
              if (_notifications.isNotEmpty)
                GestureDetector(
                  onTap: _deleteAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: TabuColors.bgCard,
                      border: Border.all(
                          color: const Color(0xFFE85D5D).withOpacity(0.4),
                          width: 0.8)),
                    child: const Text('LIMPAR', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 2,
                      color: Color(0xFFE85D5D),
                    )),
                  ),
                ),
            ]),
          ),
          Container(
              height: 0.5,
              color: TabuColors.border,
              margin: const EdgeInsets.only(top: 10)),

          // ── Conteúdo ───────────────────────────────────────────────────
          Expanded(child: _loading
              ? const Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: TabuColors.rosaPrincipal, strokeWidth: 1.5)))
              : _notifications.isEmpty
                  ? _buildVazio()
                  : RefreshIndicator(
                      color: TabuColors.rosaPrincipal,
                      backgroundColor: TabuColors.bgAlt,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => Container(
                            height: 0.5, color: TabuColors.border),
                        itemBuilder: (_, i) => _NotificationTile(
                          notification: _notifications[i],
                          onDelete: () => _delete(_notifications[i]),
                        ),
                      ),
                    )),
        ])),
      ]),
    );
  }

  Widget _buildVazio() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: TabuColors.bgCard,
            border: Border.all(color: TabuColors.border, width: 0.8)),
        child: const Icon(Icons.notifications_none_rounded,
            color: TabuColors.border, size: 28)),
      const SizedBox(height: 18),
      const Text('SEM NOTIFICAÇÕES', style: TextStyle(
        fontFamily: TabuTypography.bodyFont, fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: 4, color: TabuColors.subtle,
      )),
      const SizedBox(height: 6),
      const Text('Suas notificações aparecerão aqui',
          style: TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 12, color: TabuColors.border)),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION TILE
// ══════════════════════════════════════════════════════════════════════════════
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onDelete,
  });

  // ── Configuração visual por tipo ──────────────────────────────────────────
  _TileConfig get _config {
    switch (notification.type) {
      case 'follow':
        return _TileConfig(
          icon: Icons.people_rounded,
          color: TabuColors.rosaPrincipal,
          badge: 'SEGUIDOR',
        );
      case 'like':
        return _TileConfig(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE85D5D),
          badge: 'CURTIDA',
        );
      case 'comment':
        return _TileConfig(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF4ECDC4),
          badge: 'COMENTÁRIO',
        );
      case 'party':
        return _TileConfig(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF8C00),
          badge: 'FESTA',
        );
      default:
        return _TileConfig(
          icon: Icons.notifications_rounded,
          color: TabuColors.subtle,
          badge: 'AVISO',
        );
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}sem';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final isUnread = !notification.read;
    final hasCount = notification.count > 1;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFF3D0A0A),
        child: const Icon(Icons.delete_outline_rounded,
            color: Color(0xFFE85D5D), size: 20),
      ),
      child: Container(
        color: isUnread
            ? cfg.color.withOpacity(0.03)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Avatar / Ícone ─────────────────────────────────────────────
          Stack(children: [
            notification.actorUid != null
                ? CachedAvatar(
                    uid: notification.actorUid!,
                    name: notification.actorName ?? '',
                    size: 46, radius: 12,
                  )
                : Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.12),
                      border: Border.all(
                          color: cfg.color.withOpacity(0.4), width: 0.8),
                    ),
                    child: Icon(cfg.icon, color: cfg.color, size: 20),
                  ),
            // Badge do tipo
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: cfg.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: TabuColors.bg, width: 1.5),
                ),
                child: Icon(cfg.icon, color: Colors.white, size: 9),
              ),
            ),
          ]),

          const SizedBox(width: 12),

          // ── Conteúdo ───────────────────────────────────────────────────
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título + badge + tempo
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.12),
                    border: Border.all(
                        color: cfg.color.withOpacity(0.4), width: 0.6),
                  ),
                  child: Text(cfg.badge, style: TextStyle(
                    fontFamily: TabuTypography.bodyFont, fontSize: 7,
                    fontWeight: FontWeight.w700, letterSpacing: 2,
                    color: cfg.color,
                  )),
                ),
                // Contador agrupado
                if (hasCount) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.08),
                      border: Border.all(
                          color: cfg.color.withOpacity(0.3), width: 0.6),
                    ),
                    child: Text('×${notification.count}', style: TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 8,
                      fontWeight: FontWeight.w700, letterSpacing: 1,
                      color: cfg.color.withOpacity(0.8),
                    )),
                  ),
                ],
                const Spacer(),
                Text(_formatTime(notification.createdAt),
                    style: const TextStyle(
                      fontFamily: TabuTypography.bodyFont, fontSize: 9,
                      color: TabuColors.border,
                    )),
                // Bolinha de não lida
                if (isUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: cfg.color, shape: BoxShape.circle),
                  ),
                ],
              ]),
              const SizedBox(height: 6),

              // Corpo da notificação
              Text(notification.body, style: const TextStyle(
                fontFamily: TabuTypography.bodyFont, fontSize: 13,
                color: TabuColors.dim, height: 1.4,
              )),

              // Avatares múltiplos (quando agrupado)
              if (notification.actorUids.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: Stack(children: [
                    ...List.generate(
                      notification.actorUids.take(5).length,
                      (i) => Positioned(
                        left: i * 16.0,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: TabuColors.bg, width: 1.5),
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(child: CachedAvatar(
                            uid: notification.actorUids[i],
                            name: '',
                            size: 24, radius: 12,
                          )),
                        ),
                      ),
                    ),
                    if (notification.actorUids.length > 5)
                      Positioned(
                        left: 5 * 16.0,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: cfg.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: TabuColors.bg, width: 1.5),
                          ),
                          child: Center(child: Text(
                            '+${notification.actorUids.length - 5}',
                            style: const TextStyle(
                              fontFamily: TabuTypography.bodyFont,
                              fontSize: 7, fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )),
                        ),
                      ),
                  ]),
                ),
              ],
            ],
          )),
        ]),
      ),
    );
  }
}

class _TileConfig {
  final IconData icon;
  final Color color;
  final String badge;
  const _TileConfig(
      {required this.icon, required this.color, required this.badge});
}