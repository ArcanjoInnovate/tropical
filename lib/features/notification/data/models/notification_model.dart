// lib/models/notification_model.dart

class NotificationModel {
  final String   id;
  final String   recipientUid;
  final String   type; // 'party', 'follow', 'like', 'comment'
  final String   title;
  final String   body;
  final String?  actorUid;
  final String?  actorName;
  final String?  actorAvatar;
  final String?  targetId; // postId, partyId, etc
  final String?  targetType; // 'post', 'party', 'comment'
  final DateTime createdAt;
  final bool     read;
  final int      count; // Contador para agrupamento (ex: 3 seguidores, 5 curtidas)
  final List<String> actorUids; // UIDs agrupados

  NotificationModel({
    required this.id,
    required this.recipientUid,
    required this.type,
    required this.title,
    required this.body,
    this.actorUid,
    this.actorName,
    this.actorAvatar,
    this.targetId,
    this.targetType,
    required this.createdAt,
    this.read = false,
    this.count = 1,
    this.actorUids = const [],
  });

  Map<String, dynamic> toMap() => {
    'recipient_uid': recipientUid,
    'type':          type,
    'title':         title,
    'body':          body,
    if (actorUid != null)     'actor_uid':     actorUid,
    if (actorName != null)    'actor_name':    actorName,
    if (actorAvatar != null)  'actor_avatar':  actorAvatar,
    if (targetId != null)     'target_id':     targetId,
    if (targetType != null)   'target_type':   targetType,
    'created_at':    createdAt.millisecondsSinceEpoch,
    'read':          read,
    'count':         count,
    'actor_uids':    actorUids,
  };

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final actorUidsList = map['actor_uids'];
    return NotificationModel(
      id:           id,
      recipientUid: map['recipient_uid'] as String? ?? '',
      type:         map['type']          as String? ?? '',
      title:        map['title']         as String? ?? '',
      body:         map['body']          as String? ?? '',
      actorUid:     map['actor_uid']     as String?,
      actorName:    map['actor_name']    as String?,
      actorAvatar:  map['actor_avatar']  as String?,
      targetId:     map['target_id']     as String?,
      targetType:   map['target_type']   as String?,
      createdAt:    DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      read:         map['read']          as bool? ?? false,
      count:        map['count']         as int? ?? 1,
      actorUids:    actorUidsList is List
          ? List<String>.from(actorUidsList)
          : [],
    );
  }

  NotificationModel copyWith({
    bool? read,
    int? count,
    List<String>? actorUids,
    String? body,
    DateTime? createdAt,
  }) => NotificationModel(
    id:           id,
    recipientUid: recipientUid,
    type:         type,
    title:        title,
    body:         body ?? this.body,
    actorUid:     actorUid,
    actorName:    actorName,
    actorAvatar:  actorAvatar,
    targetId:     targetId,
    targetType:   targetType,
    createdAt:    createdAt ?? this.createdAt,
    read:         read ?? this.read,
    count:        count ?? this.count,
    actorUids:    actorUids ?? this.actorUids,
  );
}