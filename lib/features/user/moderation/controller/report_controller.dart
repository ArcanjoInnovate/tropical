// lib/features/user/moderation/controller/report_controller.dart

import 'package:flutter/material.dart';
import '../data/models/report_models.dart';
import '../data/repositories/report_repository.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ESTADO DO FLUXO DE DENÚNCIA
// ══════════════════════════════════════════════════════════════════════════════
enum ReportFlowState { checking, idle, sending, success, alreadyReported }

// ══════════════════════════════════════════════════════════════════════════════
//  REPORT CONTROLLER  (ChangeNotifier — compatível com Provider / ValueNotifier)
// ══════════════════════════════════════════════════════════════════════════════
class ReportController extends ChangeNotifier {

  final ReportRepository _repository;

  ReportController({ReportRepository? repository})
      : _repository = repository ?? ReportRepository.instance;

  // ── Estado público ────────────────────────────────────────────────────────

  ReportFlowState        state         = ReportFlowState.checking;
  ReportMotivoModel?     motivoSelecionado;
  String                 descricao     = '';
  bool                   confirmaVerdade       = false;
  bool                   confirmaConsequencias = false;
  String?                erro;

  // ── Configuração do chat (requer confirmações extras) ─────────────────────
  bool get requerConfirmacoes =>
      _type == ReportTargetType.chat;

  // ── Validações ────────────────────────────────────────────────────────────

  static const _minCharsDefault = 20;
  static const _minCharsChat    = 30;

  ReportTargetType? _type;

  int get minChars =>
      _type == ReportTargetType.chat ? _minCharsChat : _minCharsDefault;

  bool get descValida   => descricao.trim().length >= minChars;
  bool get podeEnviar {
    if (motivoSelecionado == null) return false;
    if (!descValida) return false;
    if (state == ReportFlowState.sending) return false;
    if (requerConfirmacoes && (!confirmaVerdade || !confirmaConsequencias)) {
      return false;
    }
    return true;
  }

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> init({
    required ReportTargetType type,
    required String           targetId,
  }) async {
    _type = type;
    state = ReportFlowState.checking;
    notifyListeners();

    final ja = await _repository.jaReportou(type: type, targetId: targetId);

    state = ja ? ReportFlowState.alreadyReported : ReportFlowState.idle;
    notifyListeners();
  }

  // ── Mutações de estado ────────────────────────────────────────────────────

  void selecionarMotivo(ReportMotivoModel motivo) {
    motivoSelecionado = motivo;
    notifyListeners();
  }

  void atualizarDescricao(String value) {
    descricao = value;
    notifyListeners();
  }

  void toggleConfirmaVerdade(bool value) {
    confirmaVerdade = value;
    notifyListeners();
  }

  void toggleConfirmaConsequencias(bool value) {
    confirmaConsequencias = value;
    notifyListeners();
  }

  // ── Envio ─────────────────────────────────────────────────────────────────

  Future<bool> enviar({
    required ReportTargetType type,
    required ReportPayload    payload,
  }) async {
    if (!podeEnviar) return false;

    state = ReportFlowState.sending;
    erro  = null;
    notifyListeners();

    try {
      await _repository.submit(type: type, payload: payload);
      state = ReportFlowState.success;
      notifyListeners();
      return true;
    } catch (e) {
      state = ReportFlowState.idle;
      erro  = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Reset (reutilização do controller em múltiplas telas) ─────────────────

  void reset() {
    state                 = ReportFlowState.checking;
    motivoSelecionado     = null;
    descricao             = '';
    confirmaVerdade       = false;
    confirmaConsequencias = false;
    erro                  = null;
    _type                 = null;
    notifyListeners();
  }
}

