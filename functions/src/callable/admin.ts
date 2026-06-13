// src/admin.ts

import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onValueCreated, onValueWritten } from "firebase-functions/v2/database";
import { getDatabase, ServerValue }       from "firebase-admin/database";
import { getAuth }                        from "firebase-admin/auth";
import { getMessaging }                   from "firebase-admin/messaging";
import {
  gerarProtocolo, getEmail, getNome,
  getTransporter, deleteStorageFolder,
} from "../lib/helpers";
import {
  emailAdvertenciaReportado, emailSuspensaoReportado, emailBanimentoReportado,
  emailConteudoRemovidoReportado, emailDenunciaIgnorada, emailDenunciaResolvida,
  emailConviteAprovado, emailConviteRecusado,
} from "../integrations/emails";
import { ProcessarDenunciaData, ProcessarPedidoConviteData, Denuncia, Penalidade } from "../lib/types";

// ── Deletar comentário (admin) ────────────────────────────────────────────────
export const adminDeleteComment = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Não autenticado.");

  const db        = getDatabase();
  const adminSnap = await db.ref(`Administratives/${request.auth.uid}`).get();
  if (!adminSnap.exists() || adminSnap.val() !== true)
    throw new HttpsError("permission-denied", "Acesso negado.");

  const { postId, commentId } = request.data as { postId?: string; commentId?: string };
  if (!postId || !commentId)
    throw new HttpsError("invalid-argument", "postId e commentId são obrigatórios.");

  const commentRef  = db.ref(`Comments/${postId}/${commentId}`);
  const commentSnap = await commentRef.get();
  if (!commentSnap.exists())
    throw new HttpsError("not-found", "Comentário não encontrado.");

  await commentRef.remove();

  // Decrementa comment_count no post
  await db.ref(`Posts/post/${postId}/comment_count`).transaction((current: number | null) => {
    const val = (current ?? 0) - 1;
    return val < 0 ? 0 : val;
  });

  console.log(`[adminDeleteComment] admin=${request.auth.uid} deletou comentário=${commentId} do post=${postId}`);
  return { sucesso: true };
});

// ── Processar denúncia ────────────────────────────────────────────────────────
export const processarDenuncia = onCall<ProcessarDenunciaData>(
  {
    region:  "us-central1",
    secrets: ["EMAIL_USER", "EMAIL_PASS"],
  },
  async (request) => {
    const db = getDatabase();
    if (!request.auth) throw new HttpsError("unauthenticated", "Não autenticado.");
    const adminSnap = await db.ref(`Administratives/${request.auth.uid}`).get();
    if (!adminSnap.val()) throw new HttpsError("permission-denied", "Acesso negado.");

    const { denunciaId, denunciaTipo, acao, motivoAdmin, artigoViolado, suspensaoInicio, suspensaoFim } = request.data;
    if (!denunciaId || !denunciaTipo || !acao) throw new HttpsError("invalid-argument", "Dados insuficientes.");

    const denunciaRef  = db.ref(`Reports/${denunciaTipo}/${denunciaId}`);
    const denunciaSnap = await denunciaRef.get();
    if (!denunciaSnap.exists()) throw new HttpsError("not-found", "Denúncia não encontrada.");

    const denuncia  = denunciaSnap.val() as Denuncia;
    const protocolo = gerarProtocolo();
    const agora     = Date.now();

    const reporterUid = denuncia.reporter_uid ?? denuncia.reporter_id ?? null;
    const reportedUid = denuncia.post_owner_id ?? denuncia.story_owner_id ?? denuncia.reported_uid ?? denuncia.reported_user_id ?? null;
    const conteudoId  = denuncia.post_id ?? denuncia.story_id ?? denuncia.chat_id ?? null;

    const [reporterEmail, reportedEmail, reporterNome, reportedNome] = await Promise.all([
      reporterUid ? getEmail(reporterUid) : null,
      reportedUid ? getEmail(reportedUid) : null,
      reporterUid ? getNome(reporterUid)  : "Usuário",
      reportedUid ? getNome(reportedUid)  : "Usuário",
    ]);

    const descricaoInfracao = motivoAdmin?.trim() ?? "";
    const artigoFinal       = artigoViolado ?? denuncia.artigo ?? "—";
    const denunciaMotivo    = denuncia.motivo_label ?? denuncia.motivo ?? "—";

    const penalidade: Penalidade = {
      protocolo, acao, motivo: denunciaMotivo, motivo_admin: descricaoInfracao,
      artigo_violado: artigoFinal, aplicada_em: agora, aplicada_por: request.auth.uid,
      denuncia_id: denunciaId, denuncia_tipo: denunciaTipo, vista: false,
    };

    const updates: Record<string, unknown> = {};

    if (acao === "ignorar") {
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "dismissed";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
      updates[`Reports/${denunciaTipo}/${denunciaId}/admin_uid`]    = request.auth.uid;
    }

    if (acao === "advertencia" && reportedUid) {
      const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
      updates[`Users/${reportedUid}/penalidades/${penRef.key}`]     = { ...penalidade, tipo: "advertencia" };
      updates[`Users/${reportedUid}/penalidade_ativa`]              = "advertencia";
      updates[`Users/${reportedUid}/report_count`]                  = ServerValue.increment(1);
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "advertencia";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
    }

    if (acao === "suspensao" && reportedUid) {
      const inicio = suspensaoInicio ?? agora;
      const fim    = suspensaoFim    ?? agora + 7 * 24 * 60 * 60 * 1000;
      const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
      updates[`Users/${reportedUid}/penalidades/${penRef.key}`]     = { ...penalidade, tipo: "suspensao", suspensao_inicio: inicio, suspensao_fim: fim, vista: true };
      updates[`Users/${reportedUid}/suspenso`]                      = true;
      updates[`Users/${reportedUid}/suspensao_fim`]                 = fim;
      updates[`Users/${reportedUid}/penalidade_ativa`]              = "suspensao";
      updates[`Users/${reportedUid}/report_count`]                  = ServerValue.increment(1);
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "suspensao";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
    }

    if (acao === "banimento" && reportedUid) {
      const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
      updates[`Users/${reportedUid}/penalidades/${penRef.key}`]     = { ...penalidade, tipo: "banimento", vista: true };
      updates[`Users/${reportedUid}/banido`]                        = true;
      updates[`Users/${reportedUid}/banido_em`]                     = agora;
      updates[`Users/${reportedUid}/penalidade_ativa`]              = "banimento";
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "banimento";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
      try { await getAuth().updateUser(reportedUid, { disabled: true }); } catch { /* ignore */ }
    }

    if (acao === "remover_conteudo" && conteudoId) {
      let contentPath: string | null = null;
      if (denunciaTipo === "posts")   contentPath = `Posts/post/${conteudoId}`;
      if (denunciaTipo === "stories") contentPath = `Posts/story/${conteudoId}`;
      if (denunciaTipo === "chats")   contentPath = `Chats/${conteudoId}`;
      if (contentPath) updates[contentPath] = null;
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "remover_conteudo";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
      if (reportedUid) {
        const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
        updates[`Users/${reportedUid}/penalidades/${penRef.key}`] = { ...penalidade, tipo: "remover_conteudo", conteudo_removido: conteudoId, conteudo_tipo: denunciaTipo, vista: false };
      }
    }

    await db.ref().update(updates);

    const arquivoSnap = await denunciaRef.get();
    if (arquivoSnap.exists()) {
      await db.ref(`Arquivo/${protocolo}`).set({ ...arquivoSnap.val(), protocolo, arquivado_em: agora, acao_final: acao });
    }

    try {
      const emailUser   = process.env.EMAIL_USER ?? "";
      const transporter = getTransporter();
      const acaoLabels: Record<string, string> = {
        advertencia:     "ADVERTÊNCIA FORMAL",
        suspensao:       "SUSPENSÃO TEMPORÁRIA",
        banimento:       "BANIMENTO PERMANENTE",
        remover_conteudo:"REMOÇÃO DE CONTEÚDO",
        ignorar:         "ARQUIVADO SEM MEDIDAS",
      };
      const acaoLabelStr = acaoLabels[acao] ?? acao.toUpperCase();

      if (acao === "ignorar" && reporterEmail) {
        await transporter.sendMail({
          from: `"Tabu · Suporte" <${emailUser}>`,
          to: reporterEmail,
          subject: `[${protocolo}] Sua denúncia foi analisada — Tabu`,
          html: emailDenunciaIgnorada({ nome: reporterNome, denunciaMotivo, protocolo, agora }),
        });
        return { sucesso: true, protocolo };
      }

      if (reportedEmail) {
        let html = "";
        if (acao === "advertencia")
          html = emailAdvertenciaReportado({ nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao, protocolo, agora, denunciaMotivo });
        else if (acao === "suspensao")
          html = emailSuspensaoReportado({ nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao, protocolo, agora, denunciaMotivo, inicioMs: suspensaoInicio ?? agora, fimMs: suspensaoFim ?? agora + 7 * 24 * 60 * 60 * 1000 });
        else if (acao === "banimento")
          html = emailBanimentoReportado({ nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao, protocolo, agora, denunciaMotivo });
        else if (acao === "remover_conteudo")
          html = emailConteudoRemovidoReportado({ nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao, protocolo, agora, denunciaMotivo, conteudoTipo: denunciaTipo });
        if (html) await transporter.sendMail({
          from: `"Tabu · Suporte" <${emailUser}>`,
          to: reportedEmail,
          subject: `[${protocolo}] Notificação de penalidade: ${acaoLabelStr} — Tabu`,
          html,
        });
      }

      if (reporterEmail) {
        await transporter.sendMail({
          from: `"Tabu · Suporte" <${emailUser}>`,
          to: reporterEmail,
          subject: `[${protocolo}] Medidas aplicadas à sua denúncia — Tabu`,
          html: emailDenunciaResolvida({ nome: reporterNome, acaoLabel: acaoLabelStr, denunciaMotivo, artigo: artigoFinal, protocolo, agora }),
        });
      }
    } catch (emailErr) {
      console.error(`[processarDenuncia] Erro ao enviar e-mail (protocolo=${protocolo}):`, emailErr);
    }

    return { sucesso: true, protocolo };
  }
);

// ── Processar pedido de convite ───────────────────────────────────────────────
export const processarPedidoConvite = onCall<ProcessarPedidoConviteData>(
  {
    region:  "us-central1",
    secrets: ["EMAIL_USER", "EMAIL_PASS"],
  },
  async (request) => {
    const db = getDatabase();
    if (!request.auth) throw new HttpsError("unauthenticated", "Não autenticado.");
    const adminSnap = await db.ref(`Administratives/${request.auth.uid}`).get();
    if (!adminSnap.val()) throw new HttpsError("permission-denied", "Acesso negado.");

    const { pedidoId, acao, motivoRejeicao } = request.data;
    if (!pedidoId || !acao) throw new HttpsError("invalid-argument", "Dados insuficientes.");

    const pedidoRef  = db.ref(`InviteRequests/${pedidoId}`);
    const pedidoSnap = await pedidoRef.get();
    if (!pedidoSnap.exists()) throw new HttpsError("not-found", "Pedido não encontrado.");

    const pedido = pedidoSnap.val() as { uid: string; name: string; email: string; status: string };
    if (pedido.status !== "pending") throw new HttpsError("failed-precondition", "Este pedido já foi processado.");

    const protocolo = gerarProtocolo();
    const agora     = Date.now();

    if (acao === "aprovar") {
      const codigoSnap = await db.ref("Invitation_code").get();
      const codigo     = codigoSnap.val() as string | null;
      if (!codigo) throw new HttpsError("not-found", "Código de convite não configurado.");

      await db.ref().update({
        [`InviteRequests/${pedidoId}/status`]:      "approved",
        [`InviteRequests/${pedidoId}/resolved_at`]: agora,
        [`InviteRequests/${pedidoId}/resolved_by`]: request.auth.uid,
        [`InviteRequests/${pedidoId}/protocolo`]:   protocolo,
        [`InviteRequestsArquivo/${protocolo}`]:     { ...pedido, status: "approved", resolved_at: agora, resolved_by: request.auth.uid, protocolo },
      });

      try {
        const emailUser   = process.env.EMAIL_USER ?? "";
        const transporter = getTransporter();
        if (pedido.email) await transporter.sendMail({
          from: `"Tabu · Suporte" <${emailUser}>`,
          to: pedido.email,
          subject: `[${protocolo}] Seu acesso ao Tabu foi aprovado — Bem-vindo!`,
          html: emailConviteAprovado({ nome: pedido.name, codigo, protocolo, agora }),
        });
      } catch (emailErr) {
        console.error(`[processarPedidoConvite] Erro ao enviar e-mail aprovação (protocolo=${protocolo}):`, emailErr);
      }

      return { sucesso: true, protocolo, acao: "aprovado" };
    }

    if (acao === "rejeitar") {
      const motivo = motivoRejeicao?.trim() ?? "";

      await db.ref().update({
        [`InviteRequests/${pedidoId}/status`]:          "rejected",
        [`InviteRequests/${pedidoId}/resolved_at`]:     agora,
        [`InviteRequests/${pedidoId}/resolved_by`]:     request.auth.uid,
        [`InviteRequests/${pedidoId}/motivo_rejeicao`]: motivo,
        [`InviteRequests/${pedidoId}/protocolo`]:       protocolo,
        [`InviteRequestsArquivo/${protocolo}`]:         { ...pedido, status: "rejected", resolved_at: agora, resolved_by: request.auth.uid, motivo_rejeicao: motivo, protocolo },
      });

      try {
        const emailUser   = process.env.EMAIL_USER ?? "";
        const transporter = getTransporter();
        if (pedido.email) await transporter.sendMail({
          from: `"Tabu · Suporte" <${emailUser}>`,
          to: pedido.email,
          subject: `[${protocolo}] Resposta à sua solicitação de acesso — Tabu`,
          html: emailConviteRecusado({ nome: pedido.name, motivo, protocolo, agora }),
        });
      } catch (emailErr) {
        console.error(`[processarPedidoConvite] Erro ao enviar e-mail rejeição (protocolo=${protocolo}):`, emailErr);
      }

      return { sucesso: true, protocolo, acao: "rejeitado" };
    }

    throw new HttpsError("invalid-argument", "Ação inválida.");
  }
);

// ── Deletar conta ─────────────────────────────────────────────────────────────
export const deleteAccount = onCall({ region: "us-central1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Não autenticado.");
 
  const uid = request.auth.uid;
  const db  = getDatabase();
 
  try {
    // ════════════════════════════════════════════════════════════════════════
    //  CAMADA 1 — leituras mínimas usando índices próprios do usuário
    // ════════════════════════════════════════════════════════════════════════
 
    const [
      userSnap,
      matchsSnap,
      userChatRequestsSnap,
      postsSnap,
      storiesSnap,
    ] = await Promise.all([
      db.ref(`Users/${uid}`).get(),
      db.ref(`Matchs/${uid}`).get(),
      db.ref(`UserChatRequests/${uid}`).get(),
      db.ref("Posts/post").orderByChild("user_id").equalTo(uid).get(),
      db.ref("Posts/story").orderByChild("user_id").equalTo(uid).get(),
    ]);
 
    // ── Extrair dados dos índices ─────────────────────────────────────────
 
    // UIDs que este usuário seguia → remover de Followers/{targetUid}/{uid}
    const followingUids: string[] = [];
    const userData = userSnap.val() as Record<string, unknown> | null;
    if (userData?.following && typeof userData.following === "object") {
      followingUids.push(...Object.keys(userData.following as object));
    }
 
    // UIDs de interações de match → limpar rastros nos nós alheios
    const likesGivenUids:    string[] = [];
    const dislikesGivenUids: string[] = [];
    const matchedUids:       string[] = [];
 
    const matchsData = matchsSnap.val() as Record<string, unknown> | null;
    if (matchsData) {
      if (matchsData.likes_given && typeof matchsData.likes_given === "object")
        likesGivenUids.push(...Object.keys(matchsData.likes_given as object));
 
      if (matchsData.dislikes && typeof matchsData.dislikes === "object")
        dislikesGivenUids.push(...Object.keys(matchsData.dislikes as object));
 
      if (matchsData.matched && typeof matchsData.matched === "object")
        matchedUids.push(...Object.keys(matchsData.matched as object));
    }
 
    // ChatIds aceitos → limpar Chats, ChatMessages, ChatRequests alheios
    // Formato da key: "uid1_uid2" onde um deles é o próprio uid
    const chatIds: string[] = [];
    const partnerUids: string[] = [];
 
    const ucrData = userChatRequestsSnap.val() as Record<string, string> | null;
    if (ucrData) {
      for (const [chatId, status] of Object.entries(ucrData)) {
        if (status !== "accepted") continue;
        chatIds.push(chatId);
 
        // Extrai o uid do parceiro do chatId (formato: "uidA_uidB")
        const parts = chatId.split("_");
        if (parts.length === 2) {
          const partner = parts[0] === uid ? parts[1] : parts[0];
          if (partner && !partnerUids.includes(partner)) {
            partnerUids.push(partner);
          }
        }
      }
    }
 
    // PostIds do usuário → limpar Comments
    const postIds: string[] = [];
    if (postsSnap.exists()) {
      postsSnap.forEach((child) => { if (child.key) postIds.push(child.key); });
    }
 
    const storyIds: string[] = [];
    if (storiesSnap.exists()) {
      storiesSnap.forEach((child) => { if (child.key) storyIds.push(child.key); });
    }
 
    console.log(`[deleteAccount] uid=${uid}`);
    console.log(`[deleteAccount] following=${followingUids.length} | likesGiven=${likesGivenUids.length} | dislikes=${dislikesGivenUids.length} | matched=${matchedUids.length}`);
    console.log(`[deleteAccount] chats=${chatIds.length} | partners=${partnerUids.length} | posts=${postIds.length} | stories=${storyIds.length}`);
 
    // ════════════════════════════════════════════════════════════════════════
    //  CAMADA 2 — monta o mapa de updates e deleta tudo em paralelo
    // ════════════════════════════════════════════════════════════════════════
 
    const updates: Record<string, null> = {};
 
    // ── Nós próprios do usuário ───────────────────────────────────────────
    const ownNodes = [
      `Users/${uid}`,
      `UsersPublic/${uid}`,
      `UserIndex/${uid}`,
      `UserBadges/${uid}`,
      `Presence/${uid}`,
      `RateLimits/${uid}`,
      `MatchIndex/${uid}`,
      `Matchs/${uid}`,
      `Gallery/${uid}`,
      `Notifications/${uid}`,
      `NotificationsDailyCount/${uid}`,
      `UserChats/${uid}`,
      `UserChatRequests/${uid}`,
      `ChatPreviews/${uid}`,
      `blocked_by/${uid}`,
      `InviteRequests/${uid}`,
      `InviteRequestsArquivo/${uid}`,
    ];
    for (const path of ownNodes) updates[path] = null;
 
    // ── Posts e Stories ───────────────────────────────────────────────────
    for (const postId of postIds)   updates[`Posts/post/${postId}`]   = null;
    for (const storyId of storyIds) updates[`Posts/story/${storyId}`] = null;
 
    // ── Comments dos posts deletados ──────────────────────────────────────
    for (const postId of postIds) updates[`Comments/${postId}`] = null;
 
    // ── PostLikes dos posts deletados ─────────────────────────────────────
    for (const postId of postIds) updates[`PostLikes/${postId}`] = null;
 
    // ── Followers: remove uid da lista de quem ele seguia ─────────────────
    // Followers/{targetUid}/{uid} = true  →  set null
    for (const targetUid of followingUids) {
      updates[`Followers/${targetUid}/${uid}`] = null;
      // Decrementa followers_count do alvo via transação separada (abaixo)
    }
    // Remove todos que o seguiam (Followers/{uid} inteiro já está em ownNodes implicitamente,
    // mas Followers é keyed por uid seguido, não pelo próprio uid — limpamos explicitamente)
    updates[`Followers/${uid}`] = null;
 
    // ── Match: limpa rastros nos nós alheios ──────────────────────────────
 
    // like_me: eu dei like em targetUid → remove Matchs/{targetUid}/like_me/{uid}
    for (const targetUid of likesGivenUids) {
      updates[`Matchs/${targetUid}/like_me/${uid}`] = null;
    }
 
    // dislikes_received: eu dei dislike em targetUid → remove Matchs/{targetUid}/dislikes_received/{uid}
    for (const targetUid of dislikesGivenUids) {
      updates[`Matchs/${targetUid}/dislikes_received/${uid}`] = null;
    }
 
    // matched: limpa matched/{uid} do parceiro e like_me residual
    for (const targetUid of matchedUids) {
      updates[`Matchs/${targetUid}/matched/${uid}`]  = null;
      updates[`Matchs/${targetUid}/like_me/${uid}`]  = null;
    }
 
    // ── Chats e ChatMessages ──────────────────────────────────────────────
    for (const chatId of chatIds) {
      updates[`Chats/${chatId}`]        = null;
      updates[`ChatMessages/${chatId}`] = null;
      updates[`ChatRequests/${chatId}`] = null;
    }
 
    // ── UserChatRequests e ChatPreviews dos parceiros ─────────────────────
    for (const partnerUid of partnerUids) {
      // Remove a entrada do chat da lista do parceiro
      for (const chatId of chatIds) {
        const parts = chatId.split("_");
        if (parts.includes(partnerUid)) {
          updates[`UserChatRequests/${partnerUid}/${chatId}`] = null;
          updates[`UserChats/${partnerUid}/${chatId}`]        = null;
          updates[`ChatPreviews/${partnerUid}/${chatId}`]     = null;
        }
      }
    }
 
    // ── Aplica todos os deletes em uma única operação atômica ─────────────
    await db.ref().update(updates);
    console.log(`[deleteAccount] update atômico concluído: ${Object.keys(updates).length} paths deletados`);
 
    // ── Followers count: decrementa em transação (não pode ser null no update) ──
    await Promise.allSettled(
      followingUids.map((targetUid) =>
        db.ref(`Users/${targetUid}/followers_count`).transaction((current: number | null) => {
          const val = (current ?? 1) - 1;
          return val < 0 ? 0 : val;
        })
      )
    );
 
    // ── Storage ───────────────────────────────────────────────────────────
    await Promise.allSettled([
      deleteStorageFolder(`avatars/${uid}`),
      deleteStorageFolder(`posts/${uid}`),
      deleteStorageFolder(`gallery/${uid}`),
      deleteStorageFolder(`festas/${uid}`),
      deleteStorageFolder(`stories/${uid}`),
    ]);
 
    // ── Auth: último passo — se falhar, dados já foram limpos ────────────
    await getAuth().deleteUser(uid);
 
    console.log(`[deleteAccount] ✅ conta ${uid} deletada com sucesso`);
    return { sucesso: true };
 
  } catch (error) {
    console.error(`[deleteAccount] ❌ erro uid=${uid}:`, error);
    throw new HttpsError(
      "internal",
      "Erro ao processar exclusão da conta.",
      { originalError: String(error) }
    );
  }
});

// ── Festas ────────────────────────────────────────────────────────────────────
export const notificarNovaFesta = onValueCreated(
  { ref: "Festas/{festaId}", region: "us-central1", instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { festaId } = event.params;
    const festa = event.data.val() as { creator_uid?: string; creatorId?: string; user_uid?: string; name?: string; nome?: string; status?: string; data_inicio?: number; dataInicio?: number } | null;
    if (!festa) return null;
    if (festa.status && festa.status !== "ativa") return null;

    const creatorUid = festa.creator_uid ?? festa.creatorId ?? festa.user_uid;
    if (!creatorUid) return null;

    const festaName = festa.name ?? festa.nome;
    if (!festaName?.trim()) return null;

    const dataInicio = festa.data_inicio ?? festa.dataInicio;
    if (dataInicio && dataInicio < Date.now()) return null;

    const creatorNome = await getNome(creatorUid);
    const body        = `${creatorNome} criou a festa "${festaName}"`;

    try {
      await getMessaging().send({
        topic: "novas_festas",
        notification: { title: "🎉 NOVA FESTA", body },
        data: { type: "party", targetId: festaId, targetType: "party", actorUid: creatorUid },
        android: { priority: "high", notification: { sound: "default", channelId: "festas_channel" } },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      });
    } catch (err) {
      console.error(`[notificarNovaFesta] Erro:`, err);
    }
    return null;
  }
);

export const inscreverEmTopicosAoSalvarToken = onValueWritten(
  { ref: "Users/{uid}/fcmToken", region: "us-central1", instance: "tabuapp-4325a-default-rtdb" },
  async (event) => {
    const { uid } = event.params;
    const token = event.data.after.val() as string | null;
    if (!token) return null;
    try {
      await getMessaging().subscribeToTopic([token], "novas_festas");
      console.log(`[inscreverEmTopicos] uid=${uid} inscrito`);
    } catch (err) {
      console.error(`[inscreverEmTopicos] Erro uid=${uid}:`, err);
    }
    return null;
  }
);

export const migrarInscricoesTopicos = onRequest({ region: "us-central1" }, async (req, res) => {
  const db = getDatabase();
  try {
    const usersSnap = await db.ref("Users").get();
    if (!usersSnap.exists()) { res.json({ sucesso: true, total: 0 }); return; }

    const tokens: string[] = [];
    usersSnap.forEach((child) => {
      const user = child.val() as { fcmToken?: string };
      if (user.fcmToken) tokens.push(user.fcmToken);
    });

    let inscrito = 0;
    for (let i = 0; i < tokens.length; i += 1000) {
      try {
        await getMessaging().subscribeToTopic(tokens.slice(i, i + 1000), "novas_festas");
        inscrito += Math.min(1000, tokens.length - i);
      } catch { /* ignore */ }
    }
    res.json({ sucesso: true, total: inscrito, totalTokens: tokens.length });
  } catch (error) {
    res.status(500).json({ sucesso: false, erro: String(error) });
  }
});