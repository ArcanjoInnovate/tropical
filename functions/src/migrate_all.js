// functions/src/migrate_all.js
//
// Uso — de dentro de D:\tabuapp\functions:
//   node src/migrate_all.js

const admin          = require("firebase-admin");
const serviceAccount = require("../service-account.json");

admin.initializeApp({
  credential:  admin.credential.cert(serviceAccount),
  databaseURL: "https://tabuapp-4325a-default-rtdb.firebaseio.com",
});

const db = admin.database();

const PUBLIC_FIELDS = new Set([
  "name", "avatar", "bio", "city", "state", "bairro",
  "gender_identity", "sexual_orientation", "relationship_type",
  "profile_type", "age", "interests", "partner",
]);

const MATCH_FIELDS = new Set([
  "name", "avatar", "bio", "city", "state", "bairro",
  "gender_identity", "sexual_orientation", "relationship_type",
  "profile_type", "birth_date", "age", "interests", "partner",
  "latitude", "longitude",
]);

const PRIVATE_SUBNODES = new Set([
  "likes_given", "dislikes", "dislikes_received", "like_me", "matched",
]);

async function main() {
  console.log("🚀 Iniciando migração completa...\n");

  const [usersSnap, matchsSnap, chatsSnap, ucrSnap] = await Promise.all([
    db.ref("Users").get(),
    db.ref("Matchs").get(),
    db.ref("Chats").get(),
    db.ref("UserChatRequests").get(),
  ]);

  const users  = usersSnap.val()  || {};
  const matchs = matchsSnap.val() || {};
  const chats  = chatsSnap.val()  || {};
  const ucr    = ucrSnap.val()    || {};

  console.log(`📊 Users: ${Object.keys(users).length}`);
  console.log(`📊 Matchs: ${Object.keys(matchs).length}`);
  console.log(`📊 Chats: ${Object.keys(chats).length}`);
  console.log(`📊 UserChatRequests: ${Object.keys(ucr).length}\n`);

  const updates = {};
  const stats = {
    matchsCreated: 0, matchsUpdated: 0,
    matchIndexed: 0,  chatsFixed: 0,
    ucrFixed: 0,      ghostsRemoved: 0,
  };

  // ── 1. Matchs + MatchIndex ──────────────────────────────────────────────────
  console.log("── 1. Matchs e MatchIndex ──");

  for (const [uid, user] of Object.entries(users)) {
    const name = ((user["name"]) || "").toString().trim();

    // Remove usuários fantasmas sem nome
    if (uid.startsWith("match_") && !name) {
      updates[`Users/${uid}`] = null;
      stats.ghostsRemoved++;
      console.log(`  🗑  ghost removido: ${uid}`);
      continue;
    }

    if (!name) {
      console.log(`  ⏭  sem nome, ignorado: ${uid}`);
      continue;
    }

    // Atualiza campos do perfil em Matchs (preserva sub-nós privados)
    for (const field of MATCH_FIELDS) {
      if (user[field] !== undefined) {
        updates[`Matchs/${uid}/${field}`] = user[field];
      }
    }

    const existingMatch = matchs[uid] || {};
    const publicKeys = Object.keys(existingMatch).filter(k => !PRIVATE_SUBNODES.has(k));
    const isNew = publicKeys.length === 0;

    if (isNew) {
      stats.matchsCreated++;
      console.log(`  ✅ Matchs criado: ${uid} (${name})`);
    } else {
      stats.matchsUpdated++;
      console.log(`  🔄 Matchs atualizado: ${uid} (${name})`);
    }

    // MatchIndex — apenas campos públicos
    const indexData = {};
    for (const field of PUBLIC_FIELDS) {
      if (user[field] !== undefined) indexData[field] = user[field];
    }
    updates[`MatchIndex/${uid}`] = indexData;
    stats.matchIndexed++;
  }

  // ── 2. Corrige Chats ────────────────────────────────────────────────────────
  console.log("\n── 2. Chats ──");

  for (const chatId of Object.keys(chats)) {
    const chat = chats[chatId];
    const parts = chatId.split("_");
    if (parts.length !== 2) continue;

    const [uid1, uid2] = parts;
    const now = Date.now();
    let fixed = false;

    if (!chat["user1"]) { updates[`Chats/${chatId}/user1`] = uid1; fixed = true; }
    if (!chat["user2"]) { updates[`Chats/${chatId}/user2`] = uid2; fixed = true; }

    if (!chat["metadata"]) {
      updates[`Chats/${chatId}/metadata/last_message`]   = "";
      updates[`Chats/${chatId}/metadata/last_sender`]    = "";
      updates[`Chats/${chatId}/metadata/last_timestamp`] = 0;
      updates[`Chats/${chatId}/metadata/created_at`]     = now;
      fixed = true;
    }

    const unread = chat["unreadCount"] || {};
    if (unread[uid1] === undefined) { updates[`Chats/${chatId}/unreadCount/${uid1}`] = 0; fixed = true; }
    if (unread[uid2] === undefined) { updates[`Chats/${chatId}/unreadCount/${uid2}`] = 0; fixed = true; }

    const participants = chat["participants"] || {};
    if (!participants[uid1]) {
      updates[`Chats/${chatId}/participants/${uid1}/status`]    = "offline";
      updates[`Chats/${chatId}/participants/${uid1}/last_seen`] = now;
      fixed = true;
    }
    if (!participants[uid2]) {
      updates[`Chats/${chatId}/participants/${uid2}/status`]    = "offline";
      updates[`Chats/${chatId}/participants/${uid2}/last_seen`] = now;
      fixed = true;
    }

    if (fixed) {
      stats.chatsFixed++;
      console.log(`  🔧 corrigido: ${chatId}`);
    } else {
      console.log(`  ✅ ok: ${chatId}`);
    }
  }

  // ── 3. UserChatRequests ─────────────────────────────────────────────────────
  console.log("\n── 3. UserChatRequests ──");

  for (const chatId of Object.keys(chats)) {
    const parts = chatId.split("_");
    if (parts.length !== 2) continue;
    const [uid1, uid2] = parts;

    const uid1Reqs = ucr[uid1] || {};
    const uid2Reqs = ucr[uid2] || {};

    if (!uid1Reqs[chatId]) {
      updates[`UserChatRequests/${uid1}/${chatId}`] = "accepted";
      stats.ucrFixed++;
      console.log(`  🔧 adicionado UCR para ${uid1.slice(0, 14)}...`);
    }
    if (!uid2Reqs[chatId]) {
      updates[`UserChatRequests/${uid2}/${chatId}`] = "accepted";
      stats.ucrFixed++;
      console.log(`  🔧 adicionado UCR para ${uid2.slice(0, 14)}...`);
    }
  }

  // ── 4. Aplica em batches de 100 ─────────────────────────────────────────────
  console.log("\n── 4. Aplicando atualizações ──");

  const entries = Object.entries(updates);
  const BATCH   = 100;

  console.log(`  Total: ${entries.length} operações`);

  if (entries.length === 0) {
    console.log("  ℹ️  Nada para atualizar.");
  } else {
    for (let i = 0; i < entries.length; i += BATCH) {
      const batch = Object.fromEntries(entries.slice(i, i + BATCH));
      await db.ref().update(batch);
      const done = Math.min(i + BATCH, entries.length);
      const pct  = Math.round((done / entries.length) * 100);
      console.log(`  ✅ ${done}/${entries.length} (${pct}%)`);
    }
  }

  // ── 5. Resumo ───────────────────────────────────────────────────────────────
  console.log("\n══════════════════════════════════════");
  console.log("✅ Migração concluída!");
  console.log(`   Matchs criados    : ${stats.matchsCreated}`);
  console.log(`   Matchs atualizados: ${stats.matchsUpdated}`);
  console.log(`   MatchIndex        : ${stats.matchIndexed}`);
  console.log(`   Chats corrigidos  : ${stats.chatsFixed}`);
  console.log(`   UCR corrigidos    : ${stats.ucrFixed}`);
  console.log(`   Ghosts removidos  : ${stats.ghostsRemoved}`);
  console.log("══════════════════════════════════════\n");

  // ── 6. Verificação ───────────────────────────────────────────────────────────
  console.log("🔍 Verificação final...");
  const [vM, vI] = await Promise.all([
    db.ref("Matchs").get(),
    db.ref("MatchIndex").get(),
  ]);
  const mc = Object.keys(vM.val() || {}).length;
  const ic = Object.keys(vI.val() || {}).length;
  console.log(`   Matchs   : ${mc} entradas`);
  console.log(`   MatchIndex: ${ic} entradas`);

  process.exit(0);
}

main().catch(err => {
  console.error("❌ Erro na migração:", err);
  process.exit(1);
});