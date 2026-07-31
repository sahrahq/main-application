# SAHRA — Publishing to the App Store & Google Play

*This covers both apps separately: `customer_app` (public, both stores) and `management_app` (Android-first per DEVELOPMENT.md, iOS later). Same repo, but each app is submitted, reviewed, and listed completely independently — the store has no concept of "monorepo."*

---

## 1. The core idea, one more time

One `sahra` git repo → two independent Flutter projects inside it (`apps/customer_app`, `apps/management_app`) → **four separate store listings total** once both are live on both platforms:

| App | Google Play | App Store |
|---|---|---|
| Customer app | `com.sahra.customer` | `com.sahra.customer` |
| Management app | `com.sahra.business` | `com.sahra.business` |

Each listing has its own name, icon, screenshots, description, review process, and release timeline. Building one does not touch the other.

## 2. Accounts you need (do this early — reviews and verification take days)

| Account | Cost | Who | Notes |
|---|---|---|---|
| **Apple Developer Program** | $99/year | The company (use a business/organization account, not a personal Apple ID, so ownership stays with SAHRA not one person) | Enrollment can take 1–2 days for identity/business verification |
| **Google Play Console** | $25 one-time | The company | New accounts must now complete **closed testing with at least 12 testers for 14 continuous days** before Google grants production/public access — plan for this in your timeline, don't leave it to launch week |
| **Firebase project** | Free tier | — | Already needed for FCM/Analytics/Crashlytics per the tech stack; also used for App Distribution (internal testing before store submission) |

Set these up during Phase 6 of the roadmap (`docs/blueprint/10-devops-roadmap-cto.md`), not the week you want to launch.

## 3. Per-app setup (do this once, for each of the two apps)

### 3.1 Unique identity
- **Android:** set `applicationId` in `apps/<app>/android/app/build.gradle` (e.g., `com.sahra.customer`).
- **iOS:** set the Bundle Identifier in Xcode (`apps/<app>/ios/Runner.xcodeproj`) to match (e.g., `com.sahra.customer`).
- These must be unique across all of Google Play / the App Store, globally — pick them once and never change them (changing later means losing your listing and reviews).

### 3.2 Signing
- **Android:** generate a release keystore (`keytool -genkey -v -keystore sahra-customer-release.jks ...`), reference it in `android/key.properties` (gitignored — never commit keystores or passwords). **Store the keystore file itself somewhere safe outside git** (password manager / secrets vault) — losing it means you can never update that app again under the same listing.
- **iOS:** managed through Xcode + your Apple Developer account (automatic signing is fine to start); certificates and provisioning profiles are tied to the Bundle ID.
- Do this **separately for each app** — never reuse one app's signing key for the other.

### 3.3 Store listing assets (per app)
- App name, subtitle, description (Arabic + English — both stores support localized listings, do both from day one)
- Icon (1024×1024), screenshots per required device size, feature graphic (Google Play)
- Privacy policy URL (required by both stores — write this once, host it, link from both listings; must reflect PDPL/GDPR posture per `docs/blueprint/09-security-and-scalability.md`)
- Content rating questionnaire (both stores ask this)
- **Data safety / App Privacy declarations** — list exactly what data you collect (phone, location, payment info) — mismatches here are a common rejection reason

## 4. Build & release process

### Android (Google Play)

```bash
cd apps/customer_app
flutter build appbundle --release   # produces build/app/outputs/bundle/release/app-release.aab
```

Upload the `.aab` to Play Console → your app → Release → choose track:
- **Internal testing** first (instant, up to 100 testers) — sanity check.
- **Closed testing** next — this is where the mandatory 12-tester/14-day requirement for new accounts gets satisfied.
- **Production** once closed testing requirement is met and you're ready for the public.

Repeat identically for `management_app` under its own app entry in Play Console.

### iOS (App Store)

```bash
cd apps/customer_app
flutter build ipa --release         # produces build/ios/ipa/*.ipa
```

Upload via Xcode Organizer or `xcrun altool`/Transporter to **App Store Connect** → create the app record (matching Bundle ID) → attach the build → submit for review. Use **TestFlight** first (internal testers instantly, external testers after a lighter review) before submitting for full App Store review.

Repeat identically for `management_app`.

### Review timelines (plan around these, don't be surprised by them)
- **Apple:** typically 24–48 hours for review, occasionally longer; rejections for missing privacy details or broken flows are common on first submission — expect one rejection-and-fix cycle for each app the first time.
- **Google Play:** production review usually faster (hours to ~1 day) once the closed-testing prerequisite is satisfied, but the 14-day closed testing clock is the real bottleneck to plan for.

## 5. Automate this later (don't hand-build releases forever)

Once past the first manual submission for each app (so you understand the process), wire release builds into the CI/CD pipeline already planned in `DEVELOPMENT.md` §10:
- **Fastlane** (or Codemagic/Bitrise) to automate versioning, signing, and upload to both stores for both apps — four independent lanes (`customer_android`, `customer_ios`, `management_android`, `management_ios`).
- Gate production release lanes behind manual approval in GitHub Actions, same as the backend's staging→prod gate.
- Staged rollout on both stores (10% → 50% → 100%) once a release is live, so a bad build reaches a small slice first — this is a store feature (Play Console "staged rollout", App Store Connect "phased release"), not something you build yourself.

## 6. Order of operations, tied back to the roadmap

1. Finish the customer app's core booking flow (Sprint 0, per `GETTING-STARTED-WITH-CLAUDE-CODE.md`).
2. Register both developer accounts (§2) — start the Google Play closed-testing clock as early as you have *any* working build, even before management app is done, since 14 days is pure calendar time you can't compress.
3. Submit `customer_app` first (it's simpler and store-facing/public — get the review process learned on the app that matters most for launch).
4. Submit `management_app` to Android only at first (per the "Android-first" decision in `DEVELOPMENT.md` §1) — your restaurant staff can start using it on tablets before you bother with an iOS build.
5. Automate via Fastlane once both have been through manual submission once.
