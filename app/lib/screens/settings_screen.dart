import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auto_trip_detector.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../utils/location_feedback.dart';
import '../widgets/background_location_disclosure.dart';

/// Public privacy-policy page. Must match the URL entered in Play Console.
const String kPrivacyPolicyUrl =
    'https://github.com/Harshit-stack029/MileWorth/blob/main/docs/PRIVACY.md';

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
          const Divider(),
        ],
        // Play's User Data policy requires the privacy policy to be reachable
        // from inside the app, not only from the store listing.
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final ok = await launchUrl(Uri.parse(kPrivacyPolicyUrl),
                mode: LaunchMode.externalApplication);
            if (!ok) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Could not open the privacy policy'),
              ));
            }
          },
        ),
        const AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'MileWorth',
          applicationVersion: '1.0.0',
          aboutBoxChildren: [
            Text(
              'Your trips and expenses are stored only on this device. '
              'Deduction figures are estimates only and not tax advice — '
              'confirm with a qualified accountant.',
            ),
          ],
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
        // Play policy: show the background-location disclosure right before
        // the permission request. Skip it when "Allow all the time" is
        // already granted, since no prompt will follow.
        if (v && !await detector.hasBackgroundPermission()) {
          if (!context.mounted) return;
          if (!await showBackgroundLocationDisclosure(context)) return;
        }
        final access = await detector.setEnabled(v);
        // "Allow all the time" cannot be granted from a prompt on Android 11+,
        // so the message carries a button into the right settings page.
        showLocationAccessMessage(messenger, access);
      },
    );
  }
}
