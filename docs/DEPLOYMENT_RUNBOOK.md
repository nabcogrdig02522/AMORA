# Deployment Runbook (staging first)

## 1. Accounts and ownership
- Create organization-owned Supabase, Paystack, SMS provider, domain/DNS, email/support, Apple Developer and Google Play Console accounts.
- Enable MFA and least-privilege access; store credentials in a managed secret vault.
- Establish staging and production projects separately.

## 2. Supabase
- Take a backup; apply migrations in the order in `FINAL_RELEASE_PLAN.md` to staging. The core profile/likes/blocks/reports schema is included as the first migration.
- Inspect every RLS policy and test as anonymous, normal member, blocked member and admin.
- Enable Realtime for `public.messages` only if the app uses it.
- Create private storage buckets and verify object policies.
- Configure Auth providers, redirect allow-lists, OTP expiry/rate limits and SMS sender.
- Set `app_metadata.role=admin` only through a trusted Supabase Admin API process.

## 3. Edge Functions and secrets
- Deploy `create-payment` and `paystack-webhook` from the consolidated project.
- Set `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `PAYSTACK_SECRET_KEY`, `APP_ORIGIN` and any callback URL secrets in the function secret store.
- Use Paystack test credentials in staging. Never put secret keys in Flutter or Next.js public environment variables.
- Configure the Paystack webhook URL and verify signature handling with provider test events.

## 4. Flutter application
- Set `.env` values for Supabase URL and anon key only.
- Confirm platform permissions, deep links, SMS OTP flow, privacy disclosures and photo picker behavior.
- Run `flutter pub get`, `flutter analyze`, `flutter test`, then build signed Android App Bundle and iOS archive.
- Test on physical Android/iOS devices and slow/intermittent networks.

## 5. Admin console
- Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
- Install dependencies, run `npm run build`, deploy to a protected HTTPS domain.
- Configure auth redirects and verify database-side admin checks; client role checks are UX only.

## 6. Production cutover
- Approve legal and safety policies; configure support escalation.
- Run backup/restore rehearsal and incident response drill.
- Deploy migrations and functions in a maintenance window; smoke-test registration, discovery, chat, report/block, payment and admin.
- Start with a closed Ghana pilot and capped cohorts. Do not activate additional markets until local payment, legal and support readiness is signed off.
- Monitor crashes, auth failures, webhook errors, reports, moderation queue and support tickets daily during pilot.

## Rollback
- Prefer forward-fix for additive schema changes. Do not blindly drop columns/tables after data has been written.
- Keep previous mobile builds and admin deployment available. Disable risky features through server-side flags if validated.
- Restore database only from tested backups and with a documented data-loss decision.
