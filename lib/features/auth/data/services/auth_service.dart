// lib/features/auth/data/services/auth_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:tclub/core/services/presence_service.dart';

// ── Exceções tipadas ───────────────────────────────────────────────────────────

class AuthException implements Exception {
  final String code;
  const AuthException(this.code);
  @override
  String toString() => 'AuthException: $code';
}

class BannedException implements Exception {
  final Map<String, dynamic> userData;
  const BannedException(this.userData);
}

class SuspendedException implements Exception {
  final Map<String, dynamic> userData;
  final int suspensaoFim;
  const SuspendedException(this.userData, this.suspensaoFim);
}

/// Lançada quando há uma penalidade não vista (advertencia / remover_conteudo).
/// O usuário permanece autenticado — só precisa confirmar a leitura.
class WarnedException implements Exception {
  final Map<String, dynamic> userData;
  final String               penalidadeKey;
  final Map<String, dynamic> penalidade;
  const WarnedException(this.userData, this.penalidadeKey, this.penalidade);
  @override
  String toString() =>
      'WarnedException: key=$penalidadeKey tipo=${penalidade['tipo']}';
}

// ── AuthService ────────────────────────────────────────────────────────────────

class AuthService {
  final FirebaseAuth     _auth     = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage  _storage  = FirebaseStorage.instance;

  Stream<User?> get user             => _auth.authStateChanges();
  Stream<User?> getcurrentUser()     => _auth.userChanges();
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthService] 🔄 signIn — $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      debugPrint('[AuthService] ✅ Login OK — uid: $uid');

      if (uid != null) {
        final userData = await getUserData(uid);
        if (userData != null) {
          final banido    = _toBool(userData['banido']);
          final suspenso  = _toBool(userData['suspenso']);
          final suspFim   = _toInt(userData['suspensao_fim']);
          final suspAtiva = suspenso &&
              suspFim != null &&
              suspFim > DateTime.now().millisecondsSinceEpoch;

          // 1. Banido → desloga imediatamente
          if (banido) {
            await _auth.signOut();
            throw BannedException(userData);
          }

          // 2. Suspenso → desloga imediatamente
          if (suspAtiva) {
            await _auth.signOut();
            throw SuspendedException(userData, suspFim!);
          }

          // 3. Penalidade pendente (advertência / remoção de conteúdo)
          final penEntry = await _buscarPenalidadePendente(uid);
          if (penEntry != null) {
            debugPrint('[AuthService] ⚠️ Penalidade pendente: ${penEntry.key}');
            throw WarnedException(userData, penEntry.key, penEntry.value);
          }
        }

        _salvarTokenFCM(uid).catchError((e) {
          debugPrint('[AuthService] ⚠️ FCM silencioso: $e');
        });
      }

      return credential;

    } on BannedException  { rethrow; }
    on SuspendedException { rethrow; }
    on WarnedException    { rethrow; }
    on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] ❌ FirebaseAuthException: "${e.code}"');

      // ── Conta desabilitada no Firebase Auth (banido=true no DB) ───────────
      // O Firebase não retorna o uid neste caso — buscamos pelo email
      // no UserIndex para montar o BannedException com dados reais.
      if (e.code == 'user-disabled') {
        debugPrint('[AuthService] 🔍 user-disabled — buscando dados pelo email');
        try {
          final idxSnap = await _database
              .ref('UserIndex')
              .orderByChild('email')
              .equalTo(email.trim())
              .limitToFirst(1)
              .get();

          if (idxSnap.exists && idxSnap.value != null) {
            final map = _deepCast(idxSnap.value as Map);
            final uid = map.keys.first;
            final userData = await getUserData(uid);
            if (userData != null) {
              debugPrint('[AuthService] ✅ Dados encontrados para user-disabled: $uid');
              throw BannedException(userData);
            }
          }
        } catch (inner) {
          if (inner is BannedException) rethrow;
          debugPrint('[AuthService] ⚠️ Fallback user-disabled sem dados: $inner');
        }
        // Fallback: lança BannedException com dados mínimos
        throw BannedException({
          'uid':    '',
          'email':  email.trim(),
          'banido': true,
        });
      }

      // ── Normaliza credenciais inválidas ────────────────────────────────────
      String code     = e.code;
      final  msgLower = (e.message ?? '').toLowerCase();
      if (msgLower.contains('supplied auth credential') ||
          msgLower.contains('malformed or has expired') ||
          msgLower.contains('credential is incorrect') ||
          code.toLowerCase().contains('invalid-login-credentials') ||
          code.toLowerCase().contains('invalid_login_credentials')) {
        code = 'invalid-credential';
      }
      throw AuthException(code);

    } catch (e) {
      debugPrint('[AuthService] ❌ Erro genérico signIn: $e');
      throw AuthException('network-request-failed');
    }
  }

  // ── Registro ───────────────────────────────────────────────────────────────
  Future<UserCredential?> registerWithEmail({
    required String   email,
    required String   password,
    String?   displayName,
    DateTime? birthDate,
    int?      idade,
    File?     imageFile,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );

      if (displayName != null) {
        await credential.user?.updateDisplayName(displayName);
      }

      final uid = credential.user?.uid;
      if (uid == null) throw AuthException('uid-null');

      // Upload de avatar (falha não impede cadastro)
      String avatarUrl = '';
      if (imageFile != null && imageFile.existsSync()) {
        try {
          final ref = _storage
              .ref('avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(imageFile,
              SettableMetadata(contentType: 'image/jpeg'));
          avatarUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('[AuthService] ⚠️ Avatar falhou (ignorado): $e');
        }
      }

      final birthDateStr = birthDate != null
          ? '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
          : '';

      final userPayload = <String, dynamic>{
        'uid':          uid,
        'name':         displayName ?? '',
        'email':        email.trim(),
        'avatar':       avatarUrl,
        'bio':          '',
        'isPremium':    false,
        'city':         '',
        'state':        '',
        'bairro':       '',
        'partys':       0,
        'reservations': 0,
        'vip_lists':    0,
        if (birthDateStr.isNotEmpty) 'birth_date': birthDateStr,
        if (idade != null)           'age':        idade,
      };
      await _database.ref('Users/$uid').set(userPayload);

      // UserIndex é sincronizado automaticamente pela CF syncUserIndex
      // quando Users/$uid é criado/atualizado. Não gravar diretamente
      // (regras: ".write": false).

      final matchPayload = <String, dynamic>{
        'uid':    uid,
        'name':   displayName ?? '',
        'avatar': avatarUrl,
        'city':   '',
        'state':  '',
        'bairro': '',
        if (birthDateStr.isNotEmpty) 'birth_date': birthDateStr,
        if (idade != null)           'age':        idade,
      };
      await _database.ref('Matchs/$uid').set(matchPayload);

      await _salvarTokenFCM(uid);
      debugPrint('[AuthService] ✅ Registro completo — uid: $uid');
      return credential;

    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    } catch (e) {
      debugPrint('[AuthService] ❌ Erro no registro: $e');
      rethrow;
    }
  }

  // ── Dados do usuário ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snapshot = await _database.ref('Users/$uid').get();
    if (snapshot.exists && snapshot.value != null) {
      final data = _deepCast(snapshot.value as Map);
      data['uid'] = uid;
      return data;
    }
    return null;
  }

  // ── Reset de senha ─────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _database.ref('Users/$uid/fcmToken').remove();
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
    await PresenceService.instance.setOffline();
    await _auth.signOut();
  }

  // ── Busca penalidade pendente ──────────────────────────────────────────────
  Future<MapEntry<String, Map<String, dynamic>>?> _buscarPenalidadePendente(
      String uid) async {
    try {
      final snap = await _database.ref('Users/$uid/penalidades').get();
      if (!snap.exists || snap.value == null) return null;

      final raw = _deepCast(snap.value as Map);
      for (final entry in raw.entries) {
        final pen = entry.value;
        if (pen is! Map<String, dynamic>) continue;
        final tipo  = pen['tipo']  as String? ?? '';
        final vista = _toBool(pen['vista']);
        if ((tipo == 'advertencia' || tipo == 'remover_conteudo') && !vista) {
          return MapEntry(entry.key, pen);
        }
      }
    } catch (e) {
      debugPrint('[AuthService] ⚠️ Erro buscando penalidades: $e');
    }
    return null;
  }

  // ── FCM ────────────────────────────────────────────────────────────────────
  Future<void> _salvarTokenFCM(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _database.ref('Users/$uid/fcmToken').set(token);
      await FirebaseMessaging.instance.subscribeToTopic('novas_festas');
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _database.ref('Users/$uid/fcmToken').set(t);
      });
    } catch (e) {
      debugPrint('[AuthService] FCM ignorado: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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
}

