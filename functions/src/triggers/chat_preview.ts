// src/chat_previews.ts
//
// NÍVEL 3.3 — Denormalizar ChatPreviews.
// Ao invés do client abrir N listeners por chat (metadata, unread, block_dialog),
// esta CF mantém um nó ChatPreviews/{uid}/{chatId} com tudo consolidado.
// O client escuta apenas ChatPreviews/$myUid com 1 listener para toda a lista.
//
// Trigger: Chats/{chatId}/metadata (escrito sempre que última mensagem muda)

import { onValueWritten } from "firebase-functions/v2/database";
import { getDatabase }    from "firebase-admin/database";

export const updateChatPreview = onValueWritten(
  { ref: "Chats/{chatId}/metadata", region: "us-central1", instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { chatId } = event.params;
    const db = getDatabase();

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (!chatSnap.exists()) return null;

    const chat = chatSnap.val() as {
      user1?: string;
      user2?: string;
      metadata?: {
        last_message?: string;
        last_sender?: string;
        last_timestamp?: number;
      };
      unreadCount?: Record<string, number>;
      block_dialog?: boolean;
    };

    const { user1, user2, metadata, unreadCount, block_dialog } = chat;
    if (!user1 || !user2) return null;

    const preview = {
      last_message:   metadata?.last_message ?? "",
      last_sender:    metadata?.last_sender ?? "",
      last_timestamp: metadata?.last_timestamp ?? 0,
      block_dialog:   block_dialog ?? false,
    };

    await Promise.all([
      db.ref(`ChatPreviews/${user1}/${chatId}`).set({
        ...preview,
        other_uid: user2,
        unread:    unreadCount?.[user1] ?? 0,
      }),
      db.ref(`ChatPreviews/${user2}/${chatId}`).set({
        ...preview,
        other_uid: user1,
        unread:    unreadCount?.[user2] ?? 0,
      }),
    ]);

    return null;
  }
);

// Trigger adicional: atualiza preview quando unreadCount muda
export const updateChatPreviewOnUnread = onValueWritten(
  { ref: "Chats/{chatId}/unreadCount/{uid}", region: "us-central1", instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { chatId, uid } = event.params;
    const db = getDatabase();

    const newCount = event.data.after.val() as number | null;
    await db.ref(`ChatPreviews/${uid}/${chatId}/unread`).set(newCount ?? 0);

    return null;
  }
);

// Trigger: atualiza preview quando block_dialog muda
export const updateChatPreviewOnBlock = onValueWritten(
  { ref: "Chats/{chatId}/block_dialog", region: "us-central1", instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { chatId } = event.params;
    const db = getDatabase();

    const blocked = event.data.after.val() === true;

    const chatSnap = await db.ref(`Chats/${chatId}`).get();
    if (!chatSnap.exists()) return null;

    const chat = chatSnap.val() as { user1?: string; user2?: string };
    if (!chat.user1 || !chat.user2) return null;

    await Promise.all([
      db.ref(`ChatPreviews/${chat.user1}/${chatId}/block_dialog`).set(blocked),
      db.ref(`ChatPreviews/${chat.user2}/${chatId}/block_dialog`).set(blocked),
    ]);

    return null;
  }
);