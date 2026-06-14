import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/trip_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'home_shell.dart';
import 'insights_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.summary;
    final currency = state.user?.currency ?? 'USD';

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.user != null && !state.user!.emailVerified) ...[
            const _EmailVerifyBanner(),
            const SizedBox(height: 16),
          ],
          if (state.pendingSync > 0) ...[
            Card(
              color: AppColors.personal.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.cloud_off, color: AppColors.personal),
                title: Text('${state.pendingSync} trip(s) waiting to sync'),
                subtitle: const Text('Will upload automatically when back online'),
                trailing: TextButton(
                  onPressed: state.refresh,
                  child: const Text('Retry'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _GpsStatusBanner(),
          const SizedBox(height: 16),
          // Hero deduction value — the headline number (paywall trigger point).
          Card(
            color: AppColors.money.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text('Estimated tax deductions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(s.totalDeductions, currency),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.money,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text('Estimate only — confirm with your accountant.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.route,
                  label: 'Miles tracked',
                  value: formatMiles(s.totalMiles),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.work_outline,
                  label: 'Work drives',
                  value: '${s.businessTrips}',
                  color: AppColors.business,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (s.uncategorizedTrips > 0)
            Card(
              color: AppColors.personal.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.personal),
                title: Text('${s.uncategorizedTrips} trips need classifying'),
                subtitle: const Text('Tap to review so you don\'t miss a deduction'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => HomeShell.goToTab(context, 1), // jump to Trips
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.pie_chart_outline, color: AppColors.primary),
              title: const Text('Insights'),
              subtitle: const Text('See your drives by category and top locations'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? AppColors.primary),
            const SizedBox(height: 12),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Prompts the user to confirm their email. Soft-gate (dismissible) so it never
/// strands a user — verification improves account recovery & deliverability but
/// isn't required to use the app.
class _EmailVerifyBanner extends StatefulWidget {
  const _EmailVerifyBanner();

  @override
  State<_EmailVerifyBanner> createState() => _EmailVerifyBannerState();
}

class _EmailVerifyBannerState extends State<_EmailVerifyBanner> {
  bool _busy = false;

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final devToken = await state.resendVerification();
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Verification email sent — check your inbox.')));
      if (devToken != null) await _enterCode(prefill: devToken);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterCode({String? prefill}) async {
    final controller = TextEditingController(text: prefill ?? '');
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter verification code'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          autocorrect: false,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Paste the code from your email',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Verify')),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.trim().isEmpty) return;
    try {
      await state.verifyEmail(token);
      messenger.showSnackBar(const SnackBar(content: Text('Email verified ✓')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.gold.withValues(alpha: 0.15),
      child: ListTile(
        leading: const Icon(Icons.mark_email_unread_outlined, color: AppColors.personal),
        title: const Text('Verify your email'),
        subtitle: const Text('Confirm your email to secure account recovery.'),
        trailing: _busy
            ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: _resend, child: const Text('Resend')),
        onTap: _busy ? null : () => _enterCode(),
      ),
    );
  }
}

/// Live "GPS Tracking" control. Foreground manual start/stop is wired now;
/// automatic background detection is the remaining Sprint 2 work.
class _GpsStatusBanner extends StatelessWidget {
  const _GpsStatusBanner();

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TripTracker>();
    final active = tracker.tracking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? AppColors.business.withValues(alpha: 0.12)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.gps_fixed : Icons.gps_off,
              color: active ? AppColors.business : Colors.grey.shade500, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(active
                ? 'Tracking · ${formatMiles(tracker.distanceMiles)}'
                : 'GPS tracking off'),
          ),
          FilledButton.tonal(
            onPressed: () => _toggle(context, tracker),
            child: Text(active ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, TripTracker tracker) async {
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    if (tracker.tracking) {
      final payload = tracker.stop();
      if (payload == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Drive too short to save')));
        return;
      }
      await appState.addTrip(payload);
      messenger.showSnackBar(const SnackBar(content: Text('Trip saved')));
    } else {
      final ok = await tracker.start();
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Location permission needed to track drives')));
      }
    }
  }
}
