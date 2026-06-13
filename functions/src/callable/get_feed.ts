// src/get_feed.ts
//
// LEITURAS NO BANCO:
//   • Posts/post          → limitToLast(limit) — lê exatamente o solicitado
//   • Users/{uid}/blocked_users → lido em paralelo com os posts
//   • blocked_by/{uid}          → lido em paralelo com os posts
//   • Users/{uid}/following     → lido em paralelo com os posts
//   • Users/{autor}/vip_friends/{uid} → lido só para autores únicos dos posts
//                                       retornados, não para todos os usuários
//
// ESTRATÉGIA DE BLOQUEIO:
//   Não multiplicamos o limit para compensar bloqueios. Bloqueios são raros —
//   multiplicar limit * 3 desperdiçaria leituras em 99% dos casos. Em vez disso,
//   buscamos exatamente limit posts e filtramos depois. Se alguns forem
//   bloqueados, a página retorna com menos itens — o cliente lida com isso
//   pedindo mais posts (paginação normal).
//
// ESTRATÉGIA DE VISIBILIDADE:
//   Filtro server-side na função. O banco não expõe essa lógica ao cliente.
//   Posts com visibilidade 'seguidores' ou 'vip' só chegam ao uid correto.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getDatabase } from "firebase-admin/database";

export const getFeed = onCall(
  {
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 30,
    // TODO: reativar quando App Check for implementado no cliente
    // enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Login necessário");

    const { limit = 30, startAfter } = request.data as {
      limit?: number;
      startAfter?: number;
    };

    const db = getDatabase();

    // ── 1. Leituras em paralelo (não dependem uma da outra) ────────────────
    let postsQuery = db.ref("Posts/post").orderByChild("created_at");
    if (startAfter) {
      postsQuery = postsQuery.endBefore(startAfter);
    }
    postsQuery = postsQuery.limitToLast(limit); // lê exatamente o necessário

    const [postsSnap, blockedSnap, blockedBySnap, followingSnap] =
      await Promise.all([
        postsQuery.get(),
        db.ref(`Users/${uid}/blocked_users`).get(),
        db.ref(`blocked_by/${uid}`).get(),
        db.ref(`Users/${uid}/following`).get(),
      ]);

    if (!postsSnap.exists()) return { posts: [], hasMore: false };

    // ── 2. Monta sets de bloqueio e lista de seguidos ──────────────────────
    const blockedIds = new Set<string>();
    if (blockedSnap.exists()) {
      Object.keys(blockedSnap.val() as Record<string, unknown>).forEach((id) =>
        blockedIds.add(id)
      );
    }
    if (blockedBySnap.exists()) {
      Object.keys(blockedBySnap.val() as Record<string, unknown>).forEach(
        (id) => blockedIds.add(id)
      );
    }

    const following = followingSnap.exists()
      ? new Set(Object.keys(followingSnap.val() as Record<string, unknown>))
      : new Set<string>();

    // ── 3. Coleta posts e identifica autores únicos (para lookup VIP) ──────
    const rawPosts: Array<Record<string, unknown>> = [];
    const authorIds = new Set<string>();

    postsSnap.forEach((child) => {
      const post = child.val() as Record<string, unknown>;
      const authorId = post.user_id as string | undefined;
      if (!authorId || blockedIds.has(authorId)) return; // descarta bloqueados
      rawPosts.push({ id: child.key, ...post });
      if (authorId !== uid) authorIds.add(authorId);
    });

    // ── 4. Lookup VIP — só para autores únicos dos posts desta página ──────
    //    Em vez de ler vip_friends de todos os usuários do app, lemos apenas
    //    os autores que aparecem nesta página (normalmente 5-15 autores únicos).
    const vipAuthors = new Set<string>();
    if (authorIds.size > 0) {
      const vipChecks = await Promise.all(
        [...authorIds].map(async (authorId) => {
          const snap = await db
            .ref(`Users/${authorId}/vip_friends/${uid}`)
            .get();
          return { authorId, isVip: snap.exists() && snap.val() === true };
        })
      );
      vipChecks.forEach(({ authorId, isVip }) => {
        if (isVip) vipAuthors.add(authorId);
      });
    }

    // ── 5. Filtra por visibilidade ─────────────────────────────────────────
    const filtered = rawPosts.filter((post) => {
      const authorId = post.user_id as string;
      const vis = (post.visibilidade as string) ?? "publico";

      if (authorId === uid) return true;           // próprio post sempre aparece
      if (vis === "publico") return true;           // público: todos veem
      if (vis === "seguidores") return following.has(authorId); // só seguindo
      if (vis === "vip") return vipAuthors.has(authorId);       // só VIP
      return false;
    });

    // O Firebase retorna em ordem crescente de created_at (limitToLast).
    // Invertemos para o cliente receber do mais recente para o mais antigo.
    filtered.sort(
      (a, b) =>
        ((b.created_at as number) ?? 0) - ((a.created_at as number) ?? 0)
    );

    return {
      posts: filtered,
      // hasMore: informa ao cliente se pode tentar buscar mais.
      // Como buscamos exatamente `limit`, se vieram `limit` posts antes do
      // filtro, provavelmente há mais. Se vieram menos, chegamos ao fim.
      hasMore: rawPosts.length === limit,
    };
  }
);