import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/trip_route_map.dart';
import 'trip_map_screen.dart';

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
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(height: 180, child: TripRouteMap(trip: trip)),
              ),
              // Tap anywhere on the preview to open the interactive fullscreen
              // map. The preview itself has gestures disabled so it doesn't
              // swallow this list's scroll.
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: tripRoutePoints(trip).isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TripMapScreen(trip: trip),
                              ),
                            ),
                  ),
                ),
              ),
              if (tripRoutePoints(trip).isNotEmpty)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Chip(
                    avatar: const Icon(Icons.fullscreen, size: 18),
                    label: const Text('Expand'),
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ),
          if (hasNavigableDestination(trip)) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => showNavigateSheet(context, trip),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigate'),
            ),
          ],
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
