# Release checklist

## Required once per product

- [ ] Confirm ownership of `com.allingaming.whatthetetris` before registering the Android and Apple applications.
- [ ] Complete a product-name and trademark review before commercial distribution.
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
