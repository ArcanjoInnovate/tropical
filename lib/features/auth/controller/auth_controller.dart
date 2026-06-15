// lib/features/auth/presentation/controllers/auth_controller.dart
//
// Controller de autenticação.
// Novidades:
//   • register() agora aceita birthDate, idade e imageFile (opcionais)
//   • Repassa os novos parâmetros ao AuthService

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tclub/features/auth/data/services/auth_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  AuthStatus get status       => _status;
  String?    get errorMessage => _errorMessage;
  bool       get isLoading    => _status == AuthStatus.loading;

  // ── Login ─────────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _log('🔐 Iniciando login — $email');
    _setStatus(AuthStatus.loading);

    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      _log('✅ Login OK — uid: ${credential?.user?.uid}');
      _setStatus(AuthStatus.success);
      return true;

    } catch (e) {
      final err = e.toString();
      _errorMessage = err;
      _logError('Login', err, email: email);
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  // ── Registro ──────────────────────────────────────────────────────────────────
  /// [birthDate] e [idade] são obrigatórios no fluxo multi-step.
  /// [imageFile] é opcional — se null, o avatar fica em branco.
  Future<bool> register(
    String email,
    String password,
    String name, {
    DateTime? birthDate,
    int?      idade,
    File?     imageFile,
  }) async {
    _log('📝 Iniciando registro — $email | nome: $name | foto: ${imageFile != null}');
    _setStatus(AuthStatus.loading);

    try {
      final credential = await _authService.registerWithEmail(
        email:       email,
        password:    password,
        displayName: name,
        birthDate:   birthDate,
        idade:       idade,
        imageFile:   imageFile,
      );

      _log('✅ Registro OK — uid: ${credential?.user?.uid}');
      _setStatus(AuthStatus.success);
      return true;

    } catch (e) {
      final err = e.toString();
      _errorMessage = err;
      _logError('Registro', err, email: email);
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _log('🚪 Iniciando logout');
    try {
      await _authService.signOut();
      _setStatus(AuthStatus.idle);
      _log('✅ Logout realizado');
    } catch (e) {
      debugPrint('[AUTH] ❌ Erro ao fazer logout: $e');
    }
  }

  // ── Helpers internos ──────────────────────────────────────────────────────────
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
    _log('🔄 Status → ${status.name.toUpperCase()}');
  }

  void _log(String msg) {
    debugPrint('[AUTH] $msg');
  }

  void _logError(String context, String err, {String? email}) {
    debugPrint('[AUTH] ❌ Falha em $context — $err');
    if (email != null) debugPrint('[AUTH]    Email: $email');

    if      (err.contains('user-not-found'))       debugPrint('[AUTH]    Tipo: USUÁRIO NÃO ENCONTRADO');
    else if (err.contains('wrong-password') ||
             err.contains('invalid-credential'))   debugPrint('[AUTH]    Tipo: CREDENCIAIS INVÁLIDAS');
    else if (err.contains('user-disabled'))        debugPrint('[AUTH]    Tipo: CONTA DESATIVADA');
    else if (err.contains('too-many-requests'))    debugPrint('[AUTH]    Tipo: MUITAS TENTATIVAS');
    else if (err.contains('network-request-failed')) debugPrint('[AUTH]  Tipo: SEM CONEXÃO');
    else if (err.contains('invalid-email'))        debugPrint('[AUTH]    Tipo: EMAIL INVÁLIDO');
    else if (err.contains('email-already-in-use')) debugPrint('[AUTH]    Tipo: EMAIL JÁ CADASTRADO');
    else if (err.contains('weak-password'))        debugPrint('[AUTH]    Tipo: SENHA FRACA');
    else                                           debugPrint('[AUTH]    Tipo: ERRO DESCONHECIDO');
  }
}

