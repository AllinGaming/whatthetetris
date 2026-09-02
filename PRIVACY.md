# Privacy Policy

Effective September 1, 2026.

What the Triangle stores settings, statistics, best scores, and best levels locally on the player's device using platform preferences. It does not show ads or sell personal information.

The web version uses Firebase Analytics for product and gameplay events, including session starts, selected modes, scores, levels, cleared lines, play duration, and feature usage. Firebase may associate these events with technical identifiers and device or browser information. Cloud backup is currently disabled.

The web version creates a random anonymous Firebase Authentication identifier for online features. That identifier is used as the Firebase Analytics user ID so activity from the same account can be grouped; the identifier itself does not contain a name or email address. Players may choose a public player name and may optionally create or access an account with an email address and password. Firebase Authentication stores the chosen player name as the account display name, processes the email address and password credential, sends account-verification and password-reset messages when requested, and stores the authentication account. The game does not store a readable password, add the email address or chosen player name to Analytics event parameters, or publish the email address on leaderboards.

Signed-in Firebase players, including anonymous players, may submit Classic, Daily Challenge, fixed-orientation 2 Player, 2 Player Mirror, and 2 Player Puzzle shared-team scores to separate Firestore leaderboards. A leaderboard entry uses the Firebase player identifier as its document ID and contains only the chosen public player name, score, level, and server update time. Other signed-in players can read those entries. The game writes a score only after a new local personal best; it first reads that player's existing entry and writes only when the submitted score is higher. When a player changes their name, the game checks only their existing Classic, all three 2 Player, and current Daily Challenge entries, and writes only entries whose stored name needs updating. Replay input logs, game seeds, room codes, partner identifiers, and email addresses are not sent with leaderboard submissions.

For 2 Player rooms, Firestore receives the room code, selected fixed-orientation, Mirror, or Puzzle variant, anonymous participant identifiers, connection-negotiation data, timestamps, and room status. Players share the room code themselves outside the game. Once connected, gameplay inputs and shared-board snapshots travel directly between those two players over WebRTC instead of through the game's Firestore database.

The game does not ask for an email address, precise location, contacts, or advertising identifier during anonymous play. A player name is requested when a player chooses email login or account creation and may also be changed from the Login screen; names are public, are not unique, and must be 3–20 permitted characters. An email address is requested only when a player chooses to create an account, log in, or reset a password. Local data can be removed by clearing the site's storage. Questions or requests concerning online account or leaderboard data can be submitted through the issue tracker below. Do not post passwords, reset links, or other sensitive information in a public issue.

Firebase is provided by Google. Its handling of service data is described in [Google's Firebase privacy documentation](https://firebase.google.com/support/privacy).

Questions can be submitted through the project's [GitHub issue tracker](https://github.com/allingaming/whatthetetris/issues).

The accompanying [Terms of Use](TERMS.md) govern use of the game and its online features.
