import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Drives Google Play / App Store subscription purchases (FR monetization).
///
/// Flow: query the product -> launch the store purchase sheet -> listen on the
/// purchase stream -> on a successful purchase, hand the platform verification
/// token to [onVerify] (which calls the backend, where it is verified with
/// Google before Pro is granted) -> complete the purchase.
///
/// Requires the product to be configured in Play Console and a signed build;
/// on emulators / unconfigured stores [available] stays false and the UI can
/// fall back to the dev path.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService({required this.onVerify, InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  /// Verify the purchase server-side. Returns true when Pro was granted.
  final Future<bool> Function(String purchaseToken, String productId) onVerify;

  static const monthlyProductId = 'mileworth_pro_monthly';
  static const _productIds = {monthlyProductId};

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool available = false;
  bool purchasePending = false;
  String? lastError;
  ProductDetails? monthly;

  /// The store-localized price string (e.g. "$6.99"), or null if unavailable.
  String? get monthlyPrice => monthly?.price;

  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) {
      notifyListeners();
      return;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        lastError = e.toString();
        notifyListeners();
      },
    );
    final response = await _iap.queryProductDetails(_productIds);
    if (response.productDetails.isNotEmpty) {
      monthly = response.productDetails.first;
    }
    notifyListeners();
  }

  /// Launch the store purchase sheet. Returns false if it couldn't start.
  Future<bool> buyMonthly() async {
    final product = monthly;
    if (!available || product == null) return false;
    purchasePending = true;
    lastError = null;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    // Subscriptions are bought as non-consumables in in_app_purchase.
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          notifyListeners();
          break;
        case PurchaseStatus.error:
          purchasePending = false;
          lastError = p.error?.message ?? 'Purchase failed';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Server verifies the token before granting Pro.
          try {
            final granted = await onVerify(
                p.verificationData.serverVerificationData, p.productID);
            if (!granted) {
              lastError = 'We could not verify your purchase. Try Restore, or '
                  'contact support if you were charged.';
            }
          } catch (e) {
            lastError = e.toString();
          }
          purchasePending = false;
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          notifyListeners();
          break;
      }
      // Always acknowledge/complete, or Google auto-refunds after 3 days.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
