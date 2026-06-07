import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Pro upgrade screen, shown at peak perceived value (exporting a report or
/// viewing the deduction total).
///
/// Real Google Play Billing uses the `in_app_purchase` plugin to launch the
/// purchase flow and obtain a purchaseToken, which the backend verifies. That
/// flow needs a Play Console product + signed build, so this screen calls the
/// backend's verify endpoint with a placeholder token (the backend only honours
/// it in non-production). See SubscriptionService for the wiring point.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static const monthlyProductId = 'mileworth_pro_monthly';

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;

  static const _perks = [
    'Unlimited automatic trip tracking',
    'Accountant-ready PDF & CSV reports',
    'Expense + receipt capture',
    'Category insights & top locations',
  ];

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      // TODO: replace with in_app_purchase flow -> real purchaseToken.
      await context.read<AppState>().verifySubscription(
            purchaseToken: 'dev-placeholder-token',
            productId: PaywallScreen.monthlyProductId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Welcome to MileWorth Pro!')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MileWorth Pro')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.workspace_premium, size: 72, color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Unlock the full deduction',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 24),
          ..._perks.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.money, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p)),
                  ],
                ),
              )),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _subscribe,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _busy
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Start Pro'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Billed through Google Play. Cancel anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
