// lib/screens/admin/data/models/report_model.dart

class ReportModel {
  final String  key;
  final String  tipo;
  final String  status;
  final String  motivo;
  final String  artigo;
  final String  descricao;
  final String  reporterUid;
  final String? protocolo;
  final int?    createdAt;

  // campos opcionais por tipo
  final String? postId;
  final String? storyId;
  final String? chatId;
  final String? postOwnerId;
  final String? storyOwnerId;
  final String? reportedUserId;
  final String? reportedUid;
  // ── NOVO: nome salvo no momento da denúncia (chats têm reported_name) ──
  final String? reportedName;

  const ReportModel({
    required this.key,
    required this.tipo,
    required this.status,
    required this.motivo,
    required this.artigo,
    required this.descricao,
    required this.reporterUid,
    this.protocolo,
    this.createdAt,
    this.postId,
    this.storyId,
    this.chatId,
    this.postOwnerId,
    this.storyOwnerId,
    this.reportedUserId,
    this.reportedUid,
    this.reportedName,
  });

  bool get isPending => status == 'pending';

  factory ReportModel.fromMap(
    String key,
    Map<String, dynamic> map, {
    required String tipo,
  }) {
    return ReportModel(
      key:            key,
      tipo:           tipo,
      status:         map['status']           as String? ?? 'pending',
      motivo:         map['motivo_label']     as String?
                      ?? map['motivo']        as String? ?? '—',
      artigo:         map['artigo']           as String? ?? '—',
      descricao:      map['descricao']        as String? ?? '',
      reporterUid:    map['reporter_uid']     as String? ?? '—',
      protocolo:      map['protocolo']        as String?,
      createdAt:      map['created_at']       as int?,
      postId:         map['post_id']          as String?,
      storyId:        map['story_id']         as String?,
      chatId:         map['chat_id']          as String?,
      postOwnerId:    map['post_owner_id']    as String?,
      storyOwnerId:   map['story_owner_id']   as String?,
      reportedUserId: map['reported_user_id'] as String?,
      reportedUid:    map['reported_uid']     as String?,
      // ── NOVO ──────────────────────────────────────────────────────────
      reportedName:   map['reported_name']    as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'tipo':            tipo,
    'status':          status,
    'motivo':          motivo,
    'artigo':          artigo,
    'descricao':       descricao,
    'reporter_uid':    reporterUid,
    if (protocolo      != null) 'protocolo':        protocolo,
    if (createdAt      != null) 'created_at':       createdAt,
    if (postId         != null) 'post_id':          postId,
    if (storyId        != null) 'story_id':         storyId,
    if (chatId         != null) 'chat_id':          chatId,
    if (postOwnerId    != null) 'post_owner_id':    postOwnerId,
    if (storyOwnerId   != null) 'story_owner_id':   storyOwnerId,
    if (reportedUserId != null) 'reported_user_id': reportedUserId,
    if (reportedUid    != null) 'reported_uid':     reportedUid,
    if (reportedName   != null) 'reported_name':    reportedName,
  };
}

