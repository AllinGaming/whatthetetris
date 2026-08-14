# Technical Architecture — Live Services

**Status:** Implemented and tested, but inert — every service described below exists in code (`lib/services/cloud_auth_service.dart`, `cloud_backup_service.dart`, `analytics_service.dart`, `purchase_service.dart`, `leaderboard_service.dart`, `functions/src/index.ts`, `firestore.rules`) and degrades safely against the placeholder config in `lib/firebase_options.dart`. Nothing here can actually reach a network until a real Firebase project and RevenueCat account exist — see `docs/ROADMAP.md` Phase 3/4 for exactly what's done vs. still open.
**Scope:** Analytics, anonymous accounts + cloud backup, RevenueCat subscriptions, and the store-publishing implications of all three.
**Companion docs:** [GDD.md](GDD.md) · [MONETIZATION.md](MONETIZATION.md) · [ROADMAP.md](ROADMAP.md)

**This is a serverless architecture, by deliberate choice.** Nowhere in this document does anyone provision, patch, or scale a server. Firebase is a Backend-as-a-Service — Google runs and scales it; the app talks to it directly over the Firebase SDKs. RevenueCat is a managed SaaS for subscription/entitlement handling — no server of ours sits in that path either. The one piece of custom logic (§4's score-validation function) is itself a *serverless function*: a small piece of code Firebase runs on demand and bills per-invocation, not a process anyone hosts, restarts, or monitors uptime for. "Backend" in this doc means "a managed cloud service the app calls," never "infrastructure we operate."

This is a genuinely greenfield integration: the survey of the current codebase found zero existing analytics, auth, backend, or IAP packages (`pubspec.yaml` has only `shared_preferences` beyond Flutter itself), and `PRIVACY.md` currently makes an explicit promise of no accounts/ads/analytics/server calls. Every recommendation below assumes that promise gets **honestly rewritten**, not quietly broken — see §7.

## 1. Platform choice: Firebase

Chosen over Supabase for this project because: native, first-party RevenueCat integration (no custom webhook glue required for the common path), a free tier that comfortably covers this game's expected scale pre-revenue, and one vendor covering auth + database + analytics + crash reporting + remote config + app check, which minimizes the number of new systems a two-person-or-solo team has to operate. Both Firebase and RevenueCat are managed services with no self-hosted component — the "operate" here means configuring dashboards and writing client/Cloud-Function code, not running servers.

**Dependencies** — all added to `pubspec.yaml` already:

| Package | Purpose | Status |
|---|---|---|
| `firebase_core` | Required bootstrap for all Firebase packages | Added |
| `firebase_auth` | Anonymous sign-in + Apple/Google linking | Added, wired (`cloud_auth_service.dart`) |
| `cloud_firestore` | Save backup, stats, leaderboards | Added, wired (`cloud_backup_service.dart`) |
| `firebase_analytics` | Event tracking | Added, wired (`analytics_service.dart`) |
| `firebase_crashlytics` | Crash/error reporting | Added, wired to `FlutterError.onError`/`PlatformDispatcher.instance.onError` in `main.dart` (guarded off on web, which has no Crashlytics SDK) |
| `firebase_remote_config` | Live-tunable curves/economy without a release | Not added — still optional, add when actually needed |
| `firebase_app_check` | Anti-abuse for Firestore/Cloud Function writes | Not added — add before production traffic, not before |
| `cloud_functions` (client SDK) | Calling `submitScore` from the app | Added, wired (`leaderboard_service.dart`, called from `game_screen.dart._endGame`) |
| `google_sign_in` | Account linking (Android + iOS) | Added, wired |
| `sign_in_with_apple` | Account linking (iOS) — **required alongside Google Sign-In on iOS**, see §6 | Added, wired |
| `purchases_flutter` | RevenueCat SDK | Added, wired (`purchase_service.dart`) |

All of the above compiles and passes `flutter analyze`/`flutter test`/release web build against the placeholder config in `lib/firebase_options.dart` — see `test/live_services_test.dart` for the "degrades to a safe no-op" contract every one of these services follows.

## 2. Environments

Two Firebase projects: `whatthetetris-dev` and `whatthetetris-prod`. Use Flutter flavors (`dev`/`prod`) so debug builds never write to production Firestore/Analytics, and CI can run against `dev` safely. RevenueCat mirrors this with separate dev/prod API keys per project. `android/key.properties` (already scaffolded, per `docs/RELEASE_CHECKLIST.md`) and the two `google-services.json` / `GoogleService-Info.plist` pairs are the only new secrets — all go in the existing "approved secret manager," never committed.

## 3. Identity: anonymous-first accounts

**Principle: nobody is ever forced to create an account or see a sign-in screen to play.**

1. **First launch:** silent `FirebaseAuth.instance.signInAnonymously()` in the background — no UI, no interruption. This UID becomes the backup/leaderboard identity from minute one.
2. **Local-first reads/writes stay authoritative.** `shared_preferences` continues to be the source of truth for instant, offline-safe reads (best score, settings). Firestore is a *backup*, not the primary store — the game must be fully playable with zero network connectivity, exactly as it is today.
3. **Sync triggers:** on game-over, on app background/pause, and on a debounce timer (e.g. every 5 minutes during a long Zen/Arcade session) — push local state to `users/{uid}` if it's newer than the last synced snapshot. Conflict rule: **highest score wins per field**, never a blind overwrite, so a stale device can never erase a better score.
4. **Optional linking (not required):** Settings screen offers "Back up my progress" → links the anonymous credential to Sign in with Apple or Google (`linkWithCredential`). This upgrades the *same* UID rather than creating a new account, so no data migration is needed on link — only on **restore to a new device** (§3.5).
5. **Restore on a new/reinstalled device:** app signs in anonymously (new UID) as normal, then a clearly-labeled "Restore progress" button prompts Apple/Google sign-in, looks up whether that provider credential already maps to an existing Firebase UID, and if so **replaces** the fresh anonymous session with the restored account (`signInWithCredential`, discarding the throwaway anon UID). If the new device already has local progress (rare — e.g. reinstall after partial data loss), prompt a merge choice: "Keep this device's progress" vs. "Restore my synced progress" — never merge silently.
6. **Account deletion:** Settings → "Delete my data" deletes the Firestore document tree and calls `FirebaseAuth.instance.currentUser.delete()`. Required regardless of store policy, but Apple explicitly requires an in-app account-deletion path (App Store Review Guideline 5.1.1(v)) the moment any account creation exists — anonymous auth alone likely doesn't trigger this, but the optional linking flow does, so build it at the same time as linking, not later.

## 4. Leaderboards & anti-cheat (closes an existing release-checklist item)

`docs/RELEASE_CHECKLIST.md` already states: *"Validate leaderboard submissions on a trusted service; never trust a client-provided score by itself"* and *"Define a versioned replay format containing the seed and accepted player commands."* This architecture satisfies both:

1. **Client-side — implemented:** `lib/game/replay.dart` records `(seed, mode, ordered input events with timestamps)` for every run into a versioned local replay format. Cheap, since the piece bag already takes a seedable `Random` — it's just an input logger.
2. **Submission — implemented, partially:** `functions/src/index.ts`'s `submitScore` callable rejects the easy cheats (a scoring run with zero recorded events, non-chronological event timestamps, an implausible sustained input rate) before writing to Firestore. **It does not yet fully re-simulate the run** to verify the score is exactly reproducible from `(seed, replay)` — that needs the deterministic game-logic module (`lib/game/game_board.dart` + `piece_bag.dart`, pure Dart with no Flutter/UI dependency) ported to or run from the Functions runtime. This is called out as a TODO directly in the function; don't advertise leaderboards as fully tamper-proof until it closes.
3. Firestore security rules (`firestore.rules`, implemented) make `leaderboards/*` and `dailyChallenge/*` **read-only from the client**; all writes go through the Cloud Function using the Admin SDK, so no amount of client tampering can write directly to either.
4. **Wired end-to-end:** `LeaderboardService.submitScore` (`lib/services/leaderboard_service.dart`) calls the Cloud Function from `GameScreen._endGame` for every scoring run, and `LeaderboardService.fetchTop` backs a `LeaderboardScreen` (reachable from a 🏆-adjacent icon on mode-select). Both fail closed to "no scores yet" against the placeholder config, same contract as every other live service. Daily Challenge (`lib/services/daily_challenge_service.dart`) still keeps its own honest device-local approximation described in its doc comment — the plumbing above is what a fully cross-player Daily Challenge would build on, not something it uses today.

## 5. Data model (Firestore) — as implemented

```
users/{uid}
  profile: { updatedAt }
  saves: { [modeId]: { bestScore, bestLevel, bestTimeMs } }
  stats: { gamesPlayed, totalLinesCleared, totalTetrises, totalFusionBonuses, bestComboEver, totalPlaytimeMs }
  entitlements: { vipActive: bool, entitlementIds, productId, expiresAtMs, updatedAt }   // written ONLY by the revenueCatWebhook Cloud Function, never by the client

leaderboards/{mode}/entries/{uid}: { score, level, seed, submittedAt }   // client: read-only; write: submitScore Cloud Function only

dailyChallenge/{seed}/entries/{uid}: { score, level, seed, submittedAt }   // same write model as leaderboards; keyed by the day's seed (== the date, see DailyChallengeService.seedForToday)
```

One deliberate deviation from an earlier sketch of this model: `saves` and `stats` live as nested maps on the single `users/{uid}` document (see `CloudBackupService`'s doc comment) rather than as a `saves/{mode}` subcollection, so a highest-value-wins merge is one transaction instead of a multi-document batch. Revisit only if per-mode documents are ever needed for finer-grained security rules.

**Security rules summary (implemented, `firestore.rules`):** a user may read/write anything under their own `users/{uid}` **except `entitlements`**, enforced via `diff().affectedKeys()` on both create and update. `leaderboards` and `dailyChallenge` are collection-wide read, Cloud-Function-only write, with a hard `allow read, write: if false` default-deny on everything else.

## 6. Apple Sign-In requirement (concrete compliance detail)

If Google Sign-In is offered as an account-linking option on iOS, Apple's App Store Review Guideline 4.8 requires Sign in with Apple to be offered as an equivalent option. Build both linking paths together on iOS from day one rather than adding Google first and hitting a review rejection later — this is a known, avoidable trap.

## 7. Privacy policy — what has to change

The current `PRIVACY.md` promise ("does not create accounts, show ads, use analytics, or send gameplay data to a server") becomes false the moment this code actually connects to a real project — **not before.** As of this writing the code exists but every service targets the placeholder config in `lib/firebase_options.dart`, so no real account is created and no real data leaves the device; `PRIVACY.md`'s claims remain factually true for the app as it actually behaves today. `PRIVACY.md` itself already flags what comes next: *"This policy must be reviewed before adding crash reporting, analytics, cloud saves, leaderboards, advertising, purchases, or any other networked service."* Treat that sentence as a hard gate on the moment a real Firebase project replaces the placeholder — do not point `lib/firebase_options.dart` at a real project without a rewritten, reviewed privacy policy alongside that change. The rewrite needs to honestly cover: anonymous identifiers and what they're linked to, what's collected by Firebase Analytics/Crashlytics, that purchases are processed by RevenueCat/the platform stores (not by us directly), how to delete data, and that none of this is sold to third parties.

## 8. Testing strategy

- **Firestore emulator suite** for security-rule tests (a user cannot read another user's `entitlements`, cannot write `leaderboards` directly, etc.) — run in CI alongside the existing `flutter test`.
- **RevenueCat sandbox** (StoreKit sandbox tester + Play Billing test track) for full subscription lifecycle testing (purchase, renew, cancel, restore, refund) before any production entitlement gating ships.
- **Replay determinism test**: extend the existing `piece_bag_test.dart` pattern — record a replay, re-simulate it, assert identical final board/score. This is the same guarantee the anti-cheat system depends on, so it should be a first-class regression test, not just a manual check.
