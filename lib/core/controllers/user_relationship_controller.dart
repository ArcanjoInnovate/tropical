// lib/core/controllers/user_relationship_controller.dart

import 'package:tclub/core/services/user_relationship_service.dart'; 

class UserRelationShipController {
  final _service = UserRelationshipService();

  Future<bool> blockUser(String myUserId, String targetUserId) =>
      _service.blockUser(myUserId, targetUserId);

  Future<List<String>> fetchAllBlockedUsers(String myUserId) =>
      _service.fetchAllBlockedUsers(myUserId).then((s) => s.toList());

  Future<bool> unblockUser(String myUserId, String targetUserId) =>
      _service.unblockUser(myUserId, targetUserId);

  Future<bool> isBlocking(String myUserId, String targetUserId) async {
    final rel = await _service.checkRelationship(myUserId, targetUserId);
    return rel.iBlockedThem;
  }

  Future<bool> amIBlocked(String myUserId, String targetUserId) async {
    final rel = await _service.checkRelationship(myUserId, targetUserId);
    return rel.theyBlockedMe;
  }

  Future<bool> isAnyBlockActive(
    String myUserId,
    String targetUserId,
  ) async {
    final rel = await _service.checkRelationship(myUserId, targetUserId);
    return rel.iBlockedThem || rel.theyBlockedMe;
  }
}

