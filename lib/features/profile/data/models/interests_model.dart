// lib/features/profile/data/models/interests_model.dart

/// Modelo de interesses do usuário persistido em Users/{uid} e Matchs/{uid}.
class InterestsModel {
  final List<String> interests;

  const InterestsModel({required this.interests});

  Map<String, dynamic> toMap() => {
        'interests': interests,
      };

  factory InterestsModel.fromMap(Map<String, dynamic> map) {
    final raw = map['interests'];
    final list = raw is List
        ? raw.whereType<String>().where((s) => s.isNotEmpty).toList()
        : <String>[];
    return InterestsModel(interests: list);
  }

  InterestsModel copyWith({List<String>? interests}) =>
      InterestsModel(interests: interests ?? this.interests);
}

