// functions/src/rate_limiter.ts
//
// Rate limiter server-side para RTDB.
// Usa nó RateLimits/{uid}/{action} com contagem por janela de tempo.
// Só Cloud Functions escrevem neste nó (regras: ".write": false).

import { getDatabase } from "firebase-admin/database";

interface RateLimitConfig {
  maxRequests: number;   // máximo de ações por janela
  windowMs: number;      // janela em milissegundos
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  create_post:       { maxRequests: 10,  windowMs: 3600_000 },      // 10 posts/hora
  create_story:      { maxRequests: 15,  windowMs: 3600_000 },      // 15 stories/hora
  send_message:      { maxRequests: 200, windowMs: 60_000 },        // 200 msgs/min
  send_chat_request: { maxRequests: 20,  windowMs: 3600_000 },      // 20 requests/hora
  like:              { maxRequests: 100, windowMs: 3600_000 },       // 100 likes/hora
  comment:           { maxRequests: 50,  windowMs: 3600_000 },       // 50 comments/hora
  report:            { maxRequests: 10,  windowMs: 86400_000 },      // 10 reports/dia
  follow:            { maxRequests: 60,  windowMs: 3600_000 },       // 60 follows/hora
  gallery_upload:    { maxRequests: 20,  windowMs: 3600_000 },       // 20 uploads/hora
  festa_create:      { maxRequests: 5,   windowMs: 86400_000 },      // 5 festas/dia
  match_like:        { maxRequests: 100, windowMs: 3600_000 },       // 100 likes/hora no match
};

/**
 * Verifica se o usuário pode realizar a ação.
 * Retorna true se permitido, false se rate-limited.
 *
 * Usa transaction para atomicidade.
 */
export async function checkRateLimit(
  uid: string,
  action: string,
): Promise<boolean> {
  const config = RATE_LIMITS[action];
  if (!config) return true; // ação sem limite configurado

  const db = getDatabase();
  const ref = db.ref(`RateLimits/${uid}/${action}`);
  const now = Date.now();

  const result = await ref.transaction((current: { count: number; window_start: number } | null) => {
    if (!current || !current.window_start) {
      // Primeira ação — inicializa janela
      return { count: 1, window_start: now };
    }

    const elapsed = now - current.window_start;
    if (elapsed > config.windowMs) {
      // Janela expirou — reseta
      return { count: 1, window_start: now };
    }

    if (current.count >= config.maxRequests) {
      // Limite atingido — aborta transaction sem modificar
      return; // returning undefined aborts
    }

    // Incrementa
    return { count: current.count + 1, window_start: current.window_start };
  });

  // Se a transaction foi abortada (retornou undefined), o rate limit foi atingido
  return result.committed;
}

/**
 * Wrapper que lança erro se rate-limited.
 */
export async function enforceRateLimit(uid: string, action: string): Promise<void> {
  const allowed = await checkRateLimit(uid, action);
  if (!allowed) {
    throw new Error(`rate_limited:${action}`);
  }
}

/**
 * Obtém configuração de rate limit para uma ação.
 */
export function getRateLimitConfig(action: string): RateLimitConfig | undefined {
  return RATE_LIMITS[action];
}
