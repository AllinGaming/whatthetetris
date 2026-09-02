# Release checklist

## Required once per product

- [ ] Confirm ownership of `com.allingaming.whatthetetris` before registering the Android and Apple applications.
- [ ] Complete a product-name and trademark review before commercial distribution.
- [ ] Plan and execute a coordinated migration of the legacy GitHub/Firebase/package/bundle identifiers if the old slug must also disappear from technical URLs and store identifiers.
- [ ] Select the Apple Developer team and verify signing capabilities in Xcode.
- [ ] After upgrading to Flutter 3.47 or later, migrate Android to built-in Kotlin and remove the temporary legacy-Kotlin flags.
- [ ] Create an Android upload key, copy `android/key.properties.example` to the ignored `android/key.properties`, and store the key and passwords in an approved secret manager.
- [ ] Publish the privacy policy and a support URL on a stable public domain.
- [ ] Complete store data-safety/privacy, content-rating, copyright, and export-compliance forms.
- [ ] Produce phone/tablet screenshots, feature graphics, store descriptions, and accessible alt text.

## Required for every release

- [ ] Merge through a protected pull request with the CI workflow green.
- [ ] Run `flutter analyze`, `flutter test`, and the release builds from a clean checkout.
- [ ] Update `version` and build number in `pubspec.yaml`.
- [ ] Review dependency updates and generated lockfile changes.
- [ ] Test first launch, pause/background/resume, game over, persistence, touch controls, keyboard controls, reduced connectivity, and upgrade from the previous version.
- [ ] Test the smallest supported phone, a tablet, desktop web, and at least one physical iOS and Android device.
- [ ] Verify that production artifacts are not debug-signed and contain no development endpoints or secrets.
- [ ] Tag the release, archive signed artifacts and symbols, and write release notes plus a rollback plan.
- [ ] Perform a staged rollout and monitor crashes, startup failures, frame time, and user feedback before expanding to 100%.

## Before adding online competition

- [ ] Define a versioned replay format containing the seed and accepted player commands.
- [ ] Validate leaderboard submissions on a trusted service; never trust a client-provided score by itself.
- [ ] Add abuse controls, retention rules, account deletion, incident response, and an updated privacy policy.
- [ ] Establish a player-name reporting, moderation, impersonation, and removal process before promoting public leaderboards broadly.

## Before activating online co-op

- [ ] Enable anonymous Auth, authorize `allingaming.github.io`, deploy `firestore.rules`, and run participant/attacker Firestore Emulator rule tests.
- [ ] Configure Firestore TTL on `multiplayerRooms.expiresAt` and confirm abandoned room documents are deleted.
- [ ] Provision a production TURN service with short-lived credentials; verify both relayed and direct connections rather than relying on public STUN alone.
- [ ] Test fixed, Mirror, and Puzzle variants on two physical devices across same Wi-Fi, different Wi-Fi networks, and Wi-Fi-to-cellular, including mirrored red/blue ownership, seeded Puzzle formation/victory, blocked Mirror inputs, backgrounding, disconnects, simultaneous inputs, top-out, host-only Play Again for Both, guest waiting state, synchronized rematch, and leaving the lobby.
- [ ] Update and review the privacy policy, store disclosures, data retention, and account/data-deletion behavior before enabling Firebase in a distributed build.
- [ ] Verify chosen names migrate on existing Classic, current Daily, fixed 2 Player, 2 Player Mirror, and 2 Player Puzzle entries without changing or lowering their scores.
