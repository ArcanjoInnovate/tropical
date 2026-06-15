// functions/src/index.ts

import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

export * from "./triggers/notificacoes";
export * from "./triggers/chat";
export * from "./triggers/counters";
export * from "./callable/admin";
export * from "./scheduled/manutencao_hardened";
export * from "./integrations/algolia_sync";
export * from "./triggers/users_index";
export * from "./triggers/sync_vip_of";
export * from "./sync_users_public";
export * from "./scheduled/purgar_posts_antigos";
export * from "./callable/get_feed";
export * from "./callable/cloudinary_signature";
export * from "./callable/cloudinary_delete";
export * from "./triggers/match_index_sync";
export * from "./triggers/chat_preview";
export * from "./callable/search_users";
export * from "./callable/get_match_candidates";