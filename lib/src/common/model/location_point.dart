import 'dart:convert';
import 'package:equatable/equatable.dart';

class LocationPoint extends Equatable {
  final double   latitude;
  final double   longitude;
  final double   heading;
  final double   speed;
  final double   accuracy;
  final DateTime timestamp;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
  });

  double get speedKmh => speed * 3.6;

  String get headingLabel {
    final h = heading % 360;
    if (h < 22.5 || h >= 337.5) return '↑ Shimol';
    if (h < 67.5)                return '↗ Sh-Sharq';
    if (h < 112.5)               return '→ Sharq';
    if (h < 157.5)               return '↘ J-Sharq';
    if (h < 202.5)               return '↓ Janub';
    if (h < 247.5)               return '↙ J-G\'arb';
    if (h < 292.5)               return '← G\'arb';
    return                              '↖ Sh-G\'arb';
  }

  Map<String, dynamic> toMap() => {
    'lat': latitude,
    'lng': longitude,
    'hdg': heading,
    'spd': speed,
    'acc': accuracy,
    'ts':  timestamp.millisecondsSinceEpoch,
  };

  factory LocationPoint.fromMap(Map<String, dynamic> m) => LocationPoint(
    latitude:  (m['lat'] as num).toDouble(),
    longitude: (m['lng'] as num).toDouble(),
    heading:   (m['hdg'] as num?)?.toDouble() ?? 0.0,
    speed:     ((m['spd'] as num?)?.toDouble() ?? 0.0).clamp(0, double.infinity),
    accuracy:  (m['acc'] as num?)?.toDouble() ?? 0.0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
  );

  String toJson() => jsonEncode(toMap());

  factory LocationPoint.fromJson(String src) =>
      LocationPoint.fromMap(jsonDecode(src) as Map<String, dynamic>);

  @override
  List<Object?> get props => [latitude, longitude, heading, speed, accuracy, timestamp];
}