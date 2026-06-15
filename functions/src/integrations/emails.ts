// src/emails.ts

import { formatarData, formatarDataCurta } from "../lib/helpers";

// ── Base ──────────────────────────────────────────────────────────────────────
export function baseTemplate(opts: {
  accentColor: string;
  badgeLabel:  string;
  titulo:      string;
  subtitulo:   string;
  corpo:       string;
  protocolo?:  string;
  agora:       number;
}): string {
  const { accentColor, badgeLabel, titulo, subtitulo, corpo, protocolo, agora } = opts;
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${titulo}</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');
    * { margin: 0; padding: 0; box-sizing: border-box; }

    /* Força o fundo escuro mesmo em clientes que ignoram bgcolor */
    body, #bodyTable, #bodyCell {
      background-color: #07000F !important;
      font-family: 'Space Mono', monospace;
      color: #ffffff !important;
      -webkit-text-size-adjust: 100%;
      margin: 0 !important;
      padding: 0 !important;
    }

    .wrap  { max-width: 620px; margin: 0 auto; padding: 32px 16px 48px; background-color: #07000F; }
    .neon  { height: 3px; width: 100%; background: linear-gradient(90deg, ${accentColor}33, ${accentColor}, #fff, ${accentColor}, ${accentColor}33); margin-bottom: 32px; }
    .badge { display: inline-block; background: ${accentColor}; padding: 4px 12px; font-size: 9px; font-weight: 700; letter-spacing: 3px; color: #ffffff !important; margin-bottom: 16px; }
    .logo  { font-family: 'Syne', sans-serif; font-size: 11px; letter-spacing: 6px; color: rgba(255,255,255,0.35) !important; margin-bottom: 8px; }
    .titulo { font-family: 'Syne', sans-serif; font-size: 26px; letter-spacing: 4px; font-weight: 800; color: #ffffff !important; line-height: 1.2; margin-bottom: 6px; }
    .subtitulo { font-size: 9px; letter-spacing: 3px; color: rgba(255,255,255,0.4) !important; margin-bottom: 32px; }
    .sep   { height: 1px; background: rgba(255,255,255,0.10); margin: 24px 0; }
    .card  { background-color: #110820 !important; border: 1px solid rgba(255,255,255,0.10); padding: 24px; margin-bottom: 16px; }
    .card-accent { background-color: #1a0d2e !important; border: 1px solid ${accentColor}40; padding: 20px; margin-bottom: 16px; }
    .lbl   { font-size: 8px; font-weight: 700; letter-spacing: 2.5px; color: rgba(255,255,255,0.45) !important; margin-bottom: 6px; display: block; }
    .val   { font-size: 13px; color: rgba(255,255,255,0.85) !important; line-height: 1.7; }
    .chip  { display: inline-block; border: 1px solid ${accentColor}66; background-color: ${accentColor}22 !important; padding: 4px 10px; font-size: 9px; font-weight: 700; letter-spacing: 1.5px; color: ${accentColor} !important; }
    .motivo-box { border-left: 2px solid ${accentColor}99; padding: 14px 16px; margin: 16px 0; background-color: #0d0718 !important; }
    .motivo-box p { font-size: 13px; line-height: 1.8; color: rgba(255,255,255,0.75) !important; }
    .proto-box { background-color: #1a0d2e !important; border: 1px solid ${accentColor}55; padding: 18px 20px; margin: 16px 0; }
    .proto-lbl { font-size: 8px; font-weight: 700; letter-spacing: 3px; color: rgba(255,255,255,0.45) !important; margin-bottom: 8px; }
    .proto-val { font-family: 'Syne', sans-serif; font-size: 20px; letter-spacing: 3px; font-weight: 800; color: ${accentColor} !important; }
    .info-row  { display: flex; gap: 12px; margin-bottom: 10px; }
    .info-label { font-size: 8px; font-weight: 700; letter-spacing: 2px; color: rgba(255,255,255,0.35) !important; min-width: 90px; padding-top: 2px; }
    .info-value { font-size: 11px; color: rgba(255,255,255,0.75) !important; line-height: 1.5; }
    .aviso { background-color: rgba(232,93,93,0.12) !important; border: 1px solid rgba(232,93,93,0.35); padding: 14px 16px; margin: 16px 0; }
    .aviso p { font-size: 12px; line-height: 1.65; color: rgba(255,255,255,0.80) !important; }
    .sucesso { background-color: rgba(76,175,80,0.10) !important; border: 1px solid rgba(76,175,80,0.35); padding: 14px 16px; margin: 16px 0; }
    .sucesso p { font-size: 12px; line-height: 1.65; color: rgba(255,255,255,0.80) !important; }
    .periodo { display: flex; gap: 0; margin: 16px 0; border: 1px solid ${accentColor}40; }
    .periodo-bloco { flex: 1; padding: 14px 16px; text-align: center; background-color: #110820 !important; }
    .periodo-bloco:not(:last-child) { border-right: 1px solid ${accentColor}30; }
    .periodo-lbl { font-size: 7px; font-weight: 700; letter-spacing: 2px; color: ${accentColor} !important; margin-bottom: 6px; }
    .periodo-val { font-size: 12px; font-weight: 700; color: rgba(255,255,255,0.90) !important; line-height: 1.4; }
    .conseq { background-color: #110820 !important; border: 1px solid rgba(255,255,255,0.08); padding: 16px; margin: 16px 0; }
    .conseq ul { list-style: none; padding: 0; }
    .conseq ul li { font-size: 11px; color: rgba(255,255,255,0.55) !important; line-height: 1.8; padding-left: 14px; position: relative; }
    .conseq ul li::before { content: "—"; position: absolute; left: 0; color: ${accentColor} !important; }
    .footer { border-top: 1px solid rgba(255,255,255,0.08); padding-top: 24px; margin-top: 32px; font-size: 9px; color: rgba(255,255,255,0.30) !important; line-height: 2; }
    .footer a { color: ${accentColor} !important; text-decoration: none; }

    /* Dark mode explícito — reforça onde o cliente respeita a media query */
    @media (prefers-color-scheme: dark) {
      body, #bodyTable, #bodyCell, .wrap { background-color: #07000F !important; }
      .card     { background-color: #110820 !important; }
      .card-accent { background-color: #1a0d2e !important; }
    }

    /* Light mode: mantém fundo escuro mesmo assim */
    @media (prefers-color-scheme: light) {
      body, #bodyTable, #bodyCell, .wrap { background-color: #07000F !important; }
      .card     { background-color: #110820 !important; }
      .card-accent { background-color: #1a0d2e !important; }
      .titulo, .val, .lbl, .proto-val, .subtitulo, .logo, .badge,
      .info-label, .info-value, .aviso p, .sucesso p, .periodo-val,
      .motivo-box p, .conseq ul li, .footer { color: inherit !important; }
    }

    @media (max-width: 600px) {
      .wrap { padding: 20px 12px 40px; }
      .titulo { font-size: 20px; }
      .periodo { flex-direction: column; }
      .periodo-bloco:not(:last-child) { border-right: none; border-bottom: 1px solid ${accentColor}30; }
    }
  </style>
</head>
<!--
  bgcolor no <body> e na tabela externa garante fundo escuro
  em clientes que ignoram CSS (Outlook, Yahoo, etc.)
-->
<body bgcolor="#07000F" style="background-color:#07000F; margin:0; padding:0;">
  <table id="bodyTable" width="100%" bgcolor="#07000F" cellpadding="0" cellspacing="0" border="0"
         style="background-color:#07000F; margin:0; padding:0;">
    <tr>
      <td id="bodyCell" align="center" valign="top" style="background-color:#07000F; padding:0;">
        <div class="wrap">
          <div class="neon"></div>
          <div class="logo">TCLUB · SISTEMA OFICIAL</div>
          <div class="badge">${badgeLabel}</div>
          <div class="titulo">${titulo}</div>
          <div class="subtitulo">${subtitulo}</div>
          ${corpo}
          ${protocolo ? `<div class="proto-box"><div class="proto-lbl">NÚMERO DE PROTOCOLO — GUARDE ESTA INFORMAÇÃO</div><div class="proto-val">${protocolo}</div></div>` : ""}
          <div class="footer">
            <p>E-mail automático gerado em <strong>${formatarData(agora)}</strong></p>
            <p>Este é um e-mail oficial do sistema TCLUB. Não responda a este endereço diretamente.</p>
            <p>Dúvidas ou contestações: <a href="mailto:tclubadministrative@gmail.com">tclubadministrative@gmail.com</a></p>
            ${protocolo ? `<p>Informe sempre o protocolo <strong>${protocolo}</strong> em qualquer contato.</p>` : ""}
            <p style="margin-top:16px; color: rgba(255,255,255,0.15);">TCLUB BAR & LOUNGE · Plataforma de entretenimento noturno · Termos de Uso aplicáveis</p>
          </div>
        </div>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ── Denunciado ────────────────────────────────────────────────────────────────
export function emailAdvertenciaReportado(opts: { nome: string; artigo: string; motivo: string; protocolo: string; agora: number; denunciaMotivo: string }): string {
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>⚠️ &nbsp;<strong>Sua conta recebeu uma Advertência Formal</strong> registrada pela equipe do TCLUB.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Esta notificação é oficial e permanece registrada no seu histórico de conduta na plataforma.</p>
    </div>
    <div class="card">
      <span class="lbl">ARTIGO VIOLADO</span><div class="chip">${opts.artigo}</div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TCLUB</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>
    <div class="conseq"><span class="lbl" style="margin-bottom:10px;">O QUE ACONTECE AGORA</span><ul>
      <li>Esta advertência fica registrada permanentemente no seu histórico.</li>
      <li>Seu acesso à plataforma não foi bloqueado neste momento.</li>
      <li>Reincidências resultarão em penalidades progressivas.</li>
      <li>Em caso de nova violação, a punição pode ser suspensão ou banimento permanente.</li>
    </ul></div>`;
  return baseTemplate({ accentColor: "#D4AF37", badgeLabel: "PENALIDADE · ADVERTÊNCIA", titulo: "ADVERTÊNCIA FORMAL", subtitulo: "NOTIFICAÇÃO OFICIAL DE CONDUTA · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

export function emailSuspensaoReportado(opts: { nome: string; artigo: string; motivo: string; protocolo: string; inicioMs: number; fimMs: number; agora: number; denunciaMotivo: string }): string {
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>🚫 &nbsp;<strong>Sua conta foi suspensa temporariamente</strong> por decisão da equipe do TCLUB.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
    </div>
    <div class="card">
      <span class="lbl">PERÍODO DE SUSPENSÃO</span>
      <div class="periodo">
        <div class="periodo-bloco"><div class="periodo-lbl">INÍCIO</div><div class="periodo-val">${formatarDataCurta(opts.inicioMs)}</div></div>
        <div class="periodo-bloco"><div class="periodo-lbl">TÉRMINO</div><div class="periodo-val">${formatarDataCurta(opts.fimMs)}</div></div>
      </div>
      <div class="sep"></div>
      <span class="lbl">ARTIGO VIOLADO</span><div class="chip">${opts.artigo}</div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TCLUB</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>`;
  return baseTemplate({ accentColor: "#FF8C00", badgeLabel: "PENALIDADE · SUSPENSÃO", titulo: "CONTA SUSPENSA", subtitulo: "ACESSO TEMPORARIAMENTE BLOQUEADO · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

export function emailBanimentoReportado(opts: { nome: string; artigo: string; motivo: string; protocolo: string; agora: number; denunciaMotivo: string }): string {
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>⛔ &nbsp;<strong>Sua conta foi permanentemente banida</strong> da plataforma TCLUB.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
    </div>
    <div class="card">
      <span class="lbl">ARTIGO VIOLADO</span><div class="chip">${opts.artigo}</div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TCLUB</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>
    <div class="card" style="border-color:rgba(255,255,255,0.06);">
      <span class="lbl">CONTESTAÇÃO FORMAL</span>
      <div class="info-row"><span class="info-label">E-MAIL</span><span class="info-value" style="color:#E85D5D !important;">tclubadministrative@gmail.com</span></div>
      <div class="info-row"><span class="info-label">ASSUNTO</span><span class="info-value">Contestação — ${opts.protocolo}</span></div>
    </div>`;
  return baseTemplate({ accentColor: "#E85D5D", badgeLabel: "PENALIDADE · BANIMENTO", titulo: "CONTA BANIDA", subtitulo: "ACESSO PERMANENTEMENTE REVOGADO · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

export function emailConteudoRemovidoReportado(opts: { nome: string; artigo: string; motivo: string; protocolo: string; conteudoTipo: string; agora: number; denunciaMotivo: string }): string {
  const tipoLabel = opts.conteudoTipo === "posts" ? "publicação" : opts.conteudoTipo === "stories" ? "story" : opts.conteudoTipo === "chats" ? "mensagem" : "conteúdo";
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>🗑️ &nbsp;<strong>Um ${tipoLabel} seu foi removido</strong> da plataforma TCLUB.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
    </div>
    <div class="card">
      <div class="info-row"><span class="info-label">TIPO</span><span class="info-value">${tipoLabel.toUpperCase()}</span></div>
      <div class="info-row"><span class="info-label">ARTIGO</span><span class="info-value"><span class="chip">${opts.artigo}</span></span></div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TCLUB</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>`;
  return baseTemplate({ accentColor: "#E85D5D", badgeLabel: "CONTEÚDO · REMOVIDO", titulo: "CONTEÚDO REMOVIDO", subtitulo: "NOTIFICAÇÃO OFICIAL DE REMOÇÃO · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

// ── Denunciante ───────────────────────────────────────────────────────────────
export function emailDenunciaIgnorada(opts: { nome: string; denunciaMotivo: string; protocolo: string; agora: number }): string {
  const corpo = `
    <div class="card">
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Sua denúncia foi recebida e analisada cuidadosamente pela equipe do TCLUB.</p>
      <div class="sep"></div>
      <span class="lbl">RESULTADO DA ANÁLISE</span>
      <div class="sucesso"><p>Após revisão detalhada, a equipe não identificou violações suficientes que justifiquem medidas disciplinares neste momento.</p></div>
      <div class="info-row" style="margin-top:16px;"><span class="info-label">MOTIVO</span><span class="info-value">${opts.denunciaMotivo}</span></div>
    </div>`;
  return baseTemplate({ accentColor: "#8B6914", badgeLabel: "DENÚNCIA · ANALISADA", titulo: "DENÚNCIA REVISADA", subtitulo: "RESULTADO DA ANÁLISE · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

export function emailDenunciaResolvida(opts: { nome: string; acaoLabel: string; denunciaMotivo: string; artigo: string; protocolo: string; agora: number }): string {
  const corpo = `
    <div class="card">
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Sua denúncia foi revisada e <strong>medidas foram tomadas</strong> pela equipe do TCLUB.</p>
      <div class="sep"></div>
      <div class="sucesso"><p>✅ &nbsp;<strong>Ação aplicada: ${opts.acaoLabel}</strong></p></div>
      <div class="info-row" style="margin-top:16px;"><span class="info-label">MOTIVO</span><span class="info-value">${opts.denunciaMotivo}</span></div>
      <div class="info-row"><span class="info-label">ARTIGO</span><span class="info-value">${opts.artigo}</span></div>
    </div>`;
  return baseTemplate({ accentColor: "#4CAF50", badgeLabel: "DENÚNCIA · RESOLVIDA", titulo: "MEDIDA APLICADA", subtitulo: "SUA DENÚNCIA GEROU RESULTADO · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

// ── Convites ──────────────────────────────────────────────────────────────────
export function emailConviteAprovado(opts: { nome: string; codigo: string; protocolo: string; agora: number }): string {
  const corpo = `
    <div class="card-accent">
      <div class="sucesso"><p>✅ &nbsp;<strong>Sua solicitação de acesso foi aprovada.</strong></p></div>
      <p class="val" style="margin-bottom:16px;">Prezado(a) <strong>${opts.nome}</strong>,</p>
    </div>
    <div class="card">
      <span class="lbl">SEU CÓDIGO DE CONVITE</span>
      <div style="background-color:#1a0d2e !important; border:1px solid rgba(255,45,122,0.45); padding:28px; text-align:center; margin:14px 0 10px;">
        <div style="font-family:'Syne',sans-serif; font-size:30px; font-weight:800; letter-spacing:8px; color:#FF2D7A !important;">${opts.codigo}</div>
      </div>
    </div>`;
  return baseTemplate({ accentColor: "#FF2D7A", badgeLabel: "ACESSO · APROVADO", titulo: "BEM-VINDO AO TCLUB", subtitulo: "SUA SOLICITAÇÃO FOI APROVADA · ACESSO LIBERADO", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

export function emailConviteRecusado(opts: { nome: string; motivo: string; protocolo: string; agora: number }): string {
  const motivoFinal = opts.motivo.trim() || "Sua solicitação não atendeu aos critérios necessários para acesso à plataforma neste momento.";
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>⚠️ &nbsp;<strong>Sua solicitação de acesso não foi aprovada.</strong></p></div>
      <p class="val" style="margin-bottom:16px;">Prezado(a) <strong>${opts.nome}</strong>,</p>
    </div>
    <div class="card">
      <span class="lbl">FUNDAMENTAÇÃO DA DECISÃO</span>
      <div class="motivo-box"><p>${motivoFinal}</p></div>
    </div>`;
  return baseTemplate({ accentColor: "#E85D5D", badgeLabel: "ACESSO · RECUSADO", titulo: "SOLICITAÇÃO RECUSADA", subtitulo: "SEU PEDIDO DE ACESSO NÃO FOI APROVADO · TCLUB", corpo, protocolo: opts.protocolo, agora: opts.agora });
}

// ── Match ─────────────────────────────────────────────────────────────────────
export function emailMatch(opts: { nomeRecipient: string; nomeMatch: string; avatarMatch?: string; chatId: string; agora: number }): string {
  const corpo = `
    <div style="text-align:center; padding: 32px 0 20px;">
      <div style="display:inline-block; font-size:56px; filter:drop-shadow(0 0 20px rgba(255,45,122,0.75));">💘</div>
    </div>
    <div class="card-accent" style="text-align:center; padding: 32px 24px 28px;">
      <div style="font-family:'Syne',sans-serif; font-size:10px; letter-spacing:6px; color:rgba(255,255,255,0.35) !important; margin-bottom:14px;">VOCÊS SE CURTIRAM</div>
      <div style="font-family:'Syne',sans-serif; font-size:34px; font-weight:800; letter-spacing:4px; color:#FF2D7A !important; margin-bottom:10px; text-shadow:0 0 32px rgba(255,45,122,0.55);">É UM MATCH</div>
      <p class="val" style="font-size:14px; color:rgba(255,255,255,0.6) !important; margin:0;">Você e <strong style="color:rgba(255,255,255,0.95) !important;">${opts.nomeMatch}</strong> curtiram um ao outro.</p>
    </div>
    ${opts.avatarMatch ? `<div style="text-align:center; margin:24px 0 8px;"><img src="${opts.avatarMatch}" alt="${opts.nomeMatch}" width="80" height="80" style="border-radius:50%; border:2px solid rgba(255,45,122,0.65); object-fit:cover; display:inline-block; box-shadow:0 0 24px rgba(255,45,122,0.4);"/></div>` : ""}
    <div class="card" style="text-align:center; margin-top:16px;">
      <p class="val" style="margin-bottom:24px; line-height:1.85; font-size:13px;">Olá, <strong>${opts.nomeRecipient}</strong>. Agora vocês podem conversar no TCLUB. Não deixe o momento esfriar!</p>
      <a href="tclub://chat/${opts.chatId}" style="display:inline-block; background:linear-gradient(135deg,#FF2D7A 0%,#FF6B9D 100%); color:#ffffff !important; font-family:'Syne',sans-serif; font-size:11px; font-weight:800; letter-spacing:3px; padding:15px 36px; text-decoration:none; box-shadow:0 0 28px rgba(255,45,122,0.5);">ABRIR CONVERSA</a>
    </div>`;
  return baseTemplate({ accentColor: "#FF2D7A", badgeLabel: "CONEXÃO · MATCH", titulo: "É UM MATCH!", subtitulo: `VOCÊ E ${opts.nomeMatch.toUpperCase()} SE CURTIRAM · TCLUB`, corpo, agora: opts.agora });
}