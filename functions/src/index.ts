/**
 * Serverless functions backing the live-services layer
 * (docs/TECHNICAL_ARCHITECTURE.md SS4, docs/MONETIZATION.md SS3). Deployed
 * to Firebase Cloud Functions — nothing here is a server anyone provisions,
 * patches, or keeps running; Firebase invokes each function on demand.
 *
 * Two functions:
 *   - submitScore: the leaderboard/Daily-Challenge score gate. Rejects
 *     obviously-fake submissions; does NOT yet fully replay-validate them
 *     (see the TODO inline) — that's the honest state, not a placeholder
 *     pretending to be complete.
 *   - revenueCatWebhook: mirrors RevenueCat subscription events into
 *     Firestore so the client only ever reads its own entitlement state
 *     from a field it cannot write itself (see firestore.rules).
 */

import * as admin from "firebase-admin";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onRequest} from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_AUTH_HEADER");

interface ReplayEvent {
  atMs: number;
  type: string;
}

interface SubmitScoreRequest {
  mode: string;
  score: number;
  level: number;
  seed: number;
  isDaily: boolean;
  replay: {version: number; events: ReplayEvent[]};
}

/**
 * Callable from the app once a run ends (lib/game/replay.dart already
 * records everything this needs). Throws HttpsError on anything
 * implausible; writes to the appropriate leaderboard/Daily Challenge
 * collection on success.
 */
export const submitScore = onCall<SubmitScoreRequest>(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in required to submit a score.");
  }

  const {mode, score, level, seed, isDaily, replay} = request.data;

  if (typeof score !== "number" || score < 0 || !Number.isFinite(score)) {
    throw new HttpsError("invalid-argument", "score must be a finite, non-negative number.");
  }
  if (!replay || !Array.isArray(replay.events)) {
    throw new HttpsError("invalid-argument", "A replay (seed + input log) is required.");
  }

  const events = replay.events;

  // --- Plausibility checks. Cheap, and enough to stop the two easiest
  // cheats (submitting a bare number with no replay; submitting an empty
  // or non-chronological replay) before doing anything more expensive. ---
  if (events.length === 0 && score > 0) {
    throw new HttpsError(
      "invalid-argument",
      "A run that scored points must have recorded input events."
    );
  }
  for (let i = 1; i < events.length; i++) {
    if (events[i].atMs < events[i - 1].atMs) {
      throw new HttpsError("invalid-argument", "Replay events must be chronological.");
    }
  }
  const durationMs = events.length > 0 ? events[events.length - 1].atMs : 0;
  const impliedInputsPerSecond =
    durationMs > 0 ? events.length / (durationMs / 1000) : 0;
  // No human sustains much past ~10-12 inputs/second on this control scheme;
  // 15 leaves headroom without accepting an obviously scripted input stream.
  if (impliedInputsPerSecond > 15) {
    throw new HttpsError(
      "invalid-argument",
      "Replay input rate is not physically plausible."
    );
  }

  // --- TODO (docs/TECHNICAL_ARCHITECTURE.md SS4): full deterministic replay
  // validation. The actual board/piece-bag logic lives in Dart
  // (lib/game/game_board.dart, lib/game/piece_bag.dart) and is not yet
  // ported to this Node runtime (or run via a Dart-capable Cloud Function).
  // Until that port exists, passing this function means "not an obvious
  // cheat," not "cryptographically proven to have happened." Do not
  // advertise leaderboards as fully tamper-proof until this TODO closes. ---

  const target = isDaily ?
    db
      .collection("dailyChallenge")
      .doc(String(seed))
      .collection("entries")
      .doc(uid) :
    db.collection("leaderboards").doc(mode).collection("entries").doc(uid);

  await target.set({
    score,
    level,
    seed,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {accepted: true};
});

/**
 * RevenueCat webhook receiver. Configure this function's URL in the
 * RevenueCat dashboard (Project Settings -> Integrations -> Webhooks) and
 * set REVENUECAT_WEBHOOK_AUTH_HEADER (via `firebase functions:secrets:set`)
 * to the same shared secret configured there, so this endpoint can verify
 * a request actually came from RevenueCat before trusting it.
 */
export const revenueCatWebhook = onRequest(
  {secrets: [revenueCatWebhookSecret]},
  async (req, res) => {
    const authHeader = req.get("Authorization");
    if (authHeader !== revenueCatWebhookSecret.value()) {
      res.status(401).send("Unauthorized");
      return;
    }

    const event = req.body?.event;
    const appUserId: string | undefined = event?.app_user_id;
    const entitlementIds: string[] = event?.entitlement_ids ?? [];
    const eventType: string | undefined = event?.type;

    if (!appUserId || !eventType) {
      res.status(400).send("Malformed RevenueCat event");
      return;
    }

    const isActive = [
      "INITIAL_PURCHASE",
      "RENEWAL",
      "PRODUCT_CHANGE",
      "UNCANCELLATION",
    ].includes(eventType);
    const isRevoked = [
      "CANCELLATION",
      "EXPIRATION",
      "BILLING_ISSUE",
    ].includes(eventType);

    if (isActive || isRevoked) {
      await db
        .collection("users")
        .doc(appUserId)
        .set(
          {
            entitlements: {
              vipActive: isActive,
              entitlementIds,
              productId: event?.product_id ?? null,
              expiresAtMs: event?.expiration_at_ms ?? null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          {merge: true}
        );
    }

    res.status(200).send("OK");
  }
);
