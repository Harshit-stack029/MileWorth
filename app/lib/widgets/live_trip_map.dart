import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../services/trip_tracker.dart';
import '../theme.dart';

/// Draws the drive as it is being recorded: the route so far plus a camera that
/// follows the latest GPS fix.
///
/// Reads the fixes already held by [TripTracker.route], so it costs no extra
/// GPS work — it just visualises the stream the tracker is consuming anyway.
class LiveTripMap extends StatefulWidget {
  const LiveTripMap({super.key});

  @override
  State<LiveTripMap> createState() => _LiveTripMapState();
}

class _LiveTripMapState extends State<LiveTripMap> {
  GoogleMapController? _controller;
  int _lastFollowedCount = 0;

  void _follow(List<LatLng> points) {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;
    // Only move when a new fix arrived, so user panning isn't yanked back on
    // every unrelated rebuild.
    if (points.length == _lastFollowedCount) return;
    _lastFollowedCount = points.length;
    controller.animateCamera(CameraUpdate.newLatLng(points.last));
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TripTracker>();
    final points = [
      for (final p in tracker.route) LatLng(p.latitude, p.longitude),
    ];

    if (points.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('Waiting for GPS…', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(points));

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: points.last, zoom: 16),
      onMapCreated: (c) => _controller = c,
      // The map sits inside a scrolling dashboard, so gestures stay off to keep
      // the list scrollable; the camera follows the drive on its own.
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // Tracking is only ever active with permission held, so the dot is safe.
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      polylines: points.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('live'),
                points: points,
                color: AppColors.business,
                width: 5,
              ),
            }
          : const {},
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
