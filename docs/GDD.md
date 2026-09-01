# What The Triangle — Game Design Document

**Status:** Living design document — Phases 0–4 implemented (see `ROADMAP.md` for the phase-by-phase log); retained as the original design brief, §3 kept current at a summary level
**Owner:** Design/Product
**Last updated:** 2026-08-15
**Companion docs:** [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) · [MONETIZATION.md](MONETIZATION.md) · [ROADMAP.md](ROADMAP.md)

---

## 1. Vision

**What The Triangle** is a neon falling-blocks game built on one real mechanical twist: every piece is made of **triangle halves**, not full squares. Opposite triangle halves fuse into a full cell when they meet, which gives spatial stacking under time pressure a second layer — *pairing*, not just placing. Add a mirror-flip action and a charge-based cavity filler, and the result reads as its own game.

The goal of this document is to take that mechanical core and wrap it in the systems, feel, and content depth that separate a solid solo-built puzzle game from polished falling-block games on mobile app stores. "S-tier" here means a stranger downloads it, plays for two minutes, and immediately understands the distinctive triangle-fusion mechanic and that the people who made it cared about every frame and every sound.

**Platforms:** iOS, Android, Web (already live at GitHub Pages). Portrait-first mobile, full desktop/keyboard support retained.

## 2. Design Pillars

Every new feature gets checked against these four pillars. If it doesn't serve at least one, it doesn't ship.

| Pillar | Meaning |
|---|---|
| **The fusion mechanic is the star** | Triangle-half pairing, mirroring, and cavity fills should stay central — new modes and scoring should exercise this mechanic, not bury it under generic falling-block features. |
| **Feel before features** | A game with fewer modes and flawless audio/game-feel beats a game with ten modes and a silent, stiff board. Juice is not a "nice to have" pass at the end — it's load-bearing. |
| **Fair monetization, never pay-to-win** | Money buys cosmetics, convenience, and support. It never buys a faster board, more time, or an easier curve than a free player gets. |
| **Respect the player's time and data** | No forced ads, no dark patterns, no silent data collection. Every system added (accounts, analytics, subscriptions) must have an honest, simple explanation a 12-year-old could read in the privacy policy. |

## 3. Current State (baseline, already shipped)

This section originally described the pre-Phase-0 baseline this whole document was written against. Nearly everything the doc proposed below has since shipped — see `ROADMAP.md` for the authoritative, phase-by-phase implementation log (status, exit criteria, test counts). This section is kept updated at a summary level so a reader of *this* doc alone isn't misled; treat `ROADMAP.md` as the source of truth for exact status.

- **Board:** 20×10 grid in legacy modes; the player-facing Classic is 8-wide and Daily Challenge is 8×16 (see §5). Triangle-half occupancy tracks full/bottom-left/top-right independently.
- **Piece set:** 7 shapes remain implemented. All four visible modes use the clearer I4/L4/T4/O4/J4 subset and a seedable 5-bag randomizer.
- **Core actions:** move, rotate (CW/CCW) with a simplified kick table (not full SRS — see §4.4 for the deliberate design call), mirror-flip (flips triangle orientation in place), hold (one per piece), hard drop, soft drop, cavity fill (consumes a charge to fill the lowest missing half-cell).
- **Modes:** Classic (the former Chill rules), Daily Challenge, fixed-orientation 2 Player, and 2 Player Mirror are visible. Legacy Classic, Arcade, Sprint, Ultra, and Zen remain implemented but hidden after player feedback showed little use.
- **Scoring:** line-clear table (100/300/500/800 × level), level up every 10 lines, combo counter, "TRIANGLE!" banner on 4-line clears, plus the Fusion Bonus (§4.1) and Back-to-Back chain (§4.2) both now implemented.
- **Feel:** neon glow rendering, particle bursts, lock flash, line-clear flash, hard-drop screen shake (scaled by severity), an expanding impact ring on hard drops, ambient combo/danger glows, floating toasts, haptic feedback (tiered by event).
- **Audio:** full music/SFX coverage for every action (§7's proposed scope is implemented), with supplied `tmusic.mp3` for menu/lobby waiting, supplied `zen_classic_arcade_music.mp3` for gameplay, and synthesized SFX from `tool/generate_audio.py`.
- **Meta systems:** Stats & Achievements (29 achievements), 3 cosmetic themes, a 6-page reopenable tutorial, replay recording, Firebase Analytics, anonymous or optional email/password web accounts with a chosen public player name, authenticated Classic/Daily/fixed-2-Player/Mirror-2-Player named leaderboards, and anonymous multiplayer signaling. Cloud backup, RevenueCat/VIP, Crashlytics, and native Firebase remain disabled (§10, `TECHNICAL_ARCHITECTURE.md`).
- **Persistence:** local best score/level/time per mode via `shared_preferences`, same for settings/haptics/stats. Web leaderboard identity uses Firebase Auth; cloud backup remains disabled.
- **Quality bar:** 175 automated test cases in the suite, `flutter analyze` clean, CI on every PR (format, analyze, test, web build), deployed to GitHub Pages.

## 4. Core Gameplay Deepening

### 4.1 Fusion Bonus (new)
Reward players for *using* the triangle mechanic well, not just clearing lines. When a locked piece completes one or more full cells by fusing with existing triangle halves already on the board (as opposed to landing on empty cells), award a small scoring bonus per fused cell, with its own toast ("FUSION x3") and a distinct particle color (gold vs. the standard clear-flash palette). This is a skill-expressive scoring layer built directly from the game's distinctive geometry.

### 4.2 Back-to-Back chain (new)
Consecutive four-line clears (or four-line-plus-Fusion clears) award an escalating multiplier, resetting on any clear that doesn't qualify. This pairs with the existing combo counter without replacing it — combo rewards *frequency*, back-to-back rewards *consistency of your best clears*.

### 4.3 Cavity filler tuning
Currently a single mechanic shared by both modes. Recommend: keep as-is for Classic/Arcade, but tune starting charges and gain-per-clear per mode difficulty (see §5 mode table) so easier modes feel generous and expert modes (Ultra/Sprint) feel scarce and tactical.

### 4.4 Rotation system — deliberate decision, not a gap
The current kick table (`[0, -1, 1, -2, 2]` plus one floor-kick) is simpler than SRS. **Recommendation: keep it, and say so explicitly in the README/store copy.** Exact square-piece kick tables do not obviously transfer to triangle-half geometry. Action item: playtest the current table specifically for "does it ever feel unfair," document it precisely in code, and market it honestly as "wall kicks tuned for triangle pieces," not "SRS."

## 5. Game Modes

Started as two modes (Classic, Arcade), both open-ended marathon runs. The requested "surprise me" pass plus the explicit ask for an easier on-ramp expanded this to the mode roster below — now fully implemented (`ROADMAP.md` Phase 2) — covering onboarding, mastery, short-session, and daily-puzzle play, the session shapes mobile puzzle players actually want.

| Mode | Audience / Session | Board | Piece pool | Speed curve | End condition |
|---|---|---|---|---|---|
| **Classic** *(formerly Chill, visible)* | Relaxed endless play | 8 columns (narrower), larger cell render | 5 shapes — I/O/T/L/J | Gentle decay with a true ceiling | Normal top-out game over |
| **Legacy Classic** *(hidden)* | Steady, familiar climb | 10×20, standard | 7 shapes | Gentle decay, no ceiling | Top-out |
| **Arcade** *(existing)* | Risk/reward chasers | 10×20, standard | 7 shapes | Steep decay, no ceiling, manual speed-boost stacking | Top-out |
| **Sprint** *(new)* | Short session, competitive | 10×20, standard | 7 shapes | Fixed, moderate | Clear 40 lines as fast as possible; timer is the score |
| **Ultra** *(new)* | Short session, competitive | 10×20, standard | 7 shapes | Classic curve | 2-minute clock; maximize score before time runs out |
| **Zen** *(new)* | No-pressure practice / flow state | 10×20, standard | 7 shapes | Fixed, slow, never escalates | Never ends (until player quits) — for practicing fusion timing and mirror usage without stakes |
| **Daily Challenge** *(visible)* | Retention, repeatable daily puzzle | 8×16, starts with a deterministic terrain formation 2–7 rows high | Classic's 5 shapes, same formation and order for every player that day | Capped Classic curve | Reduce the locked stack to at most one occupied row; unlimited retries, best result retained, streak advances once per day |
| **2 Player** *(visible)* | Online cooperative play through a shared six-character room code | One host-authoritative 8×20 board with two simultaneous falling pieces and a local-only landing ghost per peer | Classic's 5 shapes in independent seeded bags; host is always red/bottom-left and guest blue/top-right; each owns one starting cavity fill, and the player completing a line alone earns its recharge | Fixed 650 ms shared gravity | Normal shared top-out; level-scaled line/Fusion scoring, team combos, back-to-back hard-clear bonuses, and drop/lock points feed one shared score retained locally and on the friendly leaderboard; either peer can request a restart |
| **2 Player Mirror** *(visible)* | More flexible online cooperative play through the same room-code flow | Same host-authoritative 8×20 board and local-only ghost | Same five-shape bags and permanent red/blue player colors, but either player can Mirror their own active triangles and the chosen orientation carries into their next spawn | Fixed 650 ms shared gravity | Same top-out and shared scoring; independent local best and friendly leaderboard keep its more flexible rule set separate from fixed 2 Player |

Mode select intentionally presents **Classic**, **Daily Challenge**, **2 Player**, and **2 Player Mirror**. Timed and other legacy categories plus VIP remain hidden; Leaderboards and Login are available from the toolbar. Daily has a dedicated calendar card icon and remains the only visible mode with a win condition. Fixed 2 Player keeps Mirror out of its accepted input protocol so complementary default orientations remain the cooperative constraint. 2 Player Mirror accepts Mirror for either peer while preserving permanent red/blue ownership. Both variants give players separate one-charge fill inventories; each cleared line recharges only the player whose action completed it. The host includes versioned effect events in authoritative peer snapshots, so both screens agree on clear/fusion/combo/back-to-back presentation while each peer still sees only its own landing ghost.

## 6. Meta Systems & Retention

None of this exists today. All of it is designed to be additive — a player who never opens a menu beyond "play Classic" loses nothing.

### 6.1 Stats & Profile
A single screen aggregating lifetime stats per mode (games played, lines cleared, best combo, best back-to-back, total fusion bonuses, time played) plus a simple level/rank derived from cumulative play (cosmetic only — see Monetization Philosophy, no gameplay effect).

### 6.2 Achievements
20–30 achievements spanning onboarding ("clear your first line"), mastery ("fuse 4 cells in one piece"), and endurance ("survive 10 minutes in Arcade"). Each unlocks a small cosmetic reward (see §6.5) rather than currency, keeping the loop simple.

### 6.3 Streaks
Daily Challenge participation streak, shown as a small flame counter, resets on a missed day. No punishment beyond losing the counter — no "streak freeze" purchase, that pattern is a dark pattern and out of scope per pillar 4.

### 6.4 Replays & Sharing (uses existing seeded RNG for free)
Because the piece bag already supports a seeded `Random`, a run can be fully reconstructed from `(seed, input log)`. Recommend building a lightweight replay recorder early (Phase 1, cheap) even before any server work, because:
- It lets a player generate a shareable "replay code" for a great run (social/viral hook, zero backend required for local playback).
- It's a prerequisite for trustworthy Daily Challenge / leaderboard validation later (`docs/RELEASE_CHECKLIST.md` already flags this as required "before adding online competition" — this satisfies that item early).

### 6.5 Cosmetics (skins/themes)
Introduce a `Theme` system: board background, piece color palette, and particle color are all swappable as one unit. Ship 2–3 free themes (including a colorblind-safe palette, see §8) plus a growing set of premium themes as the primary monetization surface (cosmetic only, detailed in `MONETIZATION.md`).

### 6.6 Leaderboards
Classic, Daily Challenge, fixed 2 Player, and 2 Player Mirror shared-team scores have separate lightweight Firestore leaderboards. Each entry displays the player's chosen public, non-unique name rather than an email address or raw UID. The current no-Functions design accepts owner-written scores constrained by security rules and is suitable for friendly rankings, not cheat-resistant competition. Trusted replay validation remains a future requirement before prizes or high-stakes competitive claims; see `TECHNICAL_ARCHITECTURE.md` §4.

## 7. Audio Design

The single biggest gap versus any shipped competitor. Proposed scope:

**Music**
- One custom menu/mode-select/room-waiting loop (`tmusic.mp3`, low-energy, sets the game's tone).
- One shared gameplay loop (`zen_classic_arcade_music.mp3`) for Classic, Daily, 2 Player, and retained legacy modes.

**SFX** (all must have a volume slider independent of music, plus a master mute — the touch controls already ship accessibility semantics, audio should match that bar). The persisted master mute is also exposed as a one-tap speaker button in every solo and 2 Player gameplay HUD.
| Event | Sound |
|---|---|
| Move / rotate | Short, low-key tick (must not fatigue over a long session) |
| Mirror flip | Distinct "flip" whoosh — this is a signature action, it should sound unique |
| Soft/hard drop | Thud, scaled by drop distance |
| Lock | Soft click |
| Line clear (1–3 lines) | Ascending chime, scaled by line count |
| Four-line clear | Full fanfare, matches existing "TRIANGLE!" banner |
| Fusion bonus | Bright, distinct "shimmer" — reinforces pillar 1 |
| Combo tick | Rising pitch per combo step (already have a "heat" gradient in code at `game_screen.dart` — audio should follow the same heat curve) |
| Cavity fill | Short mechanical "snap" |
| Level up | Short rising sting |
| Game over | Descending, non-punishing tone (this is a puzzle game, not a fail-state horror game — game over should feel like "run complete," not "you lost") |
| Menu navigation | Minimal UI ticks |
| New best score | Distinct celebratory sting, separate from the four-line-clear fanfare |

**Sourcing recommendation:** commission or license a small original SFX/music pack rather than relying entirely on stock assets, specifically so the mirror-flip and fusion-bonus sounds are unique to this game — those two sounds are the brand differentiator.

## 8. Accessibility

- **Colorblind-safe theme** (see §6.5) — verify all 7 piece colors remain distinguishable under protanopia/deuteranopia/tritanopia simulation, not just "looks fine to us."
- **Reduce motion** toggle — disables screen shake and reduces particle count, keeps flashes as simple opacity changes. Required for players sensitive to motion effects, and good practice generally.
- **Haptics toggle** (haptics already exist; needs an explicit off switch for players who find them distracting or who have haptics-sensitive devices).
- **Adjustable UI scale / high-contrast option** for the stats bar and toasts.
- **One-handed touch layout** option, given the existing two-row touch d-pad already documents 48px targets and semantic labels — a one-handed variant is a layout config, not new engineering.
- **Chill mode** (§5) *is* an accessibility feature as much as an onboarding one — frame it that way in store copy ("play at your own pace") without a patronizing tone.

## 9. Monetization Philosophy (summary — full detail in MONETIZATION.md)

No pay-to-win, no forced ads, no loot boxes/gacha. Revenue comes from: a cosmetic-and-convenience subscription ("VIP Pass"), one-time cosmetic packs, an optional one-time "Supporter" purchase, and — only if the team decides to add ads at all — strictly opt-in rewarded video for a single continue per run, never interstitials. Full design, pricing bands, and entitlement mapping in `MONETIZATION.md`.

## 10. Live Services Overview (summary — full detail in TECHNICAL_ARCHITECTURE.md)

Anonymous-by-default accounts (Firebase Auth) so leaderboards and multiplayer work without ever forcing sign-up, optional email/password login for a reusable Firebase identity, Firebase Analytics for product visibility, and reserved integrations for future Crashlytics and RevenueCat use. Full architecture, data model, and privacy plan in `TECHNICAL_ARCHITECTURE.md`.

## 11. Success Metrics

Once analytics lands (Phase 3), track:
- **D1/D7/D30 retention** per acquisition source.
- **Session length and sessions/day**, split by mode (validates whether Sprint/Ultra actually serve a "short session" need).
- **Classic repeat rate and Daily retry rate** — these are now the two clearest signals that the focused mode roster is working.
- **Daily Challenge participation and streak length.**
- **Paywall view → trial start → paid conversion**, and **cosmetic pack attach rate** independent of subscription (validates whether cosmetics alone are worth selling a la carte).
- **Crash-free session rate** (target 99.5%+ before wide release).

## 12. Open Questions / Risks

- Complete trademark/product-name clearance for "What The Triangle" before store submission; changing a name in source code is not itself legal clearance.
- Whether Classic's capped pace and narrower board remain welcoming while normal top-out preserves enough tension.
- Music/SFX sourcing budget and timeline (see §7) — needs a decision before Phase 1 can fully close out.
- Full scope in this document is intentionally larger than any single phase — see `ROADMAP.md` for sequencing and what ships when.
