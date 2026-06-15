// src/chat.ts
// (apenas recalcChatTabBadge e updateChatTabBadge* alterados para UserBadges)

import { onValueWritten, onValueCreated, onValueDeleted } from "firebase-functions/v2/database";
import { onCall, HttpsError }                             from "firebase-functions/v2/https";
import { getDatabase, ServerValue }                       from "firebase-admin/database";
import {
  updateNotifBadge, sendFcmNotif, sendChatFcm,
  recalcUnreadChatsCount,
} from "../lib/helpers";
import { assertUsersExist }                               from "../lib/userExists";
import { NotifData }                                      from "../lib/types";

// ══════════════════════════════════════════════════════════════════════════════
//  CALLABLES
// ══════════════════════════════════════════════════════════════════════════════

export const sendChatRequest = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login necessário.");

    const fromUid    = request.auth.uid;
    const { toUid, fromName, fromAvatar } = request.data as {
      toUid?:       string;
      fromName?:    string;
      fromAvatar?:  string;
    };

    if (!toUid)            throw new HttpsError("invalid-argument", "toUid obrigatório.");
    if (fromUid === toUid) throw new HttpsError("invalid-argument", "Não pode enviar para si mesmo.");

    const db  = getDatabase();
    const key = buildKey(fromUid, toUid);

    const snap = await db.ref(`ChatRequests/${key}`).get();
    if (snap.exists() && snap.val() instanceof Object) {
      const existing = snap.val() as { status?: string };
      if (existing.status === "accepted") return { result: "accepted" };
      if (existing.status === "pending")  return { result: "exists" };
    }

    await assertUsersExist({ remetente: fromUid, destinatário: toUid });

    const now = Date.now();
    await db.ref().update({
      [`ChatRequests/${key}`]: {
        from_uid:    fromUid,
        to_uid:      toUid,
        from_name:   fromName   ?? "",
        from_avatar: fromAvatar ?? "",
        status:      "pending",
        created_at:  now,
        seen:        false,
      },
      [`UserChatRequests/${toUid}/${key}`]:   "pending",
      [`UserChatRequests/${fromUid}/${key}`]: "pending",
    });

    return { result: "sent" };
  }
);

export const acceptChatRequest = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login necessário.");

    const myUid          = request.auth.uid;
    const { requestKey } = request.data as { requestKey?: string };

    if (!requestKey) throw new HttpsError("invalid-argument", "requestKey obrigatório.");

    const db      = getDatabase();
    const reqSnap = await db.ref(`ChatRequests/${requestKey}`).get();

    if (!reqSnap.exists() || !(reqSnap.val() instanceof Object)) {
      throw new HttpsError("not-found", "Solicitação não encontrada.");
    }

    const reqData = reqSnap.val() as { from_uid?: string; to_uid?: string; status?: string };

    if (reqData.to_uid !== myUid) throw new HttpsError("permission-denied", "Apenas o destinatário pode aceitar.");
    if (reqData.status !== "pending") throw new HttpsError("failed-precondition", "Solicitação não está pendente.");

    const fromUid = reqData.from_uid ?? "";
    if (!fromUid) throw new HttpsError("internal", "from_uid ausente na solicitação.");

    try {
      await assertUsersExist({ remetente: fromUid, destinatário: myUid });
    } catch (err) {
      await db.ref().update({
        [`ChatRequests/${requestKey}`]:                null,
        [`UserChatRequests/${myUid}/${requestKey}`]:   null,
        [`UserChatRequests/${fromUid}/${requestKey}`]: null,
      }).catch(() => {});
      throw err;
    }

    const sorted = ([myUid, fromUid] as string[]).sort();
    const chatId = `${sorted[0]}_${sorted[1]}`;
    const now    = Date.now();

    const updates: Record<string, unknown> = {
      [`ChatRequests/${requestKey}/status`]:         "accepted",
      [`ChatRequests/${requestKey}/seen`]:           true,
      [`UserChatRequests/${myUid}/${requestKey}`]:   "accepted",
      [`UserChatRequests/${fromUid}/${requestKey}`]: "accepted",
    };

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (!chatSnap.exists()) {
      updates[`Chats/${chatId}/user1`]                               = sorted[0];
      updates[`Chats/${chatId}/user2`]                               = sorted[1];
      updates[`Chats/${chatId}/metadata/last_message`]               = "";
      updates[`Chats/${chatId}/metadata/last_sender`]                = "";
      updates[`Chats/${chatId}/metadata/last_timestamp`]             = 0;
      updates[`Chats/${chatId}/metadata/created_at`]                 = now;
      updates[`Chats/${chatId}/unreadCount/${sorted[0]}`]            = 0;
      updates[`Chats/${chatId}/unreadCount/${sorted[1]}`]            = 0;
      updates[`Chats/${chatId}/participants/${sorted[0]}/status`]    = "offline";
      updates[`Chats/${chatId}/participants/${sorted[0]}/last_seen`] = now;
      updates[`Chats/${chatId}/participants/${sorted[1]}/status`]    = "offline";
      updates[`Chats/${chatId}/participants/${sorted[1]}/last_seen`] = now;
      updates[`ChatMessages/${chatId}/_placeholder/_init`]           = true;
    }

    await db.ref().update(updates);
    return { result: "accepted", chatId };
  }
);

export const declineChatRequest = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login necessário.");

    const myUid          = request.auth.uid;
    const { requestKey } = request.data as { requestKey?: string };

    if (!requestKey) throw new HttpsError("invalid-argument", "requestKey obrigatório.");

    const db      = getDatabase();
    const reqSnap = await db.ref(`ChatRequests/${requestKey}`).get();

    if (!reqSnap.exists() || !(reqSnap.val() instanceof Object)) {
      throw new HttpsError("not-found", "Solicitação não encontrada.");
    }

    const reqData = reqSnap.val() as { from_uid?: string; to_uid?: string; status?: string };

    if (reqData.to_uid !== myUid) throw new HttpsError("permission-denied", "Apenas o destinatário pode recusar.");
    if (reqData.status !== "pending") throw new HttpsError("failed-precondition", "Solicitação não está pendente.");

    const fromUid = reqData.from_uid ?? "";

    await db.ref().update({
      [`ChatRequests/${requestKey}/status`]:         "declined",
      [`ChatRequests/${requestKey}/seen`]:           true,
      [`UserChatRequests/${myUid}/${requestKey}`]:   "declined",
      ...(fromUid ? { [`UserChatRequests/${fromUid}/${requestKey}`]: "declined" } : {}),
    });

    return { result: "declined" };
  }
);

export const acceptLike = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login necessário.");

    const myUid        = request.auth.uid;
    const { likerUid } = request.data as { likerUid?: string };

    if (!likerUid)          throw new HttpsError("invalid-argument", "likerUid obrigatório.");
    if (myUid === likerUid) throw new HttpsError("invalid-argument", "Não pode curtir a si mesmo.");

    const db = getDatabase();

    const likeSnap = await db.ref(`Matchs/${myUid}/like_me/${likerUid}`).get();
    if (!likeSnap.exists()) throw new HttpsError("not-found", "Like não encontrado.");

    try {
      await assertUsersExist({ quemAceitou: myUid, quemCurtiu: likerUid });
    } catch (err) {
      await db.ref(`Matchs/${myUid}/like_me/${likerUid}`).remove().catch(() => {});
      throw err;
    }

    const sorted = [myUid, likerUid].sort();
    const chatId = `${sorted[0]}_${sorted[1]}`;
    const now    = Date.now();

    const updates: Record<string, unknown> = {
      [`Matchs/${myUid}/like_me/${likerUid}`]:    null,
      [`Matchs/${likerUid}/like_me/${myUid}`]:    null,
      [`Matchs/${myUid}/matched/${likerUid}`]:    true,
      [`Matchs/${likerUid}/matched/${myUid}`]:    true,
      [`UserChatRequests/${myUid}/${chatId}`]:    "accepted",
      [`UserChatRequests/${likerUid}/${chatId}`]: "accepted",
    };

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (!chatSnap.exists()) {
      updates[`Chats/${chatId}/user1`]                               = sorted[0];
      updates[`Chats/${chatId}/user2`]                               = sorted[1];
      updates[`Chats/${chatId}/metadata/last_message`]               = "";
      updates[`Chats/${chatId}/metadata/last_sender`]                = "";
      updates[`Chats/${chatId}/metadata/last_timestamp`]             = 0;
      updates[`Chats/${chatId}/metadata/created_at`]                 = now;
      updates[`Chats/${chatId}/unreadCount/${sorted[0]}`]            = 0;
      updates[`Chats/${chatId}/unreadCount/${sorted[1]}`]            = 0;
      updates[`Chats/${chatId}/participants/${sorted[0]}/status`]    = "offline";
      updates[`Chats/${chatId}/participants/${sorted[0]}/last_seen`] = now;
      updates[`Chats/${chatId}/participants/${sorted[1]}/status`]    = "offline";
      updates[`Chats/${chatId}/participants/${sorted[1]}/last_seen`] = now;
      updates[`Chats/${chatId}/origin`]                              = "match";
      updates[`Chats/${chatId}/block_dialog`]                        = false;
      updates[`ChatMessages/${chatId}/_placeholder/_init`]           = true;
    }

    await db.ref().update(updates);
    console.log(`[acceptLike] match criado: ${myUid} <> ${likerUid} chatId=${chatId}`);
    return { chatId };
  }
);

function buildKey(uid1: string, uid2: string): string {
  return [uid1, uid2].sort().join("_");
}

// ══════════════════════════════════════════════════════════════════════════════
//  TRIGGERS
// ══════════════════════════════════════════════════════════════════════════════

export const notificarSolicitacaoChat = onValueCreated(
  { ref: "ChatRequests/{requestId}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const { requestId } = event.params;
    const request = event.data.val() as { from_uid?: string; to_uid?: string; from_name?: string; from_avatar?: string; status?: string } | null;
    if (!request || (request.status && request.status !== "pending")) return null;

    const fromUid = request.from_uid;
    const toUid   = request.to_uid;
    if (!fromUid || !toUid) return null;

    const db       = getDatabase();
    const fromName = request.from_name ?? "Alguém";
    const body     = `${fromName} quer conversar com você`;
    const now      = Date.now();

    const notif: NotifData = {
      recipient_uid: toUid, type: "chat_request", title: "NOVA SOLICITAÇÃO", body,
      actor_uid: fromUid, actor_name: fromName, actor_avatar: request.from_avatar,
      target_id: requestId, target_type: "chat_request",
      created_at: now, read: false, count: 1, actor_uids: [fromUid],
    };
    const key = db.ref(`Notifications/${toUid}`).push().key!;
    await db.ref(`Notifications/${toUid}/${key}`).set({ ...notif, id: key });
    await updateNotifBadge(toUid);
    await sendFcmNotif({ recipientUid: toUid, title: "NOVA SOLICITAÇÃO", body, data: { type: "chat_request", request_id: requestId, other_uid: fromUid } });
    return null;
  }
);

export const notificarChatAceito = onValueWritten(
  { ref: "UserChatRequests/{uid}/{chatId}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const { uid, chatId } = event.params;
    if (event.data.before.val() !== "pending" || event.data.after.val() !== "accepted") return null;

    const db = getDatabase();

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (chatSnap.exists()) {
      const chat = chatSnap.val() as { origin?: string };
      if (chat.origin === "match") return null;
    }

    const parts    = chatId.split("_").sort();
    const otherUid = parts[0] === uid ? parts[1] : parts[0];

    const [nameSnap, avatarSnap] = await Promise.all([
      db.ref(`Users/${uid}/name`).get(),
      db.ref(`Users/${uid}/avatar`).get(),
    ]);

    const acceptorName   = (nameSnap.val() as string | null) ?? "Usuário";
    const acceptorAvatar = (avatarSnap.val() as string | null) ?? undefined;
    const body           = `${acceptorName} aceitou sua solicitação`;
    const now            = Date.now();

    const notif: NotifData = {
      recipient_uid: otherUid, type: "chat_accepted", title: "SOLICITAÇÃO ACEITA", body,
      actor_uid: uid, actor_name: acceptorName, actor_avatar: acceptorAvatar,
      target_id: chatId, target_type: "chat",
      created_at: now, read: false, count: 1, actor_uids: [uid],
    };
    const key = db.ref(`Notifications/${otherUid}`).push().key!;
    await db.ref(`Notifications/${otherUid}/${key}`).set({ ...notif, id: key });
    await updateNotifBadge(otherUid);
    await sendFcmNotif({ recipientUid: otherUid, title: "SOLICITAÇÃO ACEITA", body, data: { type: "chat_accepted", chat_id: chatId, other_uid: uid } });
    return null;
  }
);

export const notificarNovaMensagem = onValueCreated(
  { ref: "ChatMessages/{chatId}/{msgId}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const { chatId, msgId } = event.params;
    if (msgId === "_placeholder") return null;

    const msg = event.data.val() as { text?: string; sender_id?: string; senderId?: string; read_by?: Record<string, boolean>; timestamp?: number } | null;
    if (!msg?.text) return null;

    const senderId = msg.senderId ?? msg.sender_id;
    if (!senderId) return null;

    const readBy      = msg.read_by ?? {};
    const recipientId = Object.keys(readBy).find((uid) => readBy[uid] === false);
    if (!recipientId) return null;

    const db = getDatabase();

    await db.ref(`Chats/${chatId}/unreadCount/${recipientId}`).set(ServerValue.increment(1));

    const lockRef  = db.ref(`NotificationLocks/chat_msg/${msgId}`);
    const lockSnap = await lockRef.get();
    if (lockSnap.exists()) return null;
    await lockRef.set({ created_at: Date.now(), recipient: recipientId });

    const [tokenSnap, nameSnap, avatarSnap] = await Promise.all([
      db.ref(`Users/${recipientId}/fcmToken`).get(),
      db.ref(`Users/${senderId}/name`).get(),
      db.ref(`Users/${senderId}/avatar`).get(),
    ]);

    const token        = tokenSnap.val() as string | null;
    const senderName   = (nameSnap.val() as string | null) ?? "Alguém";
    const senderAvatar = avatarSnap.val() as string | null;
    const now          = msg.timestamp ?? Date.now();
    const truncatedText = msg.text.length > 100 ? `${msg.text.substring(0, 100)}…` : msg.text;

    try {
      const existingSnap = await db.ref(`Notifications/${recipientId}`).orderByChild("target_id").equalTo(chatId).limitToLast(1).get();
      if (existingSnap.exists()) {
        const [key, existing] = Object.entries(existingSnap.val() as Record<string, NotifData>)[0];
        const ageMs = Date.now() - existing.created_at;
        if (existing.type === "chat_message" && !existing.read && ageMs < 120_000) {
          await db.ref(`Notifications/${recipientId}/${key}`).update({ body: truncatedText, count: (existing.count ?? 1) + 1, created_at: now, actor_uids: [...(existing.actor_uids ?? []), senderId] });
          await updateNotifBadge(recipientId);
          if (token) await sendChatFcm({ token, recipientId, chatId, senderId, msgId, senderName, body: truncatedText });
          return null;
        }
      }
    } catch (indexErr) {
      console.warn("[notificarNovaMensagem] Agrupamento falhou:", indexErr);
    }

    const notif: NotifData = {
      recipient_uid: recipientId, type: "chat_message", title: senderName.toUpperCase(), body: truncatedText,
      actor_uid: senderId, actor_name: senderName, actor_avatar: senderAvatar ?? undefined,
      target_id: chatId, target_type: "chat",
      created_at: now, read: false, count: 1, actor_uids: [senderId],
    };
    const key = db.ref(`Notifications/${recipientId}`).push().key!;
    await db.ref(`Notifications/${recipientId}/${key}`).set({ ...notif, id: key });
    await updateNotifBadge(recipientId);
    if (token) await sendChatFcm({ token, recipientId, chatId, senderId, msgId, senderName, body: truncatedText });
    return null;
  }
);

export const notificarMatch = onValueCreated(
  { ref: "Chats/{chatId}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const { chatId } = event.params;
    const chat = event.data.val() as { user1?: string; user2?: string; origin?: string; block_dialog?: boolean } | null;

    if (!chat || chat.origin !== "match" || chat.block_dialog) return null;

    const uid1 = chat.user1;
    const uid2 = chat.user2;
    if (!uid1 || !uid2) return null;

    const db  = getDatabase();
    const now = Date.now();

    const [name1Snap, avatar1Snap, token1Snap, name2Snap, avatar2Snap, token2Snap] = await Promise.all([
      db.ref(`Users/${uid1}/name`).get(),
      db.ref(`Users/${uid1}/avatar`).get(),
      db.ref(`Users/${uid1}/fcmToken`).get(),
      db.ref(`Users/${uid2}/name`).get(),
      db.ref(`Users/${uid2}/avatar`).get(),
      db.ref(`Users/${uid2}/fcmToken`).get(),
    ]);

    const name1   = (name1Snap.val() as string | null) ?? "Alguém";
    const avatar1 = avatar1Snap.val() as string | null;
    const token1  = token1Snap.val() as string | null;
    const name2   = (name2Snap.val() as string | null) ?? "Alguém";
    const avatar2 = avatar2Snap.val() as string | null;
    const token2  = token2Snap.val() as string | null;

    const saveNotif = async (recipientUid: string, actorUid: string, actorName: string, actorAvatar: string | null) => {
      const notif: NotifData = {
        recipient_uid: recipientUid, type: "match", title: "É UM MATCH!",
        body: `Você e ${actorName} curtiram um ao outro`,
        actor_uid: actorUid, actor_name: actorName, actor_avatar: actorAvatar ?? undefined,
        target_id: chatId, target_type: "chat",
        created_at: now, read: false, count: 1, actor_uids: [actorUid],
      };
      const key = db.ref(`Notifications/${recipientUid}`).push().key!;
      await db.ref(`Notifications/${recipientUid}/${key}`).set({ ...notif, id: key });
    };

    const sendMatchFcm = async (token: string, recipientUid: string, actorName: string, actorUid: string) => {
      try {
        const { getMessaging } = await import("firebase-admin/messaging");
        await getMessaging().send({
          token,
          notification: { title: "É UM MATCH!", body: `Você e ${actorName} curtiram um ao outro` },
          data: { type: "match", chat_id: chatId, other_uid: actorUid },
          android: { priority: "high", notification: { sound: "default", channelId: "match_channel" } },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
        });
      } catch (err: unknown) {
        const code = (err as { code?: string })?.code;
        if (code === "messaging/invalid-registration-token" || code === "messaging/registration-token-not-registered") {
          await db.ref(`Users/${recipientUid}/fcmToken`).remove();
        }
      }
    };

    await Promise.allSettled([saveNotif(uid1, uid2, name2, avatar2), saveNotif(uid2, uid1, name1, avatar1)]);
    await Promise.allSettled([updateNotifBadge(uid1), updateNotifBadge(uid2)]);

    const fcm: Promise<void>[] = [];
    if (token1) fcm.push(sendMatchFcm(token1, uid1, name2, uid2));
    if (token2) fcm.push(sendMatchFcm(token2, uid2, name1, uid1));
    await Promise.allSettled(fcm);

    return null;
  }
);

export const onUserBlocked = onValueCreated(
  { ref: "Users/{blockerUid}/blocked_users/{blockedUid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const { blockerUid, blockedUid } = event.params;
    const db      = getDatabase();
    const ids     = [blockerUid, blockedUid].sort();
    const chatId  = `${ids[0]}_${ids[1]}`;
    const updates: Record<string, unknown> = {};

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (chatSnap.exists()) updates[`Chats/${chatId}/block_dialog`] = true;

    const [reqAtoB, reqBtoA] = await Promise.all([
      db.ref("ChatRequests").orderByChild("from_uid").equalTo(blockerUid).get(),
      db.ref("ChatRequests").orderByChild("from_uid").equalTo(blockedUid).get(),
    ]);

    [reqAtoB, reqBtoA].forEach((snap, i) => {
      const otherUid = i === 0 ? blockedUid : blockerUid;
      if (snap.exists()) {
        snap.forEach((child) => {
          const req = child.val() as { to_uid?: string; status?: string };
          if (req.to_uid === otherUid && req.status === "pending") updates[`ChatRequests/${child.key}`] = null;
        });
      }
    });

    if (Object.keys(updates).length > 0) await db.ref().update(updates);
    await Promise.all([recalcUnreadChatsCount(blockerUid), recalcUnreadChatsCount(blockedUid)]);
    return null;
  }
);

export const onUserUnblocked = onValueDeleted(
  { ref: "Users/{blockerUid}/blocked_users/{blockedUid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const { blockerUid, blockedUid } = event.params;
    const db      = getDatabase();
    const ids     = [blockerUid, blockedUid].sort();
    const chatId  = `${ids[0]}_${ids[1]}`;
    const updates: Record<string, unknown> = {};

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (chatSnap.exists()) {
      const chat = chatSnap.val() as { block_dialog?: boolean };
      if (chat.block_dialog === true) updates[`Chats/${chatId}/block_dialog`] = null;
    }
    updates[`blocked_by/${blockedUid}/${blockerUid}`] = null;

    if (Object.keys(updates).length > 0) await db.ref().update(updates);
    await Promise.all([recalcUnreadChatsCount(blockerUid), recalcUnreadChatsCount(blockedUid)]);
    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  BADGE COMBINADO DA ABA DE CHAT
//  Agora escreve em UserBadges/{uid}/chatTabBadge e UserBadges/{uid}/unreadChatsCount
// ══════════════════════════════════════════════════════════════════════════════

async function recalcChatTabBadge(uid: string): Promise<void> {
  const db = getDatabase();

  try {
    const userChatsSnap = await db.ref(`UserChatRequests/${uid}`).get();
    let msgCount = 0;

    if (userChatsSnap.exists()) {
      const chatData = userChatsSnap.val() as Record<string, string>;
      const chatIds  = Object.keys(chatData).filter((id) => chatData[id] === "accepted");

      if (chatIds.length > 0) {
        const snaps = await Promise.all(
          chatIds.map((id) => db.ref(`Chats/${id}/unreadCount/${uid}`).get())
        );
        msgCount = snaps.reduce((acc, snap) => {
          const val = snap.val();
          return acc + (typeof val === "number" && val > 0 ? 1 : 0);
        }, 0);
      }
    }

    const requestsSnap = await db.ref("ChatRequests")
      .orderByChild("to_uid")
      .equalTo(uid)
      .get();

    let requestCount = 0;
    if (requestsSnap.exists()) {
      requestsSnap.forEach((child) => {
        const req = child.val() as { status?: string; seen?: boolean };
        if (req.status === "pending" && req.seen === false) requestCount++;
      });
    }

    const likesSnap = await db.ref(`Matchs/${uid}/like_me`).get();
    const likeCount = likesSnap.exists()
      ? Object.keys(likesSnap.val() as Record<string, unknown>).length
      : 0;

    const total = msgCount + requestCount + likeCount;

    // ← escrita nos novos nós
    await Promise.all([
      db.ref(`UserBadges/${uid}/chatTabBadge`).set(total),
      db.ref(`UserBadges/${uid}/unreadChatsCount`).set(msgCount),
    ]);

    console.log(`[recalcChatTabBadge] uid=${uid} msgs=${msgCount} requests=${requestCount} likes=${likeCount} total=${total}`);
  } catch (err) {
    console.error(`[recalcChatTabBadge] Erro uid=${uid}:`, err);
  }
}

export const updateChatTabBadgeOnMessage = onValueWritten(
  { ref: "Chats/{chatId}/unreadCount/{uid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    await recalcChatTabBadge(event.params.uid);
    return null;
  }
);

export const updateChatTabBadgeOnRequest = onValueWritten(
  { ref: "ChatRequests/{requestId}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    const req = (event.data.after.val() ?? event.data.before.val()) as { to_uid?: string } | null;
    if (!req?.to_uid) return null;
    await recalcChatTabBadge(req.to_uid);
    return null;
  }
);

export const updateChatTabBadgeOnLike = onValueWritten(
  { ref: "Matchs/{uid}/like_me/{likerUid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb" },
  async (event) => {
    await recalcChatTabBadge(event.params.uid);
    return null;
  }
);