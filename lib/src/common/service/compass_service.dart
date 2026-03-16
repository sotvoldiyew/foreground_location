import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  CompassService._();
  static final CompassService instance = CompassService._();

  Stream<double> get headingStream => FlutterCompass.events!
      .where((e) => e.heading != null)
      .map((e) => (e.heading! + 360) % 360);
}