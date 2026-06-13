// lib/services/services_app/videos_trim_service.dart
//
// Processa vídeos antes do upload:
//   1. Corta para o limite de segundos (se necessário)
//   2. Recorta para 9:16 (centralizado) — padroniza proporção do feed
//   3. Comprime para 720p com libx264
//
// O filtro 9:16 funciona assim:
//   - Vídeo vertical (ex: 9:16, 4:5)  → pillarbox preto nas laterais ou crop suave
//   - Vídeo horizontal (ex: 16:9)     → crop centralizado, corta topo/base
//   - Vídeo quadrado (1:1)            → crop centralizado
//
// Filtro FFmpeg: crop=ih*9/16:ih:(iw-ih*9/16)/2:0
//   - ih*9/16   = largura alvo (proporcional à altura)
//   - ih         = altura alvo (mantém a altura)
//   - (iw-...)/2 = offset X centralizado
//   - 0          = offset Y (topo)
//
// Para vídeos que já são 9:16 (margem de 2%) o crop é pulado — apenas comprime.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:video_compress/video_compress.dart';

class VideoTrimService {
  VideoTrimService._();

  static int _normalizeDurationSec(double raw) {
    return raw > 1000 ? (raw / 1000).ceil() : raw.ceil();
  }

  // ── Obtém largura e altura reais via FFprobe ──────────────────────────────
  static Future<({dynamic height, dynamic width})> _getDimensions(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final info    = session.getMediaInformation();
      if (info == null) return (width: 0, height: 0);
      final streams = info.getStreams();
      for (final stream in streams ?? []) {
        final w = stream.getWidth();
        final h = stream.getHeight();
        if (w != null && h != null && w > 0 && h > 0) {
          return (width: w, height: h);
        }
      }
    } catch (e) {
      debugPrint('[VideoTrim] _getDimensions erro: $e');
    }
    return (width: 0, height: 0);
  }

  // ── Monta o filtro de vídeo ───────────────────────────────────────────────
  // Se o vídeo já está em 9:16 (±2%), usa apenas scale.
  // Se não, faz crop centralizado para 9:16 primeiro, depois scale.
  static String _buildVideoFilter(int width, int height, String scaleH) {
    if (width <= 0 || height <= 0) {
      // Dimensões desconhecidas — só redimensiona
      return 'scale=-2:$scaleH';
    }

    final currentRatio = width / height;
    const targetRatio  = 9.0 / 16.0; // 0.5625
    final diff = (currentRatio - targetRatio).abs() / targetRatio;

    if (diff <= 0.02) {
      // Já é 9:16 (dentro de 2% de margem) — só redimensiona
      debugPrint('[VideoTrim] Vídeo já é 9:16, pulando crop.');
      return 'scale=-2:$scaleH';
    }

    // Crop centralizado para 9:16
    // Se o vídeo for mais largo que 9:16 → corta laterais
    // Se for mais estreito → corta topo/base
    final String cropFilter;
    if (currentRatio > targetRatio) {
      // Mais largo → corta laterais: nova largura = height * 9/16
      cropFilter = 'crop=ih*9/16:ih:(iw-ih*9/16)/2:0';
    } else {
      // Mais estreito → corta topo/base: nova altura = width * 16/9
      cropFilter = 'crop=iw:iw*16/9:0:(ih-iw*16/9)/2';
    }

    debugPrint(
        '[VideoTrim] ratio atual: ${currentRatio.toStringAsFixed(3)} → aplicando crop 9:16');
    return '$cropFilter,scale=-2:$scaleH';
  }

  // ── trim: só corta, sem recodificar ──────────────────────────────────────
  static Future<File> trim({
    required File file,
    required int maxSeconds,
  }) async {
    final info        = await VideoCompress.getMediaInfo(file.path);
    final durationSec = _normalizeDurationSec((info.duration ?? 0).toDouble());

    if (durationSec <= maxSeconds) return file;

    final tmp        = await getTemporaryDirectory();
    final outputPath = '${tmp.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final command    = '-y -i "${file.path}" -t $maxSeconds -c copy -avoid_negative_ts make_zero "$outputPath"';

    final session    = await FFmpegKit.execute(command);
    final rc         = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) throw VideoTrimException('FFmpeg trim falhou.');

    final out = File(outputPath);
    if (!out.existsSync() || await out.length() == 0) {
      throw VideoTrimException('Arquivo trimmed inválido.');
    }
    return out;
  }

  // ── trimAndCompress: pipeline completo ───────────────────────────────────
  // 1. Corta (se necessário)
  // 2. Crop 9:16 centralizado (se necessário)
  // 3. Comprime para 720p
  static Future<File> trimAndCompress({
    required File file,
    required int maxSeconds,
    int    crf   = 26,
    String scale = '1280', // altura alvo em px (720p = 1280 para 9:16)
  }) async {
    final info        = await VideoCompress.getMediaInfo(file.path);
    final durationSec = _normalizeDurationSec((info.duration ?? 0).toDouble());
    final dims        = await _getDimensions(file);
    final vf          = _buildVideoFilter(dims.width, dims.height, scale);

    debugPrint('[VideoTrim] trimAndCompress → ${durationSec}s | '
        '${dims.width}x${dims.height} | vf: $vf');

    final tmp        = await getTemporaryDirectory();
    final outputPath = '${tmp.path}/ready_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final durationFlag = durationSec > maxSeconds ? '-t $maxSeconds ' : '';

    final command = '-y -i "${file.path}" '
        '$durationFlag'
        '-vf "$vf" '
        '-c:v libx264 -crf $crf -preset ultrafast '
        '-c:a aac -b:a 96k '
        '-movflags +faststart '
        '"$outputPath"';

    debugPrint('[VideoTrim] Comando: $command');

    final session = await FFmpegKit.execute(command);
    final rc      = await session.getReturnCode();

    if (!ReturnCode.isSuccess(rc)) {
      debugPrint('[VideoTrim] FFmpeg falhou: ${await session.getOutput()}');
      // Fallback: devolve original sem crash
      return file;
    }

    final out = File(outputPath);
    if (!out.existsSync() || await out.length() == 0) {
      debugPrint('[VideoTrim] Saída inválida, devolvendo original.');
      return file;
    }

    final sizeMb = (await out.length() / 1024 / 1024).toStringAsFixed(2);
    debugPrint('[VideoTrim] ✅ Pronto: $outputPath (${sizeMb} MB)');
    return out;
  }

  // ── Cancela sessões em andamento ─────────────────────────────────────────
  static Future<void> cancelCompression() async {
    try {
      await FFmpegKit.cancel();
    } catch (e) {
      debugPrint('[VideoTrim] Erro ao cancelar: $e');
    }
  }
}

class VideoTrimException implements Exception {
  final String message;
  const VideoTrimException(this.message);
  @override
  String toString() => 'VideoTrimException: $message';
}