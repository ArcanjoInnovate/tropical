// lib/core/guards/auth_guard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/constants/app_constants.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/auth/presentation/pages/login_screen.dart';
import 'package:tclub/features/penalty/presentation/pages/ban_page.dart';
import 'package:tclub/features/penalty/presentation/pages/suspension_page.dart';
import 'package:tclub/features/penalty/presentation/pages/warning_page.dart';
import 'package:tclub/core/widgets/main_navigation.dart';

class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool    _loading     = true;
  Widget? _destination;

  StreamSubscription<DatabaseEvent>? _userSub;
  StreamSubscription<User?>?         _authSub;
  String? _currentUid;

  bool _bootCompleto = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  // ── Boot: resolve destino inicial ─────────────────────────────────────────
  Future<void> _boot() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _goTo(const LoginScreen());
      _bootCompleto = true;
      _listenAuth();
      return;
    }

    // NÃO seta _currentUid aqui — deixa o _assinarUsuario fazer isso.
    // Se setarmos antes, o _assinarUsuario acha que já está ouvindo
    // esse uid e pula a criação do listener.

    final dest = await _resolveDestination(user.uid);
    _goTo(dest);
    _assinarUsuario(user.uid);

    _bootCompleto = true;
    _listenAuth();
  }

  // ── Listener de auth: detecta login/logout APÓS o boot ───────────────────
  void _listenAuth() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!_bootCompleto) return;
      if (!mounted) return;

      if (user == null) {
        _userSub?.cancel();
        _userSub    = null;
        _currentUid = null;
        _goTo(const LoginScreen());
        return;
      }

      if (_currentUid != user.uid) {
        final dest = await _resolveDestination(user.uid);
        if (!mounted) return;
        _goTo(dest);
        _assinarUsuario(user.uid);
      }
    });
  }

  // ── Listener reativo: detecta penalidades com o app aberto ───────────────
  void _assinarUsuario(String uid) {
    // Cancela listener anterior e sempre recria — não pula se uid for igual.
    _userSub?.cancel();
    _currentUid = uid;

    _userSub = FirebaseDatabase.instance
        .ref('Users/$uid')
        .onValue
        .listen((event) async {
      if (_loading) return;
      if (!mounted) return;

      final raw = event.snapshot.value;
      if (raw == null) return;

      final userData = _deepCast(raw as Map)..['uid'] = uid;
      final novo     = await _avaliarPenalidade(uid, userData);

      if (!mounted) return;
      if (_destinoMudou(novo)) _goTo(novo);
    });
  }

  // ── Avalia penalidade a partir de snapshot em memória ────────────────────
  Future<Widget> _avaliarPenalidade(
      String uid, Map<String, dynamic> userData) async {
    final banido    = _toBool(userData['banido']);
    final suspenso  = _toBool(userData['suspenso']);
    final suspFim   = _toInt(userData['suspensao_fim']);
    final suspAtiva = suspenso &&
        suspFim != null &&
        suspFim > DateTime.now().millisecondsSinceEpoch;

    if (banido)    return BanPage(userData: userData, uid: uid);
    if (suspAtiva) return SuspensionPage(userData: userData, uid: uid);

    final unseen = _coletarNaoVistas(userData);
    if (unseen.isNotEmpty) {
      return WarningPage(
        penalidade:    unseen.first.penalidade,
        penalidadeKey: unseen.first.key,
        uid:           uid,
        onOk: () async {
          final dest = await _resolveDestination(uid);
          if (mounted) _goTo(dest);
        },
      );
    }

    if (_destination is BanPage ||
        _destination is SuspensionPage ||
        _destination is WarningPage) {
      return _resolveDestination(uid);
    }

    return _destination ?? await _resolveDestination(uid);
  }

  // ── Resolve destino completo (lê banco + admin) ───────────────────────────
  Future<Widget> _resolveDestination(String uid) async {
    final results = await Future.wait([
      FirebaseDatabase.instance.ref('Users/$uid').get(),
      FirebaseDatabase.instance.ref('Administratives/$uid').get(),
    ]);

    final userSnap  = results[0];
    final adminSnap = results[1];

    Map<String, dynamic> userData;
    if (userSnap.exists && userSnap.value != null) {
      userData = _deepCast(userSnap.value as Map)..['uid'] = uid;
    } else {
      final u = FirebaseAuth.instance.currentUser;
      userData = {
        'uid':   uid,
        'name':  u?.displayName ?? '',
        'email': u?.email ?? '',
      };
    }

    final isAdmin   = adminSnap.exists && adminSnap.value == true;
    final banido    = _toBool(userData['banido']);
    final suspenso  = _toBool(userData['suspenso']);
    final suspFim   = _toInt(userData['suspensao_fim']);
    final suspAtiva = suspenso &&
        suspFim != null &&
        suspFim > DateTime.now().millisecondsSinceEpoch;

    if (banido)    return BanPage(userData: userData, uid: uid);
    if (suspAtiva) return SuspensionPage(userData: userData, uid: uid);

    final unseen = _coletarNaoVistas(userData);
    if (unseen.isNotEmpty) {
      return WarningPage(
        penalidade:    unseen.first.penalidade,
        penalidadeKey: unseen.first.key,
        uid:           uid,
        onOk: () async {
          final dest = await _resolveDestination(uid);
          if (mounted) _goTo(dest);
        },
      );
    }

    return TabuShell(userData: userData, isAdmin: isAdmin);
  }

  // ── Coleta penalidades não vistas ─────────────────────────────────────────
  List<_UnseenPenalty> _coletarNaoVistas(Map<String, dynamic> userData) {
    final unseen = <_UnseenPenalty>[];
    final pens   = userData['penalidades'];
    if (pens is! Map) return unseen;

    for (final entry in (pens as Map).entries) {
      if (entry.value is! Map) continue;
      final p     = Map<String, dynamic>.from(entry.value as Map);
      final tipo  = p['tipo']  as String? ?? '';
      final vista = _toBool(p['vista']);
      if (!vista && (tipo == 'advertencia' || tipo == 'remover_conteudo')) {
        unseen.add(_UnseenPenalty(key: entry.key.toString(), penalidade: p));
      }
    }

    unseen.sort((a, b) =>
        (_toInt(b.penalidade['aplicada_em']) ?? 0)
            .compareTo(_toInt(a.penalidade['aplicada_em']) ?? 0));

    return unseen;
  }

  // ── Navegação / estado ────────────────────────────────────────────────────
  void _goTo(Widget dest) {
    if (!mounted) return;
    _aplicarUiStyle(dest);
    setState(() {
      _loading     = false;
      _destination = dest;
    });
  }

  bool _destinoMudou(Widget novo) {
    if (_destination == null) return true;
    return _destination.runtimeType != novo.runtimeType;
  }

  void _aplicarUiStyle(Widget dest) {
    final dark = dest is LoginScreen;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:                    Colors.transparent,
      statusBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:          Colors.transparent,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  // ── Cast seguro ───────────────────────────────────────────────────────────
  static bool _toBool(dynamic v) => v == true || v == 1;

  static int? _toInt(dynamic v) {
    if (v == null)   return null;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return null;
  }

  static Map<String, dynamic> _deepCast(Map raw) => raw.map((k, v) {
        final key = k?.toString() ?? '';
        final dynamic value;
        if (v is Map)       value = _deepCast(v);
        else if (v is List) value = _castList(v);
        else                value = v;
        return MapEntry(key, value);
      });

  static List<dynamic> _castList(List list) => list.map((e) {
        if (e is Map)  return _deepCast(e);
        if (e is List) return _castList(e);
        return e;
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingScreen();
    return _destination ?? const _LoadingScreen();
  }
}

// ── Modelo interno ────────────────────────────────────────────────────────────
class _UnseenPenalty {
  final String               key;
  final Map<String, dynamic> penalidade;
  const _UnseenPenalty({required this.key, required this.penalidade});
}

// ── Loading Screen ────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [TClubColors.redPrincipal, TClubColors.redClaro],
            ).createShader(b),
            child: const Text(AppConstants.appName,
                style: TextStyle(
                  fontFamily:    TClubTypography.displayFont,
                  fontSize:      36,
                  letterSpacing: 10,
                  color:         Colors.white,
                )),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width:  18,
            height: 18,
            child: CircularProgressIndicator(
              color:       TClubColors.redPrincipal,
              strokeWidth: 1.5,
            ),
          ),
        ]),
      ),
    );
  }
}

