// lib/core/utils/map_utils.dart

/// Converte recursivamente qualquer Map retornado pelo Firebase RTDB
/// (que chega como Map<Object?, Object?> no iOS) para Map<String, dynamic>.
///
/// O .cast<String, dynamic>() falha em runtime no iOS porque é lazy e
/// explode ao acessar o valor. Map<String, dynamic>.from() também falha
/// quando há Maps aninhados. Esta função resolve os dois problemas.
Map<String, dynamic> safeMapCast(Object? raw) {
  if (raw == null) return {};
  if (raw is Map<String, dynamic>) return raw;
  return (raw as Map).map(
    (k, v) => MapEntry(
      k.toString(),
      v is Map ? safeMapCast(v) : v,
    ),
  );
}