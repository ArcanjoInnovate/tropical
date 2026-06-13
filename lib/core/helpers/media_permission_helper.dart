// lib/core/helpers/media_permission_helper.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Solicita a permissão adequada (câmera ou galeria) antes de abrir o picker.
///
/// Android 13+ (SDK 33+) → READ_MEDIA_IMAGES / READ_MEDIA_VIDEO
/// Android 10–12         → READ_EXTERNAL_STORAGE
/// Android 9 e abaixo   → READ_EXTERNAL_STORAGE
/// iOS                   → photos
///
/// Retorna true se concedida, false caso contrário.
/// Se negada permanentemente, exibe SnackBar com botão para Configurações.
Future<bool> requestMediaPermission(
  BuildContext context,
  ImageSource source,
) async {
  PermissionStatus status;

  if (source == ImageSource.camera) {
    status = await Permission.camera.request();
  } else {
    status = await _requestGalleryPermission();
  }

  if (status.isGranted || status.isLimited) return true;

  if (!context.mounted) return false;

  if (status.isPermanentlyDenied) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          source == ImageSource.camera
              ? 'Permissão de câmera negada. Ative nas configurações.'
              : 'Permissão de galeria negada. Ative nas configurações.',
        ),
        action: SnackBarAction(
          label: 'ABRIR',
          onPressed: openAppSettings,
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          source == ImageSource.camera
              ? 'Permissão de câmera necessária.'
              : 'Permissão de galeria necessária.',
        ),
      ),
    );
  }

  return false;
}

/// Escolhe a permissão correta de galeria conforme plataforma e versão do SO.
Future<PermissionStatus> _requestGalleryPermission() async {
  if (Platform.isIOS) {
    return Permission.photos.request();
  }

  // Android
  final sdk = await _androidSdk();

  if (sdk >= 33) {
    // Android 13+ — READ_MEDIA_IMAGES substitui READ_EXTERNAL_STORAGE
    final status = await Permission.photos.request();
    // permission_handler 11+ mapeia Permission.photos para
    // READ_MEDIA_IMAGES no Android 13+. Se ainda assim negar,
    // tenta mediaLibrary como fallback.
    if (status.isGranted || status.isLimited) return status;
    return Permission.mediaLibrary.request();
  }

  // Android 9–12 — READ_EXTERNAL_STORAGE
  return Permission.storage.request();
}

Future<int> _androidSdk() async {
  if (!Platform.isAndroid) return 0;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  } catch (_) {
    return 0;
  }
}