// src/manutencao.ts
//
// NÍVEL 2.10 — Adicionadas funções de purgação automática:
//   - purgarNotificacoesAntigas: remove notificações lidas com mais de 30 dias
//   - purgarDislikesExpirados: remove dislikes com mais de 7 dias
// Executam junto com a manutenção diária às 3h BRT.

import { onSchedule }    from "firebase-functions/v2/scheduler";
import { getDatabase, Database } from "firebase-admin/database";
import { HttpsError, onCall } from "firebase-functions/https";

// callable/deletePostComplete.ts
export const deletePostComplete = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login necessário");
    
    const { postId } = request.data as { postId: string };
    const db = getDatabase();
    
    // Verifica ownership
    const post = await db.ref(`Posts/post/${postId}`).get();
    if (!post.exists()) throw new HttpsError("not-found", "Post não existe");
    
    const postData = post.val() as Record<string, unknown>;
    if (postData.user_id !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Não é seu post");
    }
    
    // Admin SDK ignora rules — deleta tudo de uma vez
    await db.ref().update({
      [`Posts/post/${postId}`]: null,
      [`PostLikes/${postId}`]: null,
      [`Comments/${postId}`]: null,
    });
    
    // ✅ FIX: renomeia 'tipo' para 'resourceType' e normaliza para o que
    // o Cloudinary espera ('video' ou 'image'), evitando que vídeos sejam
    // tratados como imagem e o delete no Cloudinary falhe silenciosamente.
    return {
      deleted: true,
      mediaUrl: postData.media_url,
      thumbUrl: postData.thumb_url,
      resourceType: postData.tipo === 'video' ? 'video' : 'image',
    };
  }
);

export const manutencaoDiaria = onSchedule(
  {
    schedule:       "0 3 * * *",
    timeZone:       "America/Sao_Paulo",
    region:         "us-central1",
    memory:         "256MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const db    = getDatabase();
    const agora = Date.now();
    console.log("[manutencaoDiaria] Iniciando...");

    const resultados = await Promise.allSettled([
      arquivarFestasVencidas(db, agora),
      limparLocksAntigos(db, agora),
      limparContadoresAntigos(db, agora),
      purgarNotificacoesAntigas(db, agora),
      purgarDislikesExpirados(db, agora),
    ]);

    const tarefas = [
      "Arquivar festas",
      "Limpar locks",
      "Limpar contadores",
      "Purgar notificações",
      "Purgar dislikes",
    ];
    resultados.forEach((r, i) => {
      if (r.status === "rejected") console.error(`[manutencaoDiaria] ${tarefas[i]} falhou:`, r.reason);
      else console.log(`[manutencaoDiaria] ${tarefas[i]} concluída`);
    });

    console.log("[manutencaoDiaria] Concluída");
  }
);

async function arquivarFestasVencidas(db: Database, agora: number): Promise<void> {
  const festasRef  = db.ref("Festas");
  const festasSnap = await festasRef.orderByChild("data_fim").endAt(agora).limitToFirst(100).get();
  if (!festasSnap.exists()) { console.log("[arquivarFestas] Nenhuma festa"); return; }

  const updates: Record<string, string> = {};
  let count = 0;
  festasSnap.forEach((child) => {
    const festa   = child.val() as Record<string, unknown>;
    const festaId = child.key as string;
    if (festa?.status === "ativa") {
      updates[`${festaId}/status`]      = "arquivada";
      updates[`${festaId}/arquivada_em`] = agora.toString();
      count++;
    }
  });

  if (count > 0) { await festasRef.update(updates); console.log(`[arquivarFestas] ${count} festas`); }
}

async function limparLocksAntigos(db: Database, agora: number): Promise<void> {
  const cutoff   = agora - 24 * 60 * 60 * 1000;
  const locksRef = db.ref("NotificationLocks/chat_msg");
  const snap     = await locksRef.orderByChild("created_at").endAt(cutoff).limitToFirst(200).get();
  if (!snap.exists()) { console.log("[limparLocks] Nenhum lock"); return; }

  const updates: Record<string, null> = {};
  snap.forEach((child) => { updates[child.key!] = null; });
  await locksRef.update(updates);
  console.log(`[limparLocks] ${Object.keys(updates).length} locks removidos`);
}

async function limparContadoresAntigos(db: Database, agora: number): Promise<void> {
  const sevenDaysAgo = new Date(agora - 7 * 24 * 60 * 60 * 1000);
  const cutoffKey    = `${sevenDaysAgo.getUTCFullYear()}-${String(sevenDaysAgo.getUTCMonth() + 1).padStart(2, "0")}-${String(sevenDaysAgo.getUTCDate()).padStart(2, "0")}`;

  const configRef    = db.ref("_maintenance/lastProcessedUser");
  const lastProcessed = (await configRef.get()).val() as string | null;
  let query = db.ref("NotificationsDailyCount").limitToFirst(50);
  if (lastProcessed) query = query.startAfter(lastProcessed);

  const countsSnap = await query.get();
  if (!countsSnap.exists()) { await configRef.set(null); console.log("[limparContadores] Ciclo completo"); return; }

  const updates: Record<string, null> = {};
  let lastUid: string | null = null;
  let total = 0;
  countsSnap.forEach((userChild) => {
    lastUid = userChild.key as string;
    userChild.forEach((dateChild) => {
      if ((dateChild.key as string) < cutoffKey) { updates[`NotificationsDailyCount/${lastUid}/${dateChild.key}`] = null; total++; }
    });
  });

  if (Object.keys(updates).length > 0) { await db.ref().update(updates); console.log(`[limparContadores] ${total} removidos`); }
  if (lastUid) await configRef.set(lastUid);
}

// ══════════════════════════════════════════════════════════════════════════════
//  NÍVEL 2.10 — PURGAÇÃO AUTOMÁTICA DE DADOS ANTIGOS
// ══════════════════════════════════════════════════════════════════════════════

async function purgarNotificacoesAntigas(db: Database, agora: number): Promise<void> {
  const cutoff30d = agora - 30 * 24 * 60 * 60 * 1000;

  const cursorRef = db.ref("_maintenance/lastPurgedNotifUser");
  const lastPurged = (await cursorRef.get()).val() as string | null;

  let query = db.ref("Notifications").limitToFirst(50);
  if (lastPurged) query = query.startAfter(lastPurged);

  const usersSnap = await query.get();
  if (!usersSnap.exists()) {
    await cursorRef.set(null);
    console.log("[purgarNotificacoes] Ciclo completo");
    return;
  }

  const updates: Record<string, null> = {};
  let lastUid: string | null = null;
  let total = 0;

  usersSnap.forEach((userChild) => {
    lastUid = userChild.key as string;
    if (userChild.val() && typeof userChild.val() === "object") {
      const notifs = userChild.val() as Record<string, { read?: boolean; created_at?: number }>;
      for (const [notifId, notif] of Object.entries(notifs)) {
        if (notif.read === true && notif.created_at && notif.created_at < cutoff30d) {
          updates[`Notifications/${lastUid}/${notifId}`] = null;
          total++;
        }
      }
    }
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`[purgarNotificacoes] ${total} notificações removidas`);
  }
  if (lastUid) await cursorRef.set(lastUid);
}

async function purgarDislikesExpirados(db: Database, agora: number): Promise<void> {
  const cutoff7d = agora - 7 * 24 * 60 * 60 * 1000;

  const cursorRef = db.ref("_maintenance/lastPurgedDislikeUser");
  const lastPurged = (await cursorRef.get()).val() as string | null;

  let query = db.ref("Matchs").limitToFirst(50);
  if (lastPurged) query = query.startAfter(lastPurged);

  const usersSnap = await query.get();
  if (!usersSnap.exists()) {
    await cursorRef.set(null);
    console.log("[purgarDislikes] Ciclo completo");
    return;
  }

  const updates: Record<string, null> = {};
  let lastUid: string | null = null;
  let total = 0;

  usersSnap.forEach((userChild) => {
    lastUid = userChild.key as string;
    const userData = userChild.val() as Record<string, unknown> | null;
    if (userData && typeof userData === "object") {
      const dislikes = userData["disliked"] as Record<string, number | boolean> | undefined;
      if (dislikes && typeof dislikes === "object") {
        for (const [dislikedUid, val] of Object.entries(dislikes)) {
          if (typeof val === "number" && val < cutoff7d) {
            updates[`Matchs/${lastUid}/disliked/${dislikedUid}`] = null;
            total++;
          }
        }
      }
    }
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
    console.log(`[purgarDislikes] ${total} dislikes removidos`);
  }
  if (lastUid) await cursorRef.set(lastUid);
}