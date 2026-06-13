// functions/src/user_index.ts
//
// Cloud Function: syncUserIndex
//
// Mantém o nó UserIndex/{uid} sincronizado com Users/{uid}.
// O UserIndex contém apenas os campos necessários para busca,
// reduzindo ~90% da banda em operações de search/discovery.
//
// Campos copiados:
//   name, avatar, city, state, bairro, latitude, longitude, bio (truncado 100 chars),
//   followers_count, following_count
//
// Trigger: onValueWritten em Users/{uid}
// Quando o nó Users/{uid} é atualizado, extrai os campos leves e
// escreve/atualiza UserIndex/{uid}.
// Quando o nó Users/{uid} é deletado, remove UserIndex/{uid}.

import { onValueWritten } from "firebase-functions/v2/database";
import { getDatabase }    from "firebase-admin/database";

/**
 * Trunca coordenada para 1 casa decimal (~11 km de precisão).
 * Evita expor localização exata no MatchIndex (lido por outros usuários).
 */
function truncateCoord(value: number): number {
  return Math.round(value * 10) / 10;
}

// Campos que importam para UserIndex e MatchIndex.
// Mudanças APENAS em presence, fcmToken, unreadCount, chatTabBadge, etc.
// NÃO precisam re-sincronizar o índice.
const INDEX_FIELDS = [
  "name", "Name", "avatar", "city", "state", "bairro",
  "latitude", "longitude", "bio",
  "followers_count", "following_count",
  "gender_identity", "sexual_orientation",
] as const;

function indexFieldsChanged(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
): boolean {
  if (!before || !after) return true;
  for (const field of INDEX_FIELDS) {
    if (JSON.stringify(before[field] ?? "") !== JSON.stringify(after[field] ?? "")) return true;
  }
  return false;
}

export const syncUserIndex = onValueWritten(
  { ref: "Users/{uid}", region: "us-central1", instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid = event.params.uid;
    const db  = getDatabase();

    const before = event.data.before.val() as Record<string, unknown> | null;
    const after  = event.data.after.val() as Record<string, unknown> | null;

    // Se o usuário foi deletado, remove do índice
    if (!after) {
      await db.ref(`UserIndex/${uid}`).remove();
      return;
    }

    // ── OTIMIZAÇÃO: só re-sincronizar se campos relevantes mudaram ────────
    if (!indexFieldsChanged(before, after)) {
      return; // presença, fcmToken, badges etc. — ignora
    }

    // Extrai apenas os campos leves para o índice
    const name   = (after.name || after.Name || "").toString().trim();
    const avatar = after.avatar || "";
    const city   = after.city   || "";
    const state  = after.state  || "";
    const bairro = after.bairro || "";
    const lat    = after.latitude  ?? null;
    const lng    = after.longitude ?? null;

    // Bio truncada para reduzir tamanho
    const fullBio = (after.bio || "").toString().trim();
    const bio     = fullBio.length > 100 ? fullBio.substring(0, 100) : fullBio;

    // Contadores atômicos (já calculados pela CF updateFollowersCount, ou fallback)
    let followersCount = after.followers_count;
    let followingCount = after.following_count;

    // Se os campos atômicos não existem, calcula do Map
    if (typeof followersCount !== "number") {
      followersCount = after.followers && typeof after.followers === "object"
        ? Object.keys(after.followers).length
        : 0;
    }
    if (typeof followingCount !== "number") {
      followingCount = after.following && typeof after.following === "object"
        ? Object.keys(after.following).length
        : 0;
    }

    // Não indexar usuários sem nome
    if (!name) {
      await db.ref(`UserIndex/${uid}`).remove();
      return;
    }

    const indexData: Record<string, unknown> = {
      name,
      avatar,
      city,
      state,
      bairro,
      bio,
      followers_count: followersCount,
      following_count: followingCount,
    };

    // Só inclui lat/lng se existirem — truncado para ~11 km de precisão
    if (lat !== null && lng !== null) {
      indexData.latitude  = truncateCoord(lat as number);
      indexData.longitude = truncateCoord(lng as number);
    }

    await db.ref(`UserIndex/${uid}`).set(indexData);

    // UsersPublic é sincronizado pela CF dedicada sync_users_public.ts

    // ── Sync campos de identidade para MatchIndex ────────────────────────
    // gender_identity e sexual_orientation residem exclusivamente em Users
    // (LGPD/GDPR). Quando mudam aqui, atualizamos o MatchIndex se existir.
    const oldGender = before?.gender_identity;
    const oldOrientation = before?.sexual_orientation;
    const newGender = after.gender_identity;
    const newOrientation = after.sexual_orientation;

    if (oldGender !== newGender || oldOrientation !== newOrientation) {
      const matchIndexSnap = await db.ref(`MatchIndex/${uid}`).get();
      if (matchIndexSnap.exists()) {
        const identityUpdates: Record<string, unknown> = {};
        if (newGender !== undefined) identityUpdates.gender_identity = newGender;
        if (newOrientation !== undefined) identityUpdates.sexual_orientation = newOrientation;
        if (Object.keys(identityUpdates).length > 0) {
          await db.ref(`MatchIndex/${uid}`).update(identityUpdates);
          console.log(`[syncUserIndex] identity → MatchIndex uid=${uid}`);
        }
      }
    }

    // ── Sync lat/lng para MatchIndex (fonte verdadeira é Users) ──────────
    const oldLat = before?.latitude;
    const oldLng = before?.longitude;
    const newLat = after.latitude;
    const newLng = after.longitude;

    if (oldLat !== newLat || oldLng !== newLng) {
      const matchIndexSnap2 = await db.ref(`MatchIndex/${uid}`).get();
      if (matchIndexSnap2.exists()) {
        const locUpdates: Record<string, unknown> = {};
        // Trunca para ~11 km de precisão antes de gravar no MatchIndex
        if (newLat !== undefined) locUpdates.latitude  = truncateCoord(newLat as number);
        if (newLng !== undefined) locUpdates.longitude = truncateCoord(newLng as number);
        if (Object.keys(locUpdates).length > 0) {
          await db.ref(`MatchIndex/${uid}`).update(locUpdates);
          console.log(`[syncUserIndex] lat/lng → MatchIndex uid=${uid}`);
        }
      }
    }
  }
);