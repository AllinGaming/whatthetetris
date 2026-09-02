# What the Triangle

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-live-brightgreen)](https://allingaming.github.io/whatthetetris/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-Source--Available-blue.svg)](LICENSE)

Neon triangle-based falling-blocks. The playfield uses triangle halves instead of full squares; opposite halves merge into a full cell when they meet. Seven-bag randomization, a ghost piece, hold slot, three-piece queue, wall kicks, lock delay, music/SFX, and responsive controls support competitive play across web, iOS, and Android.

Full game design, technical architecture (analytics/accounts/subscriptions), monetization design, and the phased roadmap live in [docs/](docs/) — see [docs/GDD.md](docs/GDD.md) for the design rationale behind everything below.

## Modes

| Mode | Category | What's different |
|---|---|---|
| **Classic** | Endless | A narrower 8-column board, five familiar shapes (I/O/T/L/J), a capped speed curve, and two starting cavity fills. Reaching the top ends the run normally. |
| **Daily Challenge** | Puzzle | A deterministic terrain formation 2–7 rows high, shared by everyone that day. Uses Classic's five shapes and capped pace; reduce the stack until no more than one occupied row remains to win, then retry as often as you like to improve today's best. Successful solves earn up to 5,000 extra points based on active solve time. The streak and completion count advance once per day. |
| **2 Player** | Online co-op | Create or join a six-character room-code lobby. The host always drops red bottom-left triangles and the guest always drops blue top-right triangles onto one shared 8×20 board. Both pieces fall simultaneously; Mirror is disabled, and each player has their own cavity fill and landing preview. After top-out, only the host sees **Play Again for Both**; its new-round snapshot restarts both peers. Team combos, back-to-back clears, level-scaled line and Fusion scoring, particles, flashes, impact effects, haptics, and event toasts give co-op the same polish as solo play. The shared score has a local personal best and an online leaderboard. |
| **2 Player Mirror** | Online co-op | Uses the same shared-board rules, scoring, effects, room codes, and red/blue ownership as 2 Player, but both players can Mirror their own falling piece. A player's color never swaps when its triangle orientation flips. This variant has its own local best and online leaderboard so its more flexible rules do not mix with fixed-orientation rankings. |
| **2 Player Puzzle** | Online co-op puzzle | Starts from a seeded Daily-style formation 2–7 rows high on a 16×8 shared board. Both players can Mirror their own pieces, keep permanent red/blue ownership, and start with two personal cavity fills. Reduce the locked formation to one occupied row to win. Faster team solves earn up to 5,000 extra points. It uses the same room-code flow, host-authoritative effects, host-controlled rematch, local ghost previews, and a separate friendly leaderboard. |

The legacy Classic, Arcade, Sprint, Ultra, and Zen implementations remain in code for compatibility and possible future experiments, but are hidden from mode select based on player feedback.

Puzzle speed scoring is shared by Daily Challenge and 2 Player Puzzle: a successful solve earns `max(0, 5000 - 10 × whole active seconds)`. A loss earns no completion bonus. Daily excludes the ready countdown and paused time; 2 Player uses the host's round clock and sends the awarded bonus in the final peer snapshot so both players receive the same score. The projected award is visible during play and the final award appears in the results. It is added before the existing personal-best and leaderboard checks, so it creates no additional Firestore write path.

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
- Audio: the speaker button in every game HUD instantly mutes/unmutes both music and sound effects; mode select also exposes a persistent music-only slider with a quieter 25% default
- Speed up (Arcade only): button in the side panel (higher speed = faster ticks + score multiplier)
- Menu: the ☰ button in the side panel returns to mode select
- Settings (⚙, from mode select): cosmetic theme picker, music/SFX volume, mute, reduce motion, haptics toggle, text/UI size, touch controls, Cloud Backup status, and in-app Privacy Policy/Terms access
- Stats & Achievements (🏆, from mode select): lifetime stats and a curated achievement list
- Login: choose a 3–20 character public player name, then use email and password to create or restore a reusable Firebase identity; a generated fallback name keeps anonymous Firebase play working before login
- Leaderboards: authenticated Classic, Daily, fixed 2 Player, 2 Player Mirror, and 2 Player Puzzle rankings display each anonymous or logged-in Firebase player's chosen name; email addresses are never shown
- 2 Player: one player creates a room and shares its six-character code; the second joins that code. Arrow/WASD movement, Q/W rotation, Space hard drop, and G/**Fill** control that player's own piece and cavity-fill charge. Mirror and Puzzle also enable M or the **Mirror** button while keeping red/blue ownership. Each peer sees a ghost only for their own piece. At round end, the guest waits while the host's **Play Again for Both** starts the next synchronized round.

**Mobile / narrow window** (<600px wide — native iOS/Android, or a resized browser window): a two-row touch pad provides movement, rotation, mirror, hold, hard drop, cavity fill, and Arcade speed boost. Directional controls repeat while held; one-shot actions never repeat. Controls use 48px targets, tooltips, and semantic labels. Mobile locks to portrait.

## Rules & Buffs
- Pieces are built from single triangles; opposite halves can overlap to form full squares.
- Seven shapes remain implemented, but visible modes use the simpler I4/O4/T4/L4/J4 set.
- Visible modes use a five-bag randomizer, so every full cycle contains every available shape exactly once.
- Line scoring is single 100, double 300, triple 500, four-line clear 800 (scaled by level). Level increases every 10 lines. Clearing 4 lines at once triggers a "TRIANGLE!" banner; consecutive clears build a combo counter.
- **Fusion Bonus**: locking a piece that completes one or more cells by fusing a triangle half onto a half *already on the board* (rather than an empty cell) awards bonus points, its own toast, and a gold particle burst — a skill-expressive scoring layer unique to the triangle mechanic.
- **Back-to-back**: consecutive four-line clears (or heavy-fusion clears) award an escalating bonus — it resets on any clear that doesn't qualify, but survives a non-clearing lock in between.
- Classic and Daily use a capped speed curve that plateaus instead of becoming relentlessly faster.
- Your best score and best level are saved locally per solo mode and shown on the mode-select screen; all three 2 Player variants save independent shared-team bests, and Sprint additionally tracks a best completion time.
- Classic, Daily, and 2 Player Puzzle start with two cavity filler charges per player. Fixed and Mirror 2 Player start each peer with one personal charge. Each cleared line awards one charge only to the player whose lock or fill completed it; it is never duplicated to both players.
- Arcade only: up to eight useful speed boosts stack at 20% faster per press. Boosts do not grant free points; they increase earned score by 15% each and stop once another boost would no longer increase gravity.

## Cosmetics & Meta Systems
- **Themes**: three free cosmetic palettes (Neon, Colorblind-Safe, Sunset) swap piece colors, board background, and UI accent as one unit from Settings. Colorblind-Safe uses an Okabe-Ito-derived palette chosen so all seven pieces stay distinguishable under protanopia/deuteranopia/tritanopia simulation.
- **Stats & Achievements**: lifetime totals (games played, lines cleared, four-line clears, Fusion Bonuses, best combo, mirror flips, cavities filled, playtime), a "recent form" sparkline (your last 20 runs, each as a % of that mode's personal best), and a 29-achievement set spanning onboarding through mastery.
- **Accessibility**: reduce-motion (now also respected by the start-screen/tutorial animations, not just in-game effects), haptics toggle, a text/UI scale slider, and a one-handed touch-control layout that clusters every mobile control toward the left or right thumb instead of spanning the full screen width.
- **How to Play**: a 6-page walkthrough (movement, Mirror Flip, Fusion Bonus, Back-to-Back & Combo, Hold & Cavity Fill, picking a mode) shown automatically on your first-ever game — but not locked to that moment. A "How to Play" button on the start screen and in Settings reopens the exact same overlay any time. The Mirror Flip and Fusion pages show small looping animations of the actual mechanic instead of just describing it in text.
- **Share**: once a run ends, a Share button (side panel on desktop, an icon on mobile) offers Copy game link, X, Facebook, and WhatsApp. The 2 Player lobby uses the same email-free panel and includes the room code in its invite.
- **Results screen**: every run ends with a recap — final score, level, lines, duration, and (when relevant) four-line clears/Fusion Bonuses/mirror flips/cavity fills, plus any achievement that unlocked *because of that run*, before Play Again/Share/Menu.
- **Ready countdown**: Sprint and Ultra open with a brief "3-2-1-GO" beat before the clock (and gravity) start, so the timer never starts while you're still getting oriented. Skipped on your very first-ever game, where the tutorial already covers that pause.
- **Pause Menu**: pausing opens a real menu — mode, live score/level/lines, and Resume/Restart/Settings/Quit — instead of a bare dimmed screen. Restart and Quit both ask for confirmation first.
- **Feel**: solo and 2 Player hard drops and big line clears shake the screen harder the more dramatic they are (drop distance, clear size), and longer hard drops land with expanding impact rings. Co-op also renders host-authoritative line flashes, Fusion bursts, combo/back-to-back celebrations, danger glow, level-up flash, and a shared new-best celebration on both peers.
- **2 Player clarity and performance**: co-op paints red/blue particles and player-colored hard-drop shockwaves above every board flash, gives particles a bright core so they remain visible over occupied cells, and caps the live particle pool during simultaneous clears. Particles hold before fading, co-op flashes and impact rings use longer presentation timing, and simultaneous peer events receive a short visual-only stagger. Fusion, clear, combo, and back-to-back awards from one action are consolidated into one high-contrast score card that remains readable for 1.85–2.4 seconds. A score-first responsive HUD keeps the shared score, objective, best, level, combo, and each player's clear contribution readable; the result panel repeats the large team score and red/blue split.
- **Combo glow & level-up flash**: a combo streak now pulses a soft colored glow around the board that intensifies as the chain grows, and leveling up adds a brief board-wide flash on top of the existing toast — ambient feedback to match the danger-zone border pulse.
- **Fusion hero**: the start screen opens with a small looping animation acting out the fusion mechanic — two triangle halves merging into a full cell — before you've even picked a mode.
- **New-best celebration**: hitting a new personal best triggers a warm board-wide flash, a particle shower, and a heavy haptic, with a short beat before the results screen appears so it's actually seen. Game-over haptics are now tiered: new best > achievement unlock > plain run-ended.
- **Mobile HUD feedback**: the compact mobile stats bar's top border now pulses red under danger and glows toward red with combo heat — the same signals the board shows, brought to the mobile layout too.
- **Settings, restyled**: Appearance/Audio/Accessibility/Cloud Backup now sit in bordered cards matching the rest of the app, every row has an icon, and the volume/UI-size sliders all show a live percentage at rest.

## Audio
Every action has music/SFX feedback — move, rotate, mirror, drops, lock, line clears (scaled by count), four-line-clear fanfare, Fusion Bonus shimmer, combo ticks, cavity fill, level up, game over, new-best, an achievement-unlock sting, and a danger-zone warning (pulsing red border + tone) once the stack creeps into the top rows. Menus and room waiting loop `tmusic.mp3`; every gameplay mode loops `zen_classic_arcade_music.mp3` and restores the menu music on exit. Music defaults to 25%, remains independent of the SFX volume, and can be changed directly from the mode-select slider or Settings.

The SFX in `assets/audio/` are programmatically synthesized by `tool/generate_audio.py`; `tmusic.mp3` and `zen_classic_arcade_music.mp3` are supplied tracks and are not overwritten by that generator. Regenerate the synthesized set with `python3 tool/generate_audio.py`.

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
- Every run's inputs are recorded locally into a versioned replay format (`lib/game/replay.dart`, seed + timestamped input log). Replays are not uploaded by the current lightweight leaderboard implementation.
- Best score/level/time, including the 2 Player team best, remain local to the device. Eligible new personal bests are also submitted to the selected online leaderboard; cloud backup remains disabled.
- App icons for iOS/Android/web are generated from `assets/icon/` via `flutter_launcher_icons` (`flutter_launcher_icons.yaml`) — regenerate with `dart run flutter_launcher_icons` after changing the source art.
- Legacy deployment identifiers still contain the former slug in the Dart package name, GitHub Pages route, Firebase project, and native bundle IDs. They are not displayed as the product name and remain temporarily to preserve imports, live services, update identity, and the existing URL. Renaming them requires a coordinated repository/Firebase/store migration rather than a text-only release.

## Live Services
The GitHub Pages web build uses the production Firebase web app for Analytics, anonymous-by-default accounts, authenticated Classic/Daily/fixed-2-Player/Mirror-2-Player/Puzzle-2-Player leaderboards, and 2 Player room signaling. A successful room setup uses four writes to one room document: host reservation (including the selected variant), gathered offer, guest claim, and gathered answer. ICE candidates are bundled into the offer/answer instead of becoming separate Firestore documents. After the data channel connects, signaling listeners stop and gameplay is fully peer-to-peer. Players copy the six-character room code and share it themselves through messaging, social, or voice chat—there is no in-game friends system.

Cloud backup, VIP, Firebase Functions, and native-platform Firebase remain disabled. Email login is optional; anonymous accounts have the same leaderboard eligibility. Players choose a public, non-unique name, stored as the Firebase Auth display name and copied into score entries so rankings are readable without exposing email addresses. Creating an email account links the current anonymous Firebase identity so its leaderboard UID is preserved, while logging into an existing email account restores that account's UID and name. The client submits only new local personal bests, and a Firestore transaction writes only when the score also improves that player's remote best. Changing a name checks only that player's existing Classic, all three 2 Player variants, and current Daily entries and writes only documents whose name changed. Rankings load the top 10 once per board per session, stay cached while the game is open, and query again only after a successful submission or an explicit refresh.

Firebase console setup still required:
1. Enable **Anonymous** in Authentication → Sign-in method.
2. Enable **Email/Password** in Authentication → Sign-in method. Leave email-link authentication disabled; the game uses passwords.
3. Add `allingaming.github.io` under Authentication → Settings → Authorized domains.
4. Create the Firestore database, then deploy the access rules with `firebase deploy --only firestore:rules`. No Functions deployment is required.
5. Configure Firestore TTL for `multiplayerRooms.expiresAt` so abandoned signaling rooms are removed.
6. Review the Firebase Authentication verification and password-reset templates so the sender name, support address, action URL, and copy are production-ready.
7. Add production TURN credentials to `MultiplayerSessionService` before wide release. Public STUN is sufficient for initial development, but cannot connect every restrictive NAT/firewall pair.

The Privacy Policy and Terms of Use are stored in `PRIVACY.md` and `TERMS.md` and are bundled into the app under Settings → Legal. They are product drafts and should be reviewed by qualified counsel before a broad commercial release.

### Analytics reporting

Analytics uses the random Firebase Auth UID to group repeat activity. A login email is handled by Firebase Authentication and is not added to Analytics event parameters. Analytics records mode selection and solo starts/results; tutorial, stats, settings, and Daily retries; and the 2 Player create/join/share/connection/round/restart funnel with a fixed, Mirror, or Puzzle variant tag. Co-op controls are reported only as per-round totals. Room codes and gameplay snapshots are never included in Analytics events.

| Report question | Events |
|---|---|
| Which modes and features are used? | `mode_selected`, `game_start`, `game_over`, `feature_selected`, `daily_retry` |
| Where do multiplayer players drop out? | `multiplayer_lobby_viewed`, `multiplayer_lobby_action`, `multiplayer_connection` |
| Do connected players engage and replay? | `multiplayer_round_started`, `multiplayer_round_ended`, `multiplayer_restarted` |
| Which mechanics are used? | `line_clear`, `fusion_bonus`, `four_line_clear`, `combo`, `mirror_used`, `cavity_fill_used` |

In Google Analytics, open **Admin > Custom definitions** and register event-scoped dimensions for `mode`, `feature`, `action`, `result`, `role`, `reason`, and `variant`; register event-scoped metrics for `duration_ms`, `score`, `level`, `lines`, `speed_bonus`, `wait_ms`, `moves`, `rotations`, `soft_drops`, `hard_drops`, and `round_number`; and register `last_mode` as a user-scoped dimension. These definitions make the custom parameters available in Explorations and custom reports.

Full design/status detail lives in `docs/TECHNICAL_ARCHITECTURE.md`, `docs/MONETIZATION.md`, and `docs/ROADMAP.md` Phase 3/4.

## License

Copyright © 2024–2026 AllinGaming (GitHub: [@allingaming](https://github.com/allingaming)). The current project is source-available for personal, educational, research, evaluation, and other non-commercial use. Commercial use is reserved to AllinGaming and parties separately authorized in writing. This is not an MIT or OSI-approved open-source license; see [LICENSE](LICENSE) for the complete terms. Third-party components remain under their own licenses.

Earlier versions that were already published under MIT retain the permissions granted for those versions. The current licensing text is a project-owner draft and should be reviewed by qualified intellectual-property counsel before relying on it commercially.

## Deploy (GitHub Pages)
- GitHub Actions workflow `deploy.yml` builds `flutter build web --release --base-href=/whatthetetris/` and publishes the `build/web` artifact via GitHub Pages on every push to `main` (no separate branch needed).
- Both pull requests and deployments must pass formatting, analysis, tests, and a release web build. Flutter is pinned to 3.44.4.
- Ensure Pages is set to “GitHub Actions” in the repo settings.
- Native store preparation is tracked in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).
