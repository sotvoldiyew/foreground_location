// lib/src/feature/tracking/bloc/tracking_bloc.dart

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/model/location_point.dart';
import '../../../common/service/compass_service.dart';
import '../../../common/service/location_service.dart';
import '../../../common/service/location_storage.dart';

part 'tracking_event.dart';
part 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final LocationService _locationService;
  StreamSubscription<List<LocationPoint>>? _locationSub;
  StreamSubscription<double>?              _compassSub;

  TrackingBloc({LocationService? locationService})
      : _locationService = locationService ?? LocationService.instance,
        super(const TrackingState()) {
    on<TrackingInitialized>   (_onInitialized);
    on<TrackingStartRequested>(_onStart);
    on<TrackingStopRequested> (_onStop);
    on<TrackingPointsUpdated> (_onPointsUpdated);
    on<TrackingCleared>       (_onCleared);
    on<TrackingFollowToggled> (_onFollowToggled);
    on<TrackingCompassUpdated>(_onCompassUpdated);
    on<TrackingGpsUpdated>    (_onGpsUpdated);
  }

  Future<void> _onInitialized(
      TrackingInitialized event,
      Emitter<TrackingState> emit,
      ) async {
    emit(state.copyWith(status: TrackingStatus.loading));

    await _locationSub?.cancel();
    _locationSub = _locationService.stream.listen((pts) {
      if (!isClosed) add(TrackingPointsUpdated(pts));
    });

    await _compassSub?.cancel();
    _compassSub = CompassService.instance.headingStream.listen((h) {
      if (!isClosed) add(TrackingCompassUpdated(h));
    });

    if (_locationService.isRunning) {
      debugPrint('🔵 Init: active');
      emit(state.copyWith(
        status:     TrackingStatus.active,
        points:     _locationService.points,
        followUser: true,
      ));
    } else {
      final saved = await LocationStorage.instance.load();
      debugPrint('🔵 Init: stopped, ${saved.length} nuqta');
      emit(state.copyWith(
        status: TrackingStatus.stopped,
        points: saved,
      ));
    }
  }

  Future<void> _onStart(
      TrackingStartRequested event,
      Emitter<TrackingState> emit,
      ) async {
    emit(state.copyWith(status: TrackingStatus.loading));

    final ok = await _locationService.start();

    if (ok) {
      debugPrint('🔵 Start OK');
      emit(const TrackingState(
        status:     TrackingStatus.active,
        followUser: true,
      ));
    } else {
      debugPrint('❌ Start FAIL');
      emit(state.copyWith(
        status:       TrackingStatus.error,
        errorMessage: 'GPS ruxsati berilmadi.\nSozlamalarga kiring va ruxsat bering.',
      ));
    }
  }

  Future<void> _onStop(
      TrackingStopRequested event,
      Emitter<TrackingState> emit,
      ) async {
    await _locationService.stop();
    emit(state.copyWith(status: TrackingStatus.stopped));
    debugPrint('🔵 Stopped');
  }

  void _onPointsUpdated(
      TrackingPointsUpdated event,
      Emitter<TrackingState> emit,
      ) {
    emit(state.copyWith(
      status: TrackingStatus.active,
      points: event.points,
    ));
  }

  Future<void> _onCleared(
      TrackingCleared event,
      Emitter<TrackingState> emit,
      ) async {
    await LocationStorage.instance.clear();
    emit(state.copyWith(points: const []));
  }

  void _onFollowToggled(
      TrackingFollowToggled event,
      Emitter<TrackingState> emit,
      ) {
    emit(state.copyWith(followUser: !state.followUser));
    debugPrint('🔵 Follow: ${!state.followUser}');
  }

  void _onCompassUpdated(
      TrackingCompassUpdated event,
      Emitter<TrackingState> emit,
      ) {
    if ((state.compassHeading - event.heading).abs() < 1.0) return;
    emit(state.copyWith(compassHeading: event.heading));
  }

  void _onGpsUpdated(
      TrackingGpsUpdated event,
      Emitter<TrackingState> emit,
      ) {
    emit(state.copyWith(livePoint: event.point));
  }

  @override
  Future<void> close() async {
    await _locationSub?.cancel();
    await _compassSub?.cancel();
    return super.close();
  }
}