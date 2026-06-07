import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auto_trip_detector.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;

    return ListView(
      children: [
        if (user != null) ...[
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.email),
            subtitle: Text(user.isSubscribed ? 'Pro subscriber' : 'Free plan'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Mileage rate'),
            subtitle: Text(
              '${formatMoney(user.mileageRate, user.currency)} per mile · ${user.currency}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editRate(context, state),
          ),
          const Divider(),
          const _AutoTrackingToggle(),
        ],
        const AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'MileWorth',
          applicationVersion: '0.1.0 (Sprint 1)',
          aboutBoxChildren: [
            Text(
              'Deduction figures are estimates only and not tax advice. '
              'Confirm with a qualified accountant.',
            ),
          ],
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sign out', style: TextStyle(color: Colors.red)),
          onTap: state.signOut,
        ),
      ],
    );
  }

  Future<void> _editRate(BuildContext context, AppState state) async {
    final controller =
        TextEditingController(text: state.user?.mileageRate.toString() ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mileage rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The standard rate per mile. It changes yearly and by country, '
              'so set it to match your tax authority.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: 'per mile  ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await state.updateSettings(mileageRate: result);
    }
  }
}

/// Switch for fully-automatic background trip detection (FR-1).
class _AutoTrackingToggle extends StatelessWidget {
  const _AutoTrackingToggle();

  @override
  Widget build(BuildContext context) {
    final detector = context.watch<AutoTripDetector>();
    return SwitchListTile(
      secondary: const Icon(Icons.gps_fixed),
      title: const Text('Automatic tracking'),
      subtitle: const Text(
        'Detect drives and record mileage in the background. '
        'Requires "Allow all the time" location.',
      ),
      value: detector.enabled,
      onChanged: (v) async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await detector.setEnabled(v);
        if (!ok) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Location permission is required for auto tracking'),
          ));
        }
      },
    );
  }
}
