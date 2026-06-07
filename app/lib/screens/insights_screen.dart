import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/category_pie.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<Insights> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().fetchInsights();
  }

  void _reload() {
    setState(() => _future = context.read<AppState>().fetchInsights());
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppState>().user?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: FutureBuilder<Insights>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load insights\n${snap.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            );
          }
          final insights = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Drives by category',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CategoryPie(stats: insights.byCategory),
                  ),
                ),
                const SizedBox(height: 16),
                ...insights.byCategory.map((c) => Card(
                      child: ListTile(
                        leading: Icon(Icons.circle, color: categoryColor(c.category), size: 16),
                        title: Text(_label(c.category)),
                        subtitle: Text('${c.count} trips · ${formatMiles(c.miles)}'),
                        trailing: c.value > 0
                            ? Text(formatMoney(c.value, currency),
                                style: const TextStyle(
                                    color: AppColors.money, fontWeight: FontWeight.w600))
                            : null,
                      ),
                    )),
                const SizedBox(height: 24),
                Text('Top locations', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (insights.topLocations.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Name your frequent stops (Home, Job Site, …) to see your '
                        'most-visited locations ranked here.',
                      ),
                    ),
                  )
                else
                  ...insights.topLocations.map((l) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(l.name),
                          subtitle: Text('${l.count} trips'),
                          trailing: l.value > 0
                              ? Text(formatMoney(l.value, currency))
                              : null,
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _label(String c) =>
      c.isEmpty ? c : '${c[0].toUpperCase()}${c.substring(1)}';
}
