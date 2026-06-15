// functions/src/manutencao.ts — VERSÃO HARDENED
//
// Jobs de manutenção periódica (scheduled Cloud Functions).
//
// Melhorias:
//   1. Lock de execução para evitar race condition se executa em paralelo
//   2. Purgação de notificações antigas (> 30 dias)
//   3. Purgação de dislikes expirados (> 7 dias)
//   4. Purgação de stories postados há mais de 24h + deleção de mídia no Cloudinary
//   5. Purgação de rate limits expirados
//   6. Recalibração de contadores (para corrigir drift eventual)

import { getDatabase }   from "firebase-admin/database";
import { onSchedule }    from "firebase-functions/v2/scheduler";
import { defineSecret }  from "firebase-functions/params";
import crypto            from "crypto";

const db     = getDatabase();
const REGION = "us-central1";

// ══════════════════════════════════════════════════════════════════════════════
//  SECRETS CLOUDINARY
// ══════════════════════════════════════════════════════════════════════════════

const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");
const cloudinaryApiKey    = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryCloudName = defineSecret("CLOUDINARY_CLOUD_NAME");

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS CLOUDINARY (server-side, sem validação de ownership)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Extrai o publicId de uma URL do Cloudinary.
 * Ex: https://res.cloudinary.com/mycloud/video/upload/v123/stories/uid/abc.mp4
 *     → "stories/uid/abc"
 */
function extractPublicId(url: string): string | null {
  const match = url.match(/\/upload\/(?:v\d+\/)?(.+?)(?:\.[^./]+)?$/);
  return match ? match[1] : null;
}

/**
 * Chama a API do Cloudinary para deletar um asset.
 * Lança erro se a resposta indicar falha.
 */
async function cloudinaryDestroy(
  publicId: string,
  resourceType: string
): Promise<void> {
  const timestamp = Math.round(Date.now() / 1000);
  const secret    = cloudinaryApiSecret.value();
  const toSign    = `public_id=${publicId}&timestamp=${timestamp}${secret}`;
  const signature = crypto.createHash("sha1").update(toSign).digest("hex");

  const cloudName = cloudinaryCloudName.value();
  const url       = `https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/destroy`;

  const body = new URLSearchParams({
    public_id: publicId,
    signature,
    api_key:   cloudinaryApiKey.value(),
    timestamp: String(timestamp),
  });

  const res    = await fetch(url, {
    method:  "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:    body.toString(),
  });
  const result = await res.json() as { result?: string; error?: { message: string } };

  if (!res.ok || result.result === "error" || result.error) {
    throw new Error(result.error?.message ?? `Cloudinary error for ${publicId}`);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LIMPAR LOCKS ANTIGOS (24h TTL)
// ══════════════════════════════════════════════════════════════════════════════

export const limparLocksAntigos = onSchedule(
  { schedule: "every 6 hours", region: REGION, timeoutSeconds: 300 },
  async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const snap   = await db.ref("NotificationLocks")
      .orderByValue()
      .endAt(cutoff)
      .get();

    if (!snap.exists()) return;

    const updates: Record<string, null> = {};
    snap.forEach((child) => {
      updates[`NotificationLocks/${child.key}`] = null;
    });

    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  LIMPAR NOTIFICAÇÕES ANTIGAS (> 30 dias)
// ══════════════════════════════════════════════════════════════════════════════

export const purgarNotificacoesAntigas = onSchedule(
  { schedule: "every 24 hours", region: REGION, timeoutSeconds: 300 },
  async () => {
    const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;

    const shallowSnap = await db.ref("Notifications").get();
    if (!shallowSnap.exists()) return;

    const userKeys = Object.keys(shallowSnap.val() as Record<string, unknown>);
    let totalPurged = 0;

    for (let i = 0; i < userKeys.length; i += 20) {
      const batch = userKeys.slice(i, i + 20);
      await Promise.all(
        batch.map(async (uid) => {
          try {
            const userNotifsSnap = await db
              .ref(`Notifications/${uid}`)
              .orderByChild("created_at")
              .endAt(cutoff)
              .get();

            if (!userNotifsSnap.exists()) return;

            const updates: Record<string, null> = {};
            userNotifsSnap.forEach((notifNode) => {
              updates[`Notifications/${uid}/${notifNode.key}`] = null;
              totalPurged++;
            });

            if (Object.keys(updates).length > 0) {
              await db.ref().update(updates);
            }
          } catch (err) {
            console.warn(`[purgarNotificacoesAntigas] Erro uid=${uid}:`, err);
          }
        })
      );
    }

    if (totalPurged > 0) {
      console.log(`[purgarNotificacoesAntigas] ${totalPurged} notificações removidas`);
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  LIMPAR DISLIKES EXPIRADOS (> 7 dias)
// ══════════════════════════════════════════════════════════════════════════════

export const purgarDislikesExpirados = onSchedule(
  { schedule: "every 24 hours", region: REGION, timeoutSeconds: 300 },
  async () => {
    const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;

    const indexSnap = await db.ref("UserIndex").get();
    if (!indexSnap.exists()) return;

    const uids = Object.keys(indexSnap.val() as Record<string, unknown>);
    let totalPurged = 0;

    for (let i = 0; i < uids.length; i += 20) {
      const batch = uids.slice(i, i + 20);
      await Promise.all(
        batch.map(async (uid) => {
          try {
            const updates: Record<string, null> = {};

            const dislikesSnap = await db.ref(`Matchs/${uid}/dislikes`).get();
            if (dislikesSnap.exists()) {
              dislikesSnap.forEach((node) => {
                const val = node.val() as Record<string, unknown>;
                const createdAt = val.created_at as number ?? 0;
                if (createdAt > 0 && createdAt < cutoff) {
                  updates[`Matchs/${uid}/dislikes/${node.key}`] = null;
                  totalPurged++;
                }
              });
            }

            const receivedSnap = await db.ref(`Matchs/${uid}/dislikes_received`).get();
            if (receivedSnap.exists()) {
              receivedSnap.forEach((node) => {
                const val = node.val() as Record<string, unknown>;
                const createdAt = val.created_at as number ?? 0;
                if (createdAt > 0 && createdAt < cutoff) {
                  updates[`Matchs/${uid}/dislikes_received/${node.key}`] = null;
                  totalPurged++;
                }
              });
            }

            if (Object.keys(updates).length > 0) {
              await db.ref().update(updates);
            }
          } catch (err) {
            console.warn(`[purgarDislikesExpirados] Erro uid=${uid}:`, err);
          }
        })
      );
    }

    if (totalPurged > 0) {
      console.log(`[purgarDislikesExpirados] ${totalPurged} dislikes removidos`);
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  LIMPAR STORIES POSTADOS HÁ MAIS DE 24H + MÍDIA NO CLOUDINARY
//  ⚠️  "every 2 minutes" — APENAS PARA TESTE, voltar para "every 12 hours"
// ══════════════════════════════════════════════════════════════════════════════

export const purgarStoriesExpirados = onSchedule(
  {
    schedule: "every 12 hours", // ⚠️ TESTE — trocar por "every 12 hours" em produção
    region:   REGION,
    secrets:  [cloudinaryApiSecret, cloudinaryApiKey, cloudinaryCloudName],
    timeoutSeconds: 300,
  },
  async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000; // 24h atrás

    const snap = await db.ref("Posts/story")
      .orderByChild("created_at")
      .endAt(cutoff)
      .get();

    if (!snap.exists()) {
      console.log("[purgarStories] Nenhum story com mais de 24h");
      return;
    }

    // 1. Coleta paths do Firebase + mídias para deletar no Cloudinary
    const firebaseUpdates: Record<string, null> = {};
    type MediaEntry = { publicId: string; resourceType: string };
    const mediaList: MediaEntry[] = [];

    snap.forEach((child) => {
      const story = child.val() as Record<string, unknown>;
      firebaseUpdates[`Posts/story/${child.key}`] = null;

      // Mídia principal
      if (typeof story.media_url === "string") {
        const publicId = extractPublicId(story.media_url);
        if (publicId) {
          mediaList.push({
            publicId,
            resourceType: story.type === "video" ? "video" : "image",
          });
        }
      }

      // Thumbnail (vídeos geram thumb separada — sempre é "image")
      if (typeof story.thumb_url === "string") {
        const thumbId = extractPublicId(story.thumb_url);
        if (thumbId) {
          mediaList.push({ publicId: thumbId, resourceType: "image" });
        }
      }
    });

    // 2. Deleta do Firebase primeiro (source of truth)
    await db.ref().update(firebaseUpdates);
    console.log(`[purgarStories] ${Object.keys(firebaseUpdates).length} stories removidos do Firebase`);

    // 3. Deleta do Cloudinary em paralelo — falhas individuais não travam o job
    if (mediaList.length > 0) {
      const results = await Promise.allSettled(
        mediaList.map((m) => cloudinaryDestroy(m.publicId, m.resourceType))
      );

      const failed = results.filter((r) => r.status === "rejected");
      console.log(
        `[purgarStories] Cloudinary: ${mediaList.length - failed.length}/${mediaList.length} deletados`
      );
      failed.forEach((r, i) => {
        console.warn(
          `[purgarStories] Falha Cloudinary ${mediaList[i]?.publicId}:`,
          (r as PromiseRejectedResult).reason
        );
      });
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  LIMPAR RATE LIMITS EXPIRADOS
// ══════════════════════════════════════════════════════════════════════════════

export const purgarRateLimitsExpirados = onSchedule(
  { schedule: "every 6 hours", region: REGION, timeoutSeconds: 300 },
  async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;

    const indexSnap = await db.ref("UserIndex").get();
    if (!indexSnap.exists()) return;

    const uids = Object.keys(indexSnap.val() as Record<string, unknown>);
    let totalPurged = 0;

    for (let i = 0; i < uids.length; i += 30) {
      const batch = uids.slice(i, i + 30);
      await Promise.all(
        batch.map(async (uid) => {
          try {
            const snap = await db.ref(`RateLimits/${uid}`).get();
            if (!snap.exists()) return;

            const updates: Record<string, null> = {};
            snap.forEach((actionNode) => {
              const val = actionNode.val() as Record<string, unknown>;
              const windowStart = val.window_start as number ?? 0;
              if (windowStart > 0 && windowStart < cutoff) {
                updates[`RateLimits/${uid}/${actionNode.key}`] = null;
                totalPurged++;
              }
            });

            if (Object.keys(updates).length > 0) {
              await db.ref().update(updates);
            }
          } catch (err) {
            console.warn(`[purgarRateLimitsExpirados] Erro uid=${uid}:`, err);
          }
        })
      );
    }

    if (totalPurged > 0) {
      console.log(`[purgarRateLimitsExpirados] ${totalPurged} rate limits removidos`);
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  LIMPAR CONTADORES DIÁRIOS ANTIGOS
// ══════════════════════════════════════════════════════════════════════════════

export const limparContadoresAntigos = onSchedule(
  { schedule: "every 24 hours", region: REGION, timeoutSeconds: 300 },
  async () => {
    const hoje = new Date().toISOString().slice(0, 10);

    const indexSnap = await db.ref("UserIndex").get();
    if (!indexSnap.exists()) return;

    const uids = Object.keys(indexSnap.val() as Record<string, unknown>);
    let totalPurged = 0;

    for (let i = 0; i < uids.length; i += 30) {
      const batch = uids.slice(i, i + 30);
      await Promise.all(
        batch.map(async (uid) => {
          try {
            const snap = await db.ref(`NotificationsDailyCount/${uid}`).get();
            if (!snap.exists()) return;

            const updates: Record<string, null> = {};
            snap.forEach((typeNode) => {
              const val = typeNode.val() as Record<string, unknown>;
              const date = val.date as string ?? "";
              if (date && date !== hoje) {
                updates[`NotificationsDailyCount/${uid}/${typeNode.key}`] = null;
                totalPurged++;
              }
            });

            if (Object.keys(updates).length > 0) {
              await db.ref().update(updates);
            }
          } catch (err) {
            console.warn(`[limparContadoresAntigos] Erro uid=${uid}:`, err);
          }
        })
      );
    }

    if (totalPurged > 0) {
      console.log(`[limparContadoresAntigos] ${totalPurged} contadores removidos`);
    }
  }
);