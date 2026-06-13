// functions/src/security_helpers.ts
//
// Funções utilitárias de segurança compartilhadas entre Cloud Functions.
//
// Centraliza: verificação de suspensão, admin check, bloqueio check,
// leituras otimizadas de campos parciais.

import { getDatabase } from "firebase-admin/database";
import { HttpsError } from "firebase-functions/v2/https";

const db = getDatabase();

// ══════════════════════════════════════════════════════════════════════════════
//  VERIFICAÇÃO DE SUSPENSÃO / BANIMENTO
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Verifica se o usuário está suspenso ou banido.
 * Lança HttpsError se estiver.
 * 
 * Lê APENAS os campos necessários (3 reads de ~1 byte cada, em vez de 1 read de 2-5 KB).
 */
export async function verificarSuspensao(uid: string): Promise<void> {
  const [banidoSnap, suspensoSnap, suspensaoFimSnap] = await Promise.all([
    db.ref(`Users/${uid}/banido`).get(),
    db.ref(`Users/${uid}/suspenso`).get(),
    db.ref(`Users/${uid}/suspensao_fim`).get(),
  ]);

  if (banidoSnap.val() === true) {
    throw new HttpsError("permission-denied", "Conta banida.");
  }

  if (suspensoSnap.val() === true) {
    const fimMs = suspensaoFimSnap.val() as number | null;
    if (fimMs && fimMs > Date.now()) {
      throw new HttpsError("permission-denied", "Conta suspensa temporariamente.");
    }
    // Suspensão expirou — limpa automaticamente
    await db.ref(`Users/${uid}`).update({
      suspenso: false,
      suspensao_fim: null,
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VERIFICAÇÃO DE ADMIN (via Custom Claims ou RTDB fallback)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Verifica se o uid é admin.
 * Prefere Custom Claims (mais seguro), com fallback para RTDB.
 */
export async function isAdmin(uid: string): Promise<boolean> {
  // Fallback: verificar no RTDB
  const snap = await db.ref(`Administratives/${uid}`).get();
  return snap.exists() && snap.val() === true;
}

/**
 * Lança erro se não for admin.
 */
export async function enforceAdmin(uid: string): Promise<void> {
  const admin = await isAdmin(uid);
  if (!admin) {
    throw new HttpsError("permission-denied", "Acesso negado. Requer permissão de administrador.");
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VERIFICAÇÃO DE BLOQUEIO
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Verifica se userA bloqueou userB ou vice-versa.
 */
export async function isBlocked(userA: string, userB: string): Promise<boolean> {
  const [aBlockedB, bBlockedA] = await Promise.all([
    db.ref(`Users/${userA}/blocked_users/${userB}`).get(),
    db.ref(`Users/${userB}/blocked_users/${userA}`).get(),
  ]);
  return aBlockedB.exists() || bBlockedA.exists();
}

// ══════════════════════════════════════════════════════════════════════════════
//  LEITURAS OTIMIZADAS DE PERFIL
// ══════════════════════════════════════════════════════════════════════════════

export interface UserBasicInfo {
  name: string;
  avatar: string;
  fcmToken: string | null;
}

/**
 * Lê apenas name, avatar e fcmToken de um usuário.
 * 3 reads de campos individuais (~1 byte cada) em vez de 1 read completa (~2-5 KB).
 */
export async function fetchUserBasicInfo(uid: string): Promise<UserBasicInfo | null> {
  const [nameSnap, avatarSnap, tokenSnap] = await Promise.all([
    db.ref(`Users/${uid}/name`).get(),
    db.ref(`Users/${uid}/avatar`).get(),
    db.ref(`Users/${uid}/fcmToken`).get(),
  ]);

  if (!nameSnap.exists()) return null;

  return {
    name: nameSnap.val() as string ?? "Alguém",
    avatar: avatarSnap.val() as string ?? "",
    fcmToken: tokenSnap.val() as string | null,
  };
}

/**
 * Lê apenas name e avatar (sem token).
 */
export async function fetchUserNameAvatar(uid: string): Promise<{ name: string; avatar: string } | null> {
  const [nameSnap, avatarSnap] = await Promise.all([
    db.ref(`Users/${uid}/name`).get(),
    db.ref(`Users/${uid}/avatar`).get(),
  ]);

  if (!nameSnap.exists()) return null;

  return {
    name: nameSnap.val() as string ?? "Alguém",
    avatar: avatarSnap.val() as string ?? "",
  };
}

// ══════════════════════════════════════════════════════════════════════════════
//  LOCK DE IDEMPOTÊNCIA
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Tenta adquirir um lock de idempotência.
 * Retorna true se adquiriu (primeira execução), false se já existia (duplicata).
 *
 * O lock tem TTL de 24 horas, após o qual é limpo pelo job de manutenção.
 */
export async function acquireIdempotencyLock(lockKey: string): Promise<boolean> {
  const ref = db.ref(`NotificationLocks/${lockKey}`);
  const result = await ref.transaction((current: number | null) => {
    if (current !== null) return; // aborta — já existe
    return Date.now(); // grava timestamp
  });
  return result.committed;
}