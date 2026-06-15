// src/algolia_sync.ts
//
// NÍVEL 3.1 — Indexar usuários no Algolia para busca full-text + geo.
// Esta CF sincroniza Users/{uid} → índice Algolia "users" automaticamente.
//
// Requer variáveis de ambiente no Firebase Functions:
//   firebase functions:secrets:set ALGOLIA_APP_ID
//   firebase functions:secrets:set ALGOLIA_ADMIN_KEY
//
// No Flutter, usar o pacote algolia_helper_flutter ou http direto:
//   final response = await AlgoliaService.instance.searchUsers(query, lat, lng, radiusKm);

import { onValueWritten, onValueDeleted } from "firebase-functions/v2/database";
import { defineSecret }                   from "firebase-functions/params";

const algoliaAppId   = defineSecret("ALGOLIA_APP_ID");
const algoliaAdminKey = defineSecret("ALGOLIA_ADMIN_KEY");

// Helper para fazer requests diretas à API do Algolia (sem SDK pesado)
async function algoliaRequest(
  method: "PUT" | "DELETE",
  path: string,
  body?: Record<string, unknown>,
): Promise<void> {
  const url = `https://${algoliaAppId.value()}-dsn.algolia.net${path}`;
  const headers: Record<string, string> = {
    "X-Algolia-Application-Id": algoliaAppId.value(),
    "X-Algolia-API-Key":        algoliaAdminKey.value(),
    "Content-Type":             "application/json",
  };

  const response = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const text = await response.text();
    console.error(`[algoliaRequest] ${method} ${path} → ${response.status}: ${text}`);
  }
}

// Campos que importam para o índice Algolia — mudanças em outros campos
// (presence, fcmToken, counters, etc.) NÃO disparam reindexação.
const ALGOLIA_FIELDS = [
  "name", "username", "bio", "avatar", "gender",
  "bairro", "cidade", "estado", "latitude", "longitude",
] as const;

/** Retorna true se algum campo indexável mudou entre before e after. */
function algoliaFieldsChanged(
  before: Record<string, unknown> | null,
  after: Record<string, unknown> | null,
): boolean {
  if (!before || !after) return true; // criação ou deleção sempre sincroniza
  for (const field of ALGOLIA_FIELDS) {
    const bVal = before[field] ?? "";
    const aVal = after[field]  ?? "";
    if (JSON.stringify(bVal) !== JSON.stringify(aVal)) return true;
  }
  return false;
}

export const syncUserToAlgolia = onValueWritten(
  {
    ref:     "Users/{uid}",
    region:  "us-central1", instance: "tropical-64d1b-default-rtdb",
    secrets: [algoliaAppId, algoliaAdminKey],
    timeoutSeconds: 100,
  },
  async (event) => {
    const { uid } = event.params;
    const before  = event.data.before.val() as Record<string, unknown> | null;
    const after   = event.data.after.val() as Record<string, unknown> | null;

    if (!after) {
      // Usuário deletado — remover do índice
      await algoliaRequest("DELETE", `/1/indexes/users/${uid}`);
      console.log(`[syncUserToAlgolia] Removido uid=${uid}`);
      return null;
    }

    // ── OTIMIZAÇÃO: só reindexar se campos relevantes mudaram ─────────────
    if (!algoliaFieldsChanged(before, after)) {
      return null; // presença, counter, fcmToken etc. — ignora
    }

    // Montar objeto para indexação — só campos relevantes para busca
    const record: Record<string, unknown> = {
      objectID: uid,
      name:     after.name ?? "",
      username: after.username ?? "",
      bio:      after.bio ?? "",
      avatar:   after.avatar ?? "",
      gender:   after.gender ?? "",
      bairro:   after.bairro ?? "",
      cidade:   after.cidade ?? "",
      estado:   after.estado ?? "",
    };

    // Geo-localização para busca por proximidade
    const lat = after.latitude as number | undefined;
    const lng = after.longitude as number | undefined;
    if (lat !== undefined && lng !== undefined && lat !== 0 && lng !== 0) {
      record._geoloc = { lat, lng };
    }

    await algoliaRequest("PUT", `/1/indexes/users/${uid}`, record);
    console.log(`[syncUserToAlgolia] Indexado uid=${uid}`);
    return null;
  }
);

export const removeUserFromAlgolia = onValueDeleted(
  {
    ref:     "Users/{uid}",
    region:  "us-central1", instance: "tropical-64d1b-default-rtdb",
    secrets: [algoliaAppId, algoliaAdminKey],
    timeoutSeconds: 100,
  },
  async (event) => {
    const { uid } = event.params;
    await algoliaRequest("DELETE", `/1/indexes/users/${uid}`);
    console.log(`[removeUserFromAlgolia] Removido uid=${uid}`);
    return null;
  }
);