// lib/models/comment_model.dart
//
// MUDANÇAS vs versão anterior:
//   • toMap() removeu 'post_id' e 'likes' — ambos bloqueados pelo
//     $other: { ".validate": false } nas rules de Comments.
//     post_id já está implícito na chave pai Comments/$postId.
//     likes é gerenciado pela CF trigger, não pelo cliente.
//   • fromMap() mantém leitura de 'likes' para compatibilidade com
//     registros legados que ainda tenham o campo salvo.

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String texto;
  final DateTime createdAt;
  int likes;
  final bool userDeleted;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.texto,
    required this.createdAt,
    this.likes = 0,
    this.userDeleted = false,
  });

  Map<String, dynamic> toMap() => {
        // 'post_id' REMOVIDO — bloqueado por $other nas rules.
        //   A chave pai Comments/$postId já identifica o post.
        // 'likes'   REMOVIDO — gerenciado pela CF trigger via admin SDK.
        'user_id': userId,
        'user_name': userName,
        if (userAvatar != null && userAvatar!.isNotEmpty)
          'user_avatar': userAvatar,
        'text': texto,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  /// Constrói a partir do Firebase.
  /// Aceita tanto o formato legado (sem user_name) quanto o novo.
  /// [resolvedName] e [resolvedAvatar] são injetados quando o comentário
  /// é legado e o nome foi resolvido externamente (via UsersPublic/{uid}).
  factory CommentModel.fromMap(
    String id,
    Map<dynamic, dynamic> map, {
    String? resolvedName,
    String? resolvedAvatar,
    bool userDeleted = false,
  }) {
    // Suporte ao campo "text" (novo padrão) e "texto" (legado)
    final texto = map['text'] as String? ?? map['texto'] as String? ?? '';

    // user_name: prioriza o que está salvo; fallback no resolvido externamente
    final userName = map['user_name'] as String? ?? resolvedName ?? 'Usuário';

    final userAvatar = map['user_avatar'] as String? ?? resolvedAvatar;

    return CommentModel(
      id: id,
      // post_id pode vir de registros legados que ainda salvavam o campo
      postId: map['post_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      userName: userName,
      userAvatar: userAvatar,
      texto: texto,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at'] as int? ?? 0),
      // likes ainda lido para compatibilidade com registros legados
      likes: map['likes'] as int? ?? 0,
      userDeleted: userDeleted,
    );
  }

  CommentModel copyWith({
    String? userName,
    String? userAvatar,
    bool? userDeleted,
  }) =>
      CommentModel(
        id: id,
        postId: postId,
        userId: userId,
        userName: userName ?? this.userName,
        userAvatar: userAvatar ?? this.userAvatar,
        texto: texto,
        createdAt: createdAt,
        likes: likes,
        userDeleted: userDeleted ?? this.userDeleted,
      );
}

