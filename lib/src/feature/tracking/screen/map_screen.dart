
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/src/feature/tracking/state/map_screen_state.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../common/constants/app_constants.dart';
import '../bloc/tracking_bloc.dart';
import '../widget/bottom_panel.dart';
import '../widget/compass_widget.dart';
import '../widget/top_status_bar.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends MapScreenState {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: BlocConsumer<TrackingBloc, TrackingState>(
        listenWhen: (prev, curr) =>
        prev.followUser != curr.followUser ||
            prev.livePoint  != curr.livePoint  ||
            prev.status     != curr.status,
        listener: (ctx, state) {
          if (!mapReady || !state.followUser) return;
          final pt = state.livePoint;
          if (pt == null) return;
          moveTo(
            Point(latitude: pt.latitude, longitude: pt.longitude),
            zoom:    17,
            azimuth: 0,
          );
        },
        builder: (context, state) {
          return Stack(
            children: [
              YandexMap(
                mapObjects: _buildMapObjects(state),
                onMapCreated: (ctrl) async {
                  mapCtrl  = ctrl;
                  mapReady = true;
                  if (pendingPoint != null) {
                    await moveTo(pendingPoint!, zoom: 17);
                    pendingPoint = null;
                  } else if (!initialZoomDone) {
                    await moveTo(
                      const Point(latitude: 41.2995, longitude: 69.2401),
                      zoom: 12,
                    );
                  }
                },
                onCameraPositionChanged: (pos, __, isGesture) {
                  cameraAzimuth = pos.azimuth;
                  if (isGesture && !isAnimating && state.followUser) {
                    context
                        .read<TrackingBloc>()
                        .add(const TrackingFollowToggled());
                  }
                },
              ),

              Positioned(
                top: 0, left: 0, right: 0,
                child: TopStatusBar(state: state),
              ),

              Positioned(
                top: 120, right: 16,
                child: CompassWidget(
                  heading:  liveHeading,
                  speedKmh: liveSpeedKmh,
                ),
              ),

              Positioned(
                bottom: 280, right: 16,
                child: _FollowButton(
                  active: state.followUser,
                  onTap: () => context
                      .read<TrackingBloc>()
                      .add(const TrackingFollowToggled()),
                ),
              ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: BottomPanel(state: state),
              ),

              if (state.hasError && state.errorMessage != null)
                Positioned(
                  top: 110, left: 16, right: 16,
                  child: _ErrorBanner(message: state.errorMessage!),
                ),

              if (state.isLoading)
                const Positioned.fill(child: _LoadingOverlay()),
            ],
          );
        },
      ),
    );
  }

 List<MapObject> _buildMapObjects(TrackingState state) {
    final objects    = <MapObject>[];
    final allPoints  = state.points;

    if (allPoints.length >= 2) {
      objects.add(PolylineMapObject(
        mapId:    const MapObjectId('track'),
        polyline: Polyline(
          points: allPoints
              .map((p) => Point(latitude: p.latitude, longitude: p.longitude))
              .toList(),
        ),
        strokeColor:  const Color(kPolylineColor),
        strokeWidth:  kPolylineWidth,
        outlineColor: const Color(kOutlineColor),
        outlineWidth: 1.5,
      ));

      const double minDist = 30.0;
      double accDist = 0.0;
      final List<double> pendingBearings = [];

      for (int i = 0; i < allPoints.length - 1; i++) {
        final curr = allPoints[i];
        final next = allPoints[i + 1];

        accDist += haversineDistance(
          curr.latitude, curr.longitude,
          next.latitude, next.longitude,
        );

        if (accDist < minDist) continue;
        accDist = 0.0;

        final bearing   = calculateBearing(
          curr.latitude, curr.longitude,
          next.latitude, next.longitude,
        );
        final rounded   = (bearing / 5).round() * 5;
        final iconBytes = arrowIconCache[rounded];

        if (iconBytes == null) {
          pendingBearings.add(bearing);
          continue;
        }

        final midLat = (curr.latitude  + next.latitude)  / 2;
        final midLon = (curr.longitude + next.longitude) / 2;
        objects.add(PlacemarkMapObject(
          mapId:   MapObjectId('arrow_$i'),
          point:   Point(latitude: midLat, longitude: midLon),
          opacity: 1.0,
          icon: PlacemarkIcon.single(PlacemarkIconStyle(
            image:  BitmapDescriptor.fromBytes(iconBytes),
            scale:  1.0,
            anchor: const Offset(0.5, 0.5),
          )),
        ));
      }

      if (pendingBearings.isNotEmpty) {
        Future.microtask(() => buildArrowIcons(pendingBearings));
      }

      objects.add(PlacemarkMapObject(
        mapId:   const MapObjectId('start'),
        point:   Point(
          latitude:  allPoints.first.latitude,
          longitude: allPoints.first.longitude,
        ),
        opacity: 1.0,
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/icons/start.png'),
          scale: 1.2,
        )),
      ));
    }

    final markerPoint = livePoint ?? state.livePoint;
    if (markerPoint != null && iconBytes != null) {
      objects.add(PlacemarkMapObject(
        mapId:   const MapObjectId('user'),
        point:   Point(
          latitude:  markerPoint.latitude,
          longitude: markerPoint.longitude,
        ),
        opacity: 1.0,
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image:  BitmapDescriptor.fromBytes(iconBytes!),
          scale:  1.0,
          anchor: const Offset(0.5, 0.5),
        )),
      ));
    }

    return objects;
  }
}

class _FollowButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FollowButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 50, height: 50,
        decoration: BoxDecoration(
          color:        active ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          active ? Icons.navigation_rounded : Icons.location_searching_rounded,
          color: active ? Colors.white : const Color(0xFF1565C0),
          size:  26,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:    Colors.white,
                fontSize: 13,
                height:   1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: const Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(height: 16),
                Text(
                  'Yuklanmoqda...',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}