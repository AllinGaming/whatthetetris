# Technical Architecture — Live Services

**Status:** Active on web for Firebase Analytics, anonymous accounts with optional email/password login, authenticated Classic/Daily/2 Player leaderboards, and anonymous 2 Player signaling in the production `whatthetetris` project. Cloud backup, RevenueCat, Crashlytics, and native Firebase platforms remain disabled.
**Scope:** Analytics, anonymous accounts + cloud backup, room-code WebRTC co-op, RevenueCat subscriptions, and the store-publishing implications of these services.
**Companion docs:** [GDD.md](GDD.md) · [MONETIZATION.md](MONETIZATION.md) · [ROADMAP.md](ROADMAP.md)

The implementation inventory includes `CloudAuthService`, `LeaderboardService`, `MultiplayerSessionService`, `CoopGameEngine`, and their Firestore rules. Production web enables Analytics, accounts, lightweight leaderboards, and multiplayer; Cloud Functions, cloud backup, RevenueCat, and native Firebase remain disabled.

**This is a managed-services architecture, by deliberate choice.** Nowhere in this document does anyone provision, patch, or scale a server. Firebase is a Backend-as-a-Service — Google runs and scales it, while the app talks directly to Auth, Analytics, and Firestore through client SDKs. The active web game deploys no custom Cloud Functions.

This began as a greenfield integration. The privacy policy has now been revised alongside web activation to disclose Analytics, anonymous and email/password Auth, Firestore signaling, and peer-to-peer gameplay data — see §7.

## 1. Platform choice: Firebase

Chosen over Supabase for this project because one vendor covers auth, database, analytics, crash reporting, remote config, and app check, minimizing the number of systems a small team must operate. Firebase is managed; the active web features use its client SDKs and security rules without custom server code.

**Dependencies** — all added to `pubspec.yaml` already:

| Package | Purpose | Status |
|---|---|---|
| `firebase_core` | Required bootstrap for all Firebase packages | Added |
| `firebase_auth` | Anonymous sign-in + email/password login and password reset | Added, wired (`cloud_auth_service.dart`) |
| `cloud_firestore` | Save backup, stats, leaderboards | Added, wired (`cloud_backup_service.dart`) |
| `firebase_analytics` | Event tracking | Added, wired (`analytics_service.dart`) |
| `firebase_crashlytics` | Crash/error reporting | Added, wired to `FlutterError.onError`/`PlatformDispatcher.instance.onError` in `main.dart` (guarded off on web, which has no Crashlytics SDK) |
| `firebase_remote_config` | Live-tunable curves/economy without a release | Not added — still optional, add when actually needed |
| `firebase_app_check` | Anti-abuse for Firestore client writes | Not added — consider before production traffic |
| `purchases_flutter` | RevenueCat SDK | Added, wired (`purchase_service.dart`) |
| `flutter_webrtc` | Ordered peer-to-peer gameplay data channel | Added, wired (`multiplayer_session_service.dart`) |

All packages compile against platform-aware feature flags in `lib/firebase_options.dart`: production web Analytics/Auth/multiplayer/leaderboards are enabled, while backup, RevenueCat, and native Firebase calls retain their safe no-op behavior.

## 2. Environments

Two Firebase projects: `whatthetetris-dev` and `whatthetetris-prod`. Use Flutter flavors (`dev`/`prod`) so debug builds never write to production Firestore/Analytics, and CI can run against `dev` safely. RevenueCat mirrors this with separate dev/prod API keys per project. `android/key.properties` (already scaffolded, per `docs/RELEASE_CHECKLIST.md`) and the two `google-services.json` / `GoogleService-Info.plist` pairs are the only new secrets — all go in the existing "approved secret manager," never committed.

## 3. Identity: anonymous-first accounts

**Principle: nobody is ever forced to create an account or see a sign-in screen to play.**

1. **First launch:** silent `FirebaseAuth.instance.signInAnonymously()` in the background — no UI, no interruption. This UID becomes the leaderboard and multiplayer identity from minute one.
2. **Local-first progress:** `shared_preferences` remains the source of truth for instant, offline-safe best scores, settings, stats, and achievements. Cloud backup is disabled, so login does not claim to synchronize those local values.
3. **Optional Login (implemented):** the toolbar and lobby open one Login screen with email, password, Log in, Create account, and Forgot password actions. Anonymous play remains the default and has the same leaderboard eligibility.
4. **Create account:** `EmailAuthProvider.credential` is linked to the current anonymous user. Firebase therefore keeps the same UID and existing leaderboard entries. A verification email is requested after creation; verification is not currently required for play.
5. **Returning devices:** `signInWithEmailAndPassword` restores that Firebase UID and its leaderboard identity. Local scores and settings remain device-local; logging into a different existing identity does not merge leaderboard documents or local saves.
6. **Logout:** signing out immediately creates a fresh anonymous identity so multiplayer and leaderboards keep working without a forced login.
7. **Account deletion (release blocker):** `CloudAuthService` has a deletion primitive, but the current Login UI does not expose the complete online-data deletion workflow. Add that workflow and recent-login/reauthentication handling before native store release.

## 4. Lightweight leaderboards and trust boundary

The active implementation deliberately uses no Cloud Functions:

1. `GameScreen` calls `LeaderboardService.submitScore` only for a new local personal best. Daily compares against the best result for the current date rather than the lifetime Daily score.
2. One Firestore transaction reads the authenticated player's entry and writes only if the new score is higher. Ordinary runs perform no leaderboard read or write. A retry can occur if Firestore detects concurrent edits.
3. `fetchTop`/`fetchTopMultiplayer` request at most 10 documents and cache each Classic/Daily/2 Player board for the current app session. Only a successful submission or explicit Refresh causes another query.
4. Security rules allow an authenticated player to create or increase only their own small `{score, level, updatedAt}` document. They validate the path, fields, types, ranges, server timestamp, and increasing-score direction.

This minimizes Firestore usage, but it is not cheat-proof: code running on a player's device can be modified to submit a fabricated score within the allowed range. The local replay recorder remains useful groundwork, but replays are not uploaded. Trusted replay validation is still an open release-checklist item before prizes, tournaments, or claims of competitive integrity.

### 4.1 Shared-code cooperative sessions

`MultiplayerSessionService` uses Firestore only as a short-lived signaling rendezvous. A host creates a random six-character document and stores an SDP offer after ICE gathering, then shares the code out of band. The guest atomically claims that room and stores its gathered answer. Candidates are embedded in those two descriptions rather than written as separate documents. A successful setup therefore uses four room-document writes, and signaling listeners are cancelled once WebRTC opens the ordered data channel. No gameplay state is sent through Firestore.

The host runs the authoritative `CoopGameEngine`. The guest sends only actions; the host applies both players' ordered inputs and broadcasts compact, versioned snapshots. This prevents divergent line-clear and simultaneous-lock resolution. Snapshots carry separate red/blue cavity-fill counts: each begins at one, and a line adds one only to the player whose action completed it. Each peer also derives a landing ghost locally from the same snapshot and renders only its own prediction; no extra network or Firestore traffic is required. At top-out, both peers retain the same shared score as their own local 2 Player best. A peer contacts the leaderboard only for a new local best, and the standard transaction writes only if it also beats that Firebase player's remote best. STUN is configured for development. A production TURN service is still required because direct paths cannot be established across every NAT/firewall combination.

`AudioService` remains the single owner of the persisted master-mute preference. Gameplay HUDs observe that service directly through `QuickMuteButton`, so the solo desktop panel, solo mobile stats bar, 2 Player app bar, and Settings switch remain immediately consistent without duplicating audio state. Serialized track requests prevent rapid route changes from racing: menu/lobby waiting loops `tmusic.mp3` through `MusicTrack.menu`, every gameplay mode loops `zen_classic_arcade_music.mp3` through `MusicTrack.gameplay`, and route disposal restores the menu loop.

### 4.2 Analytics measurement

`AnalyticsService` owns a typed event taxonomy so gameplay widgets do not send arbitrary payloads. The random Firebase Auth UID is set as the Analytics user ID, allowing repeat engagement to be measured without sending the login email as an event parameter. Analytics records screens, mode/feature selection, solo starts and outcomes, Daily retries, and the multiplayer lobby-to-round funnel. Co-op movement is aggregated into per-round counts instead of producing an event for every input. Room codes, SDP/ICE signaling, board snapshots, and free text are never sent as Analytics parameters.

The reporting dimensions are `mode`, `feature`, `action`, `result`, `role`, and `reason`; the useful metrics include duration, score, lines, connection wait, completed rounds, and aggregate co-op controls. Custom parameters must be registered as custom definitions in Google Analytics before they are available in Explorations and custom reports. The same schema is summarized in the README's Analytics reporting section.

## 5. Data model (Firestore) — as implemented

```
users/{uid}
  profile: { updatedAt }
  saves: { [modeId]: { bestScore, bestLevel, bestTimeMs } }
  stats: { gamesPlayed, totalLinesCleared, totalFourLineClears, totalFusionBonuses, bestComboEver, totalPlaytimeMs }
  entitlements: { vipActive: bool, entitlementIds, productId, expiresAtMs, updatedAt }   // reserved for a future trusted purchase service; VIP is disabled

leaderboards/chill/entries/{uid}: { score, level, updatedAt }   // authenticated read; owner may only increase score

leaderboards/multiplayer/entries/{uid}: { score, level, updatedAt }   // player's best shared-team result

dailyChallenge/{date}/entries/{uid}: { score, level, updatedAt }   // same owner-write model; date is YYYYMMDD

multiplayerRooms/{code}: { hostUid, guestUid?, status, offer, answer?, createdAt, updatedAt, expiresAt }
```

One deliberate deviation from an earlier sketch of this model: `saves` and `stats` live as nested maps on the single `users/{uid}` document (see `CloudBackupService`'s doc comment) rather than as a `saves/{mode}` subcollection, so a highest-value-wins merge is one transaction instead of a multi-document batch. Revisit only if per-mode documents are ever needed for finer-grained security rules.

**Security rules summary (implemented, `firestore.rules`):** a user may read/write anything under their own `users/{uid}` **except `entitlements`**, enforced via `diff().affectedKeys()` on both create and update. `leaderboards` and `dailyChallenge` require Firebase authentication for reads and allow only the document owner to create or increase a schema-limited entry, with a hard default-deny on everything else.

Multiplayer room lookup requires authentication while room listing is denied. Host and guest signaling mutations are field- and role-scoped; all nested documents are denied because candidates are bundled into SDP. Room documents expire logically after two hours; production must also enable Firestore TTL on `expiresAt` for physical cleanup.

## 6. Email/password authentication setup

The current product intentionally offers no social-login provider. In Firebase Console, enable both **Anonymous** and **Email/Password** under Authentication → Sign-in method; leave passwordless email-link login disabled. Add every production hostname, including `allingaming.github.io`, under Authentication → Settings → Authorized domains. Review the verification and password-reset templates before launch, including the sender name, support address, action URL/domain, and copy. No Cloud Function is required for account creation, login, verification-email delivery, or password reset.

## 7. Privacy policy — what has to change

`PRIVACY.md` now discloses Analytics, anonymous and email/password Firebase accounts, authenticated leaderboard fields and direct writes, Firestore signaling, and direct WebRTC gameplay. `TERMS.md` covers accounts, leaderboard fair play, acceptable use, and online availability. Both are bundled into Settings → Legal. They remain product drafts requiring qualified legal review before broad commercial release.

## 8. Testing strategy

- **Firestore emulator suite** for security-rule tests (a user cannot read another user's `entitlements`, write another player's entry, reduce a score, or add unexpected leaderboard fields) — run in CI alongside the existing `flutter test`.
- **RevenueCat sandbox** (StoreKit sandbox tester + Play Billing test track) for full subscription lifecycle testing (purchase, renew, cancel, restore, refund) before any production entitlement gating ships.
- **Replay determinism test**: extend the existing `piece_bag_test.dart` pattern — record a replay, re-simulate it, assert identical final board/score. This is the same guarantee the anti-cheat system depends on, so it should be a first-class regression test, not just a manual check.
- **Co-op test matrix:** keep pure-Dart coverage for complementary color ownership, no-Mirror actions, snapshot round-trips, and shared top-out. Before enabling production rooms, add Firestore Emulator rule tests and run real two-device connection tests across same Wi-Fi, separate mobile networks, forced TURN, reconnect/loss, app backgrounding, and simultaneous hard drops.
