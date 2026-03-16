import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<Uint8List> buildNavigationIcon({
  double heading     = 0,
  double size        = 96,
  Color  arrowColor  = const Color(0xFF1565C0),
  Color  centerColor = Colors.white,
}) async {
  return _drawIcon(
    angleDeg:    (heading + 180) % 360,
    size:        size,
    arrowColor:  arrowColor,
    centerColor: centerColor,
  );
}

Future<Uint8List> buildArrowIcon({
  double bearing     = 0,
  double size        = 64,
  Color  arrowColor  = const Color(0xFF1565C0),
  Color  centerColor = Colors.white,
}) async {
  return _drawIcon(
    angleDeg:    bearing,
    size:        size,
    arrowColor:  arrowColor,
    centerColor: centerColor,
  );
}

Future<Uint8List> _drawIcon({
  required double angleDeg,
  required double size,
  required Color  arrowColor,
  required Color  centerColor,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  final cx = size / 2;
  final cy = size / 2;
  final r  = size * 0.36;

  canvas.drawCircle(
    Offset(cx, cy + 2),
    size * 0.38,
    Paint()
      ..color      = Colors.black.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );

  canvas.drawCircle(Offset(cx, cy), size * 0.42, Paint()..color = Colors.white);


  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = arrowColor);

  canvas.save();
  canvas.translate(cx, cy);

 canvas.rotate(angleDeg * math.pi / 180);

  final tipY   = -r * 0.62;
  final baseY  =  r * 0.52;
  final wingX  =  r * 0.42;
  final notchY =  r * 0.08;

  final path = Path()
    ..moveTo(0,       tipY)
    ..lineTo( wingX,  baseY)
    ..lineTo(0,       notchY)
    ..lineTo(-wingX,  baseY)
    ..close();

  canvas.drawPath(path, Paint()..color = centerColor);
  canvas.restore();

  final picture = recorder.endRecording();
  final image   = await picture.toImage(size.toInt(), size.toInt());
  final bytes   = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}