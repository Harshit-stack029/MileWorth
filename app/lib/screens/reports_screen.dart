import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range;
  Map<String, dynamic>? _summary;
  bool _loadingSummary = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummary());
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final s = await context.read<AppState>().reportSummary(_range.start, _range.end);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _loadSummary();
    }
  }

  Future<void> _export(String format) async {
    final state = context.read<AppState>();
    setState(() => _exporting = true);
    try {
      final bytes = await state.downloadReport(
        format: format,
        from: _range.start,
        to: _range.end,
      );
      final dir = await getTemporaryDirectory();
      final name =
          'mileworth-${_d(_range.start)}_to_${_d(_range.end)}.$format';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MileWorth report',
        text: 'My mileage report from MileWorth.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppState>().user?.currency ?? 'USD';
    final s = _summary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Date range'),
            subtitle: Text('${formatDate(_range.start)} – ${formatDate(_range.end)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickRange,
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingSummary)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (s != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _row('Trips', '${s['totalTrips']} (${s['businessTrips']} business)'),
                  _row('Business miles', formatMiles((s['businessMiles'] as num).toDouble())),
                  _row('Expenses', formatMoney((s['totalExpenses'] as num).toDouble(), currency)),
                  const Divider(),
                  _row(
                    'Estimated deduction',
                    formatMoney((s['totalDeductions'] as num).toDouble(), currency),
                    highlight: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export('csv'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Share CSV report'),
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Estimates only — not tax advice. Confirm with your accountant.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: highlight ? AppColors.money : null,
                fontSize: highlight ? 16 : 14,
              )),
        ],
      ),
    );
  }
}
