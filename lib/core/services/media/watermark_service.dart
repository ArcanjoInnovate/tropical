// lib/services/services_app/watermark_service.dart
//
// Marca d'água TABU com 3 níveis de intensidade:
//   • MINIMAL  → feed (discreta, não atrapalha UX)
//   • BALANCED → visualização full, perfil (meio-termo)
//   • FULL     → download/compartilhamento (máxima proteção)
//
// USO:
//   // Feed - marca quase invisível
//   final bytes = await WatermarkService.apply(
//     imageBytes: original,
//     userName:   'JOÃO',
//     level:      WatermarkLevel.minimal,
//   );
//
//   // Download - marca completa
//   final bytes = await WatermarkService.apply(
//     imageBytes: original,
//     userName:   'JOÃO',
//     level:      WatermarkLevel.full,
//   );

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum WatermarkLevel {
  /// Discreta - ideal para feed (diagonal sutil, sem barra)
  minimal,
  
  /// Balanceada - visualização em tela cheia (diagonal + barra leve)
  balanced,
  
  /// Completa - download/compartilhamento (proteção máxima)
  full,
}

class WatermarkService {
  WatermarkService._();

  // ══════════════════════════════════════════════════════════════════════════
  //  APPLY — aplica marca d'água com nível configurável
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> apply({
    required Uint8List imageBytes,
    required String userName,
    WatermarkLevel level = WatermarkLevel.balanced,
  }) async {
    final codec    = await ui.instantiateImageCodec(imageBytes);
    final frame    = await codec.getNextFrame();
    final srcImage = frame.image;
    final w = srcImage.width.toDouble();
    final h = srcImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    canvas.drawImage(srcImage, Offset.zero, Paint());
    srcImage.dispose();
    codec.dispose();

    _paintWatermarkLayers(canvas, w: w, h: h, userName: userName, level: level);

    final picture    = recorder.endRecording();
    final finalImage = await picture.toImage(w.toInt(), h.toInt());
    final byteData   = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    finalImage.dispose();
    picture.dispose();

    if (byteData == null) throw Exception('[WatermarkService] toByteData retornou null');
    return byteData.buffer.asUint8List();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE OVERLAY PNG — para vídeos
  // ══════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> createOverlayPng({
    required int width,
    required int height,
    required String userName,
    WatermarkLevel level = WatermarkLevel.balanced,
  }) async {
    final w = width.toDouble();
    final h = height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    _paintWatermarkLayers(canvas, w: w, h: h, userName: userName, level: level);

    final picture    = recorder.endRecording();
    final finalImage = await picture.toImage(width, height);
    final byteData   = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    finalImage.dispose();
    picture.dispose();

    if (byteData == null) throw Exception('[WatermarkService] createOverlayPng: toByteData retornou null');
    return byteData.buffer.asUint8List();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CAMADAS — renderização adaptativa por nível
  // ══════════════════════════════════════════════════════════════════════════
  static void _paintWatermarkLayers(
    Canvas canvas, {
    required double w,
    required double h,
    required String userName,
    required WatermarkLevel level,
  }) {
    final ref   = math.min(w, h);
    final scale = (ref / 720).clamp(0.35, 2.5);

    // ── CAMADA 1: Diagonal repetida ─────────────────────────────────────────
    // Opacidade aumentada: minimal=0.08, balanced=0.15, full=0.25
    final diagonalOpacity = switch (level) {
      WatermarkLevel.minimal  => 0.08,
      WatermarkLevel.balanced => 0.15,
      WatermarkLevel.full     => 0.25,
    };

    final diagonalSpacing = switch (level) {
      WatermarkLevel.minimal  => 200 * scale, // espaçamento maior = menos poluído
      WatermarkLevel.balanced => 170 * scale,
      WatermarkLevel.full     => 150 * scale,
    };

    _drawDiagonalWatermarks(
      canvas,
      text:     'TABU · @${userName.toLowerCase()}',
      w:        w,
      h:        h,
      fontSize: 13 * scale,
      opacity:  diagonalOpacity,
      spacing:  diagonalSpacing,
      angleDeg: -28,
    );

    // ── CAMADA 2: Barra inferior (somente balanced e full) ──────────────────
    if (level == WatermarkLevel.minimal) {
      // No modo minimal, apenas uma micro-assinatura discreta no canto (mais visível)
      _drawText(
        canvas,
        text:          'TABU',
        xRight:        w - (8 * scale),
        y:             h - (12 * scale), // canto inferior direito
        fontSize:      8 * scale,
        color:         Colors.white.withOpacity(0.25), // era 0.15
        weight:        ui.FontWeight.w600,
        letterSpacing: 8 * scale * 0.30,
      );
      return; // não desenha barra
    }

    // Para balanced e full, desenha a barra (com opacidades diferentes)
    final barOpacityMultiplier = level == WatermarkLevel.full ? 1.0 : 0.75; // era 0.65
    
    final barHeight  = 56 * scale;
    final barTop     = h - barHeight;
    final padH       = 16 * scale;
    final titleSize  = 14 * scale;
    final nameSize   = 11 * scale;
    final lineGap    = 3  * scale;

    // Vinheta mais escura
    final vignetteGrad = ui.Gradient.linear(
      Offset(0, h * 0.7),
      Offset(0, h),
      [
        Colors.black.withOpacity(0.0),
        Colors.black.withOpacity(0.25 * barOpacityMultiplier), // era 0.15
        Colors.black.withOpacity(0.60 * barOpacityMultiplier), // era 0.45
      ],
      [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      Paint()..shader = vignetteGrad,
    );

    // Barra com gradiente horizontal mais escuro
    final barGrad = ui.Gradient.linear(
      Offset(0, barTop),
      Offset(w, barTop),
      [
        Color.lerp(const Color(0x60000000), const Color(0x70000000), barOpacityMultiplier)!, // era 0x45/0x55
        Color.lerp(const Color(0x85000000), const Color(0xA0000000), barOpacityMultiplier)!, // era 0x70/0x8C
        Color.lerp(const Color(0x85000000), const Color(0xA0000000), barOpacityMultiplier)!, // era 0x70/0x8C
      ],
      [0.0, 0.3, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, barTop, w, barHeight),
      Paint()..shader = barGrad,
    );

    // Linha de brilho no topo (mais visível)
    canvas.drawRect(
      Rect.fromLTWH(0, barTop, w, math.max(scale * 0.8, 0.8)),
      Paint()..color = Colors.white.withOpacity(0.28 * barOpacityMultiplier), // era 0.18
    );

    // Acento rosa esquerdo (mais intenso)
    final accentOpacity = level == WatermarkLevel.full ? 0.95 : 0.75; // era 0.85/0.60
    canvas.drawRect(
      Rect.fromLTWH(0, barTop, scale * 2.5, barHeight),
      Paint()..color = const Color(0xFFFF4D8F).withOpacity(accentOpacity),
    );

    // ── Texto na barra ──────────────────────────────────────────────────────
    final totalTextH = titleSize + lineGap + nameSize;
    final textStartY = barTop + (barHeight - totalTextH) / 2;

    final textOpacity = level == WatermarkLevel.full ? 1.0 : 0.85; // era 0.95/0.75

    // "TABU"
    _drawText(
      canvas,
      text:          'TABU',
      x:             padH + scale * 4,
      y:             textStartY,
      fontSize:      titleSize,
      color:         Colors.white.withOpacity(textOpacity),
      weight:        ui.FontWeight.w700,
      letterSpacing: titleSize * 0.25,
    );

    // Separador (mais visível)
    final sepX = padH + scale * 4 + titleSize * 2.4;
    _drawText(
      canvas,
      text:          '·',
      x:             sepX,
      y:             textStartY + (titleSize - nameSize * 1.15) / 2,
      fontSize:      nameSize * 1.05,
      color:         const Color(0xFFFF6EB4).withOpacity(0.75 * barOpacityMultiplier), // era 0.60
      weight:        ui.FontWeight.w400,
    );

    // "@username" (mais visível)
    _drawText(
      canvas,
      text:          '@${userName.toLowerCase()}',
      x:             padH + scale * 4,
      y:             textStartY + titleSize + lineGap,
      fontSize:      nameSize,
      color:         const Color(0xFFFF6EB4).withOpacity(0.95 * barOpacityMultiplier), // era 0.88
      weight:        ui.FontWeight.w500,
      letterSpacing: nameSize * 0.05,
    );

    // "tabu.app" à direita (mais visível)
    _drawText(
      canvas,
      text:          'tabu.app',
      xRight:        w - padH,
      y:             barTop + (barHeight / 2) - (nameSize * 0.7),
      fontSize:      nameSize * 0.85,
      color:         Colors.white.withOpacity(0.35 * barOpacityMultiplier), // era 0.22
      weight:        ui.FontWeight.w400,
      letterSpacing: nameSize * 0.08,
    );

    // ── Micro-marca superior (apenas no modo full, mais visível) ────────────
    if (level == WatermarkLevel.full) {
      _drawText(
        canvas,
        text:          'TABU',
        xRight:        w - (8 * scale),
        y:             8 * scale,
        fontSize:      9 * scale,
        color:         Colors.white.withOpacity(0.28), // era 0.16
        weight:        ui.FontWeight.w700,
        letterSpacing: 9 * scale * 0.35,
      );
    }
  }

  // ── Marca diagonal repetida em grid ──────────────────────────────────────
  static void _drawDiagonalWatermarks(
    Canvas canvas, {
    required String text,
    required double w,
    required double h,
    required double fontSize,
    required double opacity,
    required double spacing,
    required double angleDeg,
  }) {
    final angleRad = angleDeg * math.pi / 180;
    final diag     = math.sqrt(w * w + h * h);
    final steps    = (diag / spacing).ceil() + 3;

    final paraStyle = ui.ParagraphStyle(
      fontFamily: 'Montserrat',
      fontSize:   fontSize,
    );
    final textStyle = ui.TextStyle(
      color:         Colors.white.withOpacity(opacity),
      fontWeight:    ui.FontWeight.w600,
      letterSpacing: fontSize * 0.18,
      fontFamily:    'Montserrat',
    );

    for (int i = -steps; i <= steps; i++) {
      for (int j = -steps; j <= steps; j++) {
        final cx = w / 2 + i * spacing;
        final cy = h / 2 + j * spacing;

        final pb = ui.ParagraphBuilder(paraStyle)
          ..pushStyle(textStyle)
          ..addText(text);

        final para = pb.build();
        para.layout(const ui.ParagraphConstraints(width: 1200));

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(angleRad);
        canvas.drawParagraph(para, Offset(-para.longestLine / 2, -fontSize / 2));
        canvas.restore();
      }
    }
  }

  // ── Helper: renderiza texto ──────────────────────────────────────────────
  static void _drawText(
    Canvas canvas, {
    required String text,
    double?  x,
    double?  xRight,
    required double y,
    required double fontSize,
    required Color color,
    required ui.FontWeight weight,
    double letterSpacing = 0,
    String fontFamily    = 'Montserrat',
  }) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign:  xRight != null ? TextAlign.right : TextAlign.left,
      fontFamily: fontFamily,
      fontSize:   fontSize,
    ))
      ..pushStyle(ui.TextStyle(
        color:         color,
        fontWeight:    weight,
        letterSpacing: letterSpacing,
        fontFamily:    fontFamily,
      ))
      ..addText(text);

    final para = pb.build();
    para.layout(const ui.ParagraphConstraints(width: 2000));

    final dx = xRight != null ? xRight - para.longestLine : x!;
    canvas.drawParagraph(para, Offset(dx, y));
  }
}
