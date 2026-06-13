// lib/features/user/moderation/data/models/report_motivos.dart

import 'package:flutter/material.dart';
import 'report_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CATÁLOGO DE MOTIVOS POR TIPO DE ALVO
// ══════════════════════════════════════════════════════════════════════════════
//
//  Mantém todos os motivos em um único lugar.
//  Para adicionar/remover um motivo, edite apenas esta classe.
//
abstract class ReportMotives {

  // ── Post ───────────────────────────────────────────────────────────────────
  static const List<ReportMotivoModel> post = [
    ReportMotivoModel(
      id:       'conteudo_sexual',
      label:    'Nudez ou conteúdo sexual',
      artigo:   'Art. 8º, I – Política de Conteúdo Tabu',
      descricao: 'Imagens, vídeos ou textos de cunho sexual explícito não permitidos.',
    ),
    ReportMotivoModel(
      id:       'violencia',
      label:    'Violência ou conteúdo chocante',
      artigo:   'Art. 10º, I – Código de Conduta',
      descricao: 'Conteúdo que retrata violência gratuita ou material perturbador.',
    ),
    ReportMotivoModel(
      id:       'discurso_odio',
      label:    'Discurso de ódio ou discriminação',
      artigo:   'Art. 10º, II – Código de Conduta',
      descricao: 'Linguagem que ataca pessoas com base em identidade ou crença.',
    ),
    ReportMotivoModel(
      id:       'spam',
      label:    'Spam ou conteúdo enganoso',
      artigo:   'Art. 10º, II – Termos de Uso',
      descricao: 'Publicações repetitivas, links suspeitos ou informações falsas.',
    ),
    ReportMotivoModel(
      id:       'violacao_privacidade',
      label:    'Violação de privacidade',
      artigo:   'Art. 5º – Política de Privacidade',
      descricao: 'Exposição de dados ou imagens de terceiros sem consentimento.',
    ),
    ReportMotivoModel(
      id:       'conteudo_ilegal',
      label:    'Conteúdo ilegal',
      artigo:   'Art. 15º – Marco Civil da Internet',
      descricao: 'Conteúdo que viola leis brasileiras vigentes.',
    ),
  ];

  // ── Story ──────────────────────────────────────────────────────────────────
  static const List<ReportMotivoModel> story = [
    ReportMotivoModel(
      id:       'violacao_lei',
      label:    'Viola a lei',
      artigo:   'Termos de Uso – Art. 10º, I',
      descricao: 'Conteúdo que viola a legislação brasileira vigente.',
      icone:    Icons.gavel_rounded,
    ),
    ReportMotivoModel(
      id:       'ofensivo',
      label:    'Ofensivo ou discriminatório',
      artigo:   'Termos de Uso – Art. 10º, II',
      descricao: 'Conteúdo ofensivo, discriminatório ou prejudicial a terceiros.',
      icone:    Icons.warning_amber_rounded,
    ),
    ReportMotivoModel(
      id:       'seguranca',
      label:    'Ameaça à segurança',
      artigo:   'Termos de Uso – Art. 10º, III',
      descricao: 'Conteúdo que compromete a segurança ou integridade do app.',
      icone:    Icons.shield_outlined,
    ),
    ReportMotivoModel(
      id:       'spam',
      label:    'Spam ou conteúdo repetitivo',
      artigo:   'Termos de Uso – Art. 10º, II',
      descricao: 'Conteúdo repetitivo, enganoso ou sem valor para a comunidade.',
      icone:    Icons.block_rounded,
    ),
    ReportMotivoModel(
      id:       'privacidade',
      label:    'Violação de privacidade',
      artigo:   'Política de Privacidade – Art. 5º e 6º',
      descricao: 'Exposição indevida de dados ou conteúdo privado de terceiros.',
      icone:    Icons.lock_outline_rounded,
    ),
    ReportMotivoModel(
      id:       'outro',
      label:    'Outro motivo',
      artigo:   'Termos de Uso – Art. 18º',
      descricao: 'Qualquer outra violação ao Código de Conduta do Tabu.',
      icone:    Icons.more_horiz_rounded,
    ),
  ];

  // ── Chat ───────────────────────────────────────────────────────────────────
  static const List<ReportMotivoModel> chat = [
    ReportMotivoModel(
      id:       'assedio',
      label:    'Assédio ou mensagens ofensivas',
      artigo:   'Art. 7º, III – Política de Uso Responsável',
      descricao: 'Mensagens com linguagem agressiva, insultos, humilhação ou perseguição.',
    ),
    ReportMotivoModel(
      id:       'conteudo_sexual',
      label:    'Conteúdo sexual não solicitado',
      artigo:   'Art. 8º, I – Política de Conteúdo Tabu',
      descricao: 'Envio de imagens, vídeos ou textos de cunho sexual sem consentimento.',
    ),
    ReportMotivoModel(
      id:       'ameaca',
      label:    'Ameaças ou intimidação',
      artigo:   'Art. 7º, IV – Código de Conduta Tabu',
      descricao: 'Ameaças de violência física, exposição ou qualquer forma de coerção.',
    ),
    ReportMotivoModel(
      id:       'spam',
      label:    'Spam ou mensagens repetitivas',
      artigo:   'Art. 10º, II – Termos de Uso',
      descricao: 'Envio repetitivo e indesejado de mensagens, links ou promoções.',
    ),
    ReportMotivoModel(
      id:       'dados_pessoais',
      label:    'Solicitação de dados pessoais ou golpe',
      artigo:   'Art. 12º – Proteção de Dados e LGPD',
      descricao: 'Tentativa de obter dados bancários, senhas ou informações pessoais.',
    ),
    ReportMotivoModel(
      id:       'conteudo_ilegal',
      label:    'Conteúdo ilegal ou prejudicial',
      artigo:   'Art. 15º – Marco Civil da Internet / Termos de Uso',
      descricao: 'Conteúdo que viola leis vigentes, incluindo material de abuso ou crime.',
    ),
  ];

  // ── User ───────────────────────────────────────────────────────────────────
  static const List<ReportMotivoModel> user = [
    ReportMotivoModel(
      id:       'conduta_abusiva',
      label:    'Conduta abusiva ou agressiva',
      artigo:   'Art. 10º, II – Código de Conduta',
      descricao: 'Comportamento agressivo ou abusivo reiterado no app.',
    ),
    ReportMotivoModel(
      id:       'conteudo_improprio',
      label:    'Publicações com conteúdo impróprio',
      artigo:   'Art. 10º, I e II – Código de Conduta',
      descricao: 'Perfil que publica conteúdo contrário às políticas do Tabu.',
    ),
    ReportMotivoModel(
      id:       'assedio',
      label:    'Assédio ou perseguição',
      artigo:   'Art. 10º, II – Código de Conduta',
      descricao: 'Perseguição, mensagens repetitivas ou comportamento intimidatório.',
    ),
    ReportMotivoModel(
      id:       'identidade_falsa',
      label:    'Identidade falsa ou conta falsa',
      artigo:   'Art. 6º – Termos de Uso',
      descricao: 'Perfil que se passa por outra pessoa ou usa identidade fictícia.',
    ),
    ReportMotivoModel(
      id:       'spam',
      label:    'Spam ou solicitações em massa',
      artigo:   'Art. 10º, II – Código de Conduta',
      descricao: 'Envio massivo de solicitações, mensagens ou conteúdo repetitivo.',
    ),
    ReportMotivoModel(
      id:       'violacao_privacidade',
      label:    'Violação de privacidade',
      artigo:   'Art. 5º – Código de Privacidade',
      descricao: 'Exposição de dados ou informações privadas de terceiros.',
    ),
    ReportMotivoModel(
      id:       'discurso_odio',
      label:    'Discurso de ódio ou discriminação',
      artigo:   'Art. 10º, I e II – Código de Conduta',
      descricao: 'Publicações ou mensagens com ataques baseados em identidade.',
    ),
    ReportMotivoModel(
      id:       'outro',
      label:    'Outro motivo',
      artigo:   'Art. 18º – Termos de Uso',
      descricao: 'Qualquer outra conduta que viole os Termos de Uso do Tabu.',
    ),
  ];
}