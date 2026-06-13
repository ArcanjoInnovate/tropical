// functions/src/purgar_posts_antigos.ts
//
// Cloud Function: purgarPostsAntigos
//
// Scheduler: diariamente às 15h10 (horário de Brasília)
// Propósito: excluir posts com mais de 24 horas de criação.
//
// O que é limpo por post:
//   1. Posts/post/{postId}           — o post em si
//   2. PostLikes/{postId}            — curtidas (nó separado)
//   3. Comments/{postId}             — comentários
//   4. Notifications de like/comment referenciando este postId
//   5. Arquivo de mídia no Cloudinary (media_url + thumb_url)
//
// Estratégia de custo mínimo:
//   - Usa orderByChild("created_at").endAt(cutoff) → só lê posts expirados,
//     jamais a coleção inteira.
//   - Batch de updates atômicos (1 write por grupo de até 500 paths).
//   - Leituras de PostLikes e Comments só para os postIds expirados.
//   - Notificações: busca só por target_id com index (requer index no RTDB).
//   - Cloudinary: deletado em paralelo, falha silenciosa (arquivo pode já não existir).
//   - Máximo de 200 posts por execução (evita timeout de 540s).

import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { getDatabase } from "firebase-admin/database";

const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");
const cloudinaryApiKey    = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryCloudName = defineSecret("CLOUDINARY_CLOUD_NAME");

const REGION             = "us-central1";
const MAX_POSTS_PER_RUN  = 200;
const BATCH_SIZE         = 500;

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Extrai o public_id do Cloudinary a partir de uma media_url.
 * Retorna null se não for uma URL do Cloudinary.
 *
 * Exemplos:
 *   "https://res.cloudinary.com/demo/image/upload/v1234/posts/uid/foto.jpg"
 *   → "posts/uid/foto"   (sem extensão — Cloudinary não usa extensão no public_id)
 *
 *   "https://res.cloudinary.com/demo/video/upload/v1234/posts/uid/video.mp4"
 *   → "posts/uid/video"
 */
function extractCloudinaryPublicId(url: string | undefined): string | null {
  if (!url) return null;
  if (!url.includes("res.cloudinary.com")) return null;

  try {
    // Remove query string e fragmento
    const cleanUrl = url.split("?")[0].split("#")[0];

    // Formato: /…/{resource_type}/upload/v{version}/{public_id}.{ext}
    //      ou: /…/{resource_type}/upload/{public_id}.{ext}  (sem versão)
    const uploadIndex = cleanUrl.indexOf("/upload/");
    if (uploadIndex === -1) return null;

    let afterUpload = cleanUrl.slice(uploadIndex + "/upload/".length);

    // Remove prefixo de versão (v1234567890/) se presente
    afterUpload = afterUpload.replace(/^v\d+\//, "");

    // Remove extensão do arquivo (.jpg, .mp4, .webp, etc.)
    const lastDot = afterUpload.lastIndexOf(".");
    if (lastDot !== -1) {
      afterUpload = afterUpload.slice(0, lastDot);
    }

    return afterUpload || null;
  } catch {
    return null;
  }
}

/**
 * Detecta o resource_type a partir da URL do Cloudinary.
 * Retorna "video" ou "image" (default).
 */
function extractCloudinaryResourceType(url: string): "video" | "image" {
  if (url.includes("/video/upload/")) return "video";
  return "image";
}

/**
 * Deleta um asset no Cloudinary via API REST, usando a mesma lógica
 * de assinatura do deleteCloudinaryAsset (HMAC-SHA1).
 * Falha silenciosa: se o arquivo não existir, apenas loga e continua.
 */
async function deleteCloudinaryAsset(
  publicId: string,
  resourceType: "video" | "image",
): Promise<void> {
  try {
    const crypto    = await import("crypto");
    const timestamp = Math.round(Date.now() / 1000);
    const toSign    = `public_id=${publicId}&timestamp=${timestamp}${cloudinaryApiSecret.value()}`;
    const signature = crypto.createHash("sha1").update(toSign).digest("hex");

    const cloudName = cloudinaryCloudName.value();
    const url       = `https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/destroy`;

    const body = new URLSearchParams({
      public_id: publicId,
      signature,
      api_key:   cloudinaryApiKey.value(),
      timestamp: String(timestamp),
    });

    const response = await fetch(url, {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    body.toString(),
    });

    const result = (await response.json()) as { result?: string; error?: { message: string } };

    if (result.result === "ok") {
      console.log(`[purgarPosts] Cloudinary deletado: ${publicId}`);
    } else if (result.result === "not found") {
      // Arquivo já não existia — sem problema
      console.log(`[purgarPosts] Cloudinary já inexistente: ${publicId}`);
    } else {
      console.warn(`[purgarPosts] Cloudinary resposta inesperada para ${publicId}:`, result);
    }
  } catch (err) {
    // Nunca lança — falha no Cloudinary não deve parar a limpeza do RTDB
    console.error(`[purgarPosts] Erro ao deletar Cloudinary asset ${publicId}:`, err);
  }
}

/**
 * Executa updates em batches de até BATCH_SIZE entradas.
 * Necessário pois o RTDB rejeita updates com mais de 500 paths por chamada.
 */
async function batchUpdate(
  db: ReturnType<typeof getDatabase>,
  updates: Record<string, null>,
): Promise<void> {
  const entries = Object.entries(updates);
  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const batch = Object.fromEntries(entries.slice(i, i + BATCH_SIZE));
    await db.ref().update(batch);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCHEDULED FUNCTION — 15:10 BRT diariamente
// ══════════════════════════════════════════════════════════════════════════════

export const purgarPostsAntigos = onSchedule(
  {
    schedule:       "10 15 * * *",
    timeZone:       "America/Sao_Paulo",
    region:         REGION,
    memory:         "256MiB",
    timeoutSeconds: 300,
    secrets:        [cloudinaryApiSecret, cloudinaryApiKey, cloudinaryCloudName],
  },
  async () => {
    const db     = getDatabase();
    const agora  = Date.now();
    const cutoff = agora - 24 * 60 * 60 * 1000;

    console.log(`[purgarPostsAntigos] Iniciando — cutoff: ${new Date(cutoff).toISOString()}`);

    // ── 1. Buscar apenas os posts expirados ───────────────────────────────────
    //
    // Requer regra no RTDB:
    //   "Posts/post": { ".indexOn": ["created_at"] }
    //
    const postsSnap = await db
      .ref("Posts/post")
      .orderByChild("created_at")
      .endAt(cutoff)
      .limitToFirst(MAX_POSTS_PER_RUN)
      .get();

    if (!postsSnap.exists()) {
      console.log("[purgarPostsAntigos] Nenhum post expirado. Encerrando.");
      return;
    }

    type PostMeta = {
      postId:   string;
      userId:   string;
      mediaUrl: string | null;
      thumbUrl: string | null;
    };

    const postsParaDeletar: PostMeta[] = [];

    postsSnap.forEach((child) => {
      const val = child.val();
      if (!val || typeof val !== "object") return;

      const post = val as Record<string, unknown>;
      postsParaDeletar.push({
        postId:   child.key!,
        userId:   (post.user_id as string) ?? "",
        mediaUrl: (post.media_url as string) ?? null,
        thumbUrl: (post.thumb_url as string) ?? null,
      });
    });

    if (postsParaDeletar.length === 0) {
      console.log("[purgarPostsAntigos] Nenhum post válido para deletar.");
      return;
    }

    const postIds = postsParaDeletar.map((p) => p.postId);
    console.log(`[purgarPostsAntigos] Posts a deletar: ${postIds.length}`);

    // ── 2. Buscar PostLikes e Comments em paralelo ────────────────────────────
    const [likesResults, commentsResults] = await Promise.all([
      Promise.all(postIds.map((id) => db.ref(`PostLikes/${id}`).get())),
      Promise.all(postIds.map((id) => db.ref(`Comments/${id}`).get())),
    ]);

    // ── 3. Montar update batch para RTDB ──────────────────────────────────────
    const updates: Record<string, null> = {};

    for (let i = 0; i < postIds.length; i++) {
      const postId = postIds[i];

      updates[`Posts/post/${postId}`] = null;

      if (likesResults[i].exists())    updates[`PostLikes/${postId}`] = null;
      if (commentsResults[i].exists()) updates[`Comments/${postId}`]  = null;
    }

    // ── 4. Limpar notificações que referenciam esses posts ────────────────────
    const notifsSnap = await db.ref("Notifications").get();
    if (notifsSnap.exists()) {
      const postIdSet = new Set(postIds);

      notifsSnap.forEach((userNode) => {
        const uid = userNode.key!;
        userNode.forEach((notifNode) => {
          const notif = notifNode.val() as Record<string, unknown> | null;
          if (!notif) return;

          const tipo     = notif.type     as string | undefined;
          const targetId = notif.target_id as string | undefined;

          if (
            targetId &&
            postIdSet.has(targetId) &&
            (tipo === "like" || tipo === "comment")
          ) {
            updates[`Notifications/${uid}/${notifNode.key}`] = null;
          }
        });
      });
    }

    // ── 5. Executar updates no RTDB ───────────────────────────────────────────
    const totalUpdates = Object.keys(updates).length;
    console.log(`[purgarPostsAntigos] Aplicando ${totalUpdates} deleções no RTDB...`);
    await batchUpdate(db, updates);
    console.log(`[purgarPostsAntigos] RTDB limpo.`);

    // ── 6. Deletar arquivos no Cloudinary ─────────────────────────────────────
    //
    // Executado APÓS o RTDB para garantir consistência:
    // se o Cloudinary falhar, o RTDB já está limpo.
    // Os deletes rodam em paralelo para minimizar tempo total.
    //
    const cloudinaryDeletes: Promise<void>[] = [];

    for (const post of postsParaDeletar) {
      // media_url (vídeo ou imagem principal)
      if (post.mediaUrl) {
        const publicId    = extractCloudinaryPublicId(post.mediaUrl);
        const resType     = extractCloudinaryResourceType(post.mediaUrl);
        if (publicId) {
          cloudinaryDeletes.push(deleteCloudinaryAsset(publicId, resType));
        }
      }

      // thumb_url (sempre imagem)
      if (post.thumbUrl) {
        const publicId = extractCloudinaryPublicId(post.thumbUrl);
        if (publicId) {
          cloudinaryDeletes.push(deleteCloudinaryAsset(publicId, "image"));
        }
      }
    }

    if (cloudinaryDeletes.length > 0) {
      console.log(`[purgarPostsAntigos] Deletando ${cloudinaryDeletes.length} assets no Cloudinary...`);
      await Promise.allSettled(cloudinaryDeletes);
      console.log(`[purgarPostsAntigos] Cloudinary concluído.`);
    }

    // ── 7. Log final ──────────────────────────────────────────────────────────
    console.log(
      `[purgarPostsAntigos] Concluído. ` +
      `Posts: ${postsParaDeletar.length} | ` +
      `Paths RTDB: ${totalUpdates} | ` +
      `Assets Cloudinary: ${cloudinaryDeletes.length}`
    );
  },
);