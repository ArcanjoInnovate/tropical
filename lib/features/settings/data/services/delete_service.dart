// lib/features/settings/data/services/delete_service.dart
//
// Re-autentica no client (obrigatório pelo Firebase Auth) e delega
// TODA a limpeza + deleteUser para a Cloud Function `deleteAccount`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DeleteAccountService {
  DeleteAccountService._();

  static final _auth      = FirebaseAuth.instance;
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Deleta a conta do usuário após re-autenticação.
  ///
  /// Lança [FirebaseAuthException] se a senha estiver incorreta.
  /// Lança [FirebaseFunctionsException] se a Cloud Function retornar erro.
  static Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Nenhum usuário autenticado.');
    }

    // 1. Re-autenticação — obrigatória antes de operações sensíveis
    final credential = EmailAuthProvider.credential(
      email:    user.email ?? '',
      password: password,
    );

    // FirebaseAuthException sobe direto para o controller se senha errada
    await user.reauthenticateWithCredential(credential);

    print('[DeleteAccountService] Re-autenticação bem-sucedida');

    // 2. Cloud Function cuida de toda a limpeza + deleteUser no Admin SDK
    final callable = _functions.httpsCallable(
      'deleteAccount',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>({});
    print('[DeleteAccountService] Cloud Function retornou: $result');

    // 3. Sign-out local — só após tudo ter dado certo
    //    Erro aqui é ignorado (usuário já foi deletado no servidor)
    try {
      await _auth.signOut();
      print('[DeleteAccountService] Sign-out realizado');
    } catch (signOutError) {
      print('[DeleteAccountService] Erro ao fazer sign-out (esperado se conta já foi deletada): $signOutError');
    }
  }
} 

