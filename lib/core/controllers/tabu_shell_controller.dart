// lib/controllers/controllers_app/tabu_shell_controller.dart

import 'package:flutter/material.dart';

class TabuShellController extends ChangeNotifier {
  static TabuShellController? _instance;
  static TabuShellController get instance => _instance ??= TabuShellController._();
  TabuShellController._();

  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  int _chatListTab = 0;
  int get chatListTab => _chatListTab;

  String? _pendingPartyId;
  String? get pendingPartyId => _pendingPartyId;

  // ── Novo: contexto de admin ───────────────────────────────────────────────
  bool _isAdmin = false;

  /// Deve ser chamado uma vez no initState do TabuShell
  void initialize({bool isAdmin = false}) {
    _isAdmin = isAdmin;
    // NÃO reseta _currentTabIndex aqui para não voltar ao início
  }

  /// Índice real da aba de chat dependendo do perfil
  int get _chatTabIndex => _isAdmin ? 3 : 2;

  void setTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  /// Abre a lista de chats com sub-tab específica
  void openChatList({int listTab = 0}) {
    _chatListTab = listTab;
    _currentTabIndex = _chatTabIndex; // ← corrigido
    notifyListeners();
  }

  void closeChat() {
    _chatListTab = 0;
    notifyListeners();
  }

  /// Abre a tela Home e agenda abertura de festa
  void openPartyDetail(String partyId) {
    _pendingPartyId = partyId;
    _currentTabIndex = 0;
    notifyListeners();
  }

  String? consumePendingPartyId() {
    final id = _pendingPartyId;
    _pendingPartyId = null;
    return id;
  }

}