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
    'latitude':  latitude,
    'longitude': longitude,
    'heading':   heading,
    'speed':     speed,
    'accuracy':  accuracy,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LocationPoint.fromMap(Map<String, dynamic> map) => LocationPoint(
    latitude:  (map['latitude']  as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    heading:   (map['heading']   as num?)?.toDouble() ?? 0.0,
    speed:     (map['speed']     as num?)?.toDouble() ?? 0.0,
    accuracy:  (map['accuracy']  as num?)?.toDouble() ?? 0.0,
    timestamp: map['timestamp'] != null
        ? DateTime.parse(map['timestamp'] as String)
        : DateTime.now(),
  );

  String toJson() => jsonEncode(toMap());

  factory LocationPoint.fromJson(String src) =>
      LocationPoint.fromMap(jsonDecode(src) as Map<String, dynamic>);

  @override
  List<Object?> get props =>
      [latitude, longitude, heading, speed, accuracy, timestamp];
}