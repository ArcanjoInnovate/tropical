// lib/screens/admin/data/services/invite_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import '../models/invite_model.dart';
import '../repositories/invite_repository.dart';

class InviteService {
  final InviteRepository  _repo;
  final FirebaseFunctions _functions;

  InviteService(this._repo)
      : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<InviteModel>> fetchAll() => _repo.fetchAll();

  /// Aprovar ou rejeitar chama a Cloud Function que envia o e-mail
  /// e atualiza o status no banco.
  Future<void> processar({
    required String pedidoId,
    required String acao,
    String? motivoRejeicao,
  }) async {
    await _functions.httpsCallable('processarPedidoConvite').call({
      'pedidoId': pedidoId,
      'acao':     acao,
      if (motivoRejeicao != null) 'motivoRejeicao': motivoRejeicao,
    });
  }
}