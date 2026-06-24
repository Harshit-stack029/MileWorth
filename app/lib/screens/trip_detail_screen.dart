import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/polyline.dart';

class TripDetailScreen extends StatelessWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trip = state.trips.where((t) => t.id == tripId).firstOrNull;

    if (trip == null) {
      return const Scaffold(body: Center(child: Text('Trip not found')));
    }
    final currency = state.user?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, state, trip),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 180, child: _TripRouteMap(trip: trip)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(formatMiles(trip.distance),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          if (trip.deductionValue > 0)
            Center(
              child: Text(
                '${formatMoney(trip.deductionValue, currency)} deduction',
                style: const TextStyle(
                    color: AppColors.money, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 24),
          _DetailRow(icon: Icons.play_arrow, label: 'Start', value: formatDateTime(trip.startTime)),
          _DetailRow(icon: Icons.stop, label: 'End', value: formatDateTime(trip.endTime)),
          _DetailRow(icon: Icons.timer_outlined, label: 'Duration', value: formatDuration(trip.duration)),
          const Divider(height: 32),
          Text('Classification', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'business', label: Text('Business'), icon: Icon(Icons.work)),
              ButtonSegment(value: 'personal', label: Text('Personal'), icon: Icon(Icons.home)),
              ButtonSegment(value: 'uncategorized', label: Text('—')),
            ],
            selected: {trip.category},
            onSelectionChanged: (sel) => state.setCategory(trip, sel.first),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppState state, Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await state.deleteTrip(trip);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

/// Renders the recorded trip route on a Google map: the decoded polyline plus
/// start/end markers, with the camera fitted to the route. Falls back to a
/// straight start→end line when only endpoints are known, and to a placeholder
/// when the trip has no coordinates at all (e.g. a manually-entered trip).
class _TripRouteMap extends StatefulWidget {
  final Trip trip;
  const _TripRouteMap({required this.trip});

  @override
  State<_TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<_TripRouteMap> {
  GoogleMapController? _controller;

  /// The ordered points that make up the route. Prefers the full decoded
  /// polyline; otherwise uses whatever endpoints exist.
  List<LatLng> get _points {
    final encoded = widget.trip.routePolyline;
    if (encoded != null && encoded.isNotEmpty) {
      final decoded = decodePolyline(encoded);
      if (decoded.length >= 2) {
        return [for (final p in decoded) LatLng(p.lat, p.lng)];
      }
    }
    final t = widget.trip;
    final pts = <LatLng>[];
    if (t.startLat != null && t.startLng != null) {
      pts.add(LatLng(t.startLat!, t.startLng!));
    }
    if (t.endLat != null && t.endLng != null) {
      pts.add(LatLng(t.endLat!, t.endLng!));
    }
    return pts;
  }

  LatLngBounds _boundsOf(List<LatLng> points) {
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
      controller.moveCamera(CameraUpdate.newLatLngBounds(_boundsOf(points), 32));
    } catch (_) {
      controller.moveCamera(CameraUpdate.newLatLngZoom(points.first, 13));
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points.isEmpty) return const _MapPlaceholder();

    final hasRoute = points.length >= 2;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: points.first, zoom: 13),
      onMapCreated: (c) {
        _controller = c;
        _fitToRoute(points);
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      liteModeEnabled: true, // static, non-interactive map is plenty here
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
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

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
