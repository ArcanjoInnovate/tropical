// lib/screens/admin/data/services/report_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';

class ReportService {
  final ReportRepository  _repo;
  final FirebaseFunctions _functions;

  ReportService(this._repo)
      : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Regra de negócio: retorna todos os reports de todos os tipos
  /// mesclados e ordenados por data (mais recente primeiro).
  Future<List<ReportModel>> fetchAllMerged() async {
    final map = await _repo.fetchAll();
    return map.values
        .expand((list) => list)
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
  }

  Future<Map<String, List<ReportModel>>> fetchGrouped() => _repo.fetchAll();

  Future<void> dismiss(ReportModel report) =>
      _repo.updateStatus(report.tipo, report.key, 'dismissed');

  /// Regra de negócio: monta o caminho correto de deleção
  /// de acordo com o tipo do report.
  Future<void> deleteContent(ReportModel report) async {
    final path = _contentPath(report);
    if (path == null) return;
    await _repo.resolveWithDeletion(
      tipo:        report.tipo,
      key:         report.key,
      contentPath: path,
    );
  }

  /// Regra de negócio: verifica se o tipo do report permite deleção direta.
  bool canDeleteDirectly(ReportModel report) =>
      _contentPath(report) != null;

  String? _contentPath(ReportModel report) {
    if (report.tipo == 'posts'   && report.postId  != null)
      return 'Posts/post/${report.postId}';
    if (report.tipo == 'stories' && report.storyId != null)
      return 'Posts/story/${report.storyId}';
    if (report.tipo == 'chats'   && report.chatId  != null)
      return 'Chats/${report.chatId}';
    return null;
  }

  /// Chama a Cloud Function para processar a denúncia formalmente
  Future<String> processarDenuncia({
    required ReportModel report,
    required String acao,
    required String motivoAdmin,
    required String artigoViolado,
    DateTime? suspensaoInicio,
    DateTime? suspensaoFim,
  }) async {
    final result = await _functions
        .httpsCallable('processarDenuncia')
        .call({
      'denunciaId':    report.key,
      'denunciaTipo':  report.tipo,
      'acao':          acao,
      'motivoAdmin':   motivoAdmin,
      'artigoViolado': artigoViolado,
      if (suspensaoInicio != null)
        'suspensaoInicio': suspensaoInicio.millisecondsSinceEpoch,
      if (suspensaoFim != null)
        'suspensaoFim': suspensaoFim.millisecondsSinceEpoch,
    });

    return result.data['protocolo'] as String? ?? '—';
  }

  Future<Map<String, dynamic>?> fetchContentData(ReportModel report) =>
      _repo.fetchContentData(report);
}