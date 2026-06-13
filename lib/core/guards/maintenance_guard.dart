// lib/core/guards/maintenance_guard.dart
//
// Escuta Maintenance/isMaintenance em tempo real.
// Se true e o usuário NÃO está em Maintenance/Testers → tela de manutenção.
// Se false ou usuário é tester → mostra o child normalmente.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

class MaintenanceGuard extends StatefulWidget {
  final Widget child;
  const MaintenanceGuard({super.key, required this.child});

  @override
  State<MaintenanceGuard> createState() => _MaintenanceGuardState();
}

class _MaintenanceGuardState extends State<MaintenanceGuard> {
  final _db = FirebaseDatabase.instance;

  StreamSubscription<DatabaseEvent>? _maintenanceSub;
  StreamSubscription<User?>? _authSub;

  bool _isMaintenance = false;
  bool _isTester = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _listenMaintenance();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _checkTester();
    });
  }

  void _listenMaintenance() {
    _maintenanceSub = _db
        .ref('Maintenance/isMaintenance')
        .onValue
        .listen((event) async {
      final value = event.snapshot.value == true;

      if (value != _isMaintenance) {
        _isMaintenance = value;
        await _checkTester();
      } else if (!_checked) {
        await _checkTester();
      }
    });
  }

  Future<void> _checkTester() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || !_isMaintenance) {
      if (mounted) {
        setState(() {
          _isTester = false;
          _checked = true;
        });
      }
      return;
    }

    try {
      final snap = await _db.ref('Maintenance/Testers/$uid').get();
      final tester = snap.exists && snap.value == true;
      if (mounted) {
        setState(() {
          _isTester = tester;
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTester = false;
          _checked = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _maintenanceSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const _LoadingSplash();

    if (_isMaintenance && !_isTester) {
      return const MaintenancePage();
    }

    return widget.child;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TELA DE MANUTENÇÃO
// ══════════════════════════════════════════════════════════════════════════════

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
                  ).createShader(b),
                  child: const Text(
                    'TABU',
                    style: TextStyle(
                      fontFamily: TabuTypography.displayFont,
                      fontSize: 36,
                      letterSpacing: 10,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Ícone
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: TabuColors.rosaPrincipal.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 36,
                    color: TabuColors.rosaPrincipal,
                  ),
                ),

                const SizedBox(height: 32),

                // Título
                const Text(
                  'Em manutenção',
                  style: TextStyle(
                    fontFamily: TabuTypography.displayFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TabuColors.rosaPrincipal,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 16),

                // Descrição
                Text(
                  'Estamos fazendo melhorias para você.\nVolte em alguns minutos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: TabuColors.rosaPrincipal.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 40),

                // Indicador sutil
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: TabuColors.rosaPrincipal.withOpacity(0.3),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SPLASH ENQUANTO VERIFICA
// ══════════════════════════════════════════════════════════════════════════════

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Center(
        child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro],
          ).createShader(b),
          child: const Text(
            'TABU',
            style: TextStyle(
              fontFamily: TabuTypography.displayFont,
              fontSize: 36,
              letterSpacing: 10,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}