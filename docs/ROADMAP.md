# Roadmap — What The Triangle

**Status:** Phases 0–2 are implemented. Phase 3 is active in code on web for Analytics, anonymous/linked accounts, lightweight authenticated leaderboards, and multiplayer signaling; Firebase console/rules deployment is still required. Cloud Functions and cloud backup remain disabled. Phase 4 remains inert pending RevenueCat/store setup.
**Companion docs:** [GDD.md](GDD.md) · [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) · [MONETIZATION.md](MONETIZATION.md)

Sequencing principle, per direct instruction: **make the game itself excellent before adding any monetization or backend.** Phases 0–2 are pure game quality with zero new infrastructure risk. Phases 3–5 add the systems requested (analytics, RevenueCat, anonymous accounts + backup) only once the core game earns them. Sizing is relative (S/M/L/XL), not calendar time, since actual pace depends on who's implementing and asset sourcing lead time (audio in particular).

## Phase 0 — Audio Foundation ✅ Implemented
**Size: M · Depends on: nothing · Unlocks: the single biggest "feels unfinished" gap closing**

- Built `AudioService` (music bus + SFX bus, independent volume sliders, master mute).
- Wired every action (move, rotate, mirror, drop, lock, four-line clear, combo, cavity fill, level up, game over, new best, menu nav, pause) to its sound.
- **Shipped with a caveat, by design:** SFX are programmatically synthesized (`tool/generate_audio.py`), while `tmusic.mp3` and `zen_classic_arcade_music.mp3` are the supplied menu/lobby and gameplay loops. A fully licensed or commissioned production pack remains a release item.
- **Exit criteria met:** every action has audio feedback; volume/mute/haptics controls exist in Settings; full test suite green.

## Phase 1 — Mechanical Depth + Replay Foundation ✅ Implemented
**Size: M · Depends on: nothing (parallel to Phase 0) · Unlocks: Fusion Bonus, back-to-back scoring, and a free replay format**

- Implemented Fusion Bonus scoring (`GDD.md` §4.1) and back-to-back chain (`GDD.md` §4.2), each with its own toast/particle/SFX treatment.
- Wall-kick table left as-is (the "not SRS, tuned for triangle pieces" call from `GDD.md` §4.4) — still needs the broader playtest pass to confirm it never feels unfair, independent of this phase.
- Built the local replay recorder (`lib/game/replay.dart`: seed + mode + timestamped input log, versioned format) per `TECHNICAL_ARCHITECTURE.md` §4.1. Wired into every run; nothing consumes it yet beyond a `lastReplay` getter — that's intentional, it's groundwork for Phase 3's leaderboard validation, not a feature in itself yet.
- **Exit criteria met:** covered by `test/replay_test.dart` (serialization round-trip) plus the existing `piece_bag_test.dart` determinism guarantee it depends on.

## Phase 2 — Mode Roster + Meta Systems ✅ Implemented
**Size: L · Depends on: Phase 0 (for mode-specific music cues) · Unlocks: Chill mode (the explicitly requested easier mode), short-session modes, retention loop**

- Implemented **Chill mode** (`GDD.md` §5): narrower 8-column board, 5-piece pool, capped speed curve, soft-floor. Shipped first within this phase as the explicitly requested easier mode.
- Implemented **Sprint, Ultra, Zen** — reused the existing board/piece code, added end-condition/curve wiring and a mode-clock HUD readout.
- Initially implemented **Daily Challenge** as a device-local, one-attempt approximation. The later player-feedback pass below replaced that limit with unlimited deterministic retries while keeping streaks once-per-day.
- Regrouped mode-select UI into all four categories (Marathon / Timed / Practice / Daily).
- Built the Stats & Achievements screen (`GDD.md` §6.1–6.2) — lifetime stats via `StatsService`, achievement unlock state derived live from those stats (no separate "unlocked" set to keep in sync). Shipped with a curated 17-achievement starting set rather than the full 20–30 the design doc describes — a content-authoring pass, not an engineering gap.
- Built the `ThemePalette`/`ThemeService` cosmetic system (`GDD.md` §6.5) with 3 free themes (Neon, Colorblind-Safe, Sunset), threaded through board rendering, next/hold previews, and the app's own accent color.
- Full accessibility pass: reduce-motion toggle, haptics off-switch, a text/UI scale slider, and a one-handed touch-control layout (balanced/left/right) that clusters mobile controls toward one thumb instead of spanning the full width.
- Expanded the achievement roster from 17 to 22, adding mirror-flip and cavity-fill lifetime counters (`StatsService`), a Daily Challenge completion counter (`DailyChallengeService`), and per-mode achievements (Chill, Ultra).
- **Exit criteria met:** new modes and systems covered by an expanded `widget_test.dart` plus dedicated unit tests (`theme_service_test.dart`, `stats_and_achievements_test.dart`, `daily_challenge_service_test.dart`); `flutter analyze`/`flutter test`/`dart format`/release web build all green.

**This is the natural point to pause and playtest broadly** — Phases 0–2 should already make the game demonstrably more complete and "finished-feeling" with zero backend risk taken on. Recommend a real playtest round with players of varied falling-block experience before committing to Phase 3.

### Post-Phase-2 polish (unplanned, added on request) ✅ Implemented

A further round of feel/retention additions, still entirely local — no new infrastructure risk:

- **Danger-zone warning**: `GameBoard.isNearTop()` + a pulsing red border and a distinct SFX once the stack creeps into the top rows — closes an obvious "feels unfinished" gap for a falling-blocks game.
- **Daily Challenge streak**: consecutive-day counter (🔥) on the mode card and in the recap dialog, lazily invalidated so it never shows stale after a missed day — the "Streaks" system `GDD.md` §6.3 had designed but Phase 2 hadn't built yet.
- **First-run tutorial**: a short, skippable 4-page overlay (Move & Rotate, Mirror Flip, Fusion Bonus, Hold & Assists) shown once, ever, closing a real onboarding gap — previously a first-time player got no explanation of the fusion mechanic beyond the mode-card copy.
- **Recent-form sparkline**: on the Stats screen, each of the last 20 runs plotted as % of that mode's personal best (normalized so cross-mode score-scale differences — a Chill run vs. an Ultra run — never distort a single-axis chart).
- **Share result**: an email-free panel after every run (side panel on desktop, an icon on mobile) with Copy game link, X, Facebook, and WhatsApp, sharing score/level or Sprint time plus the GitHub Pages link — a cheap viral loop with zero backend.

62 tests total, `flutter analyze`/`dart format`/release web build all green.

## Phase 3 — Firebase Foundation ✅ Web Analytics + multiplayer configured
**Size: L · Depends on: Phase 1 (replay format), Phase 2 (stats/achievements data to sync) · Unlocks: cloud backup, analytics visibility, leaderboards, and everything Phase 4 needs**

Serverless throughout — Firebase and RevenueCat are managed services with nothing for us to host (see `TECHNICAL_ARCHITECTURE.md` §1). The production Firebase web app is present in `firebase_options.dart`; web feature flags enable Analytics, Auth, leaderboards, and multiplayer. Cloud backup remains a safe no-op.

- ~~Stand up `whatthetetris-dev` / `whatthetetris-prod` Firebase projects, Flutter flavors, CI wiring against `dev`.~~ Still needs the account owner's Firebase console action — everything downstream of it is written.
- **Implemented:** `CloudAuthService` — anonymous auth, optional email/password account creation and login, a 3–20 character public player name stored in Firebase Auth, password reset, logout to a new anonymous identity, and an account-deletion primitive (`lib/services/cloud_auth_service.dart`, `TECHNICAL_ARCHITECTURE.md` §3).
- **Implemented:** `CloudBackupService` — Firestore sync with highest-value-wins merge (`lib/services/cloud_backup_service.dart`). One deviation from the original sketch: a single `users/{uid}` document with nested `saves`/`stats` maps rather than a `saves/{mode}` subcollection, so the merge is one transaction — see the doc comment for the tradeoff.
- **Implemented:** `firestore.rules` — owners can read/write their own user document except the reserved `entitlements` field; leaderboard reads require authentication, and clients may create or increase only their own schema-limited Classic/Daily/fixed-2-Player/Mirror-2-Player/Puzzle-2-Player entry or change its validated public name without changing the score.
- **Implemented:** `AnalyticsService` wired to the event taxonomy (session, mode, game-over, scoring events, mirror/cavity-fill usage) — `lib/services/analytics_service.dart`, called from `lib/game/game_screen.dart`. Crashlytics wired to `FlutterError.onError`/`PlatformDispatcher.instance.onError` in `main.dart` (off on web, which has no Crashlytics SDK).
- **Implemented and web-enabled:** `LeaderboardService` + `LeaderboardScreen` submit/fetch named Classic, Daily, and 2 Player shared-team top-10 scores for anonymous or logged-in Firebase players. The client attempts only new local bests; a transaction writes only a higher remote best, top-10 queries are cached for the app session, and a name change touches only existing entries on the five visible boards.
- **Deliberate tradeoff:** no leaderboard Cloud Function is deployed. Security rules constrain ownership, schema, ranges, timestamps, and increasing scores, but a modified client can still fabricate a score. Trusted replay validation remains future work before competitive stakes are added.
- **Completed for current scope:** `PRIVACY.md` now discloses web Analytics, anonymous Auth, Firestore signaling, and peer-to-peer gameplay exchange.
- **Exit criteria for the current friendly-ranking scope:** a fresh install silently gets a working anonymous account; creating an email account preserves that anonymous UID; email/password login restores an existing Firebase leaderboard identity on another device; direct writes obey the deployed rules; privacy policy is reviewed and published. Cheat-resistant competition remains out of scope without trusted validation.

## Phase 4 — RevenueCat + Subscriptions + Cosmetic Store ⏸️ Disabled
**Size: L · Depends on: Phase 3 and a future trusted entitlement-verification design, Phase 2 (Theme system is the product being sold)**

- **Implemented:** `PurchaseService` (`lib/services/purchase_service.dart`) — configures RevenueCat, fetches offerings, purchases a package, checks the `vip_pass` entitlement, restores purchases. Refuses to even attempt `Purchases.configure` against the known-placeholder API key, so it never surfaces a native error dialog for a config that was never going to work.
- **Implemented:** `PaywallScreen` (`lib/ui/paywall_screen.dart`) — an honest "not available yet" state when unconfigured, a VIP-active state, and an offerings list wired to `purchase`/`restorePurchases`. Reachable from a ⭐ button on the mode-select screen.
- **Not active:** the previous Functions webhook scaffold was removed so the current game has no Functions runtime or deployment. A future paid launch must add trusted purchase verification without allowing the client to write entitlements.
- **Still open, and can't be closed from here:** actually configuring RevenueCat products against real App Store Connect/Play Console listings — blocked on the Apple Developer Program/Google Play Console accounts `docs/RELEASE_CHECKLIST.md` already flags as outstanding. Sandbox-testing the full purchase lifecycle is meaningless before that exists.
- **Exit criteria for full activation** (unchanged, still not met): a full purchase → entitlement-unlock → restore-on-new-device cycle verified in sandbox for both stores; a refunded/cancelled subscription revokes entitlement within a reasonable delay; a deliberate audit confirms no purchase touches speed, scoring, the piece bag, or leaderboard eligibility (`MONETIZATION.md` §1).

### Post-Phase-4 additions ✅ Implemented

Closed the remaining backend loose ends, then a further round of pure game-feel polish — no new infrastructure risk in either:

- **Crashlytics wired** to `FlutterError.onError`/`PlatformDispatcher.instance.onError` in `main.dart` (off on web, which has no Crashlytics SDK; inert everywhere until real config exists).
- **`LeaderboardService` + `LeaderboardScreen`** — a new local best is submitted from `GameScreen._finishGame`, and a real leaderboard screen (mode chips + ranked list) is reachable from mode-select.
- **Results screen**: a dedicated post-run recap (`lib/ui/widgets/results_screen.dart`) — score, level, lines, duration, and any four-line clears/Fusion Bonuses/mirror flips/cavity fills that happened, plus a before/after diff against `Achievement.all` surfacing anything that unlocked *because of this specific run*. Replaces "Game Over" as a bare overlay label with an actual moment.
- **Ready countdown**: Sprint and Ultra hold gravity and the clock until a brief "3-2-1-GO" plays out, so the timer never starts before the player is oriented — a real fairness gap for modes where the clock is the score. Deliberately skipped on the very first-ever game, where the tutorial overlay already provides that pause.
- **Pause Menu** (`lib/ui/widgets/pause_menu.dart`): replaces the bare dimmed "Paused" overlay with a real menu — mode label, live score/level/lines, and Resume/Restart/Settings/Quit. Restart and Quit both confirm via an `AlertDialog` before discarding the run, since both are otherwise-irreversible actions mid-game.
- **Shake intensity by severity**: `GameAnimations.triggerShake(intensity:)` scales the screen-shake wobble amplitude (clamped 0.4–1.6) so a long hard drop or a four-line clear reads as more forceful than a routine one, instead of every trigger looking identical.
- **Hard-drop impact ring** (`GameAnimations.triggerImpactRing`, drawn in `board_painter.dart`): an expanding, fading ring at the landing cell on any hard drop of 3+ rows, layered with the existing particle burst for a clearer "impact" read.

### Gameplay/UI/vibes balanced pass ✅ Implemented

A survey of the game's current state found Hold and the 3-piece next queue already solid, but a real asymmetry: danger (stack near the top) had an ambient, continuous visual, while combo streaks only got a one-shot toast. This round closes that gap and adds a first-impression moment to the menu — no new mechanics, no infrastructure risk:

- **Ambient combo glow**: `GameAnimations.setComboHeat` drives a soft blurred pulse around the board (`comboPulse`, rendered in `board_painter.dart`) that intensifies and reddens as the combo streak grows, mirroring the shape of the existing danger-border pulse but confined to the board rect and blurred so the two signals never read as the same thing.
- **Level-up flash**: `GameAnimations.triggerLevelUp` adds a brief whole-board accent-colored flash layered on top of the existing "LEVEL n!" toast/SFX, giving level-ups a felt moment rather than just a text popup.
- **Start screen fusion hero** (`lib/ui/widgets/fusion_hero.dart`): a small looping animation above the title that acts out the game's core, otherwise-unexplained hook — two opposite triangle halves sliding together and fusing into a full cell — reusing the same `tri_paint.dart` drawing code as the real board, so it's a preview of actual gameplay, not a separate illustration. Respects the OS-level "reduce motion" accessibility flag (settles on a static frame rather than looping).

90 tests total, `flutter analyze`/`dart format`/release web build all green.

### New-best celebration, graduated haptics, Settings restyle ✅ Implemented

A second survey (Settings screen, mobile stats bar, haptics coverage, new-best treatment) found the game's single biggest emotional beat — hitting a new personal best — got only a colored toast and a sound cue, no haptic, and no board-level moment; and that Settings was the one screen left as a bare default-Material `ListView` while every other screen had been restyled over the last several rounds:

- **New-best celebration**: `GameAnimations.triggerCelebration` adds a slow, warm whole-board flash, paired with a per-column particle shower (`_finishGame` in `game_screen.dart`) and a heavy haptic — plus a deliberate ~550ms beat before the Results dialog opens so the celebration is actually visible instead of being instantly covered by the modal scrim.
- **Graduated game-over haptics**: new best → heavy impact, an achievement unlock with no new best → medium, a plain run-ended → light — previously `_finishGame` fired no haptic at all, the one dead spot in an otherwise-tiered haptic scheme (rotate/hold/mirror already use `selectionClick`, hard drop/power-clear `mediumImpact`, line clears `heavyImpact`).
- **Settings screen restyle** (`lib/ui/settings_screen.dart`): each section (Appearance/Audio/Accessibility/Cloud Backup) now sits in a bordered, tinted card matching the `PauseMenu`/mode-select visual language instead of running together in a plain list. Every row gained an identifying icon, and the Music/SFX volume sliders now show a live percentage at rest (`_SliderRow`) — previously only the Text & UI size slider had one, an inconsistency the earlier survey flagged directly. Fixed a real Flutter framework warning surfaced by this change (a `ListTile` painting its background through an intervening colored `Container` with no `Material` ancestor in between) by wrapping each card's content in a transparent `Material`.

93 tests total, `flutter analyze`/`dart format`/release web build all green.

### Tutorial rewrite ✅ Implemented

A mechanics survey (`countFusions`/`_mirrorActive`/`fillLowestCavity`/combo/back-to-back logic in `game_screen.dart` and `game_board.dart`) found the old "How to Play" overlay was 4 pages of icon+text with no visual demonstration of anything, shown exactly once ever with no way to reopen it — a real gap for a game whose star mechanic (fusion) is genuinely hard to picture from text alone:

- **Expanded to 6 accurate pages** (`lib/ui/widgets/tutorial_overlay.dart`): Move & Rotate, Mirror Flip, Fusion Bonus, Back-to-Back & Combo (previously not mentioned at all), Hold & Cavity Fill, and Picking a Mode (a Chill/Zen callout for uncertain new players, framed per `docs/GDD.md`'s "play at your own pace," not as a difficulty apology). Copy was written directly from the mechanics' actual code — e.g. fusion is color-blind (any two opposite halves fuse, not matching colors), Cavity Fill self-completes a stray half with its own color rather than borrowing one, and a "hard clear" is a four-line clear or a 2+-fusion lock.
- **Real visual demonstrations, not icons**: the Fusion page embeds `FusionHero` (the start-screen animation, reused as-is); the Mirror Flip page gets a new `lib/ui/widgets/mirror_flip_demo.dart` — a looping 3D card-flip showing a piece's triangle-half assignment swapping in place; the Cavity Fill page gets a new static `lib/ui/widgets/cavity_fill_diagram.dart` before/after pair. Both new widgets respect the OS-level "reduce motion" flag the same way `FusionHero` does.
- **No longer locked to first launch**: added a permanent "How to Play" entry point on the start screen's header icon row and a "How to Play" row in Settings' new Help card — either one reopens the exact same overlay and marks it seen, so a player who skipped it (or wants a refresher) isn't locked out for good.

101 tests total, `flutter analyze`/`dart format`/release web build all green.

### Mobile HUD, achievement audio, per-mode music, and a real reset bug ✅ Implemented

A follow-up survey targeted three specific gaps (the mobile HUD was still the least-juiced surface, achievement unlocks were purely silent until the Results screen, Arcade/Sprint/Ultra/Classic/Daily all shared one "marathon" music loop) and, while checking the newer `GameAnimations` controllers, turned up a genuine correctness bug:

- **Fixed a real bug**: `celebration` and `levelUp` (the new-best flash and level-up flash) were never stopped or zeroed at run-start, unlike `danger`/`comboHeat` — a fast "Play Again" right after a new-best game-over could carry a still-animating celebration flash into the first frames of the new run. Consolidated into `GameAnimations.resetForNewRun()`, which stops and zeroes every transient controller (including particles) in one place, called from `_startGame()`.
- **Mobile HUD now carries danger/combo feedback**: `MobileStatsBar`'s top border now pulses red under danger and glows accent-to-red with combo heat — the same signals the board already shows, previously invisible on the compact mobile layout since neither `MobileStatsBar` nor `GameSidePanel` had ever been given access to `GameAnimations`.
- **Achievement unlocks get a distinct sting**: a new `Sfx.achievementUnlock` cue (`tool/generate_audio.py`) plays once, timed to the Results screen's reveal, whenever a run unlocks at least one achievement — previously a unlock was visually shown on the Results screen but had no audio cue of its own at all.
- **Historical audio pass:** earlier builds assigned different synthesized beds by mode. The current player-feedback pass intentionally replaces them with one consistent `zen_classic_arcade_music.mp3` gameplay loop.

108 tests total, `flutter analyze`/`dart format`/release web build all green.

### Adversarial QA pass ✅ Implemented

After several rounds of rapid feature work, three parallel adversarial code reviews (core game loop/animation state, the UI/dialog layer, and the persistence/input layer) were run specifically to find correctness bugs before building further — not more features, a deliberate stop to verify what already shipped. All three found genuine, traceable issues:

- **Fixed a critical race**: the game's own advertised instant-restart shortcuts (Space, the mobile Play button) could fire `_startGame()` while `_finishGame()`'s persistence/analytics work for the *previous* run was still in flight — resetting `_score`/`_lines`/`_lastReplay` out from under a still-running score/leaderboard submission, mislabeling or silently dropping it, and in the worst case leaving a stale Results dialog modal over an already-running second game. Fixed with a `_finishingGame` guard flag, cleared before the Results dialog opens (not around it) so a legitimate Play Again tapped from inside that dialog is never mistaken for the race.
- **Fixed a use-after-dispose risk**: `_finishGame` touched `setState`/`GameAnimations` (the new-best toast, celebration trigger, particle burst) *before* its only `mounted` check, reachable by backing out of the app right after a run ends. Added the missing check.
- **Fixed a real data-corruption bug**: `DailyChallengeService.recordResult` wasn't idempotent — a second same-day call could collapse a real streak back down to 1 while double-counting `completedCount`. Same-day retries now update only the best score/clear state and leave daily counters intact.
- **Fixed a tutorial navigation bug**: a fast double-tap on Skip/"Let's go" could pop the tutorial dialog *and* the screen underneath it (Start screen, Settings, or a brand-new first-launch `GameScreen`), since Navigator's pop transition is synchronous and nothing debounced the second call. Fixed with a `_closing` guard in `TutorialOverlay`.
- **Fixed a real accessibility gap**: the in-app Settings > Accessibility > "Reduce motion" toggle never reached `FusionHero`/`MirrorFlipDemo` — they only checked the OS-level `MediaQuery.disableAnimations` flag, so turning the setting on still left the looping demos animating. Both widgets (and `TutorialOverlay`, which embeds them) now take an explicit `reduceMotion` param wired from `SettingsService` at all three of the tutorial's entry points.
- **Fixed a layout risk**: `TutorialOverlay`'s fixed-height content had no scroll fallback, unlike `ResultsScreen` — a short/landscape viewport (an acknowledged real scenario on mobile web, which can't be orientation-locked) or a high UI-scale setting could overflow it with no way to reach Skip/Next. Wrapped in a `SingleChildScrollView` with a height cap, matching `ResultsScreen`'s pattern.
- **Fixed a performance issue**: `MobileStatsBar` rebuilt its entire subtree on every tick of all 9 `GameAnimations` controllers merged in `anim.repaint`, when it only ever reads `danger`/`comboPulse`. Narrowed to `Listenable.merge([anim.danger, anim.comboPulse])`.
- **Fixed a resilience gap**: `_finishGame`'s four sequential local-persistence writes (`submitRun`/`submitTime`/`recordResult`/`recordRun`) had no error handling — one throw silently skipped every write after it, including `recordRun`, which ran last. Each write is now isolated via a `_tryPersist` helper so one failure can't cascade into the others being skipped.
- **Minor consistency fixes**: the combo glow is now gated by `state == GameState.playing` like the danger border already was (previously could render faintly under the Game Over overlay); the first-launch tutorial dialog now closes over its own `dialogContext` instead of the enclosing screen's, matching the other two entry points.

Also confirmed clean by the reviews (worth recording so it isn't re-litigated): the `_lockResets` budget and its interaction with mirror/rotate/move; hold-once-per-piece; `HoldRepeatButton`'s timer lifecycle; touch-control pointer routing when a finger slides off a button; every achievement's unlock predicate against the actual stat fields it reads; `game_mode.dart`'s per-mode config values; `speed_curve.dart`'s floor/ceiling clamping; `game_board.dart`'s bounds checks in `countFusions`/`fillLowestCavity`.

115 tests total, `flutter analyze`/`dart format`/release web build all green.

### Golden-image visual verification + achievement roster expansion ✅ Implemented

Two previously-flagged gaps closed in one round: several rounds of animation work (`FusionHero`, `MirrorFlipDemo`, the mobile HUD's combo/danger border) had shipped without ever actually being *seen* — no browser/screenshot tool is available in this environment — and the achievement roster sat at 22, the low end of the documented 20-30 target.

- **Golden-image tests** (`test/golden/`): `matchesGoldenFile` snapshots of `FusionHero` (resting/mid-slide/flash frames), `MirrorFlipDemo` (before/mid-turn/after frames), and `MobileStatsBar` (baseline/combo/danger border states), rendered against an explicit dark backdrop `Container` — `matchesGoldenFile` only rasterizes the finder's own bounds, not an ancestor's background, so the backdrop has to be inside the captured widget, not a parent `Scaffold`. Actually looking at these caught a real, previously-invisible issue: **fixed a flat/washed-out resting frame in `FusionHero`** — `Color.lerp`'s naive RGB blend of two saturated colors (cyan + pink) desaturates to a muted grey, and the glow had no floor once the flash decayed to 0, unlike the real board (which always keeps a small ambient glow on the active piece). This mattered because reduce-motion users see this exact settled frame *indefinitely*, not just mid-loop. Fixed with a glow floor (`0.4 + flash * 0.6`) so it never goes fully flat. A full `StartScreen` integration golden was attempted but dropped — `audioplayers` opens per-instance `EventChannel`s with runtime-generated UUIDs that can't be stubbed by exact channel name, making it impractical to automate here; the individual widget goldens above were the higher-value target anyway.
- **7 new achievements** (22 → 29, within the documented range): `cavity_novice` (fill your first cavity — Fusion/Mirror already had a "first use" tier, Cavity Fill didn't), `back_to_back_master` (5-chain streak), `iron_will` (10-hour tier above the existing 1-hour `dedicated`), `classic_grinder` (level 20 in Classic — the flagship mode had no mode-specific achievement, unlike Arcade/Sprint/Chill/Ultra), `zen_master` (level 10 in Zen — same gap for the practice mode), `overdrive` (max Arcade Speed Boost stack — the mechanic had no achievement of its own), `daily_devotee` (30-run tier above the existing 7-run `daily_challenger`). `overdrive` needed a new `StatsService.maxSpeedBoostEver` field — `_speedBoost` only increases within a run and resets at `_startGame`, so its value at game-over already *is* that run's peak, no new run-tracking needed in `game_screen.dart`.

130 tests total, `flutter analyze`/`dart format`/release web build all green.

### Daily Challenge redesign ✅ Implemented

The original Daily Challenge (`ROADMAP.md` Phase 2) was a normal marathon run on a seeded board — same mechanic as Classic, just with a shared daily seed and a streak counter. That undersold the "daily puzzle" framing `GDD.md` §5/§6.3 actually wanted: a puzzle players solve once a day, not another endurance run. Redesigned it into a proper stack-reduction puzzle:

- **`GameModeConfig.startsPrefilled`** (`lib/models/game_mode.dart`): Daily Challenge spawns with one of several deterministic, bottom-aligned terrain formations 2–7 rows high. The day-derived seed selects its height, profile, reflection, position, and exposed triangle edges independently from the seeded piece bag.
- **`EndCondition.boardReducedToOneRow`**: the run ends as a win once the locked board occupies no more than one row. An empty-board over-clear also wins, so clearing the final two rows together is never punished. The check is shared by normal locks and cavity fills.
- **`DailyChallengeService.todaysCleared`**: tracks whether today's attempt actually cleared the board versus topping out first, stored alongside the existing streak/score/completed-count fields, surfaced on the mode card and in the recap dialog.
- The consecutive-day streak, device-local seed derivation, and caveat about needing a real server for cross-player validation remained unchanged in this first redesign.

138 tests total, `flutter analyze`/`dart format`/release web build all green.

### Player-feedback focus pass ✅ Implemented

- Renamed the successful Chill experience to player-facing **Classic** while preserving its internal storage key and saved scores. The old Classic and all timed/legacy modes remain implemented but are hidden from mode select.
- Removed Classic's soft floor after follow-up feedback: the relaxed pace and five-shape pool remain, but reaching the top now ends the run normally.
- Daily Challenge now supports unlimited retries of the same deterministic board and piece order. It stores the best score and clear state for the day while advancing streak/completion only once.
- Daily uses Classic's five-shape pool, capped speed curve, two starting cavity fills, a dedicated calendar card icon, and a deterministic 2–7-row terrain formation. Reducing the locked stack to at most one occupied row is its win condition.
- Daily and 2 Player Puzzle now award `max(0, 5000 - 10 × whole active seconds)` only on a successful solve. Both HUDs preview the remaining award and both result presentations break it out from the final score; Daily excludes ready-countdown and paused time.
- VIP remains hidden. Authenticated Classic/Daily/fixed-2-Player/Mirror-2-Player/Puzzle-2-Player leaderboards and Login are available from the start-screen toolbar.

### Shared-board 2 Player foundation ✅ Implemented (configuration required)

- Added a visible 2 Player mode with a shared six-character room-code lobby: the host is permanently red/bottom-left and the guest permanently blue/top-right.
- Added a host-authoritative 8×20 cooperative engine with two simultaneous falling pieces, Classic's five-shape pool, normal shared top-out, and synchronized restart. The original fixed variant rejects Mirror actions.
- Added **2 Player Mirror** as a separate visible variant: either peer can Mirror their own active piece, their chosen orientation persists into the next spawn, and snapshot masks preserve permanent red/blue color independently from triangle orientation.
- Added **2 Player Puzzle** as a third visible room-code variant: a seeded 16×8 board reuses Daily's 2–7-row terrain generator, both peers may Mirror, each starts with two fills, and reducing the formation to one occupied row produces a synchronized team victory.
- Puzzle speed scoring is host-authoritative and idempotent: the host adds the shared completion bonus once before broadcasting the final snapshot, so both peers and both separate player leaderboard submissions receive the same total without an additional Firestore operation.
- Added separate cavity-fill inventories: red and blue each start with one, and every cleared line awards one recharge only to the player whose action completed it. Compact snapshots keep both counts synchronized.
- Added Classic-style landing ghosts to 2 Player, calculated from the latest authoritative snapshot and rendered only for the local player's falling piece.
- Polished co-op readability and frame stability: particles now have colored halos and white cores, hold before their fade, and remain bounded during simultaneous clears; impacts use the acting player's color and locked-piece center, while co-op flashes/rings use longer presentation timing above full-board effects. Fusion, clear, combo, and back-to-back awards from the same action are consolidated into one 1.85–2.4-second high-contrast card, and simultaneous peer effects get a 260 ms visual-only stagger. A responsive score-first HUD plus a redesigned result card make team score, objective, best, combo, and red/blue contributions visible on phone and desktop layouts.
- Added a persisted one-tap master mute to every solo and 2 Player gameplay HUD; it controls both the shared music bed and sound effects and stays synchronized with Settings. Mode select now also has a visible persistent music-only slider, and the untouched default is reduced from 40% to 25%.
- Menus and room waiting loop `tmusic.mp3`; every gameplay mode loops the supplied `zen_classic_arcade_music.mp3`; anonymous lobby players get a non-blocking Login option.
- Each peer records the final shared score as their local best for the selected variant. Fixed, Mirror, and Puzzle bests and Firestore boards are separate; only a new local best attempts the player's own minimal transaction, and room codes or partner IDs are not part of leaderboard entries.
- Firestore is signaling only. The selected fixed/Mirror/Puzzle variant is stored in the host reservation without adding a write. Gathered ICE candidates are bundled into one offer and answer, keeping a successful lobby to four room-document writes; listeners stop after connection. Ordered gameplay inputs and compact board snapshots move peer-to-peer over WebRTC.
- Rematches are host-controlled: the guest sees a waiting state, and only the host gets **Play Again for Both**. Every snapshot carries a monotonically increasing round ID before its per-round revision, fixing the bug where the guest rejected a fresh rematch snapshot after the host engine reset its revision counter.
- Added participant-scoped Firestore rules, compact versioned snapshots, room-code validation, teardown safety, and focused engine/lobby tests.
- The production web Firebase app is configured in code for Analytics, anonymous plus email/password accounts, authenticated leaderboards, and anonymous room signaling; cloud backup remains disabled. Console activation requires Anonymous and Email/Password Auth, deployed Firestore rules, the GitHub Pages authorized domain, and TTL cleanup. Physical two-device testing and a TURN service remain multiplayer release gates.

## Phase 5 — Store Publishing Readiness
**Size: M · Depends on: everything above being feature-complete and stable · Existing tracking: `docs/RELEASE_CHECKLIST.md`**

This phase is mostly already tracked in `docs/RELEASE_CHECKLIST.md` and doesn't need restating here — it becomes actionable once Phases 0–4 close:

- Resolve trademark/product-name clearance (flagged as a pre-existing open item, independent of this whole roadmap).
- Apple Developer team/signing, Android upload key + `key.properties`.
- Store metadata: screenshots (now meaningfully more interesting with themes/modes to show), descriptions, content rating, data-safety forms (now non-trivial to fill out honestly given accounts/analytics/purchases — this is exactly why `PRIVACY.md` had to be rewritten in Phase 3 first).
- Staged rollout per the existing checklist's monitoring guidance (crashes, startup failures, frame time, user feedback) — Crashlytics from Phase 3 is what makes this observable at all.

## Summary Table

| Phase | Focus | Status | Depends on |
|---|---|---|---|
| 0 | Audio | ✅ Implemented | — |
| 1 | Fusion/B2B scoring + replay format | ✅ Implemented | — |
| 2 | Modes (incl. Chill), meta systems, themes, accessibility | ✅ Implemented | Phase 0 (music cues) |
| 3 | Firebase: accounts, backup, analytics, leaderboards | Web Analytics, accounts, lightweight leaderboards, and multiplayer configured; backup off | Phases 1, 2; Firebase console activation |
| 4 | RevenueCat subscriptions + cosmetic store | ✅ Code written · ⏸️ inert without a real RevenueCat account + store listings | Phase 3; a RevenueCat account the account owner creates |
| 5 | Store submission | Not started | Phases 0–4 |

**Recommendation:** playtest the visible Classic, repeatable Daily, and shared-board 2 Player modes broadly. Known open items include a commissioned audio pack, a larger achievement roster, trusted leaderboard validation if competitive stakes are ever added, `firebase_app_check` before meaningful abuse risk, a production TURN service for reliable co-op connectivity, legal review, and the external store/RevenueCat configuration only the project owner can complete.
