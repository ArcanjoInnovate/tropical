// lib/features/profile/data/models/avatar_model.dart

/// Resultado do upload de avatar — URL pública gerada pelo Firebase Storage.
///
/// Usado para sincronizar `Users/{uid}/avatar` e `Matchs/{uid}/avatar`
/// após um upload bem-sucedido.
class AvatarModel {
  final String url; // URL pública do avatar no Firebase Storage

  const AvatarModel({required this.url});

  Map<String, dynamic> toMap() => {'avatar': url};

  factory AvatarModel.fromMap(Map<String, dynamic> map) =>
      AvatarModel(url: map['avatar'] as String? ?? '');
}