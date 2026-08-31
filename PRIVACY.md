# Privacy Policy

Effective September 1, 2026.

What the Triangle stores settings, statistics, best scores, and best levels locally on the player's device using platform preferences. It does not show ads or sell personal information.

The web version uses Firebase Analytics for product and gameplay events, including session starts, selected modes, scores, levels, cleared lines, play duration, and feature usage. Firebase may associate these events with technical identifiers and device or browser information. Cloud backup is currently disabled.

The web version creates a random anonymous Firebase Authentication identifier for online features. That identifier is used as the Firebase Analytics user ID so activity from the same account can be grouped; the identifier itself does not contain a name or email address. Players may optionally create or access an account with an email address and password. Firebase Authentication processes the email address and password credential, sends account-verification and password-reset messages when requested, and stores the authentication account. The game does not store a readable password, add the email address to Analytics event parameters, or publish it on leaderboards.

Signed-in Firebase players, including anonymous players, may submit Classic, Daily Challenge, and 2 Player shared-team scores to Firestore leaderboards. A leaderboard entry uses the Firebase player identifier as its document ID and contains only the score, level, and server update time. Other signed-in players can read leaderboard entries. The game writes directly to Firestore only after a new local personal best; it first reads that player's existing entry and writes only when the submitted score is higher. Replay input logs, game seeds, room codes, partner identifiers, and email addresses are not sent with leaderboard submissions.

For 2 Player rooms, Firestore receives the room code, anonymous participant identifiers, connection-negotiation data, timestamps, and room status. Players share the room code themselves outside the game. Once connected, gameplay inputs and shared-board snapshots travel directly between those two players over WebRTC instead of through the game's Firestore database.

The game does not ask for a name, email address, precise location, contacts, or advertising identifier during anonymous play. An email address is requested only when a player chooses to create an account, log in, or reset a password. Local data can be removed by clearing the site's storage. Questions or requests concerning online account or leaderboard data can be submitted through the issue tracker below. Do not post passwords, reset links, or other sensitive information in a public issue.

Firebase is provided by Google. Its handling of service data is described in [Google's Firebase privacy documentation](https://firebase.google.com/support/privacy).

Questions can be submitted through the project's [GitHub issue tracker](https://github.com/allingaming/whatthetetris/issues).

The accompanying [Terms of Use](TERMS.md) govern use of the game and its online features.
