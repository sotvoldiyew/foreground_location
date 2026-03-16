import 'package:location_tracker/src/common/model/location_point.dart';
import 'package:location_tracker/src/common/service/location_api_service.dart';
import 'package:location_tracker/src/common/service/location_storage.dart';
import 'package:logger/logger.dart';


final _log = Logger();

class LocationRepository {
  LocationRepository._();
  static final LocationRepository instance = LocationRepository._();

  final _api     = LocationApiService.instance;
  final _storage = LocationStorage.instance;

  final List<LocationPoint> _pendingQueue = [];

  int get pendingCount => _pendingQueue.length;

  Future<void> saveLocation(LocationPoint point) async {

    final saved = await _storage.load();
    saved.add(point);
    await _storage.save(saved);

    final ok = await _api.sendLocation(
      latitude:  point.latitude,
      longitude: point.longitude,
      heading:   point.heading,
    );

    if (!ok) {
      _pendingQueue.add(point);
      _log.w('📥 [Repo] Offline queue: ${_pendingQueue.length} ta');
      return;
    }

    await _flushQueue();
  }

  Future<void> _flushQueue() async {
    if (_pendingQueue.isEmpty) return;

    _log.i('🔄 [Repo] Queue flush: ${_pendingQueue.length} ta');
    final toSend = List<LocationPoint>.from(_pendingQueue);

    for (final point in toSend) {
      final ok = await _api.sendLocation(
        latitude:  point.latitude,
        longitude: point.longitude,
        heading:   point.heading,
      );
      if (ok) {
        _pendingQueue.remove(point);
        _log.i('✅ [Repo] Queue dan yuborildi. Qoldi: ${_pendingQueue.length}');
      } else {
        _log.i('⏸️ [Repo] Internet yo\'q, queue to\'xtatildi');
        break;
      }
    }
  }

  Future<List<LocationPoint>> loadPoints() => _storage.load();

  Future<void> clearPoints() => _storage.clear();

  Future<void> retryPending() => _flushQueue();
}