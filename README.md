# AMORA — consolidated Flutter/Supabase release candidate

AMORA is a Ghana-first adult dating and matchmaking application, built with Flutter and Supabase, with a staged West African expansion catalogue.

## Included
- Flutter mobile source for email/password authentication, 18+ date-of-birth capture, profile setup, compatibility preferences, discovery, likes, mutual matches, chat, subscriptions, regional preferences and trust/safety workflows.
- Ordered Supabase migrations, including the core profile/likes/blocks/reports schema, matching/messaging, market configuration, Ghana Paystack payment records, moderation and admin analytics.
- Supabase Edge Functions for Paystack checkout and verified webhook subscription activation.
- Next.js founder console for member controls, moderation and aggregated analytics.
- GitHub Actions checks and an Android QA APK build workflow.
- Deployment, QA, Android APK and release-risk documentation.

## Start locally
1. Install Flutter stable and Android Studio / Android SDK; run `flutter doctor`.
2. Copy `.env.example` to `.env` and set the Supabase project URL and anon/public key.
3. Run `flutter pub get`, `flutter analyze`, `flutter test`.
4. Run the SQL migrations in the order listed in `FINAL_RELEASE_PLAN.md` against a clean staging project.
5. Configure Supabase Auth, SMS provider, private verification bucket, Realtime for messages, Edge Function secrets and Paystack test credentials.
6. Run `flutter run` on an Android device/emulator.

## Android APK
This authoring environment did not contain Flutter/Dart or the Android SDK, so no APK is included. The GitHub Actions workflow generates the Android platform project, runs checks and uploads a QA APK artifact when manually triggered or on a version tag. See `docs/ANDROID_APK_BUILD.md`.

## Important launch boundaries
- Ghana is the only payment-enabled pilot market; other catalogue markets are disabled until local approvals and payment rails are completed.
- Prices are illustrative and require founder approval.
- Subscription renewals are member-initiated; automatic recurring billing is not implemented.
- Age is self-declared at registration and checked server-side against the supplied date of birth; this is not independent identity/age verification.
- Phone OTP requires an SMS provider. Selfie verification is manual review, not automated liveness or identity verification.
- Distance preference is saved but not used to filter discovery until a privacy-reviewed location/distance feature is implemented.
- No production Supabase project, payment merchant, SMS sender, signing keystore or app-store account is configured in this bundle.

## Security notes
- Never put Supabase service-role or Paystack secret keys in Flutter, `.env`, GitHub public variables or the admin browser bundle.
- Admin authorization is based on trusted `app_metadata.role=admin` plus database-side RPC/RLS enforcement.
- Profile date of birth is excluded from authenticated client column grants; the discovery RPC returns only intended public fields.
- Use staging first. Do not apply migrations blindly over an existing AMORA database with a different schema.
