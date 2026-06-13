// functions/src/counters.ts
//
// Cloud Functions para gerenciamento seguro de contadores.
// Estes contadores NÃO podem ser escritos pelo cliente (rules: ".write": false).
// Apenas estas CFs atualizam via admin SDK (bypass rules).
//
// Contadores gerenciados:
//   - Users/{uid}/followers_count
//   - Users/{uid}/following_count
//   - UserBadges/{uid}/unreadNotificationsCount  ← antes: Users/{uid}/unreadNotificationsCount
//   - UserBadges/{uid}/unreadChatsCount          ← antes: Users/{uid}/unreadChatsCount
//   - UserBadges/{uid}/chatTabBadge              ← antes: Users/{uid}/chatTabBadge
//   - Users/{uid}/report_count
//   - Festas/{id}/interessados
//   - Festas/{id}/confirmados
//   - Festas/{id}/comment_count

import { getDatabase, ServerValue } from "firebase-admin/database";
import {
  onValueCreated,
  onValueDeleted,
  onValueWritten,
} from "firebase-functions/v2/database";

const db     = getDatabase();
const REGION = "us-central1";

// ══════════════════════════════════════════════════════════════════════════════
//  FOLLOWERS COUNT — incremento/decremento atômico
// ══════════════════════════════════════════════════════════════════════════════

export const onFollowerAdded = onValueCreated(
  { ref: "Users/{uid}/followers/{followerUid}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid = event.params.uid;
    await db.ref(`Users/${uid}/followers_count`).set(ServerValue.increment(1));
  }
);

export const onFollowerRemoved = onValueDeleted(
  { ref: "Users/{uid}/followers/{followerUid}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid = event.params.uid;
    await db.ref(`Users/${uid}/followers_count`).transaction((c: number | null) => {
      if (c === null || c <= 0) return 0;
      return c - 1;
    });
  }
);

export const onFollowingAdded = onValueCreated(
  { ref: "Users/{uid}/following/{targetUid}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid = event.params.uid;
    await db.ref(`Users/${uid}/following_count`).set(ServerValue.increment(1));
  }
);

export const onFollowingRemoved = onValueDeleted(
  { ref: "Users/{uid}/following/{targetUid}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid = event.params.uid;
    await db.ref(`Users/${uid}/following_count`).transaction((c: number | null) => {
      if (c === null || c <= 0) return 0;
      return c - 1;
    });
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  REPORT COUNT
// ══════════════════════════════════════════════════════════════════════════════

export const onUserReportCreated = onValueCreated(
  { ref: "Reports/users/{reportId}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const data = event.data.val() as Record<string, unknown> | null;
    if (!data) return;
    const reportedUid = data.reported_user_id as string | undefined;
    if (!reportedUid) return;
    await db.ref(`Users/${reportedUid}/report_count`).set(ServerValue.increment(1));
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  NOTIFICATION BADGE
//  Agora escreve em UserBadges/{uid}/unreadNotificationsCount
// ══════════════════════════════════════════════════════════════════════════════

export const onNotificationCreated = onValueCreated(
  { ref: "Notifications/{uid}/{notifId}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid  = event.params.uid;
    const data = event.data.val() as Record<string, unknown> | null;
    if (!data) return;
    if (data.read !== true) {
      await db.ref(`UserBadges/${uid}/unreadNotificationsCount`).set(
        ServerValue.increment(1)
      );
    }
  }
);

export const onNotificationUpdated = onValueWritten(
  { ref: "Notifications/{uid}/{notifId}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const uid    = event.params.uid;
    const before = event.data.before.val() as Record<string, unknown> | null;
    const after  = event.data.after.val()  as Record<string, unknown> | null;

    const ref = db.ref(`UserBadges/${uid}/unreadNotificationsCount`);

    // Se foi deletada
    if (!after && before && before.read !== true) {
      await ref.transaction((c: number | null) => (c && c > 0) ? c - 1 : 0);
      return;
    }

    // Se foi marcada como lida
    if (before && after && before.read !== true && after.read === true) {
      await ref.transaction((c: number | null) => (c && c > 0) ? c - 1 : 0);
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  FESTAS — CONTADORES DE PRESENÇA
// ══════════════════════════════════════════════════════════════════════════════

export const onFestaPresencaChanged = onValueWritten(
  { ref: "Festas/{festaId}/presenca/{uid}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const festaId = event.params.festaId;
    const before  = event.data.before.val() as string | null;
    const after   = event.data.after.val()  as string | null;
    const updates: Record<string, unknown> = {};

    if (before === "interessado") updates[`Festas/${festaId}/interessados`] = ServerValue.increment(-1);
    else if (before === "confirmado") updates[`Festas/${festaId}/confirmados`] = ServerValue.increment(-1);

    if (after === "interessado") updates[`Festas/${festaId}/interessados`] = ServerValue.increment(1);
    else if (after === "confirmado") updates[`Festas/${festaId}/confirmados`] = ServerValue.increment(1);

    if (Object.keys(updates).length > 0) await db.ref().update(updates);
  }
);

export const onFestaCommentAdded = onValueCreated(
  { ref: "Festas/{festaId}/comentarios/{commentId}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    await db.ref(`Festas/${event.params.festaId}/comment_count`).set(
      ServerValue.increment(1)
    );
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  POST LIKES — decremento ao descurtir
// ══════════════════════════════════════════════════════════════════════════════

export const onLikeRemoved = onValueDeleted(
  { ref: "PostLikes/{postId}/{likerUid}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { postId } = event.params;
    await db.ref(`Posts/post/${postId}/likes`).transaction((c: number | null) => {
      if (c === null || c <= 0) return 0;
      return c - 1;
    });
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  COMMENTS — decremento ao deletar comentário
// ══════════════════════════════════════════════════════════════════════════════

export const onCommentRemoved = onValueDeleted(
  { ref: "Comments/{postId}/{commentId}", region: REGION, instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { postId } = event.params;
    await db.ref(`Posts/post/${postId}/comment_count`).transaction((c: number | null) => {
      if (c === null || c <= 0) return 0;
      return c - 1;
    });
  }
);