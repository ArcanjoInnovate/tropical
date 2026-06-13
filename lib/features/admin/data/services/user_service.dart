// lib/screens/admin/data/services/user_service.dart

import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class UserService {
  final UserRepository _repo;

  UserService(this._repo);

  static const int pageSize = UserRepository.pageSize;

  /// Regra de negócio: um usuário só é considerado válido
  /// se tiver completado o cadastro (name, email, uid e localização).
  /// Nós criados pelo SDK antes do onboarding terminar são descartados.
  bool isValid(UserModel u) =>
      u.name.isNotEmpty  &&
      u.email.isNotEmpty &&
      u.uid.isNotEmpty   &&
      (u.city.isNotEmpty || u.state.isNotEmpty);

  /// Pagina a partir de um mapa já baixado — sem nova leitura ao Firebase.
  /// Usado pelo controller no loadAll() para reaproveitar o fetchRawMap.
  ({List<UserModel> users, bool hasMore}) paginateFromRaw(
      Map<String, dynamic> raw) {
    final all = raw.entries
        .where((e) => e.value is Map)
        .map((e) => UserModel.fromMap(
              e.key,
              Map<String, dynamic>.from(e.value as Map),
            ))
        .where(isValid)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final page = all.take(pageSize).toList();
    return (users: page, hasMore: all.length >= pageSize);
  }

  /// Busca a primeira página diretamente do Firebase.
  /// Usado apenas no pull-to-refresh de usuários.
  Future<({List<UserModel> users, bool hasMore})> fetchFirstPage() async {
    final all = await _repo.fetchFirstPage();
    final valid = all.where(isValid).toList();
    return (users: valid, hasMore: all.length >= pageSize);
  }

  Future<({List<UserModel> users, bool hasMore})> fetchNextPage(
      String lastUserName) async {
    final all = await _repo.fetchNextPage(lastUserName);
    final valid = all.where(isValid).toList();
    return (users: valid, hasMore: all.length >= pageSize);
  }

  Future<UserModel?> fetchById(String uid) => _repo.fetchById(uid);
}