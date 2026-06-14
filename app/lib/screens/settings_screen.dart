import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auto_trip_detector.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'paywall_screen.dart';

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
          if (!user.isSubscribed)
            Card(
              color: AppColors.primary.withValues(alpha: 0.08),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.workspace_premium, color: AppColors.primary),
                title: const Text('Upgrade to Pro'),
                subtitle: const Text('Unlimited tracking, reports, insights'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                ),
              ),
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
          SwitchListTile(
            secondary: const Icon(Icons.weekend_outlined),
            title: const Text('Weekends are personal'),
            subtitle: const Text(
              'Automatically classify new weekend drives as personal.',
            ),
            value: user.classifyWeekendsAsPersonal,
            onChanged: (v) =>
                state.updateSettings(classifyWeekendsAsPersonal: v),
          ),
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
        if (user != null)
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete account',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text(
              'Permanently erase your account, trips, expenses and receipts.',
            ),
            onTap: () => _confirmDeleteAccount(context, state),
          ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppState state) async {
    final confirm = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and all of your trips, '
              'expenses and receipts. This cannot be undone.\n\n'
              'Type DELETE to confirm.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirm,
              autocorrect: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'DELETE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: confirm,
            builder: (_, value, _) => FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: value.text.trim().toUpperCase() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Delete forever'),
            ),
          ),
        ],
      ),
    );
    confirm.dispose();
    if (ok != true) return;
    try {
      await state.deleteAccount();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
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
    controller.dispose();
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
