# Roadmap — What The Tetris

**Status:** Phases 0–2 implemented and merged. Phases 3–4's code is now also written (client services, Firestore rules, Cloud Functions) but inert — it needs a real Firebase project and RevenueCat account before any of it can actually connect to anything. See per-phase notes below.
**Companion docs:** [GDD.md](GDD.md) · [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) · [MONETIZATION.md](MONETIZATION.md)

Sequencing principle, per direct instruction: **make the game itself excellent before adding any monetization or backend.** Phases 0–2 are pure game quality with zero new infrastructure risk. Phases 3–5 add the systems requested (analytics, RevenueCat, anonymous accounts + backup) only once the core game earns them. Sizing is relative (S/M/L/XL), not calendar time, since actual pace depends on who's implementing and asset sourcing lead time (audio in particular).

## Phase 0 — Audio Foundation ✅ Implemented
**Size: M · Depends on: nothing · Unlocks: the single biggest "feels unfinished" gap closing**

- Built `AudioService` (music bus + SFX bus, independent volume sliders, master mute).
- Wired every action (move, rotate, mirror, drop, lock, clear, tetris, combo, cavity fill, level up, game over, new best, menu nav, pause) to its sound.
- **Shipped with a caveat, by design:** the current SFX/music set is programmatically synthesized (`tool/generate_audio.py`), not the commissioned pack this phase originally called for — real, distinct audio today, meant to be swapped for licensed/commissioned assets later. Sourcing that pack is still open.
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
- Implemented **Daily Challenge** as a device-local approximation: date-derived seed, one attempt per day, recap dialog on repeat visits. Explicitly *not* the cross-player validated version — that still needs Phase 3's Cloud Function design; see the caveat in `lib/services/daily_challenge_service.dart`.
- Regrouped mode-select UI into all four categories (Marathon / Timed / Practice / Daily).
- Built the Stats & Achievements screen (`GDD.md` §6.1–6.2) — lifetime stats via `StatsService`, achievement unlock state derived live from those stats (no separate "unlocked" set to keep in sync). Shipped with a curated 17-achievement starting set rather than the full 20–30 the design doc describes — a content-authoring pass, not an engineering gap.
- Built the `ThemePalette`/`ThemeService` cosmetic system (`GDD.md` §6.5) with 3 free themes (Neon, Colorblind-Safe, Sunset), threaded through board rendering, next/hold previews, and the app's own accent color.
- Full accessibility pass: reduce-motion toggle, haptics off-switch, a text/UI scale slider, and a one-handed touch-control layout (balanced/left/right) that clusters mobile controls toward one thumb instead of spanning the full width.
- Expanded the achievement roster from 17 to 22, adding mirror-flip and cavity-fill lifetime counters (`StatsService`), a Daily Challenge completion counter (`DailyChallengeService`), and per-mode achievements (Chill, Ultra).
- **Exit criteria met:** new modes and systems covered by an expanded `widget_test.dart` plus dedicated unit tests (`theme_service_test.dart`, `stats_and_achievements_test.dart`, `daily_challenge_service_test.dart`); `flutter analyze`/`flutter test`/`dart format`/release web build all green.

**This is the natural point to pause and playtest broadly** — Phases 0–2 should already make the game demonstrably more complete and "finished-feeling" with zero backend risk taken on. Recommend a real playtest round (including non-Tetris-fluent players, to validate Chill mode specifically per `GDD.md` §12) before committing to Phase 3.

### Post-Phase-2 polish (unplanned, added on request) ✅ Implemented

A further round of feel/retention additions, still entirely local — no new infrastructure risk:

- **Danger-zone warning**: `GameBoard.isNearTop()` + a pulsing red border and a distinct SFX once the stack creeps into the top rows — closes an obvious "feels unfinished" gap for a falling-blocks game.
- **Daily Challenge streak**: consecutive-day counter (🔥) on the mode card and in the recap dialog, lazily invalidated so it never shows stale after a missed day — the "Streaks" system `GDD.md` §6.3 had designed but Phase 2 hadn't built yet.
- **First-run tutorial**: a short, skippable 4-page overlay (Move & Rotate, Mirror Flip, Fusion Bonus, Hold & Assists) shown once, ever, closing a real onboarding gap — previously a first-time player got no explanation of the fusion mechanic beyond the mode-card copy.
- **Recent-form sparkline**: on the Stats screen, each of the last 20 runs plotted as % of that mode's personal best (normalized so cross-mode score-scale differences — a Chill run vs. an Ultra run — never distort a single-axis chart).
- **Share result**: a native share-sheet button after every run (side panel on desktop, an icon on mobile), sharing score/level or Sprint time plus the GitHub Pages link — a cheap viral loop with zero backend.

62 tests total, `flutter analyze`/`dart format`/release web build all green.

## Phase 3 — Firebase Foundation ✅ Code written, ⏸️ inert pending real config
**Size: L · Depends on: Phase 1 (replay format), Phase 2 (stats/achievements data to sync) · Unlocks: cloud backup, analytics visibility, leaderboards, and everything Phase 4 needs**

Serverless throughout — Firebase and RevenueCat are both managed services with nothing for us to host (see `TECHNICAL_ARCHITECTURE.md` §1). All of the following is now written and passing `flutter analyze`/`flutter test`/release web build, but **cannot actually connect to anything** until the account owner creates a real Firebase project and runs `flutterfire configure` (replacing the honestly-labeled placeholder in `lib/firebase_options.dart`). Every service degrades to a safe no-op against that placeholder — see `test/live_services_test.dart`, which locks in exactly that contract.

- ~~Stand up `whatthetetris-dev` / `whatthetetris-prod` Firebase projects, Flutter flavors, CI wiring against `dev`.~~ Still needs the account owner's Firebase console action — everything downstream of it is written.
- **Implemented:** `CloudAuthService` — anonymous auth, Apple/Google linking, restore-on-new-device, account deletion (`lib/services/cloud_auth_service.dart`, `TECHNICAL_ARCHITECTURE.md` §3).
- **Implemented:** `CloudBackupService` — Firestore sync with highest-value-wins merge (`lib/services/cloud_backup_service.dart`). One deviation from the original sketch: a single `users/{uid}` document with nested `saves`/`stats` maps rather than a `saves/{mode}` subcollection, so the merge is one transaction — see the doc comment for the tradeoff.
- **Implemented:** `firestore.rules` — owners can read/write their own document except the `entitlements` field (server-write-only via the Cloud Function's Admin SDK access, which bypasses rules); leaderboards/Daily Challenge are world-readable, never client-writable.
- **Implemented:** `AnalyticsService` wired to the event taxonomy (session, mode, game-over, scoring events, mirror/cavity-fill usage) — `lib/services/analytics_service.dart`, called from `lib/game/game_screen.dart`. Crashlytics wired to `FlutterError.onError`/`PlatformDispatcher.instance.onError` in `main.dart` (off on web, which has no Crashlytics SDK).
- **Implemented:** `LeaderboardService` + `LeaderboardScreen` (`lib/services/leaderboard_service.dart`, `lib/ui/leaderboard_screen.dart`) — calls `submitScore` after every scoring run and renders per-mode top-20 lists, reachable from mode-select. Fails to an honest "no scores yet" / "not available yet" state against the placeholder config, same as every other live service.
- **Implemented, partially:** `functions/src/index.ts`'s `submitScore` rejects implausible replay submissions (non-chronological events, impossibly fast input rates, a scoring run with no recorded inputs) but does **not yet** fully replay-validate a run — that needs the Dart game logic ported to (or run from) the Functions runtime, called out explicitly as a TODO in the function itself. Treat a passing call as "not an obvious cheat," not "cryptographically proven."
- **Still open:** `PRIVACY.md` rewrite — genuinely not needed yet, because none of this code can make a real network call against the placeholder config; the app's actual behavior today is unchanged. This stays a hard gate for the moment real config replaces the placeholder, not before.
- **Exit criteria for full activation** (unchanged from the original plan, still not met): a fresh install silently gets a working anonymous account; restoring on a new device via Apple/Google linking works; a tampered client cannot write a leaderboard score directly; privacy policy reviewed and published.

## Phase 4 — RevenueCat + Subscriptions + Cosmetic Store ✅ Code written, ⏸️ inert pending real config
**Size: L · Depends on: Phase 3 (entitlement mirroring needs the Cloud Function/webhook pattern already in place), Phase 2 (Theme system is the product being sold)**

- **Implemented:** `PurchaseService` (`lib/services/purchase_service.dart`) — configures RevenueCat, fetches offerings, purchases a package, checks the `vip_pass` entitlement, restores purchases. Refuses to even attempt `Purchases.configure` against the known-placeholder API key, so it never surfaces a native error dialog for a config that was never going to work.
- **Implemented:** `PaywallScreen` (`lib/ui/paywall_screen.dart`) — an honest "not available yet" state when unconfigured, a VIP-active state, and an offerings list wired to `purchase`/`restorePurchases`. Reachable from a ⭐ button on the mode-select screen.
- **Implemented:** `revenueCatWebhook` Cloud Function (`functions/src/index.ts`) mirroring RevenueCat subscription events into `users/{uid}.entitlements`, gated by a shared-secret `Authorization` header check.
- **Still open, and can't be closed from here:** actually configuring RevenueCat products against real App Store Connect/Play Console listings — blocked on the Apple Developer Program/Google Play Console accounts `docs/RELEASE_CHECKLIST.md` already flags as outstanding. Sandbox-testing the full purchase lifecycle is meaningless before that exists.
- **Exit criteria for full activation** (unchanged, still not met): a full purchase → entitlement-unlock → restore-on-new-device cycle verified in sandbox for both stores; a refunded/cancelled subscription revokes entitlement within a reasonable delay; a deliberate audit confirms no purchase touches speed, scoring, the piece bag, or leaderboard eligibility (`MONETIZATION.md` §1).

### Post-Phase-4 additions ✅ Implemented

Closed the remaining backend loose ends, then a further round of pure game-feel polish — no new infrastructure risk in either:

- **Crashlytics wired** to `FlutterError.onError`/`PlatformDispatcher.instance.onError` in `main.dart` (off on web, which has no Crashlytics SDK; inert everywhere until real config exists).
- **`LeaderboardService` + `LeaderboardScreen`** — `submitScore` is now actually called from `GameScreen._endGame` for every scoring run, and a real leaderboard screen (mode chips + ranked list) is reachable from mode-select, closing the "written but not wired" gap from the previous round.
- **Results screen**: a dedicated post-run recap (`lib/ui/widgets/results_screen.dart`) — score, level, lines, duration, and any of Tetrises/Fusion Bonuses/mirror flips/cavity fills that happened, plus a before/after diff against `Achievement.all` surfacing anything that unlocked *because of this specific run*. Replaces "Game Over" as a bare overlay label with an actual moment.
- **Ready countdown**: Sprint and Ultra hold gravity and the clock until a brief "3-2-1-GO" plays out, so the timer never starts before the player is oriented — a real fairness gap for modes where the clock is the score. Deliberately skipped on the very first-ever game, where the tutorial overlay already provides that pause.
- **Pause Menu** (`lib/ui/widgets/pause_menu.dart`): replaces the bare dimmed "Paused" overlay with a real menu — mode label, live score/level/lines, and Resume/Restart/Settings/Quit. Restart and Quit both confirm via an `AlertDialog` before discarding the run, since both are otherwise-irreversible actions mid-game.
- **Shake intensity by severity**: `GameAnimations.triggerShake(intensity:)` scales the screen-shake wobble amplitude (clamped 0.4–1.6) so a long hard drop or a Tetris-line clear reads as more forceful than a routine one, instead of every trigger looking identical.
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

- **Expanded to 6 accurate pages** (`lib/ui/widgets/tutorial_overlay.dart`): Move & Rotate, Mirror Flip, Fusion Bonus, Back-to-Back & Combo (previously not mentioned at all), Hold & Cavity Fill, and Picking a Mode (a Chill/Zen callout for uncertain new players, framed per `docs/GDD.md`'s "play at your own pace," not as a difficulty apology). Copy was written directly from the mechanics' actual code — e.g. fusion is color-blind (any two opposite halves fuse, not matching colors), Cavity Fill self-completes a stray half with its own color rather than borrowing one, and a "hard clear" for Back-to-Back is a Tetris *or* a 2+-fusion lock.
- **Real visual demonstrations, not icons**: the Fusion page embeds `FusionHero` (the start-screen animation, reused as-is); the Mirror Flip page gets a new `lib/ui/widgets/mirror_flip_demo.dart` — a looping 3D card-flip showing a piece's triangle-half assignment swapping in place; the Cavity Fill page gets a new static `lib/ui/widgets/cavity_fill_diagram.dart` before/after pair. Both new widgets respect the OS-level "reduce motion" flag the same way `FusionHero` does.
- **No longer locked to first launch**: added a permanent "How to Play" entry point on the start screen's header icon row and a "How to Play" row in Settings' new Help card — either one reopens the exact same overlay and marks it seen, so a player who skipped it (or wants a refresher) isn't locked out for good.

101 tests total, `flutter analyze`/`dart format`/release web build all green.

### Mobile HUD, achievement audio, per-mode music, and a real reset bug ✅ Implemented

A follow-up survey targeted three specific gaps (the mobile HUD was still the least-juiced surface, achievement unlocks were purely silent until the Results screen, Arcade/Sprint/Ultra/Classic/Daily all shared one "marathon" music loop) and, while checking the newer `GameAnimations` controllers, turned up a genuine correctness bug:

- **Fixed a real bug**: `celebration` and `levelUp` (the new-best flash and level-up flash) were never stopped or zeroed at run-start, unlike `danger`/`comboHeat` — a fast "Play Again" right after a new-best game-over could carry a still-animating celebration flash into the first frames of the new run. Consolidated into `GameAnimations.resetForNewRun()`, which stops and zeroes every transient controller (including particles) in one place, called from `_startGame()`.
- **Mobile HUD now carries danger/combo feedback**: `MobileStatsBar`'s top border now pulses red under danger and glows accent-to-red with combo heat — the same signals the board already shows, previously invisible on the compact mobile layout since neither `MobileStatsBar` nor `GameSidePanel` had ever been given access to `GameAnimations`.
- **Achievement unlocks get a distinct sting**: a new `Sfx.achievementUnlock` cue (`tool/generate_audio.py`) plays once, timed to the Results screen's reveal, whenever a run unlocks at least one achievement — previously a unlock was visually shown on the Results screen but had no audio cue of its own at all.
- **Arcade gets its own music** (`MusicTrack.arcade`, `music_arcade_loop.wav`): a punchier lead-over-bass loop distinct from the shared "marathon" bed, matching Arcade's manual speed-boost adrenaline. Chill/Zen keep the calm ambient loop; Classic/Sprint/Ultra/Daily keep marathon.

108 tests total, `flutter analyze`/`dart format`/release web build all green.

### Adversarial QA pass ✅ Implemented

After several rounds of rapid feature work, three parallel adversarial code reviews (core game loop/animation state, the UI/dialog layer, and the persistence/input layer) were run specifically to find correctness bugs before building further — not more features, a deliberate stop to verify what already shipped. All three found genuine, traceable issues:

- **Fixed a critical race**: the game's own advertised instant-restart shortcuts (Space, the mobile Play button) could fire `_startGame()` while `_finishGame()`'s persistence/analytics work for the *previous* run was still in flight — resetting `_score`/`_lines`/`_lastReplay` out from under a still-running score/leaderboard submission, mislabeling or silently dropping it, and in the worst case leaving a stale Results dialog modal over an already-running second game. Fixed with a `_finishingGame` guard flag, cleared before the Results dialog opens (not around it) so a legitimate Play Again tapped from inside that dialog is never mistaken for the race.
- **Fixed a use-after-dispose risk**: `_finishGame` touched `setState`/`GameAnimations` (the new-best toast, celebration trigger, particle burst) *before* its only `mounted` check, reachable by backing out of the app right after a run ends. Added the missing check.
- **Fixed a real data-corruption bug**: `DailyChallengeService.recordResult` wasn't idempotent — a second same-day call (a caller bug, a retry, two sessions racing) read its own just-written date as "not yesterday" and collapsed a real streak back down to 1 while double-counting `completedCount`. Now a no-op if today's result is already recorded.
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

The original Daily Challenge (`ROADMAP.md` Phase 2) was a normal marathon run on a seeded board — same mechanic as Classic, just with a shared daily seed and a streak counter. That undersold the "daily puzzle" framing `GDD.md` §5/§6.3 actually wanted: a puzzle players solve once a day, not another endurance run. Redesigned it into a proper board-clearing puzzle:

- **`GameModeConfig.startsPrefilled`** (`lib/models/game_mode.dart`): Daily Challenge now spawns with the board already roughly half-filled via `GameBoard.seedPuzzle` — a deterministic mix of full/single-triangle cells seeded from the same day-derived seed as the piece bag (its own `Random` instance, so puzzle-layout draws never perturb piece-bag draws or vice versa), retrying any row that would generate 100% full (a pre-solved row would just sit there blocking play).
- **New `EndCondition.boardCleared`**: the run now ends — as a win — the instant `_board.isEmpty` after a clear, instead of only ending by topping out. Wired in `game_screen.dart`, alongside the existing Ready-countdown treatment (now also triggered for `startsPrefilled`, giving the player a beat to survey the puzzle before gravity starts).
- **`DailyChallengeService.todaysCleared`**: tracks whether today's attempt actually cleared the board versus topping out first, stored alongside the existing streak/score/completed-count fields, surfaced on the mode card and in the recap dialog.
- Every other Daily Challenge mechanic (one attempt per calendar day, consecutive-day streak, device-local seed derivation, the caveat about needing a real server for cross-player validation) is unchanged from Phase 2 — this was a win-condition/board-state change, not a rebuild of the daily-cadence machinery.

138 tests total, `flutter analyze`/`dart format`/release web build all green.

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
| 3 | Firebase: accounts, backup, analytics, leaderboards | ✅ Code written · ⏸️ inert without a real Firebase project | Phases 1, 2; a Firebase project the account owner creates |
| 4 | RevenueCat subscriptions + cosmetic store | ✅ Code written · ⏸️ inert without a real RevenueCat account + store listings | Phase 3; a RevenueCat account the account owner creates |
| 5 | Store submission | Not started | Phases 0–4 |

**Recommendation:** playtest the Phase 0–2 game (including non-Tetris-fluent players, to validate Chill mode per `GDD.md` §12) — that part is real and running today. Phases 3–4 are written and tested against their own "degrades gracefully" contract (`test/live_services_test.dart`), but every line of it is inert until a real Firebase project and RevenueCat account exist; there's no benefit to activating them before the game itself is proven fun, and no cost to having the code sit ready in the meantime. Known open items, for whenever they're picked back up: a commissioned audio pack to replace the synthesized placeholder set, growing the achievement roster further toward the full 20–30, the `submitScore` full-replay-validation TODO, `firebase_app_check`/`firebase_remote_config` (deliberately not added yet — genuinely optional until there's real traffic), and — before any of Phase 3/4 goes live — the actual Firebase/RevenueCat/developer accounts only the project owner can create.
