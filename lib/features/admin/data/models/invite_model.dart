// lib/screens/admin/data/models/invite_model.dart

class InviteModel {
  final String  key;
  final String  name;
  final String  email;
  final String  status;
  final String  message;
  final String? protocolo;
  final String? motivoRejeicao;
  final int?    createdAt;
  final bool    isProcessing;

  const InviteModel({
    required this.key,
    required this.name,
    required this.email,
    required this.status,
    required this.message,
    this.protocolo,
    this.motivoRejeicao,
    this.createdAt,
    this.isProcessing = false,
  });

  bool get isPending => status == 'pending';

  factory InviteModel.fromMap(String key, Map<String, dynamic> map) {
    return InviteModel(
      key:            key,
      name:           map['name']             as String? ?? '—',
      email:          map['email']            as String? ?? '—',
      status:         map['status']           as String? ?? 'pending',
      message:        map['message']          as String? ?? '',
      protocolo:      map['protocolo']        as String?,
      motivoRejeicao: map['motivo_rejeicao']  as String?,
      createdAt:      map['created_at']       as int?,
    );
  }

  // Permite criar uma cópia com campos alterados (útil no controller)
  InviteModel copyWith({bool? isProcessing}) {
    return InviteModel(
      key:            key,
      name:           name,
      email:          email,
      status:         status,
      message:        message,
      protocolo:      protocolo,
      motivoRejeicao: motivoRejeicao,
      createdAt:      createdAt,
      isProcessing:   isProcessing ?? this.isProcessing,
    );
  }
}