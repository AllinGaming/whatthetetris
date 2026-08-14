import 'package:flutter/material.dart';

import '../services/purchase_service.dart';
import 'widgets/neon_text.dart';

/// VIP Pass paywall (docs/MONETIZATION.md SS2.1) — cosmetics, priority
/// sync, and a leaderboard badge, never a gameplay advantage. Renders a
/// clear "not available yet" state rather than a blank/broken screen when
/// [PurchaseService] isn't configured against a real RevenueCat project.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.purchases});

  final PurchaseService purchases;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: purchases,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            'VIP Pass',
            style: TextStyle(shadows: neonShadows(accent, intensity: 0.6)),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: purchases.isVip
                    ? _VipActiveCard(accent: accent)
                    : purchases.isConfigured
                    ? _OfferingsList(purchases: purchases, accent: accent)
                    : const _NotAvailableYet(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotAvailableYet extends StatelessWidget {
  const _NotAvailableYet();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.star_border, size: 48, color: Colors.white38),
        SizedBox(height: 16),
        Text(
          "VIP Pass isn't available yet.",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          'The whole game is free to play in the meantime — this screen '
          'will come alive once subscriptions are configured.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _VipActiveCard extends StatelessWidget {
  const _VipActiveCard({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 48, color: accent),
        const SizedBox(height: 16),
        const Text(
          "You're a VIP!",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Full theme library, exclusive rotating theme, priority cloud '
          'sync, and a leaderboard badge — thank you for supporting the '
          'game.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _OfferingsList extends StatelessWidget {
  const _OfferingsList({required this.purchases, required this.accent});

  final PurchaseService purchases;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final packages = purchases.offerings?.current?.availablePackages ?? [];
    if (packages.isEmpty) {
      return const _NotAvailableYet();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cosmetics, priority sync, and a leaderboard badge — never a '
          'gameplay advantage.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        for (final package in packages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton(
              onPressed: () async {
                final ok = await purchases.purchase(package);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Welcome to VIP!'
                            : "That didn't go through — try again anytime.",
                      ),
                    ),
                  );
                }
              },
              child: Text(
                '${package.storeProduct.title} — '
                '${package.storeProduct.priceString}',
              ),
            ),
          ),
        TextButton(
          onPressed: () => purchases.restorePurchases(),
          child: const Text('Restore purchases'),
        ),
      ],
    );
  }
}
