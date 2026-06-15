// src/triggers/match_index_sync.ts
//
// Mantém MatchIndex sincronizado com Matchs.
//
// Campos copiados de Matchs:
//   name, avatar, bio, city, state, bairro,
//   relationship_type, profile_type, age, interests, partner
//
// Campos sensíveis EXCLUÍDOS:
//   latitude, longitude, likes_given, dislikes,
//   dislikes_received, like_me, matched
//
// gender_identity e sexual_orientation são lidos de Users/{uid}
// (fonte verdadeira). A sync reversa (Users → MatchIndex) é feita
// pelo syncUserIndex em users_index.ts.

import { onValueWritten, onValueDeleted } from "firebase-functions/v2/database";
import { getDatabase } from "firebase-admin/database";

/**
 * Trunca coordenada para 1 casa decimal (~11 km de precisão).
 * Evita expor localização exata no MatchIndex (lido por outros usuários).
 */
function truncateCoord(value: number): number {
  return Math.round(value * 10) / 10;
}

const MATCHS_FIELDS = new Set([
  "name",
  "avatar",
  "bio",
  "city",
  "state",
  "bairro",
  "relationship_type",
  "profile_type",
  "age",
  "interests",
  "partner",
]);

export const syncMatchIndex = onValueWritten(
  { ref: "Matchs/{uid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const { uid } = event.params;
    const db = getDatabase();
    const after = event.data.after.val() as Record<string, unknown> | null;

    if (!after) {
      await db.ref(`MatchIndex/${uid}`).remove();
      return null;
    }

    const name = (after["name"] as string | null)?.trim() ?? "";
    if (!name) {
      await db.ref(`MatchIndex/${uid}`).remove();
      return null;
    }

    const indexData: Record<string, unknown> = {};
    for (const field of MATCHS_FIELDS) {
      if (after[field] !== undefined) {
        indexData[field] = after[field];
      }
    }

    // Lê campos sensíveis de Users (fonte verdadeira — não ficam em Matchs)
    const userSnap = await db.ref(`Users/${uid}`).get();
    if (userSnap.exists()) {
      const userData = userSnap.val() as Record<string, unknown>;
      if (userData["gender_identity"] !== undefined) {
        indexData["gender_identity"] = userData["gender_identity"];
      }
      if (userData["sexual_orientation"] !== undefined) {
        indexData["sexual_orientation"] = userData["sexual_orientation"];
      }
      // lat/lng para cálculo de distância (não ficam em Matchs por LGPD)
      // Truncado para 1 casa decimal (~11 km de precisão) — não expõe localização exata
      if (userData["latitude"] !== undefined && userData["longitude"] !== undefined) {
        indexData["latitude"]  = truncateCoord(userData["latitude"]  as number);
        indexData["longitude"] = truncateCoord(userData["longitude"] as number);
      }
    }

    await db.ref(`MatchIndex/${uid}`).set(indexData);
    console.log(`[syncMatchIndex] ok uid=${uid}`);
    return null;
  }
);

export const removeMatchIndex = onValueDeleted(
  { ref: "Matchs/{uid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const { uid } = event.params;
    await getDatabase().ref(`MatchIndex/${uid}`).remove();
    console.log(`[removeMatchIndex] removido uid=${uid}`);
    return null;
  }
);