part of 'tracking_bloc.dart';

sealed class TrackingEvent extends Equatable {
  const TrackingEvent();
  @override
  List<Object?> get props => [];
}

class TrackingInitialized    extends TrackingEvent { const TrackingInitialized(); }
class TrackingStartRequested extends TrackingEvent { const TrackingStartRequested(); }
class TrackingStopRequested  extends TrackingEvent { const TrackingStopRequested(); }
class TrackingFollowToggled  extends TrackingEvent { const TrackingFollowToggled(); }
class TrackingCleared        extends TrackingEvent { const TrackingCleared(); }

class TrackingPointsUpdated extends TrackingEvent {
  final List<LocationPoint> points;
  const TrackingPointsUpdated(this.points);
  @override List<Object?> get props => [points];
}

class TrackingCompassUpdated extends TrackingEvent {
  final double heading;
  const TrackingCompassUpdated(this.heading);
  @override List<Object?> get props => [heading];
}

class TrackingGpsUpdated extends TrackingEvent {
  final LocationPoint point;
  const TrackingGpsUpdated(this.point);
  @override List<Object?> get props => [point];
}