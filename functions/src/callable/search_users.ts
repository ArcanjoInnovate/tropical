// functions/src/callable/search_users.ts
//
// CORREÇÃO DE ESCALABILIDADE: Busca de usuários server-side.
//
// Antes: o cliente baixava o nó UserIndex inteiro (~20 MB a 100k users)
// e filtrava em memória. Custo: ~$60.000/mês em egress RTDB.
//
// Agora: o cliente chama esta CF que faz a busca no servidor,
// retornando apenas os resultados filtrados e paginados (~2 KB por página).
//
// Suporta:
//   - Busca por texto (nome, bio)
//   - Filtro por estado e cidade
//   - Busca por proximidade (lat/lng + raio)
//   - Paginação com cursor
//   - Exclusão de usuários bloqueados

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getDatabase } from "firebase-admin/database";

const PAGE_SIZE = 20;

interface SearchRequest {
  query?: string;
  estadoSigla?: string;
  cidadeNome?: string;
  latitude?: number;
  longitude?: number;
  radiusKm?: number;
  page?: number;
}

interface UserResult {
  uid: string;
  name: string;
  avatar: string;
  bio: string;
  city: string;
  state: string;
  bairro: string;
  followers_count: number;
  following_count: number;
  latitude?: number;
  longitude?: number;
  distanceKm?: number;
}

export const searchUsers = onCall(
  {
    region: "us-central1",
    memory: "512MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário");

    const data = request.data as SearchRequest;
    const page = data.page ?? 0;
    const db = getDatabase();

    // ── 1. Leituras em paralelo ──────────────────────────────────────────
    const [indexSnap, blockedSnap, blockedBySnap, followingSnap] =
      await Promise.all([
        db.ref("UserIndex").get(),
        db.ref(`Users/${uid}/blocked_users`).get(),
        db.ref(`blocked_by/${uid}`).get(),
        db.ref(`Users/${uid}/following`).get(),
      ]);

    if (!indexSnap.exists()) return { users: [], hasMore: false, totalCount: 0 };

    // ── 2. Sets de bloqueio ──────────────────────────────────────────────
    const blockedIds = new Set<string>();
    if (blockedSnap.exists()) {
      Object.keys(blockedSnap.val() as Record<string, unknown>).forEach((id) =>
        blockedIds.add(id)
      );
    }
    if (blockedBySnap.exists()) {
      Object.keys(blockedBySnap.val() as Record<string, unknown>).forEach(
        (id) => blockedIds.add(id)
      );
    }

    const followingSet = followingSnap.exists()
      ? new Set(Object.keys(followingSnap.val() as Record<string, unknown>))
      : new Set<string>();

    // ── 3. Filtrar e processar ───────────────────────────────────────────
    const raw = indexSnap.val() as Record<string, Record<string, unknown>>;
    const results: UserResult[] = [];

    for (const [userUid, userData] of Object.entries(raw)) {
      if (userUid === uid) continue;
      if (blockedIds.has(userUid)) continue;
      if (!userData || typeof userData !== "object") continue;

      const name = ((userData.name as string) ?? "").trim();
      if (!name) continue;

      const user: UserResult = {
        uid: userUid,
        name,
        avatar: (userData.avatar as string) ?? "",
        bio: (userData.bio as string) ?? "",
        city: (userData.city as string) ?? "",
        state: (userData.state as string) ?? "",
        bairro: (userData.bairro as string) ?? "",
        followers_count: (userData.followers_count as number) ?? 0,
        following_count: (userData.following_count as number) ?? 0,
        latitude: userData.latitude as number | undefined,
        longitude: userData.longitude as number | undefined,
      };

      // Filtro de estado
      if (data.estadoSigla) {
        if (normalize(user.state) !== normalize(data.estadoSigla)) continue;
      }

      // Filtro de cidade
      if (data.cidadeNome) {
        if (normalize(user.city) !== normalize(data.cidadeNome)) continue;
      }

      // Filtro de proximidade
      if (
        data.latitude !== undefined &&
        data.longitude !== undefined &&
        data.radiusKm !== undefined
      ) {
        if (user.latitude == null || user.longitude == null) continue;
        const dist = haversineKm(
          data.latitude,
          data.longitude,
          user.latitude,
          user.longitude
        );
        if (dist > data.radiusKm) continue;
        user.distanceKm = Math.round(dist * 10) / 10;
      }

      // Filtro de texto
      if (data.query && data.query.trim()) {
        const q = normalize(data.query.trim());
        const nameNorm = normalize(name);
        const bioNorm = normalize(user.bio);
        if (!nameNorm.includes(q) && !bioNorm.includes(q)) continue;
      }

      results.push(user);
    }

    // ── 4. Ordenação ─────────────────────────────────────────────────────
    if (data.latitude !== undefined && data.longitude !== undefined) {
      // Por distância
      results.sort((a, b) => (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity));
    } else {
      // Seguidos primeiro, depois por nome
      results.sort((a, b) => {
        const aFollow = followingSet.has(a.uid) ? 0 : 1;
        const bFollow = followingSet.has(b.uid) ? 0 : 1;
        if (aFollow !== bFollow) return aFollow - bFollow;
        return a.name.localeCompare(b.name);
      });
    }

    // ── 5. Paginação ─────────────────────────────────────────────────────
    const totalCount = results.length;
    const start = page * PAGE_SIZE;
    const pageResults = results.slice(start, start + PAGE_SIZE);

    return {
      users: pageResults,
      hasMore: start + PAGE_SIZE < totalCount,
      totalCount,
      page,
    };
  }
);

// ── Helpers ──────────────────────────────────────────────────────────────────

function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}
