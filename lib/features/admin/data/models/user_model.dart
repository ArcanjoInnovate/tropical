// lib/screens/admin/data/models/user_model.dart

class UserModel {
  final String  uid;
  final String  name;
  final String  email;
  final String  city;
  final String  state;
  final int     vipLists;
  final int     partys;
  final bool    banido;
  final bool    suspenso;
  final bool    online;
  final int     reportCount;
  final String? penalidadeAtiva;
  final String? avatar;                       // ← NOVO
  final Map<String, dynamic>? penalidades;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.city,
    required this.state,
    required this.vipLists,
    required this.partys,
    required this.banido,
    required this.suspenso,
    required this.online,
    required this.reportCount,
    this.penalidadeAtiva,
    this.avatar,                              // ← NOVO
    this.penalidades,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    final presence = map['presence'] as Map?;
    return UserModel(
      uid:             uid,
      name:            (map['name']         as String? ?? '').trim(),
      email:           (map['email']        as String? ?? '').trim(),
      city:            (map['city']         as String? ?? '').trim(),
      state:           (map['state']        as String? ?? '').trim(),
      vipLists:        (map['vip_lists']    as num? ?? 0).toInt(),
      partys:          (map['partys']       as num? ?? 0).toInt(),
      banido:          map['banido']        as bool? ?? false,
      suspenso:        map['suspenso']      as bool? ?? false,
      online:          presence?['online']  as bool? ?? false,
      reportCount:     (map['report_count'] as num? ?? 0).toInt(),
      penalidadeAtiva: map['penalidade_ativa'] as String?,
      avatar:          map['avatar']           as String?,  // ← NOVO
      penalidades:     map['penalidades'] != null
                         ? Map<String, dynamic>.from(map['penalidades'] as Map)
                         : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':    uid,
    'name':   name,
    'email':  email,
    'city':   city,
    'state':  state,
    if (avatar != null) 'avatar': avatar,    // ← NOVO
  };
}

