import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat wrapper for the VIP Pass subscription (docs/MONETIZATION.md
/// SS2.1, SS3). A managed SaaS, not a server of ours — see
/// docs/TECHNICAL_ARCHITECTURE.md SS1.
///
/// [apiKey] is a placeholder until a real RevenueCat project exists
/// (app.revenuecat.com) with its own App Store Connect/Play Console
/// products connected — neither exists yet per docs/RELEASE_CHECKLIST.md.
/// [configure] is safe to call with the placeholder key: it will "succeed"
/// locally but every network call after it fails, caught the same way as
/// [CloudAuthService] — this class degrades to "not entitled, no offerings"
/// rather than throwing.
class PurchaseService extends ChangeNotifier {
  static const _placeholderApiKey = 'revenuecat_placeholder_api_key';
  static const vipEntitlementId = 'vip_pass';

  bool _configured = false;
  bool _vipActive = false;
  Offerings? _offerings;

  bool get isConfigured => _configured;
  bool get isVip => _vipActive;
  Offerings? get offerings => _offerings;

  Future<void> initialize() async {
    if (_placeholderApiKey.startsWith('revenuecat_placeholder')) {
      // Do not even attempt to configure against a key we know is fake —
      // Purchases.configure with a bad key can surface a native-side error
      // dialog on some platforms, which a silent placeholder shouldn't do.
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(_placeholderApiKey));
      _configured = true;
      await refresh();
    } catch (_) {
      _configured = false;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!_configured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _vipActive = info.entitlements.active.containsKey(vipEntitlementId);
      _offerings = await Purchases.getOfferings();
    } catch (_) {
      // Keep the last-known state rather than flipping entitlement off on
      // a transient network failure.
    }
    notifyListeners();
  }

  /// Returns true on a completed purchase. False (never throws) on
  /// cancellation or failure — callers show a plain "purchase didn't go
  /// through" message rather than branching on exception types.
  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      final result = await Purchases.purchasePackage(package);
      _vipActive = result.entitlements.active.containsKey(vipEntitlementId);
      notifyListeners();
      return _vipActive;
    } catch (_) {
      // Covers user cancellation and any purchase/network failure alike —
      // callers show one plain "didn't go through" message either way.
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      _vipActive = info.entitlements.active.containsKey(vipEntitlementId);
      notifyListeners();
      return _vipActive;
    } catch (_) {
      return false;
    }
  }
}
