// lib/screens/screens_home/home_screen/posts/cloudinary_service.dart
//
// NÍVEL 4.1 — Upload Cloudinary com assinatura server-side.
//
// CORREÇÃO: folder e public_id agora são enviados para a CF assinar.
// O form de upload usa exatamente os parâmetros que vieram assinados,
// sem adicionar campos extras que invalidariam a assinatura.

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ─── Configuração ────────────────────────────────────────────────────────────
const _kCloudName    = 'dh7ixbnzc';
const _kUploadPreset = 'ml_default'; // fallback only
// ─────────────────────────────────────────────────────────────────────────────

enum CloudinaryResourceType { image, video, raw }

extension _Ext on CloudinaryResourceType {
  String get value => name; // 'image' | 'video' | 'raw'
}

class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout:    const Duration(minutes: 5),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // ── Obter assinatura do servidor ───────────────────────────────────────────
  // Envia folder e public_id para que a CF os inclua na assinatura.
  Future<Map<String, dynamic>?> _getSignature({
    required String folder,
    String? publicId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('getUploadSignature');

      final result = await callable.call<Map<String, dynamic>>({
        'folder': folder,
        if (publicId != null && publicId.isNotEmpty) 'public_id': publicId,
      });

      return result.data;
    } catch (e) {
      debugPrint('[Cloudinary] Falha ao obter assinatura: $e — usando fallback unsigned');
      return null;
    }
  }

  // ── Upload de arquivo ──────────────────────────────────────────────────────
  Future<String?> uploadFile({
    required File file,
    required CloudinaryResourceType resourceType,
    required String folder,
    String? publicId,
    void Function(double progress)? onProgress,
  }) async {
    final uri =
        'https://api.cloudinary.com/v1_1/$_kCloudName/${resourceType.value}/upload';

    try {
      final signature = await _getSignature(
        folder:   folder,
        publicId: publicId,
      );

      final Map<String, dynamic> formFields;
      if (signature != null) {
        // Upload assinado — usa exatamente os parâmetros que a CF assinou
        formFields = {
          'timestamp': signature['timestamp'],
          'signature': signature['signature'],
          'api_key':   signature['apiKey'],
          'folder':    signature['folder'],
          if ((signature['publicId'] as String?) != null &&
              (signature['publicId'] as String).isNotEmpty)
            'public_id': signature['publicId'],
          'file': await MultipartFile.fromFile(file.path),
        };
      } else {
        // Fallback unsigned
        formFields = {
          'upload_preset': _kUploadPreset,
          'folder':        folder,
          if (publicId != null && publicId.isNotEmpty) 'public_id': publicId,
          'file': await MultipartFile.fromFile(file.path),
        };
      }

      final formData = FormData.fromMap(formFields);

      final response = await _dio.post<Map<String, dynamic>>(
        uri,
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
        },
      );

      final url = response.data?['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        debugPrint('[Cloudinary] secure_url ausente: ${response.data}');
        return null;
      }

      onProgress?.call(1.0);
      debugPrint('[Cloudinary] Upload concluído: $url');
      return url;
    } on DioException catch (e) {
      debugPrint('[Cloudinary] DioException: ${e.message}');
      debugPrint('[Cloudinary] Response: ${e.response?.data}');
      return null;
    } catch (e, st) {
      debugPrint('[Cloudinary] Erro: $e\n$st');
      return null;
    }
  }

  // ── Upload de bytes (thumbnail, capa, etc.) ────────────────────────────────
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required CloudinaryResourceType resourceType,
    required String folder,
    String? publicId,
    void Function(double progress)? onProgress,
  }) async {
    final uri =
        'https://api.cloudinary.com/v1_1/$_kCloudName/${resourceType.value}/upload';

    try {
      final signature = await _getSignature(
        folder:   folder,
        publicId: publicId,
      );

      final Map<String, dynamic> formFields;
      if (signature != null) {
        formFields = {
          'timestamp': signature['timestamp'],
          'signature': signature['signature'],
          'api_key':   signature['apiKey'],
          'folder':    signature['folder'],
          if ((signature['publicId'] as String?) != null &&
              (signature['publicId'] as String).isNotEmpty)
            'public_id': signature['publicId'],
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        };
      } else {
        formFields = {
          'upload_preset': _kUploadPreset,
          'folder':        folder,
          if (publicId != null && publicId.isNotEmpty) 'public_id': publicId,
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        };
      }

      final formData = FormData.fromMap(formFields);

      final response = await _dio.post<Map<String, dynamic>>(
        uri,
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress((sent / total).clamp(0.0, 1.0));
          }
        },
      );

      final url = response.data?['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        debugPrint('[Cloudinary] secure_url ausente: ${response.data}');
        return null;
      }

      onProgress?.call(1.0);
      return url;
    } on DioException catch (e) {
      debugPrint('[Cloudinary] DioException bytes: ${e.message}');
      debugPrint('[Cloudinary] Response: ${e.response?.data}');
      return null;
    } catch (e, st) {
      debugPrint('[Cloudinary] Erro bytes: $e\n$st');
      return null;
    }
  }
}

