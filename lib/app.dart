// lib/app.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tclub/core/providers/block_provider.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/utils/notification_handler.dart';
import 'package:tclub/core/guards/auth_guard.dart';
import 'package:tclub/core/guards/maintenance_guard.dart';

class ImmersiveScaffold extends StatelessWidget {
  final Widget child;
  const ImmersiveScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.dark,
        systemNavigationBarColor:          Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: child,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme:     TClubTheme.main,
      darkTheme: TClubTheme.main,
      themeMode: ThemeMode.light,
      builder: (context, child) => ImmersiveScaffold(child: child!),
      home: const NotificationAwareAuthGuard(),
    );
  }
}

class NotificationAwareAuthGuard extends StatefulWidget {
  const NotificationAwareAuthGuard({super.key});

  @override
  State<NotificationAwareAuthGuard> createState() =>
      _NotificationAwareAuthGuardState();
}

class _NotificationAwareAuthGuardState
    extends State<NotificationAwareAuthGuard> {
  StreamSubscription<User?>? _authSub;
  String? _lastInitializedUid;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      // ── Logout ─────────────────────────────────────────────────────────
      // Limpa estado do NotificationHandler para que o próximo login
      // reinicialize corretamente com o uid do novo usuário.
      await NotificationHandler.clearOnLogout();
      _lastInitializedUid = null;
      return;
    }

    // ── Login / mudança de usuário ─────────────────────────────────────────
    // Só reinicializa se o uid mudou — evita double-init no mesmo usuário.
    if (user.uid == _lastInitializedUid) return;
    _lastInitializedUid = user.uid;

    final userData = {
      'uid':   user.uid,
      'email': user.email ?? '',
    };

    if (!mounted) return;
    final blockProvider = Provider.of<BlockProvider>(context, listen: false);
    await blockProvider.init();

    if (!mounted) return;
    await NotificationHandler.init(context, userData: userData);

    if (mounted) {
      await NotificationHandler.handleInitialMessage(
        context,
        userData: userData,
      );
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MaintenanceGuard(child: AuthGuard());
}

