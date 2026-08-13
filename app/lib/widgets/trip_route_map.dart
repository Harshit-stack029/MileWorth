import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/trip.dart';
import '../services/location_access.dart';
import '../theme.dart';
import '../utils/polyline.dart';

/// The ordered points making up a trip's route: the full decoded polyline when
/// one was recorded, otherwise whatever endpoints exist (a manually-entered trip
/// has none).
List<LatLng> tripRoutePoints(Trip trip) {
  final encoded = trip.routePolyline;
  if (encoded != null && encoded.isNotEmpty) {
    final decoded = decodePolyline(encoded);
    if (decoded.length >= 2) {
      return [for (final p in decoded) LatLng(p.lat, p.lng)];
    }
  }
  final points = <LatLng>[];
  if (trip.startLat != null && trip.startLng != null) {
    points.add(LatLng(trip.startLat!, trip.startLng!));
  }
  if (trip.endLat != null && trip.endLng != null) {
    points.add(LatLng(trip.endLat!, trip.endLng!));
  }
  return points;
}

LatLngBounds boundsOf(List<LatLng> points) {
  var minLat = points.first.latitude, maxLat = points.first.latitude;
  var minLng = points.first.longitude, maxLng = points.first.longitude;
  for (final p in points) {
    minLat = p.latitude < minLat ? p.latitude : minLat;
    maxLat = p.latitude > maxLat ? p.latitude : maxLat;
    minLng = p.longitude < minLng ? p.longitude : minLng;
    maxLng = p.longitude > maxLng ? p.longitude : maxLng;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// Renders a recorded trip route: the polyline plus start/end markers, camera
/// fitted to the route.
///
/// [interactive] controls pan/zoom. The card-sized preview embedded in a
/// scrolling list keeps gestures off so the map does not swallow the list's
/// scroll; the fullscreen view turns them on.
class TripRouteMap extends StatefulWidget {
  final Trip trip;
  final bool interactive;

  const TripRouteMap({super.key, required this.trip, this.interactive = false});

  @override
  State<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<TripRouteMap> {
  GoogleMapController? _controller;
  bool _myLocationAllowed = false;

  @override
  void initState() {
    super.initState();
    if (widget.interactive) _resolveMyLocation();
  }

  /// The blue my-location dot throws if enabled without permission, so only
  /// turn it on once we know we hold it. Never prompts — the dot is a nicety,
  /// and a permission dialog on opening a map would be a surprise.
  Future<void> _resolveMyLocation() async {
    final access = await const LocationAccessService().check();
    if (mounted && access.isGranted) {
      setState(() => _myLocationAllowed = true);
    }
  }

  void _fitToRoute(List<LatLng> points) {
    final controller = _controller;
    if (controller == null) return;
    if (points.length < 2) {
      controller.moveCamera(CameraUpdate.newLatLngZoom(points.first, 14));
      return;
    }
    // newLatLngBounds throws if the map view hasn't been laid out yet ("map
    // size can't be 0"). Guard so a slow first frame can't crash the screen;
    // fall back to centering on the route start.
    try {
      controller.moveCamera(CameraUpdate.newLatLngBounds(boundsOf(points), 32));
    } catch (_) {
      controller.moveCamera(CameraUpdate.newLatLngZoom(points.first, 13));
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = tripRoutePoints(widget.trip);
    if (points.isEmpty) return const MapPlaceholder();

    final hasRoute = points.length >= 2;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: points.first, zoom: 13),
      onMapCreated: (c) {
        _controller = c;
        _fitToRoute(points);
      },
      // Gestures off in the embedded preview so the parent list stays scrollable.
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      rotateGesturesEnabled: widget.interactive,
      tiltGesturesEnabled: widget.interactive,
      zoomControlsEnabled: widget.interactive,
      myLocationEnabled: _myLocationAllowed,
      myLocationButtonEnabled: _myLocationAllowed,
      mapToolbarEnabled: false,
      polylines: hasRoute
          ? {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: AppColors.money,
                width: 5,
              ),
            }
          : const {},
      markers: {
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: points.last,
          infoWindow: const InfoWindow(title: 'End'),
        ),
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No route recorded for this trip',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
