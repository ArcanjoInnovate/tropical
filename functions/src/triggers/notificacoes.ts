// functions/src/notificacoes.ts
//
// MUDANÇAS vs versão anterior:
//   • notificarNovaCurtida — contador já estava correto com transaction().
//     Nenhuma mudança funcional aqui.
//   • notificarNovoComentario — contador já estava correto com transaction().
//     Nenhuma mudança funcional aqui.
//
// O cliente Flutter NÃO escreve mais em likes nem comment_count.
// Toda contagem passa por estas CFs via admin SDK + transaction(),
// o que elimina race conditions de escritas simultâneas.

import { getDatabase } from "firebase-admin/database";
import { getMessaging } from "firebase-admin/messaging";
import { onValueCreated } from "firebase-functions/v2/database";

import {
  verificarSuspensao,
  isBlocked,
  fetchUserBasicInfo,
  acquireIdempotencyLock,
} from "../lib/security_helpers";
import { checkRateLimit } from "../lib/rate_limiter";

const db     = getDatabase();
const REGION = "us-central1";

const GROUP_WINDOW_MS = 24 * 60 * 60 * 1000;

const MAX_DAILY: Record<string, number> = {
  follow:  8,
  like:    3,
  comment: 8,
  party:   5,
};

const GROUP_SIZE: Record<string, number> = {
  follow: 3,
  like:   5,
};

interface DailyCountEntry { date: string; count: number }

async function canSendNotification(uid: string, tipo: string): Promise<boolean> {
  const max = MAX_DAILY[tipo];
  if (!max) return true;

  const today = new Date().toISOString().slice(0, 10);
  const ref   = db.ref(`NotificationsDailyCount/${uid}/${tipo}`);
  const snap  = await ref.get();
  const entry = snap.val() as DailyCountEntry | null;

  if (!entry || entry.date !== today) {
    await ref.set({ date: today, count: 1 });
    return true;
  }
  if (entry.count >= max) return false;

  await ref.update({ count: entry.count + 1 });
  return true;
}

// ── FCM helper ────────────────────────────────────────────────────────────────
async function sendFcmNotif(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: data ?? {},
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            badge: 1,
            sound: "default",
            contentAvailable: true,
          },
        },
        headers: {
          "apns-priority": "10",
        },
      },
    });
  } catch (err: unknown) {
    const code = (err as { code?: string })?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      return;
    }
    throw err;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NOVO SEGUIDOR
// ══════════════════════════════════════════════════════════════════════════════

export const notificarNovoSeguidor = onValueCreated(
  { ref: "Followers/{followedUid}/{followerUid}", region: REGION, instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const followedUid = event.params.followedUid;
    const followerUid = event.params.followerUid;
    if (followedUid === followerUid) return null;

    const lockKey = `follow_${followerUid}_${followedUid}`;
    if (!(await acquireIdempotencyLock(lockKey))) return null;

    if (await isBlocked(followedUid, followerUid)) return null;

    try { await verificarSuspensao(followerUid); } catch { return null; }

    if (!(await checkRateLimit(followerUid, "follow"))) return null;
    if (!(await canSendNotification(followedUid, "follow"))) return null;

    const followerInfo = await fetchUserBasicInfo(followerUid);
    if (!followerInfo) return null;

    const existingNotifs = await db
      .ref(`Notifications/${followedUid}`)
      .orderByChild("type")
      .equalTo("follow")
      .limitToLast(1)
      .get();

    const now = Date.now();
    let grouped = false;

    if (existingNotifs.exists()) {
      existingNotifs.forEach((child) => {
        const val = child.val() as Record<string, unknown>;
        const ts  = val.created_at as number ?? 0;
        const cnt = (val.group_count as number) ?? 1;

        if (now - ts < GROUP_WINDOW_MS && cnt < (GROUP_SIZE.follow ?? 3)) {
          child.ref.update({
            group_count: cnt + 1,
            body: `${followerInfo.name} e mais ${cnt} pessoa${cnt > 1 ? "s" : ""} começaram a te seguir`,
            updated_at: now,
          });
          grouped = true;
        }
      });
    }

    if (!grouped) {
      await db.ref(`Notifications/${followedUid}`).push({
        type:        "follow",
        from_uid:    followerUid,
        from_name:   followerInfo.name,
        from_avatar: followerInfo.avatar,
        title:       "Novo seguidor",
        body:        `${followerInfo.name} começou a te seguir`,
        read:        false,
        created_at:  now,
        group_count: 1,
      });
    }

    const targetInfo = await fetchUserBasicInfo(followedUid);
    if (targetInfo?.fcmToken) {
      await sendFcmNotif(
        targetInfo.fcmToken,
        "Novo seguidor",
        `${followerInfo.name} começou a te seguir`,
        { type: "follow", uid: followerUid },
      );
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  NOVA CURTIDA EM POST
//
//  Dispara em PostLikes/{postId}/{likerUid} — onValueCreated.
//
//  CONTADOR (sempre roda, antes de qualquer checagem de bloqueio):
//    transaction() garante que dois likes simultâneos não percam nenhum
//    incremento — o cliente não escreve mais em likes diretamente.
//
//  NOTIFICAÇÃO (pode ser pulada por bloqueio/rate-limit/mesmo dono):
//    Só envia se o liker não for o dono do post.
// ══════════════════════════════════════════════════════════════════════════════

export const notificarNovaCurtida = onValueCreated(
  { ref: "PostLikes/{postId}/{likerUid}", region: REGION, instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const postId   = event.params.postId;
    const likerUid = event.params.likerUid;

    // ── Contador — roda sempre, independente de bloqueio/suspensão ───────────
    await db.ref(`Posts/post/${postId}/likes`).transaction(
      (current: number | null) => (current ?? 0) + 1
    );

    // ── Notificação — pode ser pulada ────────────────────────────────────────
    const postOwnerSnap = await db.ref(`Posts/post/${postId}/user_id`).get();
    const ownerUid = postOwnerSnap.val() as string | null;
    if (!ownerUid || ownerUid === likerUid) return null;

    const lockKey = `like_${likerUid}_${postId}`;
    if (!(await acquireIdempotencyLock(lockKey))) return null;

    if (await isBlocked(ownerUid, likerUid)) return null;

    try { await verificarSuspensao(likerUid); } catch { return null; }

    if (!(await canSendNotification(ownerUid, "like"))) return null;

    const likerInfo = await fetchUserBasicInfo(likerUid);
    if (!likerInfo) return null;

    const now = Date.now();

    await db.ref(`Notifications/${ownerUid}`).push({
      type:        "like",
      from_uid:    likerUid,
      from_name:   likerInfo.name,
      from_avatar: likerInfo.avatar,
      target_id:   postId,
      title:       "Nova curtida",
      body:        `${likerInfo.name} curtiu seu post`,
      read:        false,
      created_at:  now,
    });

    const ownerInfo = await fetchUserBasicInfo(ownerUid);
    if (ownerInfo?.fcmToken) {
      await sendFcmNotif(
        ownerInfo.fcmToken,
        "Nova curtida",
        `${likerInfo.name} curtiu seu post`,
        { type: "like", postId },
      );
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  NOVO COMENTÁRIO
//
//  Dispara em Comments/{postId}/{commentId} — onValueCreated.
//
//  CONTADOR (sempre roda):
//    transaction() em comment_count — o cliente não escreve mais diretamente.
//
//  NOTIFICAÇÃO (pode ser pulada por bloqueio/rate-limit/mesmo dono):
//    Só envia se o autor não for o dono do post.
// ══════════════════════════════════════════════════════════════════════════════

export const notificarNovoComentario = onValueCreated(
  { ref: "Comments/{postId}/{commentId}", region: REGION, instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const postId    = event.params.postId;
    const commentId = event.params.commentId;
    const data = event.data.val() as Record<string, unknown> | null;
    if (!data) return null;

    // ── Contador — roda sempre ───────────────────────────────────────────────
    await db.ref(`Posts/post/${postId}/comment_count`).transaction(
      (current: number | null) => (current ?? 0) + 1
    );

    // user_id é o campo padrão atual; author_id era o legado
    const authorUid = (data.user_id ?? data.author_id) as string | undefined;
    if (!authorUid) return null;

    const postOwnerSnap = await db.ref(`Posts/post/${postId}/user_id`).get();
    const ownerUid = postOwnerSnap.val() as string | null;
    if (!ownerUid || ownerUid === authorUid) return null;

    const lockKey = `comment_${commentId}`;
    if (!(await acquireIdempotencyLock(lockKey))) return null;

    if (await isBlocked(ownerUid, authorUid)) return null;

    try { await verificarSuspensao(authorUid); } catch { return null; }

    if (!(await canSendNotification(ownerUid, "comment"))) return null;

    const authorInfo = await fetchUserBasicInfo(authorUid);
    if (!authorInfo) return null;

    const commentText = (data.text ?? data.texto) as string ?? "";
    const preview = commentText.length > 50
      ? commentText.slice(0, 50) + "…"
      : commentText;
    const now = Date.now();

    await db.ref(`Notifications/${ownerUid}`).push({
      type:        "comment",
      from_uid:    authorUid,
      from_name:   authorInfo.name,
      from_avatar: authorInfo.avatar,
      target_id:   postId,
      title:       "Novo comentário",
      body:        `${authorInfo.name}: ${preview}`,
      read:        false,
      created_at:  now,
    });

    const ownerInfo = await fetchUserBasicInfo(ownerUid);
    if (ownerInfo?.fcmToken) {
      await sendFcmNotif(
        ownerInfo.fcmToken,
        "Novo comentário",
        `${authorInfo.name}: ${preview}`,
        { type: "comment", postId },
      );
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  ME CURTIU (MATCH)
// ══════════════════════════════════════════════════════════════════════════════

export const notificarMeCurtiu = onValueCreated(
  { ref: "Matchs/{uid}/like_me/{likerUid}", region: REGION, instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const uid      = event.params.uid;
    const likerUid = event.params.likerUid;
    if (uid === likerUid) return null;

    const lockKey = `like_me_${likerUid}_${uid}`;
    if (!(await acquireIdempotencyLock(lockKey))) return null;

    if (await isBlocked(uid, likerUid)) return null;

    try { await verificarSuspensao(likerUid); } catch { return null; }

    const likerInfo = await fetchUserBasicInfo(likerUid);
    if (!likerInfo) return null;

    const now = Date.now();

    await db.ref(`Notifications/${uid}`).push({
      type:        "like_me",
      from_uid:    likerUid,
      from_name:   likerInfo.name,
      from_avatar: likerInfo.avatar,
      title:       "Alguém te curtiu!",
      body:        "Alguém acabou de te curtir. Vai lá conferir!",
      read:        false,
      created_at:  now,
    });

    const targetInfo = await fetchUserBasicInfo(uid);
    if (targetInfo?.fcmToken) {
      await sendFcmNotif(
        targetInfo.fcmToken,
        "Alguém te curtiu!",
        "Alguém acabou de te curtir. Vai lá conferir!",
        { type: "like_me" },
      );
    }

    return null;
  }
);