// lib/services/services_app/cloudinary_cleanup_helper.dart
//
// Helper unificado para deletar mídias do Cloudinary E do Firebase Storage.
// Detecta automaticamente a origem pela URL e roteia para o serviço correto.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CloudinaryCleanupHelper {
  CloudinaryCleanupHelper._();
  static final CloudinaryCleanupHelper instance = CloudinaryCleanupHelper._();

  /// Deleta um asset a partir da URL.
  ///
  /// Detecta automaticamente se é Cloudinary ou Firebase Storage:
  ///   - cloudinary.com → Cloud Function `deleteCloudinaryAsset`
  ///   - firebasestorage.googleapis.com → FirebaseStorage.refFromURL
  ///
  /// [resourceType] — 'image' ou 'video' (usado apenas para Cloudinary).
  ///
  /// Não lança exceção em caso de falha — apenas loga.
  Future<void> deleteAsset(String? url, String resourceType) async {
    if (url == null || url.isEmpty) return;

    if (url.contains('firebasestorage.googleapis.com') ||
        url.contains('firebasestorage.app')) {
      await _deleteFromFirebaseStorage(url);
    } else if (url.contains('cloudinary.com')) {
      await _deleteFromCloudinary(url, resourceType);
    } else {
      debugPrint('⚠️ [MediaCleanup] URL desconhecida, ignorando: $url');
    }
  }

  /// Deleta múltiplas URLs em paralelo. Ignora nulas/vazias e duplicatas.
  Future<void> deleteAll(List<(String?, String)> assets) async {
    final futures = <Future<void>>[];
    final seen = <String>{};

    for (final (url, resourceType) in assets) {
      if (url == null || url.isEmpty) continue;
      if (!seen.add(url)) continue;
      futures.add(deleteAsset(url, resourceType));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FIREBASE STORAGE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deleteFromFirebaseStorage(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
      debugPrint('🗑️ [Storage] Deleted: ${ref.fullPath}');
    } on FirebaseException catch (e) {
      // object-not-found é OK — já foi deletado ou nunca existiu
      if (e.code == 'object-not-found') {
        debugPrint('ℹ️ [Storage] Já deletado: $url');
      } else {
        debugPrint('⚠️ [Storage] Error [${e.code}]: ${e.message} | $url');
      }
    } catch (e) {
      debugPrint('⚠️ [Storage] Unexpected error: $e | $url');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CLOUDINARY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _deleteFromCloudinary(String url, String resourceType) async {
    final publicId = extractPublicId(url);
    if (publicId == null) {
      debugPrint('⚠️ [Cloudinary] Não extraiu publicId de: $url');
      return;
    }

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('deleteCloudinaryAsset');
      final result = await callable.call<Map<String, dynamic>>({
        'publicId': publicId,
        'resourceType': resourceType,
      });
      debugPrint(
        '☁️ [Cloudinary] Deleted $publicId ($resourceType) → ${result.data}',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '⚠️ [Cloudinary] CF error: [${e.code}] ${e.message} | publicId=$publicId',
      );
    } catch (e) {
      debugPrint('⚠️ [Cloudinary] Unexpected error: $e | publicId=$publicId');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EXTRAÇÃO DE PUBLIC ID (Cloudinary)
  //
  //  Exemplos:
  //    .../upload/v1234/gallery/uid/videos/file.mp4 → gallery/uid/videos/file
  //    .../upload/v1234/posts/uid/thumbs/file.jpg   → posts/uid/thumbs/file
  //    .../upload/c_fill,w_400/v1234/users/uid/f.jpg → users/uid/f
  // ══════════════════════════════════════════════════════════════════════════

  @visibleForTesting
  static String? extractPublicId(String url) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) {
      return null;
    }

    try {
      final uploadIndex = url.indexOf('/upload/');
      String afterUpload = url.substring(uploadIndex + 8);

      // Remove transformações (ex: "c_fill,w_400/")
      final versionMatch =
          RegExp(r'^(?:[^/]+/)*?(v\d+/.+)$').firstMatch(afterUpload);
      if (versionMatch != null) {
        afterUpload = versionMatch.group(1)!;
      }

      // Remove prefixo de versão "v1234567/"
      afterUpload = afterUpload.replaceFirst(RegExp(r'^v\d+/'), '');

      // Remove extensão (.jpg, .mp4, etc.)
      final dotIndex = afterUpload.lastIndexOf('.');
      if (dotIndex > 0) {
        afterUpload = afterUpload.substring(0, dotIndex);
      }

      return afterUpload.isEmpty ? null : afterUpload;
    } catch (e) {
      debugPrint('⚠️ [Cloudinary] extractPublicId error: $e');
      return null;
    }
  }
}