# What the Tetris

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-live-brightgreen)](https://allingaming.github.io/whatthetetris/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Neon triangle-based falling-blocks. The playfield uses triangle halves instead of full squares; opposite halves merge into a full cell when they meet. Seven-bag randomization, a ghost piece, hold slot, three-piece queue, wall kicks, lock delay, music/SFX, and responsive controls support competitive play across web, iOS, and Android.

Full game design, technical architecture (analytics/accounts/subscriptions), monetization design, and the phased roadmap live in [docs/](docs/) — see [docs/GDD.md](docs/GDD.md) for the design rationale behind everything below.

## Modes

| Mode | Category | What's different |
|---|---|---|
| **Chill** | Marathon | Narrower 8-column board, a 5-piece pool that drops the two hardest-to-read shapes (S4/Z4), a speed curve with a real ceiling, and a "soft floor" — a spawn that would top out instead clears space so the run keeps going. The easy on-ramp. |
| **Classic** | Marathon | The steady, predictable speed curve (starts at 700ms/row, decays gently). No speed-boost stacking. |
| **Arcade** | Marathon | A faster, steeper speed curve from the very first piece, plus a stackable manual speed-boost button for extra risk/reward scoring on top. |
| **Sprint** | Timed | Clear 40 lines as fast as possible, fixed pace — the clock is the score. Tracks a separate best-time record. |
| **Ultra** | Timed | Score as much as you can in 2 minutes, on the Classic curve. |
| **Zen** | Practice | Fixed slow pace, never escalates, soft floor keeps it going indefinitely — practice fusion timing and mirroring with zero stakes. |
| **Daily Challenge** | Puzzle | One attempt per calendar day on a board that starts **half-filled** with the same deterministic layout for every player that day — clear it back down to empty to win, rather than surviving as long as possible. Tracks a consecutive-day streak (🔥 on the mode card) and whether today's attempt actually cleared. Comes back with a fresh layout tomorrow. Device-local for now — see the note in `lib/services/daily_challenge_service.dart` about what a real cross-player Daily Challenge still needs. |

All modes share the same 7-piece triangle-half catalog (Chill uses a 5-piece subset), the same controls below, and the same cavity-filler/fusion/scoring mechanics.

## How to Play

**Desktop / web** (window ≥600px wide):
- Move: Arrow keys, or the ◀/▼/▶ buttons in the side panel
- Rotate right: Arrow Up / W (also a side-panel button)
- Rotate left: Q / Z (also a side-panel button)
- Mirror triangles: M (also a side-panel button)
- Hold piece: C or either Shift key
- Hard drop: Space
- Pause: P or Escape
- Cavity fill: G — fills one missing half-cell from the bottom up
- Speed up (Arcade only): button in the side panel (higher speed = faster ticks + score multiplier)
- Menu: the ☰ button in the side panel returns to mode select
- Settings (⚙, from mode select): cosmetic theme picker, music/SFX volume, mute, reduce motion, haptics toggle, text/UI size, a one-handed touch-control layout (balanced/left/right), and a Cloud Backup section (see "Live Services" below — currently inactive)
- Stats & Achievements (🏆, from mode select): lifetime stats and a curated achievement list
- Leaderboards (🏆-adjacent icon, from mode select): per-mode top scores — currently shows "not available yet" (see "Live Services" below)
- VIP Pass (⭐, from mode select): the subscription paywall — currently shows "not available yet" (see "Live Services" below)

**Mobile / narrow window** (<600px wide — native iOS/Android, or a resized browser window): a two-row touch pad provides movement, rotation, mirror, hold, hard drop, cavity fill, and Arcade speed boost. Directional controls repeat while held; one-shot actions never repeat. Controls use 48px targets, tooltips, and semantic labels. Mobile locks to portrait.

## Rules & Buffs
- Pieces are built from single triangles; opposite halves can overlap to form full squares.
- Seven shapes: I4, L4, J4, T4, O4, S4, Z4 — all still single-triangle, uniform-diagonal pieces. Chill mode uses only I4/O4/T4/L4/J4.
- Pieces use a seven-bag randomizer (five-bag in Chill), so every full cycle contains every available shape exactly once.
- Line scoring matches Tetris: single 100, double 300, triple 500, Tetris 800 (scaled by level). Level increases every 10 lines. Clearing 4 lines at once triggers a "TETRIS!" banner; consecutive clears build a combo counter.
- **Fusion Bonus**: locking a piece that completes one or more cells by fusing a triangle half onto a half *already on the board* (rather than an empty cell) awards bonus points, its own toast, and a gold particle burst — this is this game's own answer to a T-spin bonus.
- **Back-to-back**: consecutive Tetrises (or heavy-fusion clears) award an escalating bonus, same spirit as classic Tetris back-to-back — resets on any clear that doesn't qualify, but survives a non-clearing lock in between.
- Difficulty has no early ceiling in Classic/Arcade — the speed curve keeps tightening smoothly the longer a run lasts. Chill and Zen use curves that plateau instead. Arcade's curve is steeper than Classic's by default, independent of the speed-boost button.
- Your best score and best level are saved locally per mode and shown on the mode-select screen; Sprint additionally tracks a best completion time.
- Cavity filler charges vary by mode (Classic/Arcade start at 1, Chill at 2, Zen at 3); each cleared line grants +1 charge.
- Arcade only: up to eight useful speed boosts stack at 20% faster per press. Boosts do not grant free points; they increase earned score by 15% each and stop once another boost would no longer increase gravity.

## Cosmetics & Meta Systems
- **Themes**: three free cosmetic palettes (Neon, Colorblind-Safe, Sunset) swap piece colors, board background, and UI accent as one unit from Settings. Colorblind-Safe uses an Okabe-Ito-derived palette chosen so all seven pieces stay distinguishable under protanopia/deuteranopia/tritanopia simulation.
- **Stats & Achievements**: lifetime totals (games played, lines cleared, Tetrises, Fusion Bonuses, best combo, mirror flips, cavities filled, playtime), a "recent form" sparkline (your last 20 runs, each as a % of that mode's personal best — normalized so Chill and Ultra scores can share one chart honestly), and a 29-achievement set spanning onboarding through mode-specific mastery, unlocked state derived live from those totals rather than stored separately.
- **Accessibility**: reduce-motion (now also respected by the start-screen/tutorial animations, not just in-game effects), haptics toggle, a text/UI scale slider, and a one-handed touch-control layout that clusters every mobile control toward the left or right thumb instead of spanning the full screen width.
- **How to Play**: a 6-page walkthrough (movement, Mirror Flip, Fusion Bonus, Back-to-Back & Combo, Hold & Cavity Fill, picking a mode) shown automatically on your first-ever game — but not locked to that moment. A "How to Play" button on the start screen and in Settings reopens the exact same overlay any time. The Mirror Flip and Fusion pages show small looping animations of the actual mechanic instead of just describing it in text.
- **Share**: once a run ends, a Share button (side panel on desktop, an icon on mobile) opens the native share sheet with your score/level or Sprint time.
- **Results screen**: every run ends with a recap — final score, level, lines, duration, and (when relevant) Tetrises/Fusion Bonuses/mirror flips/cavity fills, plus any achievement that unlocked *because of that run*, before Play Again/Share/Menu.
- **Ready countdown**: Sprint and Ultra open with a brief "3-2-1-GO" beat before the clock (and gravity) start, so the timer never starts while you're still getting oriented. Skipped on your very first-ever game, where the tutorial already covers that pause.
- **Pause Menu**: pausing opens a real menu — mode, live score/level/lines, and Resume/Restart/Settings/Quit — instead of a bare dimmed screen. Restart and Quit both ask for confirmation first.
- **Feel**: hard drops and big line clears shake the screen harder the more dramatic they are (drop distance, clear size), and a hard drop of 3+ rows lands with an expanding impact ring at the landing cell.
- **Combo glow & level-up flash**: a combo streak now pulses a soft colored glow around the board that intensifies as the chain grows, and leveling up adds a brief board-wide flash on top of the existing toast — ambient feedback to match the danger-zone border pulse.
- **Fusion hero**: the start screen opens with a small looping animation acting out the fusion mechanic — two triangle halves merging into a full cell — before you've even picked a mode.
- **New-best celebration**: hitting a new personal best triggers a warm board-wide flash, a particle shower, and a heavy haptic, with a short beat before the results screen appears so it's actually seen. Game-over haptics are now tiered: new best > achievement unlock > plain run-ended.
- **Mobile HUD feedback**: the compact mobile stats bar's top border now pulses red under danger and glows toward red with combo heat — the same signals the board shows, brought to the mobile layout too.
- **Settings, restyled**: Appearance/Audio/Accessibility/Cloud Backup now sit in bordered cards matching the rest of the app, every row has an icon, and the volume/UI-size sliders all show a live percentage at rest.

## Audio
Every action has music/SFX feedback — move, rotate, mirror, drops, lock, line clears (scaled by count), Tetris fanfare, Fusion Bonus shimmer, combo ticks, cavity fill, level up, game over, new-best, an achievement-unlock sting, and a danger-zone warning (pulsing red border + tone) once the stack creeps into the top rows. Music switches per mode: a calmer ambient loop for Chill/Zen, a punchier high-energy loop for Arcade, and a steady climbing loop for Classic/Sprint/Ultra/Daily Challenge.

The current audio set (`assets/audio/`) is programmatically synthesized by `tool/generate_audio.py` — real, distinct sounds that ship today rather than silence, meant to be swapped for a commissioned pack later (see `docs/GDD.md` §7). Regenerate it with `python3 tool/generate_audio.py`.

## Running
```bash
flutter run                 # picks a connected device/simulator/browser
flutter run -d chrome       # web
flutter run -d <ios-sim-id> # iOS Simulator (flutter devices to list)
flutter run -d <android-id> # Android emulator/device
flutter analyze             # static analysis
flutter test                # unit and widget regression suite
```

## Notes
- Mirroring flips triangle orientation only (piece position stays put).
- Cavity fills prioritize the lowest rows first.
- Deterministic board rules live in `lib/game/game_board.dart`; piece sequencing lives in `piece_bag.dart`. Flutter widgets coordinate session timing and render those rules.
- Every run's inputs are recorded locally into a versioned replay format (`lib/game/replay.dart`, seed + timestamped input log) — groundwork for future server-validated leaderboards, not yet surfaced anywhere in the UI.
- Best score/level/time remain local to the device, same as audio, settings, and haptics preferences. See [PRIVACY.md](PRIVACY.md) — accurate as written, because every live-service call below fails closed against a placeholder config and never reaches a real network.
- App icons for iOS/Android/web are generated from `assets/icon/` via `flutter_launcher_icons` (`flutter_launcher_icons.yaml`) — regenerate with `dart run flutter_launcher_icons` after changing the source art.

## Live Services (code present, not active)
Anonymous cloud accounts, cross-device backup, analytics, crash reporting, leaderboards, and a VIP Pass subscription are fully coded — `lib/services/cloud_auth_service.dart`, `cloud_backup_service.dart`, `analytics_service.dart`, `leaderboard_service.dart`, `purchase_service.dart`, plus `firestore.rules` and `functions/src/index.ts` — but **inert**: `lib/firebase_options.dart` is an honestly-labeled placeholder, so every one of these calls fails closed and the game behaves exactly as if none of it existed. `test/live_services_test.dart` locks in that "never throws, always degrades" contract.

To activate:
1. Create a project at [console.firebase.google.com](https://console.firebase.google.com), run `dart pub global activate flutterfire_cli` then `flutterfire configure` from the repo root — this overwrites `lib/firebase_options.dart` with real values.
2. Deploy the backend pieces: `firebase deploy --only firestore:rules,functions` (from `functions/`, `npm install` first).
3. Create a RevenueCat account at [app.revenuecat.com](https://app.revenuecat.com), connect it to real App Store Connect/Play Console products (needs a paid Apple Developer Program membership and a Google Play Console account — both still open per [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)), and replace the placeholder key in `lib/services/purchase_service.dart`.
4. **Rewrite [PRIVACY.md](PRIVACY.md) before shipping a build with real config** — see `docs/TECHNICAL_ARCHITECTURE.md` §7.

Full design/status detail lives in `docs/TECHNICAL_ARCHITECTURE.md`, `docs/MONETIZATION.md`, and `docs/ROADMAP.md` Phase 3/4.

## Deploy (GitHub Pages)
- GitHub Actions workflow `deploy.yml` builds `flutter build web --release --base-href=/whatthetetris/` and publishes the `build/web` artifact via GitHub Pages on every push to `main` (no separate branch needed).
- Both pull requests and deployments must pass formatting, analysis, tests, and a release web build. Flutter is pinned to 3.44.4.
- Ensure Pages is set to “GitHub Actions” in the repo settings.
- Native store preparation is tracked in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).
