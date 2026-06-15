// lib/features/user/moderation/data/models/report_models.dart

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  TIPO DE ALVO DA DENÚNCIA
// ══════════════════════════════════════════════════════════════════════════════
enum ReportTargetType { post, story, chat, user }

// ══════════════════════════════════════════════════════════════════════════════
//  MOTIVO GENÉRICO (usado por post, story e user)
// ══════════════════════════════════════════════════════════════════════════════
class ReportMotivoModel {
  final String    id;
  final String    label;
  final String    artigo;
  final String    descricao;
  final IconData? icone; // opcional — usado na tela de story

  const ReportMotivoModel({
    required this.id,
    required this.label,
    required this.artigo,
    required this.descricao,
    this.icone,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAYLOAD ENVIADO AO FIREBASE
//
//  Regras importantes:
//   • reporter_uid NÃO é incluído aqui — o ReportRepository injeta o
//     uid do FirebaseAuth no momento do envio, garantindo que sempre
//     bate com auth.uid nas security rules.
//   • created_at NÃO é incluído aqui — o ReportRepository usa
//     ServerValue.timestamp para que o valor venha do servidor.
//   • Nenhum campo extra é enviado além dos validados pelas rules
//     (posts/stories/chats/users todos têm "$other": false).
// ══════════════════════════════════════════════════════════════════════════════
class ReportPayload {
  final String  targetId;      // id do alvo (postId, storyId, chatId, userId)
  final String  targetOwnerId; // uid do dono do conteúdo
  final String? targetName;    // nome — usado em chat e user
  final String  motivoId;
  final String  motivoLabel;
  final String  artigo;
  final String  descricao;

  const ReportPayload({
    required this.targetId,
    required this.targetOwnerId,
    this.targetName,
    required this.motivoId,
    required this.motivoLabel,
    required this.artigo,
    required this.descricao,
  });

  // Retorna apenas os campos aceitos pelas security rules de cada coleção.
  // reporter_uid e created_at são adicionados pelo ReportRepository.
  Map<String, dynamic> toMap(ReportTargetType type) {
    final base = <String, dynamic>{
      'motivo':       motivoId,
      'motivo_label': motivoLabel,
      'artigo':       artigo,
      'descricao':    descricao.trim(),
      'status':       'pending',
    };

    switch (type) {
      case ReportTargetType.post:
        // Rules: post_id, post_owner_id, reporter_uid, motivo, motivo_label,
        //        artigo, descricao, status, created_at — sem post_titulo
        return {
          ...base,
          'post_id':       targetId,
          'post_owner_id': targetOwnerId,
        };

      case ReportTargetType.story:
        // Rules: story_id, story_owner_id, reporter_uid, motivo, motivo_label,
        //        artigo, descricao, status, created_at
        return {
          ...base,
          'story_id':       targetId,
          'story_owner_id': targetOwnerId,
        };

      case ReportTargetType.chat:
        // Rules: chat_id, reported_uid, reported_name, reporter_uid, motivo,
        //        motivo_label, artigo, descricao, status, created_at
        return {
          ...base,
          'chat_id':       targetId,
          'reported_uid':  targetOwnerId,
          'reported_name': targetName ?? '',
        };

      case ReportTargetType.user:
        // Rules: reported_user_id, reported_user_name, reporter_uid, motivo,
        //        motivo_label, artigo, descricao, status, created_at
        return {
          ...base,
          'reported_user_id':   targetOwnerId,
          'reported_user_name': targetName ?? '',
        };
    }
  }
}

