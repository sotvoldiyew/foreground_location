import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../model/location_point.dart';

class LocationStorage {
  LocationStorage._();
  static final LocationStorage instance = LocationStorage._();

  Future<List<LocationPoint>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kPrefPoints);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => LocationPoint.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('❌ load xato: $e');
      return [];
    }
  }

  Future<void> save(List<LocationPoint> points) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefPoints, jsonEncode(points.map((p) => p.toMap()).toList()));
    } catch (e) {
      debugPrint('❌ save xato: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kPrefPoints);
      debugPrint('🗑️ storage tozalandi');
    } catch (e) {
      debugPrint('❌ clear xato: $e');
    }
  }

  Future<void> setRunning(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefRunning, value);
  }

  Future<bool> isRunning() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPrefRunning) ?? false;
  }
}