// functions/src/callable/get_match_candidates.ts
//
// CORREÇÃO DE ESCALABILIDADE: Deck de match server-side.
//
// Antes: o cliente baixava MatchIndex inteiro + Matchs/{myUid} inteiro
// e filtrava em memória. Custo absurdo em egress.
//
// Agora: o servidor filtra, exclui e pagina — o cliente recebe ~20 perfis por vez.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getDatabase } from "firebase-admin/database";

const DECK_SIZE = 20;

// Cooldown de dislike: 60 dias
const DISLIKE_COOLDOWN_MS = 60 * 24 * 60 * 60 * 1000;

interface MatchRequest {
  latitude: number;
  longitude: number;
  distanciaKm?: number;
  onlyInDistance?: boolean;
  generos?: string[];
  orientacoes?: string[];
  relacionamentos?: string[];
  idadeMin?: number;
  idadeMax?: number;
  onlyInAge?: boolean;
  tipoLocalizacao?: string;
  latCustom?: number;
  lngCustom?: number;
}

export const getMatchCandidates = onCall(
  {
    region: "us-central1",
    memory: "512MiB",
    timeoutSeconds: 100,
  },
  async (request) => {
    const myUid = request.auth?.uid;
    if (!myUid) throw new HttpsError("unauthenticated", "Login necessário");

    const data = request.data as MatchRequest;
    const db = getDatabase();

    // ── 1. Busca tudo em paralelo ────────────────────────────────────────
    const [
      matchIndexSnap,
      likesGivenSnap,
      dislikesSnap,
      dislikesReceivedSnap,
      matchedSnap,
      chatPartnersSnap,
    ] = await Promise.all([
      db.ref("MatchIndex").get(),
      db.ref(`Matchs/${myUid}/likes_given`).get(),
      db.ref(`Matchs/${myUid}/dislikes`).get(),
      db.ref(`Matchs/${myUid}/dislikes_received`).get(),
      db.ref(`Matchs/${myUid}/matched`).get(),
      db.ref(`UserChatRequests/${myUid}`).get(),
    ]);

    if (!matchIndexSnap.exists()) return { candidates: [] };

    // ── 2. UIDs excluídos ────────────────────────────────────────────────
    const blocked = new Set<string>([myUid]);
    const now = Date.now();

    // Likes já dados
    if (likesGivenSnap.exists()) {
      for (const uid of Object.keys(likesGivenSnap.val() as Record<string, unknown>)) {
        blocked.add(uid);
      }
    }

    // Dislikes dados (com cooldown)
    if (dislikesSnap.exists()) {
      const dislikes = dislikesSnap.val() as Record<string, { created_at?: number }>;
      for (const [uid, val] of Object.entries(dislikes)) {
        const elapsed = now - (val.created_at ?? 0);
        if (elapsed < DISLIKE_COOLDOWN_MS) blocked.add(uid);
      }
    }

    // Dislikes recebidos
    if (dislikesReceivedSnap.exists()) {
      const dislikes = dislikesReceivedSnap.val() as Record<string, { created_at?: number }>;
      for (const [uid, val] of Object.entries(dislikes)) {
        const elapsed = now - (val.created_at ?? 0);
        if (elapsed < DISLIKE_COOLDOWN_MS) blocked.add(uid);
      }
    }

    // Matches
    if (matchedSnap.exists()) {
      for (const uid of Object.keys(matchedSnap.val() as Record<string, unknown>)) {
        blocked.add(uid);
      }
    }

    // Chat partners aceitos
    if (chatPartnersSnap.exists()) {
      const chats = chatPartnersSnap.val() as Record<string, string>;
      for (const [key, status] of Object.entries(chats)) {
        if (status !== "accepted") continue;
        const parts = key.split("_");
        if (parts.length === 2) {
          blocked.add(parts[0] === myUid ? parts[1] : parts[0]);
        }
      }
    }

    // ── 3. Referência de localização ─────────────────────────────────────
    const refLat =
      data.tipoLocalizacao === "personalizada" && data.latCustom != null
        ? data.latCustom
        : data.latitude;
    const refLng =
      data.tipoLocalizacao === "personalizada" && data.lngCustom != null
        ? data.lngCustom
        : data.longitude;

    // ── 4. Filtrar candidatos ────────────────────────────────────────────
    const indexData = matchIndexSnap.val() as Record<string, Record<string, unknown>>;
    const candidates: Array<Record<string, unknown>> = [];

    for (const [uid, profile] of Object.entries(indexData)) {
      if (blocked.has(uid)) continue;
      if (!profile || typeof profile !== "object") continue;

      const name = ((profile.name as string) ?? "").trim();
      if (!name) continue;

      const lat = profile.latitude as number | undefined;
      const lng = profile.longitude as number | undefined;

      // Calcular distância
      let distanceKm: number | null = null;
      if (lat != null && lng != null && refLat != null && refLng != null) {
        distanceKm = haversineKm(refLat, refLng, lat, lng);
      }

      // Filtro de distância
      if (data.onlyInDistance && data.distanciaKm) {
        if (distanceKm == null || distanceKm > data.distanciaKm) continue;
      }

      // Filtro de gênero
      if (data.generos && data.generos.length > 0) {
        const g = ((profile.gender_identity as string) ?? "").toLowerCase();
        if (!data.generos.some((f) => f.toLowerCase() === g)) continue;
      }

      // Filtro de orientação
      if (data.orientacoes && data.orientacoes.length > 0) {
        const o = ((profile.sexual_orientation as string) ?? "").toLowerCase();
        if (!data.orientacoes.some((f) => f.toLowerCase() === o)) continue;
      }

      // Filtro de tipo de relacionamento
      if (data.relacionamentos && data.relacionamentos.length > 0) {
        const r = ((profile.relationship_type as string) ?? "").toLowerCase();
        if (!data.relacionamentos.some((f) => f.toLowerCase() === r)) continue;
      }

      // Filtro de idade
      if (data.onlyInAge && data.idadeMin != null && data.idadeMax != null) {
        const age = profile.age as number | undefined;
        if (age == null || age < data.idadeMin || age > data.idadeMax) continue;
      }

      candidates.push({
        uid,
        name,
        avatar: profile.avatar ?? "",
        bio: profile.bio ?? "",
        bairro: profile.bairro ?? "",
        city: profile.city ?? "",
        state: profile.state ?? "",
        interests: profile.interests ?? [],
        gender_identity: profile.gender_identity ?? "",
        sexual_orientation: profile.sexual_orientation ?? "",
        relationship_type: profile.relationship_type ?? "",
        profile_type: profile.profile_type ?? "",
        age: profile.age,
        partner: profile.partner ?? null,
        latitude: lat,
        longitude: lng,
        distanceKm: distanceKm != null ? Math.round(distanceKm * 10) / 10 : null,
      });

      // Limita a DECK_SIZE para evitar payload gigante
      if (candidates.length >= DECK_SIZE) break;
    }

    // ── 5. Ordena por distância ──────────────────────────────────────────
    candidates.sort((a, b) => {
      const dA = (a.distanceKm as number) ?? Infinity;
      const dB = (b.distanceKm as number) ?? Infinity;
      return dA - dB;
    });

    return { candidates };
  }
);

// ── Helpers ──────────────────────────────────────────────────────────────────

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
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