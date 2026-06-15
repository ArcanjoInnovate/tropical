// lib/services/notification_handler.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/controllers/tclub_shell_controller.dart';
import 'package:tclub/features/chat/presentation/pages/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationHandler] Background message: ${message.messageId}');
}

class NotificationHandler {
  NotificationHandler._();

  static bool _initialized = false;

  static Future<void> init(
    BuildContext context, {
    required Map<String, dynamic> userData,
  }) async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _saveToken(userData['uid'] as String);

    messaging.onTokenRefresh.listen((newToken) {
      _updateToken(userData['uid'] as String, newToken);
    });

    // Foreground
    FirebaseMessaging.onMessage.listen((message) {
      _handleForegroundMessage(context, message, userData);
    });

    // Background (app não encerrado) — usuário tocou na notificação
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[NotificationHandler] onMessageOpenedApp: ${message.data}');
      _navigate(context, message.data, userData);
    });

    debugPrint('[NotificationHandler] Initialized uid=${userData['uid']}');
  }

  static Future<void> clearOnLogout() async {
    try {
      _initialized = false;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseDatabase.instance
            .ref('Users/${currentUser.uid}/fcmToken')
            .remove();
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[NotificationHandler] clearOnLogout error: $e');
    }
  }

  /// App encerrado — usuário tocou na notificação.
  ///
  /// Estratégia: configura o destino no [TclubShellController] ANTES do delay.
  /// O [TabuShell] lê esse estado no [addPostFrameCallback] do initState e
  /// navega corretamente já dentro do shell (com bottom nav bar visível).
  static Future<void> handleInitialMessage(
    BuildContext context, {
    required Map<String, dynamic> userData,
  }) async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;

    debugPrint('[NotificationHandler] getInitialMessage: ${initial.data}');

    final type = initial.data['type'] as String? ?? '';

    // Define o destino no controller IMEDIATAMENTE (antes do shell montar).
    // O TabuShell vai ler e aplicar no addPostFrameCallback.
    switch (type) {
      case 'chat_request':
        TclubShellController.instance.openChatList(listTab: 1);
        break;
      case 'chat_accepted':
      case 'chat_message':
        TclubShellController.instance.openChatList(listTab: 0);
        break;
      case 'party':
        // Nova festa: abre Home e agenda abertura do modal
        final partyId = initial.data['targetId'] as String?;
        if (partyId != null && partyId.isNotEmpty) {
          TclubShellController.instance.openPartyDetail(partyId);
        }
        break;
      default:
        TclubShellController.instance.setTabIndex(0);
    }

    // Para chat_message, adicionalmente empurra o ChatRoom.
    // Aguarda o context estar pronto.
    if (type == 'chat_message') {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!context.mounted) return;
      _navigateChatMessage(context, initial.data, userData);
    }
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static Future<void> _saveToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseDatabase.instance.ref('Users/$uid/fcmToken').set(token);
        debugPrint('[NotificationHandler] Token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('[NotificationHandler] _saveToken error: $e');
    }
  }

  static Future<void> _updateToken(String uid, String token) async {
    if (uid.isEmpty) return;
    try {
      await FirebaseDatabase.instance.ref('Users/$uid/fcmToken').set(token);
    } catch (e) {
      debugPrint('[NotificationHandler] _updateToken error: $e');
    }
  }

  // ── Foreground ─────────────────────────────────────────────────────────────
  static void _handleForegroundMessage(
    BuildContext context,
    RemoteMessage message,
    Map<String, dynamic> userData,
  ) {
    final type = message.data['type'] ?? '';

    // Chat messages suprimidas no foreground
    if (type == 'chat_message') return;

    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? '';
    final body  = notification.body  ?? '';

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A0029),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0x66FF2D7A), width: 0.8),
        ),
        duration: const Duration(seconds: 4),
        content: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _navigate(context, message.data, userData);
          },
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: Color(0xFFFF2D7A), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(title,
                          style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          )),
                    if (body.isNotEmpty)
                      Text(body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 11,
                            color: Color(0xAAFFFFFF),
                          )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navegação (background / foreground tap) ───────────────────────────────
  static void _navigate(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
  ) {
    if (!context.mounted) return;

    final type = data['type'] as String? ?? '';
    debugPrint('[NotificationHandler] _navigate type=$type');

    switch (type) {
      case 'chat_request':
        TclubShellController.instance.openChatList(listTab: 1);
        break;
      case 'chat_accepted':
        TclubShellController.instance.openChatList(listTab: 0);
        break;
      case 'chat_message':
        _navigateChatMessage(context, data, userData);
        break;
      case 'party':
        // Nova festa: navega para Home e abre modal
        final partyId = data['targetId'] as String?;
        if (partyId != null && partyId.isNotEmpty) {
          TclubShellController.instance.openPartyDetail(partyId);
        }
        break;
      default:
        TclubShellController.instance.setTabIndex(0);
    }
  }

  static void _navigateChatMessage(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
  ) {
    if (!context.mounted) return;

    final myUid    = userData['uid']   as String? ?? '';
    final otherUid = data['other_uid'] as String? ?? '';
    final chatId   = data['chat_id']   as String? ?? '';

    final resolvedUid = _resolveOtherUid(otherUid, chatId, myUid);
    if (resolvedUid.isNotEmpty) {
      Navigator.of(context).push(_slideRoute(
        _OtherUserChatRoom(myUid: myUid, otherUid: resolvedUid),
      ));
    } else {
      TclubShellController.instance.openChatList(listTab: 0);
    }
  }

  static String _resolveOtherUid(String otherUid, String chatId, String myUid) {
    if (otherUid.isNotEmpty) return otherUid;
    if (chatId.isNotEmpty) {
      final parts = chatId.split('_');
      if (parts.length == 2) return parts[0] == myUid ? parts[1] : parts[0];
    }
    return '';
  }

  static PageRouteBuilder<T> _slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}

// ── Helper: carrega dados do outro usuário e abre ChatRoomScreen ──────────────
class _OtherUserChatRoom extends StatelessWidget {
  final String myUid;
  final String otherUid;
  const _OtherUserChatRoom({required this.myUid, required this.otherUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('Users/$otherUid').once(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF07000F),
            body: Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Color(0xFFFF2D7A)))),
          );
        }
        final data   = snap.data!.snapshot.value as Map<dynamic, dynamic>?;
        final name   = data?['name']   as String? ?? 'Usuário';
        final avatar = data?['avatar'] as String?;
        return ChatRoomScreen(
          myUid: myUid, otherUid: otherUid,
          otherName: name, otherAvatar: avatar,
        );
      },
    );
  }
}

