// lib/routes/auth_guard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/auth/presentation/pages/login_screen.dart';
import 'package:tabuapp/features/penalty/presentation/pages/ban_page.dart';
import 'package:tabuapp/features/penalty/presentation/pages/suspension_page.dart';
import 'package:tabuapp/features/penalty/presentation/pages/warning_page.dart';
import 'package:tabuapp/core/widgets/main_navigation.dart';

class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _sessionLoading = true;
  Widget? _destination;

  // ── Listener reativo ─────────────────────────────────────────────────────
  StreamSubscription<DatabaseEvent>? _userSub;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _sessionLoading = false;
          _destination    = const LoginScreen();
        });
      }
      return;
    }

    // Resolve destino inicial (igual ao original)
    final destination = await _resolveDestination(user.uid);
    if (mounted) {
      setState(() {
        _sessionLoading = false;
        _destination    = destination;
      });
    }

    // Inicia listener reativo APÓS o boot inicial
    _assinarUsuario(user.uid);
  }

  // ── Listener em tempo real ────────────────────────────────────────────────
  void _assinarUsuario(String uid) {
    if (_currentUid == uid) return; // já assinou
    _currentUid = uid;
    _userSub?.cancel();

    _userSub = FirebaseDatabase.instance
        .ref('Users/$uid')
        .onValue
        .listen((event) async {
      // Ignora o primeiro evento — já resolvemos no boot
      if (_sessionLoading) return;
      if (!mounted) return;

      final raw = event.snapshot.value;
      if (raw == null) return;
      final userData = _deepCast(raw as Map)..['uid'] = uid;

      final novoDestino = await _avaliarPenalidade(uid, userData);
      if (!mounted) return;

      // Só atualiza se o tipo de tela mudou para evitar rebuilds desnecessários
      if (_destinoMudou(novoDestino)) {
        setState(() => _destination = novoDestino);
      }
    });
  }

  /// Verifica se o novo destino é diferente do atual (por tipo).
  bool _destinoMudou(Widget novo) {
    if (_destination == null) return true;
    return _destination.runtimeType != novo.runtimeType;
  }

  /// Avalia apenas penalidade — chamado pelo listener reativo.
  /// Não precisa buscar o nó admin de novo (já sabemos o destino base).
  Future<Widget> _avaliarPenalidade(
      String uid, Map<String, dynamic> userData) async {
    final banido       = userData['banido']      as bool? ?? false;
    final suspenso     = userData['suspenso']    as bool? ?? false;
    final suspensaoFim = userData['suspensao_fim'] as int?;
    final suspensaoAtiva = suspenso &&
        suspensaoFim != null &&
        suspensaoFim > DateTime.now().millisecondsSinceEpoch;

    if (banido)          return BanPage(userData: userData, uid: uid);
    if (suspensaoAtiva)  return SuspensionPage(userData: userData, uid: uid);

    // Advertência não vista
    final unseen = _coletarNaoVistas(userData);
    if (unseen.isNotEmpty) {
      return WarningPage(
        penalidade:    unseen.first.penalidade,
        penalidadeKey: unseen.first.key,
        uid:           uid,
        onOk: () async {
          // Recarrega destino após confirmar ciência
          final dest = await _resolveDestination(uid);
          if (mounted) {
            setState(() => _destination = dest);
          }
        },
      );
    }

    // Sem penalidade — restaura o shell se estávamos numa tela de penalidade
    if (_destination is BanPage ||
        _destination is SuspensionPage ||
        _destination is WarningPage) {
      return _resolveDestination(uid); // busca admin flag de novo
    }

    return _destination!; // sem mudança necessária
  }

  // ── Boot inicial (igual ao original) ─────────────────────────────────────
  Future<Widget> _resolveDestination(String uid) async {
    final results = await Future.wait([
      FirebaseDatabase.instance.ref('Users/$uid').get(),
      FirebaseDatabase.instance.ref('Administratives/$uid').get(),
    ]);

    final userSnap  = results[0];
    final adminSnap = results[1];

    Map<String, dynamic> userData;
    if (userSnap.exists && userSnap.value != null) {
      userData = _deepCast(userSnap.value as Map);
      userData['uid'] = uid;
    } else {
      final u = FirebaseAuth.instance.currentUser;
      userData = {
        'uid':   uid,
        'name':  u?.displayName ?? '',
        'email': u?.email ?? '',
      };
    }

    final isAdmin        = adminSnap.exists && adminSnap.value == true;
    final banido         = userData['banido']       as bool? ?? false;
    final suspenso       = userData['suspenso']     as bool? ?? false;
    final suspensaoFim   = userData['suspensao_fim'] as int?;
    final suspensaoAtiva = suspenso &&
        suspensaoFim != null &&
        suspensaoFim > DateTime.now().millisecondsSinceEpoch;

    if (banido)         return BanPage(userData: userData, uid: uid);
    if (suspensaoAtiva) return SuspensionPage(userData: userData, uid: uid);

    final unseen = _coletarNaoVistas(userData);
    if (unseen.isNotEmpty) {
      return WarningPage(
        penalidade:    unseen.first.penalidade,
        penalidadeKey: unseen.first.key,
        uid:           uid,
        onOk: () async {
          final dest = await _resolveDestination(uid);
          if (mounted) {
            setState(() => _destination = dest);
          }
        },
      );
    }

    return TabuShell(userData: userData, isAdmin: isAdmin);
  }

  List<_UnseenPenalty> _coletarNaoVistas(Map<String, dynamic> userData) {
    final unseen = <_UnseenPenalty>[];
    final pens   = userData['penalidades'];
    if (pens is Map) {
      for (final entry in pens.entries) {
        if (entry.value is! Map) continue;
        final p    = Map<String, dynamic>.from(entry.value as Map);
        final tipo = p['tipo']  as String? ?? '';
        final vista = p['vista'] as bool?   ?? false;
        if (!vista && (tipo == 'advertencia' || tipo == 'remover_conteudo')) {
          unseen.add(_UnseenPenalty(key: entry.key.toString(), penalidade: p));
        }
      }
      unseen.sort((a, b) =>
          (b.penalidade['aplicada_em'] as int? ?? 0)
              .compareTo(a.penalidade['aplicada_em'] as int? ?? 0));
    }
    return unseen;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
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
    if (_sessionLoading) return const _LoadingScreen();
    return _destination ?? const _LoadingScreen();
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────
class _UnseenPenalty {
  final String key;
  final Map<String, dynamic> penalidade;
  const _UnseenPenalty({required this.key, required this.penalidade});
}

// ── Loading Screen ─────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
                    colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro])
                .createShader(b),
            child: const Text('TABU',
                style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 36,
                    letterSpacing: 10,
                    color: Colors.white)),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: TabuColors.rosaPrincipal, strokeWidth: 1.5),
          ),
        ]),
      ),
    );
  }
}