// lib/services/services_app/gallery_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tclub/features/feed/data/services/cloudinary_cleanup_helper.dart';
import 'package:tclub/features/gallery/data/models/gallery_item_model.dart';

class GalleryService {
  static final GalleryService instance = GalleryService._();
  GalleryService._();

  final _db = FirebaseDatabase.instance.ref();

  // ── Criar galeria ───────────────────────────────────────────────────────────
  Future<void> createGallery(String userId) async {
    await _db.child('Gallery/$userId/created').set(true);
    await _db.child('Gallery/$userId/created_at')
        .set(DateTime.now().millisecondsSinceEpoch);
    await _db.child('Gallery/$userId/items').set({});
  }

  // ── Verificar se tem galeria (tem itens) ───────────────────────────────────
  Future<bool> hasGallery(String userId) async {
    final snap = await _db.child('Gallery/$userId/items').get();
    if (!snap.exists || snap.value == null) return false;
    final data = snap.value as Map<dynamic, dynamic>?;
    return data != null && data.isNotEmpty;
  }

  // ── Verificar se a galeria foi criada (mesmo que vazia) ─────────────────────
  Future<bool> isGalleryCreated(String userId) async {
    final snap = await _db.child('Gallery/$userId/created').get();
    return snap.exists && snap.value == true;
  }

  // ── Adicionar item ──────────────────────────────────────────────────────────
  Future<void> addItem({
    required String userId,
    required String type,
    required String mediaUrl,
    String? thumbUrl,
    String? coverUrl,
    int? videoDuration,
  }) async {
    final itemRef = _db.child('Gallery/$userId/items').push();
    final item = GalleryItem(
      id:            itemRef.key!,
      userId:        userId,
      type:          type,
      mediaUrl:      mediaUrl,
      thumbUrl:      thumbUrl,
      coverUrl:      coverUrl,
      videoDuration: videoDuration,
      createdAt:     DateTime.now(),
    );
    await itemRef.set(item.toMap());
  }

  // ── Atualizar capa de um item já existente ──────────────────────────────────
  Future<void> updateItemCover({
    required String userId,
    required String itemId,
    required String coverUrl,
    String? thumbUrl,
  }) async {
    final updates = <String, dynamic>{
      'cover_url': coverUrl,
      if (thumbUrl != null && thumbUrl.isNotEmpty) 'thumb_url': thumbUrl,
    };
    await _db.child('Gallery/$userId/items/$itemId').update(updates);
  }

  // ── Buscar itens (com paginação por cursor de data) ─────────────────────────
  Future<List<GalleryItem>> fetchItems(
    String userId, {
    int limit = 15,
    DateTime? startAfter,
  }) async {
    debugPrint('🔍 Buscando galeria de $userId (limit=$limit, cursor=$startAfter)');
    final snap = await _db.child('Gallery/$userId/items').get();

    debugPrint('📦 Snap exists: ${snap.exists}, value: ${snap.value}');

    if (!snap.exists || snap.value == null) {
      debugPrint('❌ Galeria não existe ou vazia');
      return [];
    }

    final raw = snap.value;
    if (raw is! Map) {
      debugPrint('❌ Value não é Map: $raw');
      return [];
    }

    final data = Map<String, dynamic>.from(raw);
    debugPrint('📊 Itens raw: ${data.length}');

    final items = <GalleryItem>[];
    data.forEach((key, value) {
      if (value is Map) {
        try {
          final itemMap = Map<String, dynamic>.from(value);
          itemMap['id']     = key;
          itemMap['userId'] = userId;

          final item = GalleryItem.fromMap(itemMap);

          if (startAfter != null && !item.createdAt.isBefore(startAfter)) return;

          items.add(item);
        } catch (e) {
          debugPrint('❌ Parse error [$key]: $e');
        }
      }
    });

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final page = items.take(limit).toList();

    debugPrint('🎉 fetchItems FINAL: ${page.length} itens');
    return page;
  }

  // ── Deletar item (Firebase + Cloudinary) ────────────────────────────────────
  //
  // 1. Remove o nó do Firebase Realtime Database.
  // 2. Chama a Cloud Function `deleteCloudinaryAsset` para deletar
  //    o arquivo original (e suas transformações) no Cloudinary.
  //
  // O publicId é extraído da mediaUrl do Cloudinary.
  // Formato típico de URL:
  //   https://res.cloudinary.com/<cloud>/image/upload/v123456/users/uid/abc.jpg
  //   publicId = "users/uid/abc"  (sem extensão)
  //
  Future<void> deleteItem(String userId, String itemId) async {
    // 1. Primeiro busca os dados do item para obter mediaUrl, thumbUrl, coverUrl e type
    final snap = await _db.child('Gallery/$userId/items/$itemId').get();

    String? mediaUrl;
    String? thumbUrl;
    String? coverUrl;
    String  resourceType = 'image';

    if (snap.exists && snap.value != null) {
      final map  = Map<String, dynamic>.from(snap.value as Map);
      mediaUrl   = map['media_url'] as String?;
      thumbUrl   = map['thumb_url'] as String?;
      coverUrl   = map['cover_url'] as String?;
      final type = map['type']      as String? ?? 'foto';
      resourceType = type == 'video' ? 'video' : 'image';
    }

    // 2. Remove do Firebase (independente do resultado do Cloudinary)
    await _db.child('Gallery/$userId/items/$itemId').remove();
    debugPrint('✅ Item $itemId removido do Firebase');

    // 3. Deleta todos os assets do Cloudinary (media, thumb, cover)
    await CloudinaryCleanupHelper.instance.deleteAll([
      (mediaUrl, resourceType),
      (thumbUrl, 'image'),
      (coverUrl, 'image'),
    ]);
  }

  // ── Contar itens ────────────────────────────────────────────────────────────
  Future<int> countItems(String userId) async {
    final snap = await _db.child('Gallery/$userId/items').get();
    if (!snap.exists) return 0;
    final data = snap.value as Map<dynamic, dynamic>;
    return data.length;
  }
}

