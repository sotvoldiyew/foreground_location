import 'dart:math' as math;
import 'package:flutter/material.dart';

class CompassWidget extends StatelessWidget {
  final double heading;
  final double speedKmh;

  const CompassWidget({
    super.key,
    required this.heading,
    required this.speedKmh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82, height: 82,
      decoration: BoxDecoration(
        color:  Colors.white.withOpacity(0.95),
        shape:  BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.22),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(alignment: Alignment.center, children: [
        _DirectionLabels(),
        Transform.rotate(
          angle: -heading * math.pi / 180,
          child: CustomPaint(size: const Size(54, 54), painter: _NeedlePainter()),
        ),
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color:  Colors.white,
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Center(
            child: Text(
              speedKmh.toStringAsFixed(0),
              style: const TextStyle(
                fontSize:   9.5,
                fontWeight: FontWeight.bold,
                color:      Color(0xFF1565C0),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DirectionLabels extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74, height: 74,
      child: Stack(alignment: Alignment.center, children: [
        _label('N', Alignment.topCenter,    Colors.red),
        _label('S', Alignment.bottomCenter, Colors.grey),
        _label('E', Alignment.centerRight,  Colors.grey),
        _label('W', Alignment.centerLeft,   Colors.grey),
      ]),
    );
  }

  Widget _label(String t, Alignment a, Color c) => Align(
    alignment: a,
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Text(t, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)),
    ),
  );
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 20)
        ..lineTo(cx - 5, cy)
        ..lineTo(cx + 5, cy)
        ..close(),
      Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cx, cy + 20)
        ..lineTo(cx - 5, cy)
        ..lineTo(cx + 5, cy)
        ..close(),
      Paint()..color = Colors.grey.shade400..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}