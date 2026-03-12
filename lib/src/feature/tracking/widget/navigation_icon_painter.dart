// lib/src/feature/tracking/widget/navigation_icon_painter.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Heading bo'yicha burilgan navigation arrow PNG.
/// heading = 0 → shimolga (yuqori), 90 → sharqqa va h.k.
Future<Uint8List> buildNavigationIcon({
  double heading     = 0,
  double size        = 96,
  Color  arrowColor  = const Color(0xFF1565C0),
  Color  centerColor = Colors.white,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  final cx = size / 2;
  final cy = size / 2;

  // Heading burchagiga burish
  canvas.translate(cx, cy);
  canvas.rotate(heading * math.pi / 180);
  canvas.translate(-cx, -cy);

  // Shadow
  canvas.drawCircle(
    Offset(cx, cy + 3),
    size * 0.38,
    Paint()
      ..color      = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  // Oq outline
  canvas.drawCircle(Offset(cx, cy), size * 0.42,
      Paint()..color = Colors.white);

  // Asosiy doira
  canvas.drawCircle(Offset(cx, cy), size * 0.36,
      Paint()..color = arrowColor);

  // Strelka (tip yuqorida = shimol = 0°)
  final arrow = Path()
    ..moveTo(cx,               cy - size * 0.22)
    ..lineTo(cx + size * 0.16, cy + size * 0.20)
    ..lineTo(cx,               cy + size * 0.08)
    ..lineTo(cx - size * 0.16, cy + size * 0.20)
    ..close();
  canvas.drawPath(arrow, Paint()..color = centerColor);

  // Markaziy nuqta
  canvas.drawCircle(
    Offset(cx, cy + size * 0.06),
    size * 0.04,
    Paint()..color = arrowColor.withOpacity(0.6),
  );

  final picture = recorder.endRecording();
  final image   = await picture.toImage(size.toInt(), size.toInt());
  final bytes   = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}