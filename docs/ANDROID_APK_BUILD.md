# Android APK build

## Current build status
This source bundle does not contain a generated `android/` directory or a compiled APK. The authoring environment used to prepare it does not have Flutter/Dart or the Android SDK. The GitHub Actions workflow therefore creates the Android platform folder on a hosted runner, runs Flutter checks, and uploads `app-release.apk` as an Actions artifact.

## Build the QA APK
1. Create a private GitHub repository and upload the contents of this project folder to its root.
2. In repository Settings → Secrets and variables → Actions, add `SUPABASE_URL` and `SUPABASE_ANON_KEY` for the staging Supabase project. These are public client configuration values; never add the Supabase service-role key or Paystack secret to the mobile app.
3. Open Actions → **Flutter checks and Android APK** → Run workflow.
4. Wait for the `android-apk` job to complete. Download the `amora-android-release-qa` artifact from the workflow run. It contains `app-release.apk`.
5. Install the QA APK on a test Android device and complete the test plan before any public release.

The workflow currently produces a QA APK using Flutter's generated default signing configuration. It is not the founder's production signing identity and must not be treated as the final Google Play release artifact.

## Production signing
Before a production APK/AAB is built, create and securely retain an Android upload/release keystore. Add GitHub Actions secrets for a base64-encoded keystore, keystore password, key alias and key password; then add the corresponding Gradle signing configuration and protect the secrets with repository/environment approvals. Never commit a keystore or passwords. Keep an offline backup: losing the signing key can prevent updates to the published app.

## Required release checks
- Use production Supabase URL/anon key only after staging tests pass.
- Confirm Android application ID/package name and app display name.
- Set app icon, splash screen, privacy policy URL and support contact.
- Test Android permissions, camera/selfie upload, OTP, checkout return, offline behavior, screen sizes and accessibility.
- Verify that no service-role key, Paystack secret or other server secret is present in the APK.
- For Google Play, produce a signed Android App Bundle (`flutter build appbundle --release`) and complete Play Console declarations. An APK alone is not the usual Play Store upload artifact.
