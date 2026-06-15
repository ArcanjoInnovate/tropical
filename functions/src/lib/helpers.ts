// src/helpers.ts

import { getDatabase, ServerValue } from "firebase-admin/database";
import { getMessaging }             from "firebase-admin/messaging";
import * as nodemailer               from "nodemailer";
import { NotifData, UserSuspenso }  from "./types";

// ── Limites de notificação ────────────────────────────────────────────────────
export const MAX_DAILY           = 8;
export const FOLLOW_GROUP_SIZE   = 3;
export const LIKE_GROUP_SIZE     = 5;
export const MAX_FOLLOW_PER_DAY  = 2;
export const MAX_LIKE_PER_DAY    = 3;
export const MAX_COMMENT_PER_DAY = 8;

// ── Formatação ────────────────────────────────────────────────────────────────
export function formatarData(ms: number): string {
  return new Date(ms).toLocaleDateString("pt-BR", {
    day: "2-digit", month: "long", year: "numeric",
    hour: "2-digit", minute: "2-digit",
    timeZone: "America/Sao_Paulo",
  });
}

export function formatarDataCurta(ms: number): string {
  return new Date(ms).toLocaleDateString("pt-BR", {
    day: "2-digit", month: "long", year: "numeric",
    timeZone: "America/Sao_Paulo",
  });
}

// ── Database ──────────────────────────────────────────────────────────────────
export function gerarProtocolo(): string {
  const ts   = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `TCLUB-${ts}-${rand}`;
}

export async function getEmail(uid: string): Promise<string | null> {
  try {
    const snap = await getDatabase().ref(`Users/${uid}/email`).get();
    return snap.val() ?? null;
  } catch { return null; }
}

export async function getNome(uid: string): Promise<string> {
  try {
    const snap = await getDatabase().ref(`Users/${uid}/name`).get();
    return snap.val() ?? uid;
  } catch { return uid; }
}

export async function verificarSuspensaoUsuario(uid: string): Promise<void> {
  const db    = getDatabase();
  const agora = Date.now();
  const userSnap = await db.ref(`Users/${uid}`).get();
  if (!userSnap.exists()) return;
  const user = userSnap.val() as UserSuspenso;
  if (user.suspenso && user.suspensao_fim && user.suspensao_fim <= agora) {
    await db.ref(`Users/${uid}`).update({
      suspenso:                 null,
      suspensao_fim:            null,
      penalidade_ativa:         null,
      reativacao_solicitada:    null,
      reativacao_solicitada_em: null,
    });
    console.log(`[verificarSuspensaoUsuario] Suspensão expirada uid=${uid}`);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  recalcUnreadChatsCount
//  Agora escreve em UserBadges/{uid}/unreadChatsCount
// ══════════════════════════════════════════════════════════════════════════════

export async function recalcUnreadChatsCount(uid: string): Promise<void> {
  const db = getDatabase();
  try {
    const userChatsSnap = await db.ref(`UserChatRequests/${uid}`).get();
    if (!userChatsSnap.exists()) {
      await db.ref(`UserBadges/${uid}/unreadChatsCount`).set(0);
      return;
    }
    const chatData = userChatsSnap.val() as Record<string, string>;
    const chatIds  = Object.keys(chatData).filter((id) => chatData[id] === "accepted");
    if (chatIds.length === 0) {
      await db.ref(`UserBadges/${uid}/unreadChatsCount`).set(0);
      return;
    }
    const snaps = await Promise.all(
      chatIds.map((id) => db.ref(`Chats/${id}/unreadCount/${uid}`).get())
    );
    const count = snaps.reduce((acc, snap) => {
      const val = snap.val();
      return acc + (typeof val === "number" && val > 0 ? 1 : 0);
    }, 0);
    await db.ref(`UserBadges/${uid}/unreadChatsCount`).set(count);
    console.log(`[recalcUnreadChatsCount] uid=${uid} → ${count}`);
  } catch (err) {
    console.error(`[recalcUnreadChatsCount] Erro uid=${uid}:`, err);
  }
}

// ── Notificações ──────────────────────────────────────────────────────────────
export function getTodayKey(): string {
  const d  = new Date();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${d.getUTCFullYear()}-${mm}-${dd}`;
}

export async function canSendNotification(
  uid:  string,
  type: "follow" | "like" | "comment",
): Promise<boolean> {
  const db    = getDatabase();
  const snap  = await db.ref(`NotificationsDailyCount/${uid}/${getTodayKey()}`).get();
  if (!snap.exists()) return true;
  const data = snap.val() as Record<string, number>;
  if ((data.total ?? 0) >= MAX_DAILY) return false;
  const byType = data[type] ?? 0;
  if (type === "follow"  && byType >= MAX_FOLLOW_PER_DAY)  return false;
  if (type === "like"    && byType >= MAX_LIKE_PER_DAY)    return false;
  if (type === "comment" && byType >= MAX_COMMENT_PER_DAY) return false;
  return true;
}

export async function incrementDailyCount(uid: string, type: string): Promise<void> {
  const db  = getDatabase();
  const ref = db.ref(`NotificationsDailyCount/${uid}/${getTodayKey()}`);
  await Promise.all([
    ref.child("total").set(ServerValue.increment(1)),
    ref.child(type).set(ServerValue.increment(1)),
    ref.child("updated_at").set(Date.now()),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  updateNotifBadge
//  Agora escreve em UserBadges/{uid}/unreadNotificationsCount
// ══════════════════════════════════════════════════════════════════════════════

export async function updateNotifBadge(uid: string): Promise<void> {
  const db   = getDatabase();
  const snap = await db.ref(`Notifications/${uid}`).get();
  if (!snap.exists()) {
    await db.ref(`UserBadges/${uid}/unreadNotificationsCount`).set(0);
    return;
  }
  let count = 0;
  snap.forEach((child) => {
    const val = child.val() as Record<string, unknown>;
    if (!val?.read) count++;
  });
  await db.ref(`UserBadges/${uid}/unreadNotificationsCount`).set(count);
}

export async function writeAndNotify(uid: string, notif: NotifData, fcmBody: string): Promise<void> {
  const db  = getDatabase();
  const key = db.ref(`Notifications/${uid}`).push().key!;
  await db.ref(`Notifications/${uid}/${key}`).set({ ...notif, id: key });
  await updateNotifBadge(uid);
  await sendFcmNotif({
    recipientUid: uid,
    title:        notif.title,
    body:         fcmBody,
    data: {
      type:       notif.type,
      targetId:   notif.target_id   ?? "",
      targetType: notif.target_type ?? "",
      actorUid:   notif.actor_uid   ?? "",
    },
  });
}

// ── FCM ───────────────────────────────────────────────────────────────────────
export async function sendFcmNotif(opts: {
  recipientUid: string;
  title:        string;
  body:         string;
  data:         Record<string, string>;
}): Promise<void> {
  const db        = getDatabase();
  const tokenSnap = await db.ref(`Users/${opts.recipientUid}/fcmToken`).get();
  const token     = tokenSnap.val() as string | null;
  if (!token) {
    console.warn(`[sendFcmNotif] No token uid=${opts.recipientUid}`);
    return;
  }
  try {
    await getMessaging().send({
      token,
      notification: { title: opts.title, body: opts.body },
      data: opts.data,
      android: { priority: "high", notification: { sound: "default" } },
      apns:    { payload: { aps: { sound: "default", badge: 1 } } },
    });
  } catch (err: unknown) {
    console.error(`[sendFcmNotif] Error uid=${opts.recipientUid}:`, err);
    const code = (err as { code?: string })?.code;
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      await db.ref(`Users/${opts.recipientUid}/fcmToken`).remove();
    }
  }
}

export async function sendChatFcm(opts: {
  token:       string;
  recipientId: string;
  chatId:      string;
  senderId:    string;
  msgId:       string;
  senderName:  string;
  body:        string;
}): Promise<void> {
  const db = getDatabase();
  try {
    await getMessaging().send({
      token: opts.token,
      notification: { title: opts.senderName, body: opts.body },
      data: {
        type:       "chat_message",
        chat_id:    opts.chatId,
        other_uid:  opts.senderId,
        message_id: opts.msgId,
      },
      android: { priority: "high", notification: { sound: "default" } },
      apns: { payload: { aps: { sound: "default", badge: 1, "thread-id": opts.chatId } } },
    });
  } catch (err: unknown) {
    console.error(`[sendChatFcm] Error:`, err);
    const code = (err as { code?: string })?.code;
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      await db.ref(`Users/${opts.recipientId}/fcmToken`).remove();
    }
  }
}

// ── Email ─────────────────────────────────────────────────────────────────────
export const getTransporter = (): nodemailer.Transporter =>
  nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER ?? "",
      pass: process.env.EMAIL_PASS ?? "",
    },
  });

// ── Storage ───────────────────────────────────────────────────────────────────
export async function deleteStorageFolder(path: string): Promise<void> {
  const { getStorage } = await import("firebase-admin/storage");
  try {
    const bucket = getStorage().bucket();
    const [files] = await bucket.getFiles({ prefix: `${path}/` });
    if (files.length === 0) return;
    await Promise.all(files.map((f) => f.delete().catch(() => null)));
    console.log(`[deleteStorageFolder] ${files.length} arquivos em ${path}`);
  } catch (err) {
    console.warn(`[deleteStorageFolder] Falha em ${path}:`, err);
  }
}