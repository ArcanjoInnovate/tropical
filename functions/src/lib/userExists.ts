// functions/lib/userExists.ts
//
// Verifica se uma conta de usuário ainda existe e está ativa.
// Consulta Users/$uid E UsersPublic/$uid em paralelo — ambos devem existir.
// Se qualquer um estiver ausente, a conta foi deletada ou está inconsistente.
//
// Uso nas callables:
//   const check = await assertUsersExist([uid1, uid2]);
//   // lança HttpsError('not-found', ...) automaticamente se algum não existir

import { getDatabase }  from "firebase-admin/database";
import { HttpsError }   from "firebase-functions/v2/https";

// ─── Tipo de resultado por UID ─────────────────────────────────────────────
export interface UserExistsResult {
  exists: boolean;
  reason?: "invalid-uid" | "not-found-in-users" | "not-found-in-users-public";
}

// ─── Verifica um único UID ─────────────────────────────────────────────────
export async function userExists(uid: string): Promise<UserExistsResult> {
  if (!uid || typeof uid !== "string" || uid.trim() === "") {
    return { exists: false, reason: "invalid-uid" };
  }

  const db = getDatabase();

  // Lê apenas um campo leve de cada nó — evita baixar o documento inteiro.
  const [usersSnap, publicSnap] = await Promise.all([
    db.ref(`Users/${uid}/uid`).get(),       // campo presente em todos os Users
    db.ref(`UsersPublic/${uid}/name`).get(), // campo presente em todos os UsersPublic
  ]);

  // Fallback: se 'uid' não existir no Users, tenta a raiz do nó
  // (contas antigas podem não ter o campo 'uid' dentro de Users)
  if (!usersSnap.exists()) {
    const rootSnap = await db.ref(`Users/${uid}`).get();
    if (!rootSnap.exists()) {
      return { exists: false, reason: "not-found-in-users" };
    }
  }

  if (!publicSnap.exists()) {
    const rootPublicSnap = await db.ref(`UsersPublic/${uid}`).get();
    if (!rootPublicSnap.exists()) {
      return { exists: false, reason: "not-found-in-users-public" };
    }
  }

  return { exists: true };
}

// ─── Verifica múltiplos UIDs em paralelo ──────────────────────────────────
export async function checkUsersExist(
  uids: string[]
): Promise<Record<string, UserExistsResult>> {
  const results = await Promise.all(uids.map((uid) => userExists(uid)));
  return Object.fromEntries(uids.map((uid, i) => [uid, results[i]]));
}

// ─── Guard: lança HttpsError se qualquer UID não existir ──────────────────
// Ideal para uso direto no início de cada callable.
//
// Exemplo:
//   await assertUsersExist({ myUid, likerUid });
//
// O argumento é um objeto nomeado para que a mensagem de erro indique
// qual "papel" o UID representa (ex: "likerUid está deletado").
export async function assertUsersExist(
  namedUids: Record<string, string>
): Promise<void> {
  const entries  = Object.entries(namedUids);  // [["myUid", "abc123"], ...]
  const uids     = entries.map(([, uid]) => uid);
  const results  = await Promise.all(uids.map((uid) => userExists(uid)));

  for (let i = 0; i < entries.length; i++) {
    const [label, uid] = entries[i];
    const result       = results[i];

    if (!result.exists) {
      const detail = result.reason ?? "unknown";
      console.warn(`[assertUsersExist] ${label}=${uid} não existe — reason=${detail}`);

      throw new HttpsError(
        "not-found",
        `O usuário referenciado como "${label}" não existe ou foi deletado. (reason: ${detail})`
      );
    }
  }
}