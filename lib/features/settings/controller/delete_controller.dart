// lib/features/settings/controller/delete_controller.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tabuapp/features/settings/data/services/delete_service.dart';

// ─── Estados da exclusão ────────────────────────────────────────────────────
enum DeleteStep { idle, loading, success, error }

class DeleteController extends GetxController {
  // ── Observables ─────────────────────────────────────────────────────────
  final step         = DeleteStep.idle.obs;
  final errorMessage = ''.obs;
  final obscurePass  = true.obs;
  final canDelete    = false.obs; // true quando campo de senha não está vazio

  // ── Form ────────────────────────────────────────────────────────────────
  final passwordController = TextEditingController();

  // ── Getters de conveniência ────────────────────────────────────────────
  bool get isLoading => step.value == DeleteStep.loading;
  bool get hasError  => step.value == DeleteStep.error;

  // ────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    passwordController.addListener(_onPasswordChanged);
  }

  @override
  void onClose() {
    passwordController
      ..removeListener(_onPasswordChanged)
      ..dispose();
    super.onClose();
  }

  // ── Listeners ───────────────────────────────────────────────────────────

  void _onPasswordChanged() {
    canDelete.value = passwordController.text.trim().isNotEmpty;
    // Limpa erro ao usuário começar a digitar novamente
    if (hasError) {
      step.value         = DeleteStep.idle;
      errorMessage.value = '';
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void toggleObscure() => obscurePass.value = !obscurePass.value;

  /// Reseta o estado para quando o sheet for reaberto.
  void reset() {
    passwordController.clear();
    step.value         = DeleteStep.idle;
    errorMessage.value = '';
    obscurePass.value  = true;
    canDelete.value    = false;
  }

  /// Executa a exclusão de conta.
  ///
  /// Retorna `true` se a conta foi deletada com sucesso.
  /// Retorna `false` se houve erro recuperável (senha incorreta, etc).
  Future<bool> confirmDelete() async {
    if (!canDelete.value || isLoading) return false;

    step.value         = DeleteStep.loading;
    errorMessage.value = '';

    try {
      await DeleteAccountService.deleteAccount(
        password: passwordController.text.trim(),
      );

      step.value = DeleteStep.success;
      print('[DeleteController] Exclusão bem-sucedida');
      return true;

    } on FirebaseAuthException catch (e) {
      print('[DeleteController] FirebaseAuthException: ${e.code}');
      step.value         = DeleteStep.error;
      errorMessage.value = _authErrorMessage(e.code);
      return false;

    } on FirebaseFunctionsException catch (e) {
      print('[DeleteController] FirebaseFunctionsException: ${e.code}');

      // Se timeout mas o usuário sumiu do Auth, considera sucesso
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        await Future.delayed(const Duration(seconds: 2));
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          print('[DeleteController] Usuário foi deletado apesar do timeout, navegando...');
          step.value = DeleteStep.success;
          return true;
        }
      }

      step.value         = DeleteStep.error;
      errorMessage.value = _functionsErrorMessage(e.code);
      return false;

    } catch (e) {
      print('[DeleteController] Erro desconhecido: $e');
      step.value         = DeleteStep.error;
      errorMessage.value = 'Ocorreu um erro inesperado. Tente novamente.';
      return false;
    }
  }

  // ── Mensagens de erro amigáveis ────────────────────────────────────────

  String _authErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Senha incorreta. Verifique e tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'user-mismatch':
        return 'Credencial não corresponde ao usuário atual.';
      case 'requires-recent-login':
        return 'Sessão expirada. Faça login novamente.';
      case 'user-not-found':
        return 'Conta já foi removida.';
      case 'user-disabled':
        return 'Conta já está desativada.';
      default:
        return 'Erro de autenticação ($code). Tente novamente.';
    }
  }

  String _functionsErrorMessage(String? code) {
    switch (code) {
      case 'unauthenticated':
        return 'Sessão inválida. Faça login novamente.';
      case 'not-found':
        return 'Conta não encontrada.';
      case 'deadline-exceeded':
        return 'Processando exclusão... Aguarde um momento.';
      case 'unavailable':
        return 'Servidor temporariamente indisponível.';
      case 'internal':
        return 'Erro interno ao processar exclusão.';
      default:
        return 'Erro ao processar a exclusão. Tente novamente.';
    }
  }
} 