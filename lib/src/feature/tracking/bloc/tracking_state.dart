// lib/src/feature/tracking/bloc/tracking_state.dart

part of 'tracking_bloc.dart';

enum TrackingStatus { initial, loading, active, stopped, error }

class TrackingState extends Equatable {
  final TrackingStatus      status;
  final List<LocationPoint> points;
  final bool                followUser;
  final String?             errorMessage;
  final double              compassHeading;
  final LocationPoint?      livePoint;

  const TrackingState({
    this.status         = TrackingStatus.initial,
    this.points         = const [],
    this.followUser     = true,
    this.errorMessage,
    this.compassHeading = 0,
    this.livePoint,
  });

  LocationPoint? get currentPoint =>
      points.isNotEmpty ? points.last : livePoint;

  double get displayHeading {
    final cur = currentPoint;
    if (cur != null && cur.speedKmh > 3.0) return cur.heading;
    return compassHeading;
  }

  bool get isLoading => status == TrackingStatus.loading;
  bool get isActive  => status == TrackingStatus.active;
  bool get isStopped => status == TrackingStatus.stopped ||
      status == TrackingStatus.initial;
  bool get hasError  => status == TrackingStatus.error;

  TrackingState copyWith({
    TrackingStatus?      status,
    List<LocationPoint>? points,
    bool?                followUser,
    String?              errorMessage,
    double?              compassHeading,
    LocationPoint?       livePoint,
  }) =>
      TrackingState(
        status:         status         ?? this.status,
        points:         points         ?? this.points,
        followUser:     followUser     ?? this.followUser,
        errorMessage:   errorMessage   ?? this.errorMessage,
        compassHeading: compassHeading ?? this.compassHeading,
        livePoint:      livePoint      ?? this.livePoint,
      );

  @override
  List<Object?> get props =>
      [status, points, followUser, errorMessage, compassHeading, livePoint];
}