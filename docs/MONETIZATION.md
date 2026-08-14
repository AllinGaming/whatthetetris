# Monetization Design

**Status:** Only the `vip_pass` row of §3 is implemented in code — RevenueCat entitlement wiring, `PurchaseService`, `PaywallScreen` (see `docs/TECHNICAL_ARCHITECTURE.md`) — checking a single subscription entitlement. Individual cosmetic packs and the Supporter Pack (§3's other two rows) are design-only: no owned-items list, no per-item purchase flow, and no code path for either exists yet. Nothing here is active regardless: no real RevenueCat products exist, no pricing is committed, and the paywall shows an honest "not available yet" state until real App Store/Play Console listings are connected.
**Companion docs:** [GDD.md](GDD.md) · [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md)

## 1. North Star

Money buys **cosmetics, convenience, and support** — never a gameplay advantage. A free player and a paying player face the identical speed curve, the identical piece bag, the identical scoring rules, and the identical leaderboard eligibility. This isn't just an ethical stance — it's a positioning decision: this game's audience (puzzle-game players who came from Tetris) is unusually quick to detect and resent pay-to-win, and a fair model is a genuine differentiator worth advertising in store copy.

Concretely, ruled **out** entirely: purchasable score multipliers, purchasable slower curves, purchasable extra lives/continues that a free player can't also earn some other way, loot boxes/gacha of any kind, forced interstitial ads, and streak-freeze-style purchases that monetize anxiety.

## 2. Revenue Surfaces

### 2.1 VIP Pass (subscription) — primary recurring revenue
| | |
|---|---|
| **Grants** | Full cosmetic theme library (all past + future themes, see `GDD.md` §6.5) · exclusive rotating monthly theme · cloud backup priority (still free for everyone, but VIP gets faster/immediate sync vs. a longer debounce for free tier) · exclusive leaderboard badge/frame (cosmetic marker only, no score/ranking effect) · 1-week early access to new modes |
| **Does not grant** | Any change to speed, scoring, piece bag, or continues |
| **Tiers** | Monthly and Annual (annual at a meaningful discount to reward committed players) |
| **Trial** | A short free trial (e.g. 3–7 days) so players can see the cosmetic value before paying — standard, low-risk, and required by both stores to be clearly disclosed |

### 2.2 One-time cosmetic packs
Individual theme packs sold a la carte for players who want one specific look without subscribing. Validates whether cosmetics have standalone demand (tracked via the "cosmetic pack attach rate" metric in `GDD.md` §11) independent of the subscription's other perks.

### 2.3 Supporter Pack (one-time)
A single "buy the devs a coffee" purchase at a low price point, granting a small cosmetic badge and nothing else. Exists purely for players who want to support the game without wanting any subscription commitment — common in indie puzzle games and low-effort to build once IAP plumbing exists.

### 2.4 Ads — recommendation: none at launch, optional rewarded-only later
Given the fair-monetization pillar and that this game has no forced-continue mechanic to hang an ad on honestly, the recommendation is **ship with no ads at all**. If ad revenue is revisited later, the only acceptable form is a strictly **opt-in rewarded video** offering a single continue after topping out in a marathon mode (Classic/Arcade) — never in Sprint/Ultra/Daily Challenge (would trivialize competitive scores) — and never an interstitial. This is explicitly a "later, if ever" item, not part of the initial monetization launch.

## 3. Entitlement Mapping (RevenueCat)

| RevenueCat Entitlement | Unlocks |
|---|---|
| `vip_pass` | Full theme library, exclusive monthly theme, priority sync, leaderboard badge, early access flag |
| *(none — direct consumable, not yet built)* | Individual cosmetic pack purchases — designed to be checked against a per-user owned-items list in Firestore rather than an entitlement, once built |
| *(none — non-consumable, no unlock, not yet built)* | Supporter Pack — purely a badge flag, once built |

Entitlement state is mirrored server-side into `users/{uid}/entitlements` by a Cloud Function subscribed to RevenueCat webhooks (see `TECHNICAL_ARCHITECTURE.md` §5) — the client **checks Firestore, not RevenueCat directly, for gating**, so a jailbroken/tampered client can't spoof entitlement locally.

## 4. Pricing — placeholder bands, not commitments

These are industry-typical ranges for a cosmetic-only puzzle game subscription, to be refined against actual store guidance and competitor pricing before launch — **not final numbers**:

- VIP Pass Monthly: ~$2.99–4.99
- VIP Pass Annual: ~$19.99–29.99 (roughly a 40–50% discount vs. monthly, standard for the category)
- Individual theme pack: ~$0.99–1.99
- Supporter Pack: ~$2.99–4.99, single tier

## 5. Store Compliance Checklist (subscription-specific, additive to `RELEASE_CHECKLIST.md`)

- [ ] Clear in-app disclosure of price, billing period, and auto-renewal terms before purchase confirmation (both stores require this verbatim).
- [ ] "Restore Purchases" button reachable from the same screen as any paywall.
- [ ] Trial-to-paid conversion disclosed clearly, with a visible reminder before the trial converts if the store guidelines require it (Apple does for some trial types).
- [ ] Subscription management deep link (Settings → "Manage Subscription" → opens the platform's native subscription management screen).
- [ ] Sandbox-tested full lifecycle (purchase, renew, cancel, refund, restore) via `TECHNICAL_ARCHITECTURE.md` §8 before any production entitlement gating ships.
- [ ] Privacy policy (post-rewrite, see `TECHNICAL_ARCHITECTURE.md` §7) explicitly discloses that purchases are processed by the platform store / RevenueCat.

## 6. What Ships When

Monetization does not ship until the game itself (Phase 0–2 in `ROADMAP.md`) is genuinely good — a subscription paywall in front of a two-mode, silent game is not a viable launch. See `ROADMAP.md` for exact sequencing.
