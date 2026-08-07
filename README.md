# What the Tetris

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-live-brightgreen)](https://allingaming.github.io/whatthetetris/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Neon triangle-based falling-blocks. The playfield uses triangle halves instead of full squares; opposite halves merge into a full cell when they meet. Pick **Classic** for a steady, predictable climb, or **Arcade** for a faster, steeper one plus capped risk/reward speed boosts. Seven-bag randomization, a ghost piece, hold slot, three-piece queue, wall kicks, lock delay, and responsive controls support competitive play across web, iOS, and Android.

## Modes
- **Classic** — the steady, predictable speed curve (starts at 700ms/row, decays gently). No speed-boost stacking.
- **Arcade** — a faster, steeper speed curve from the very first piece (starts at 600ms/row and escalates much more aggressively), plus a stackable manual speed-boost button for extra risk/reward scoring on top.

Both modes include cavity fillers, use the same 7-piece triangle-half set, and share the same controls below.

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

**Mobile / narrow window** (<600px wide — native iOS/Android, or a resized browser window): a two-row touch pad provides movement, rotation, mirror, hold, hard drop, cavity fill, and Arcade speed boost. Directional controls repeat while held; one-shot actions never repeat. Controls use 48px targets, tooltips, and semantic labels. Mobile locks to portrait.

## Rules & Buffs
- Pieces are built from single triangles; opposite halves can overlap to form full squares.
- Seven shapes: I4, L4, J4, T4, O4, S4, Z4 — all still single-triangle, uniform-diagonal pieces.
- Pieces use a seven-bag randomizer, so every seven draws contain every shape exactly once.
- Line scoring matches Tetris: single 100, double 300, triple 500, Tetris 800 (scaled by level). Level increases every 10 lines. Clearing 4 lines at once triggers a "TETRIS!" banner; back-to-back clears build a combo counter.
- Difficulty has no early ceiling — the speed curve keeps tightening smoothly the longer a run lasts. Arcade's curve is steeper than Classic's by default, independent of the speed-boost button.
- Your best score and best level are saved locally per mode and shown on the mode-select screen.
- You start with 1 cavity filler charge; each cleared line grants +1 charge.
- Arcade only: up to eight useful speed boosts stack at 20% faster per press. Boosts do not grant free points; they increase earned score by 15% each and stop once another boost would no longer increase gravity.

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
- Best score and level remain local to the device. See [PRIVACY.md](PRIVACY.md).
- App icons for iOS/Android/web are generated from `assets/icon/` via `flutter_launcher_icons` (`flutter_launcher_icons.yaml`) — regenerate with `dart run flutter_launcher_icons` after changing the source art.

## Deploy (GitHub Pages)
- GitHub Actions workflow `deploy.yml` builds `flutter build web --release --base-href=/whatthetetris/` and publishes the `build/web` artifact via GitHub Pages on every push to `main` (no separate branch needed).
- Both pull requests and deployments must pass formatting, analysis, tests, and a release web build. Flutter is pinned to 3.44.4.
- Ensure Pages is set to “GitHub Actions” in the repo settings.
- Native store preparation is tracked in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).
