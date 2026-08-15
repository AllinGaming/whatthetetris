# What The Tetris — Game Design Document

**Status:** Living design document — Phases 0–4 implemented (see `ROADMAP.md` for the phase-by-phase log); retained as the original design brief, §3 kept current at a summary level
**Owner:** Design/Product
**Last updated:** 2026-08-15
**Companion docs:** [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) · [MONETIZATION.md](MONETIZATION.md) · [ROADMAP.md](ROADMAP.md)

---

## 1. Vision

**What The Tetris** is a neon falling-blocks game built on one real mechanical twist: every piece is made of **triangle halves**, not full squares. Opposite triangle halves fuse into a full cell when they meet, which means the classic Tetris skill (spatial stacking under time pressure) gets a second layer — *pairing*, not just placing. Add a mirror-flip action and a charge-based cavity filler, and the result already reads as its own game, not a reskin.

The goal of this document is to take that mechanical core — which is genuinely good — and wrap it in the systems, feel, and content depth that separate a solid solo-built puzzle game from one that competes with the best falling-block games on mobile app stores (Tetris®, Blockudoku, Tricky Towers, EVERSPACE-adjacent arcade polish bar, etc.). "S-tier" here means: a stranger downloads it, plays for two minutes, and immediately understands (a) what makes this different from Tetris, and (b) that the people who made it cared about every frame and every sound.

**Platforms:** iOS, Android, Web (already live at GitHub Pages). Portrait-first mobile, full desktop/keyboard support retained.

## 2. Design Pillars

Every new feature gets checked against these four pillars. If it doesn't serve at least one, it doesn't ship.

| Pillar | Meaning |
|---|---|
| **The fusion mechanic is the star** | Triangle-half pairing, mirroring, and cavity fills should stay central — new modes and scoring should exercise this mechanic, not bury it under generic Tetris features. |
| **Feel before features** | A game with fewer modes and flawless audio/game-feel beats a game with ten modes and a silent, stiff board. Juice is not a "nice to have" pass at the end — it's load-bearing. |
| **Fair monetization, never pay-to-win** | Money buys cosmetics, convenience, and support. It never buys a faster board, more time, or an easier curve than a free player gets. |
| **Respect the player's time and data** | No forced ads, no dark patterns, no silent data collection. Every system added (accounts, analytics, subscriptions) must have an honest, simple explanation a 12-year-old could read in the privacy policy. |

## 3. Current State (baseline, already shipped)

This section originally described the pre-Phase-0 baseline this whole document was written against. Nearly everything the doc proposed below has since shipped — see `ROADMAP.md` for the authoritative, phase-by-phase implementation log (status, exit criteria, test counts). This section is kept updated at a summary level so a reader of *this* doc alone isn't misled; treat `ROADMAP.md` as the source of truth for exact status.

- **Board:** 20×10 grid (8-wide in Chill; Daily Challenge is 8×16 — see §5), triangle-half occupancy (`CellOccupancy` tracks full/bottom-left/top-right independently), 7-bag randomizer with a seedable RNG (deterministic — powers replays and Daily Challenge, see §6.4 and §6.6).
- **Piece set:** 7 shapes (I4, L4, T4, O4, S4, Z4, J4), each a single uniform-diagonal triangle version of the familiar tetromino, 4 rotation states via coordinate rotation. Chill restricts the bag to a 5-shape subset (drops S4/Z4).
- **Core actions:** move, rotate (CW/CCW) with a simplified kick table (not full SRS — see §4.4 for the deliberate design call), mirror-flip (flips triangle orientation in place), hold (one per piece), hard drop, soft drop, cavity fill (consumes a charge to fill the lowest missing half-cell).
- **Modes:** all seven from §5 are implemented — Chill, Classic, Arcade, Sprint, Ultra, Zen, and Daily Challenge (now a prefilled-board, clear-it-to-win puzzle rather than an open-ended run — see the Daily Challenge row in §5 and `ROADMAP.md`'s Daily Challenge redesign entry).
- **Scoring:** standard line-clear table (100/300/500/800 × level), level up every 10 lines, combo counter, "TETRIS!" banner on 4-line clears, plus the Fusion Bonus (§4.1) and Back-to-Back chain (§4.2) both now implemented.
- **Feel:** neon glow rendering, particle bursts, lock flash, line-clear flash, hard-drop screen shake (scaled by severity), an expanding impact ring on hard drops, ambient combo/danger glows, floating toasts, haptic feedback (tiered by event).
- **Audio:** full music/SFX coverage for every action (§7's proposed scope is implemented), synthesized by `tool/generate_audio.py` as a real placeholder pack pending a commissioned replacement.
- **Meta systems:** Stats & Achievements (29 achievements), 3 cosmetic themes, a 6-page reopenable tutorial, replay recording, Firebase-backed accounts/cloud backup/analytics/leaderboards and a RevenueCat-backed VIP Pass — all coded but inert until a real Firebase project/RevenueCat account exists (§10, `TECHNICAL_ARCHITECTURE.md`).
- **Persistence:** local best score/level/time per mode via `shared_preferences`, same for settings/haptics/stats. No live accounts yet (see `PRIVACY.md`, accurate as long as that stays true).
- **Quality bar:** 138 tests passing, `flutter analyze` clean, CI on every PR (format, analyze, test, web build), deployed to GitHub Pages.

## 4. Core Gameplay Deepening

### 4.1 Fusion Bonus (new)
Reward players for *using* the triangle mechanic well, not just clearing lines. When a locked piece completes one or more full cells by fusing with existing triangle halves already on the board (as opposed to landing on empty cells), award a small scoring bonus per fused cell, with its own toast ("FUSION x3") and a distinct particle color (gold vs. the standard clear-flash palette). This is this game's answer to a T-spin bonus: a skill-expressive scoring layer built from a mechanic Tetris doesn't have, instead of importing Tetris's own.

### 4.2 Back-to-Back chain (new)
Standard Tetris back-to-back: consecutive Tetrises (or Tetris+Fusion combos) award an escalating multiplier, resetting on any clear that doesn't qualify. Pairs with the existing combo counter without replacing it — combo rewards *frequency*, back-to-back rewards *consistency of your best clears*.

### 4.3 Cavity filler tuning
Currently a single mechanic shared by both modes. Recommend: keep as-is for Classic/Arcade, but tune starting charges and gain-per-clear per mode difficulty (see §5 mode table) so easier modes feel generous and expert modes (Ultra/Sprint) feel scarce and tactical.

### 4.4 Rotation system — deliberate decision, not a gap
The current kick table (`[0, -1, 1, -2, 2]` plus one floor-kick) is simpler than SRS. **Recommendation: keep it, and say so explicitly in the README/store copy.** This game already diverges from vanilla Tetris in its piece geometry; importing SRS's exact kick tables (designed for full-square tetrominoes) doesn't obviously transfer to triangle-half geometry, and competitive Tetris players will test it against SRS expectations if we don't set that expectation ourselves. Action item: playtest the current table specifically for "does it ever feel unfair," document the kick table precisely in-code, and market it honestly as "wall kicks tuned for triangle pieces," not "SRS."

## 5. Game Modes

Started as two modes (Classic, Arcade), both open-ended marathon runs. The requested "surprise me" pass plus the explicit ask for an easier on-ramp expanded this to the mode roster below — now fully implemented (`ROADMAP.md` Phase 2) — covering onboarding, mastery, short-session, and daily-puzzle play, the session shapes mobile puzzle players actually want.

| Mode | Audience / Session | Board | Piece pool | Speed curve | End condition |
|---|---|---|---|---|---|
| **Chill** *(new)* | First-time players, kids, accessibility, "I just want to relax" | 8 columns (narrower), larger cell render | 5 shapes — drops S4/Z4 (the two hardest to read at a glance for new players), keeps I/O/T/L/J | Gentle decay **with a true ceiling** (unlike Classic/Arcade's uncapped curve) — difficulty plateaus so it's never a wall | Never game-overs from stack-out in the traditional sense — board auto-clears bottom rows if it would top out ("soft floor"), so the mode teaches without punishing. Optional toggle: "Learner" (soft floor on) vs. "Chill+" (soft floor off, still capped speed) |
| **Classic** *(existing)* | Steady, familiar climb | 10×20, standard | 7 shapes | Gentle decay, no ceiling | Top-out |
| **Arcade** *(existing)* | Risk/reward chasers | 10×20, standard | 7 shapes | Steep decay, no ceiling, manual speed-boost stacking | Top-out |
| **Sprint** *(new)* | Short session, competitive | 10×20, standard | 7 shapes | Fixed, moderate | Clear 40 lines as fast as possible; timer is the score |
| **Ultra** *(new)* | Short session, competitive | 10×20, standard | 7 shapes | Classic curve | 2-minute clock; maximize score before time runs out |
| **Zen** *(new)* | No-pressure practice / flow state | 10×20, standard | 7 shapes | Fixed, slow, never escalates | Never ends (until player quits) — for practicing fusion timing and mirror usage without stakes |
| **Daily Challenge** *(new, redesigned post-launch)* | Retention, social, one run/day | 8×16 (narrower and shorter than standard — keeps the prefilled puzzle small enough to clear without feeling like a slog), **starts half-filled** with a deterministic puzzle layout | 7 shapes, **same seed for every player that day** | Classic curve | Board-clear win condition, not top-out: clear the prefilled board back to empty to win; score still posts to a daily leaderboard (see §6.6 and Technical Architecture §4 for anti-cheat) |

Naming is a placeholder for review — "Chill" was chosen to read as an inviting, non-condescending name for the easy mode rather than "Easy" or "Junior," but this is very much bikeshed-able before ship.

Mode select screen groups these as **Marathon** (Chill, Classic, Arcade), **Timed** (Sprint, Ultra), **Practice** (Zen), and **Daily** (Daily Challenge) — four short rows instead of one long list, so the roster growing doesn't make mode-select overwhelming.

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
Per-mode leaderboards (all-time + Daily Challenge). Requires server-side validation before launch — never trust a client-submitted score (this is already called out in `docs/RELEASE_CHECKLIST.md`). See `TECHNICAL_ARCHITECTURE.md` §4 for the Cloud Function design that replays `(seed, input log)` server-side before accepting a score.

## 7. Audio Design

The single biggest gap versus any shipped competitor. Proposed scope:

**Music**
- One menu/mode-select loop (low-energy, sets neon-arcade tone).
- One marathon-mode loop that layers intensity as level increases (simplest implementable version: 2–3 stem layers that fade in by level tier, not a full adaptive score).
- One Zen-mode ambient loop (distinct — calmer, reinforces "no pressure" positioning).
- Sting stingers, not loops, for Sprint/Ultra (a ticking-clock motif under the existing music bed).

**SFX** (all must have a volume slider independent of music, plus a master mute — the touch controls already ship accessibility semantics, audio should match that bar)
| Event | Sound |
|---|---|
| Move / rotate | Short, low-key tick (must not fatigue over a long session) |
| Mirror flip | Distinct "flip" whoosh — this is a signature action, it should sound unique |
| Soft/hard drop | Thud, scaled by drop distance |
| Lock | Soft click |
| Line clear (1–3 lines) | Ascending chime, scaled by line count |
| Tetris (4 lines) | Full fanfare, matches existing "TETRIS!" banner |
| Fusion bonus | Bright, distinct "shimmer" — reinforces pillar 1 |
| Combo tick | Rising pitch per combo step (already have a "heat" gradient in code at `game_screen.dart` — audio should follow the same heat curve) |
| Cavity fill | Short mechanical "snap" |
| Level up | Short rising sting |
| Game over | Descending, non-punishing tone (this is a puzzle game, not a fail-state horror game — game over should feel like "run complete," not "you lost") |
| Menu navigation | Minimal UI ticks |
| New best score | Distinct celebratory sting, separate from Tetris fanfare |

**Sourcing recommendation:** commission or license a small original SFX/music pack (a single freelance sound designer for a game this scope is typically a few hundred dollars and 1–2 weeks) rather than stock asset packs, specifically so the mirror-flip and fusion-bonus sounds are unique to this game — those two sounds *are* the brand differentiator and shouldn't sound like a stock Tetris clone.

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

Anonymous-by-default accounts (Firebase Auth) so cloud backup and leaderboards work without ever forcing sign-up, optional linking to Sign in with Apple/Google for cross-device restore, Firebase Analytics + Crashlytics for product and stability visibility, RevenueCat for subscription/IAP handling across both stores. Full architecture, data model, and privacy rewrite plan in `TECHNICAL_ARCHITECTURE.md`.

## 11. Success Metrics

Once analytics lands (Phase 3), track:
- **D1/D7/D30 retention** per acquisition source.
- **Session length and sessions/day**, split by mode (validates whether Sprint/Ultra actually serve a "short session" need).
- **Chill-mode-to-Classic/Arcade graduation rate** — the whole point of Chill mode is to convert first-time players into long-term players; if nobody graduates, the mode's design needs revisiting, not just its existence.
- **Daily Challenge participation and streak length.**
- **Paywall view → trial start → paid conversion**, and **cosmetic pack attach rate** independent of subscription (validates whether cosmetics alone are worth selling a la carte).
- **Crash-free session rate** (target 99.5%+ before wide release).

## 12. Open Questions / Risks

- Trademark/product-name clearance for "What The Tetris" against the Tetris® trademark — flagged in `docs/RELEASE_CHECKLIST.md` already; this should resolve *before* store submission, independent of everything else in this doc.
- Whether Chill mode's "soft floor" (auto-clearing bottom rows to prevent top-out) feels like generous design or feels patronizing/cheap in practice — needs a real playtest with non-Tetris-fluent players before committing.
- Music/SFX sourcing budget and timeline (see §7) — needs a decision before Phase 1 can fully close out.
- Full scope in this document is intentionally larger than any single phase — see `ROADMAP.md` for sequencing and what ships when.
