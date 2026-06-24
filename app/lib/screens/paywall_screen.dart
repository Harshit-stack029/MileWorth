import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Pro upgrade screen, shown at peak perceived value (exporting a report or
/// viewing the deduction total).
///
/// Uses the real [SubscriptionService] (Google Play / App Store) when the store
/// is available. On emulators or before the Play product is configured, it
/// falls back to the backend's dev activation so the flow stays testable.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static const monthlyProductId = SubscriptionService.monthlyProductId;

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
    final messenger = ScaffoldMessenger.of(context);
    final billing = context.read<SubscriptionService>();
    try {
      if (billing.available && billing.monthly != null) {
        // Real store flow: the purchase stream drives verification; we pop when
        // AppState reports the account is subscribed (see build()'s listener).
        final started = await billing.buyMonthly();
        if (!started) {
          messenger.showSnackBar(
              const SnackBar(content: Text('Could not start the purchase')));
        }
      } else {
        // Dev fallback (store unavailable): activate via backend dev path.
        final ok = await context.read<AppState>().verifySubscription(
              purchaseToken: 'dev-placeholder-token',
              productId: PaywallScreen.monthlyProductId,
            );
        if (ok && mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<SubscriptionService>();
    final subscribed = context.select<AppState, bool>(
      (s) => s.user?.isSubscribed ?? false,
    );

    // Once the (async) purchase verifies, close the paywall as a success.
    if (subscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      });
    }

    final pending = _busy || billing.purchasePending;
    final priceLabel =
        billing.monthlyPrice != null ? 'Start Pro — ${billing.monthlyPrice}/mo' : 'Start Pro';

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
            onPressed: pending ? null : _subscribe,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: pending
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(priceLabel),
            ),
          ),
          TextButton(
            onPressed: pending
                ? null
                : () async {
                    await billing.restore();
                    // Reconcile with the server so a restored/renewed entitlement
                    // (or a lapse) is reflected even if no purchase event fires.
                    if (context.mounted) {
                      await context.read<AppState>().refreshSubscription();
                    }
                  },
            child: const Text('Restore purchase'),
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
