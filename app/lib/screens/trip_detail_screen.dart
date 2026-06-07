import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

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
          // Map placeholder — real route polyline rendered in Sprint 2.
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('Route map — coming with GPS tracking',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
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
