import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../utils/navigation_launcher.dart';
import '../widgets/trip_route_map.dart';

/// Fullscreen, fully interactive view of a trip's route, with a shortcut to
/// navigate to either end of it.
class TripMapScreen extends StatelessWidget {
  final Trip trip;
  const TripMapScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route')),
      body: TripRouteMap(trip: trip, interactive: true),
      floatingActionButton: hasNavigableDestination(trip)
          ? FloatingActionButton.extended(
              onPressed: () => showNavigateSheet(context, trip),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigate'),
            )
          : null,
    );
  }
}

/// True when at least one endpoint is known, so "Navigate" has somewhere to go.
bool hasNavigableDestination(Trip trip) =>
    (trip.startLat != null && trip.startLng != null) ||
    (trip.endLat != null && trip.endLng != null);

/// Offers the endpoints worth navigating to. Opens directions straight away
/// when only one endpoint exists, rather than showing a one-item menu.
Future<void> showNavigateSheet(BuildContext context, Trip trip) async {
  final hasStart = trip.startLat != null && trip.startLng != null;
  final hasEnd = trip.endLat != null && trip.endLng != null;
  final messenger = ScaffoldMessenger.of(context);

  Future<void> go(double lat, double lng) async {
    final launched = await launchDirections(lat, lng);
    if (!launched) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No maps app available to show directions'),
      ));
    }
  }

  if (hasEnd && !hasStart) return go(trip.endLat!, trip.endLng!);
  if (hasStart && !hasEnd) return go(trip.startLat!, trip.startLng!);
  if (!hasStart && !hasEnd) return;

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Navigate to', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Destination'),
            subtitle: const Text('Where this drive ended'),
            onTap: () {
              Navigator.pop(sheetContext);
              go(trip.endLat!, trip.endLng!);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow_outlined),
            title: const Text('Start point'),
            subtitle: const Text('Where this drive began'),
            onTap: () {
              Navigator.pop(sheetContext);
              go(trip.startLat!, trip.startLng!);
            },
          ),
        ],
      ),
    ),
  );
}
