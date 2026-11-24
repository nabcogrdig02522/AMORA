# AMORA Final Release Candidate

This is the consolidated working package for the AMORA Ghana-first dating platform and planned West African expansion.

Start with `FINAL_RELEASE_PLAN.md`. Review `docs/DEPLOYMENT_RUNBOOK.md`, `docs/QA_TEST_PLAN.md`, `docs/LAUNCH_CHECKLIST.md` and `docs/RELEASE_RISK_REGISTER.md` before any live deployment.

**Status:** implementation candidate / staging handoff. Not production-live.

The Flutter project is at this package root. The founder console is in `backend_reference/AMORA_Sprint2/admin`. The ordered core and feature migrations are in `supabase/migrations`; apply them to a clean staging project first, and reconcile carefully before using an existing database.


## Android APK
The source bundle includes a GitHub Actions workflow to generate a QA APK on a hosted Flutter/Android runner. Follow `docs/ANDROID_APK_BUILD.md`. A production-signed APK/AAB requires the founder's Android signing keystore and secrets; no keystore or APK was available in this authoring environment.
