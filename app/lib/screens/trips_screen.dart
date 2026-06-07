import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.trips.isEmpty) {
      return RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.directions_car_outlined,
                size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Center(
              child: Text('No trips yet',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Add one with the + button to get started.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: state.trips.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _TripTile(trip: state.trips[i]),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Trip trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final currency = state.user?.currency ?? 'USD';
    final color = categoryColor(trip.category);

    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.navigation, color: color, size: 20),
        ),
        title: Text(formatMiles(trip.distance),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(formatDateTime(trip.startTime)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CategoryBadge(category: trip.category),
            if (trip.deductionValue > 0) ...[
              const SizedBox(height: 4),
              Text(formatMoney(trip.deductionValue, currency),
                  style: const TextStyle(
                      color: AppColors.money,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ],
        ),
        onLongPress: () => _showClassifySheet(context, state),
      ),
    );
  }

  void _showClassifySheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Classify this trip',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final c in const ['business', 'personal', 'uncategorized'])
              ListTile(
                leading: Icon(Icons.circle, color: categoryColor(c), size: 16),
                title: Text(_label(c)),
                trailing: trip.category == c ? const Icon(Icons.check) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await state.setCategory(trip, c);
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _label(String c) => '${c[0].toUpperCase()}${c.substring(1)}';

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_label(category),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
