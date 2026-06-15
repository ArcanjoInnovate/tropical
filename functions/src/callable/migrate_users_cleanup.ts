// functions/src/callable/migrate_users_cleanup.ts
//
// Callable CF — migra campos voláteis de Users/{uid} para nós dedicados
// e remove nós fantasma (UIDs sem perfil real).
//
// Execução: chamar UMA vez via Firebase Console ou app admin.
// Após concluir com sucesso, pode ser removida do index.ts.
//
// Migrações realizadas:
//   Users/{uid}/chatTabBadge          → UserBadges/{uid}/chatTabBadge
//   Users/{uid}/unreadChatsCount      → UserBadges/{uid}/unreadChatsCount
//   Users/{uid}/unreadNotificationsCount → UserBadges/{uid}/unreadNotificationsCount
//   Users/{uid}/presence              → Presence/{uid}
//
// Limpeza:
//   Remove nós em Users/ que não possuem campo "name" ou "username"
//   (considerados fantasma — criados por badge/presence sem perfil real).

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getDatabase }        from "firebase-admin/database";

export const migrateUsersCleanup = onCall(
  { region: "us-central1", timeoutSeconds: 300 },
  async (request) => {
    // Apenas admins podem executar
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login necessário.");
    }

    const db = getDatabase();

    // ── 1. Carregar todos os nós de Users/ ──────────────────────────────────
    const usersSnap = await db.ref("Users").get();
    if (!usersSnap.exists()) {
      return { migrated: 0, ghosts: 0, message: "Nenhum nó em Users/." };
    }

    const usersData = usersSnap.val() as Record<string, Record<string, unknown>>;
    const uids = Object.keys(usersData);

    const badgesUpdates:   Record<string, unknown> = {};
    const presenceUpdates: Record<string, unknown> = {};
    const usersCleanup:    Record<string, unknown> = {};

    let migrated = 0;
    let ghosts   = 0;

    for (const uid of uids) {
      const node = usersData[uid];

      // ── Detectar fantasma: sem name E sem username ─────────────────────
      const hasProfile =
        (typeof node.name     === "string" && node.name.trim()     !== "") ||
        (typeof node.username === "string" && node.username.trim() !== "");

      if (!hasProfile) {
        // Marcar nó inteiro para remoção
        usersCleanup[`Users/${uid}`] = null;
        ghosts++;
        continue;
      }

      // ── Migrar chatTabBadge ────────────────────────────────────────────
      if (node.chatTabBadge !== undefined) {
        badgesUpdates[`UserBadges/${uid}/chatTabBadge`] = node.chatTabBadge;
        usersCleanup[`Users/${uid}/chatTabBadge`]       = null;
        migrated++;
      }

      // ── Migrar unreadChatsCount ────────────────────────────────────────
      if (node.unreadChatsCount !== undefined) {
        badgesUpdates[`UserBadges/${uid}/unreadChatsCount`] = node.unreadChatsCount;
        usersCleanup[`Users/${uid}/unreadChatsCount`]       = null;
        migrated++;
      }

      // ── Migrar unreadNotificationsCount ───────────────────────────────
      if (node.unreadNotificationsCount !== undefined) {
        badgesUpdates[`UserBadges/${uid}/unreadNotificationsCount`] =
          node.unreadNotificationsCount;
        usersCleanup[`Users/${uid}/unreadNotificationsCount`] = null;
        migrated++;
      }

      // ── Migrar presence ───────────────────────────────────────────────
      if (node.presence !== undefined) {
        presenceUpdates[`Presence/${uid}`]      = node.presence;
        usersCleanup[`Users/${uid}/presence`]   = null;
        migrated++;
      }
    }

    // ── 2. Aplicar writes em paralelo ───────────────────────────────────────
    const tasks: Promise<void>[] = [];

    if (Object.keys(badgesUpdates).length > 0) {
      tasks.push(db.ref().update(badgesUpdates));
    }
    if (Object.keys(presenceUpdates).length > 0) {
      tasks.push(db.ref().update(presenceUpdates));
    }
    if (Object.keys(usersCleanup).length > 0) {
      tasks.push(db.ref().update(usersCleanup));
    }

    await Promise.all(tasks);

    const message =
      `Migração concluída: ${migrated} campos movidos, ${ghosts} nós fantasma removidos.`;

    console.log("[migrateUsersCleanup]", message);

    return { migrated, ghosts, message };
  }
);