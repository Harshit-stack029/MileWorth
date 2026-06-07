import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Manual trip entry (FR-6). Until GPS auto-tracking lands, this is how trips
/// get created.
class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distance = TextEditingController();
  DateTime _start = DateTime.now().subtract(const Duration(minutes: 30));
  DateTime _end = DateTime.now();
  String _category = 'business';
  bool _busy = false;

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = combined;
      } else {
        _end = combined;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('End time must be after start time')));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().addTrip({
        'startTime': _start.toUtc().toIso8601String(),
        'endTime': _end.toUtc().toIso8601String(),
        'distance': double.parse(_distance.text),
        'category': _category,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add trip')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _distance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Distance (miles)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.route),
              ),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d <= 0) return 'Enter a distance greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey), borderRadius: BorderRadius.all(Radius.circular(4))),
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start'),
              subtitle: Text(_start.toLocal().toString().substring(0, 16)),
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey), borderRadius: BorderRadius.all(Radius.circular(4))),
              leading: const Icon(Icons.stop),
              title: const Text('End'),
              subtitle: Text(_end.toLocal().toString().substring(0, 16)),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 24),
            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'business', label: Text('Business'), icon: Icon(Icons.work)),
                ButtonSegment(value: 'personal', label: Text('Personal'), icon: Icon(Icons.home)),
              ],
              selected: {_category},
              onSelectionChanged: (sel) => setState(() => _category = sel.first),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save trip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
