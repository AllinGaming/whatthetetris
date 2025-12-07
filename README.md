# What the Tetris

[![Deploy Web](https://github.com/allingaming/whatthetetris/actions/workflows/deploy.yml/badge.svg)](https://github.com/allingaming/whatthetetris/actions/workflows/deploy.yml)
[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-live-brightgreen)](https://allingaming.github.io/whatthetetris/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Fast, triangle-based falling-blocks with cavity helpers and speed boosts. Scoring/leveling follow classic Tetris values; the playfield uses triangle halves.

## How to Play
- Move: Arrow keys
- Rotate: Arrow Up / W
- Mirror triangles: M
- Hard drop: Space
- Pause: P
- Cavity fill: G (fills one missing half-cell from the bottom up)
- Speed up: Button in the side panel (higher speed = faster ticks + score multiplier)

## Rules & Buffs
- Pieces are built from single triangles; opposite halves can overlap to form full squares.
- Line scoring matches Tetris: single 100, double 300, triple 500, Tetris 800 (scaled by level). Level increases every 10 lines.
- You start with 1 cavity filler charge; each cleared line grants +1 charge. A cavity fill completes one missing half-cell starting from the bottom.
- Speed boosts stack (20% faster per press) and add a small score kicker for risk/reward.

## Running
```bash
flutter run
```

## Notes
- Mirroring flips triangle orientation only (piece position stays put).
- Cavity fills prioritize the lowest rows first.

## Deploy (GitHub Pages)
- GitHub Actions workflow `deploy.yml` builds `flutter build web --release` and publishes `build/web` to the `gh-pages` branch on every push to `main`.
- Ensure Pages is set to deploy from the `gh-pages` branch in the repo settings.
