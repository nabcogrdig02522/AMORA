# AMORA — Final Release Candidate Plan

## What this package is
This is a consolidated implementation candidate built on the Sprint 9 archive. It adds Sprint 10 administration/analytics controls and the final integration, QA, deployment, compliance and launch runbooks. It is **not a deployed production service** and does not imply successful live transactions, store approval or legal clearance.

## Implemented in this package
- Existing Flutter/Supabase starter, profiles, discovery, matching, chat, subscriptions, regional preferences and trust/safety workflows retained.
- Admin member listing with search, account status actions and database RPC enforcement.
- Admin aggregated daily registration, payment and subscription reports.
- Admin-only functions for member status, report review and verification review, with audit log entries.
- Release candidate SQL migration: `supabase/migrations/20261130_release_candidate_admin_analytics.sql`.
- Launch runbooks, QA plan, environment matrix, risk register and store submission checklist.

## Important constraints / unresolved integration items
1. The bundle now includes a minimal core migration for `profiles`, `likes`, `blocks` and `reports`; Sprint 4 creates the new `matches`, `conversations` and `messages` tables. Apply this ordered chain to a clean Supabase project. Do not apply it blindly over a pre-existing MVP schema without reconciling old tables and constraints.
2. Server-side sign-up profile creation enforces the 18+ rule using date-of-birth metadata. The Flutter sign-up form collects DOB, but the founder must still review age-assurance obligations and abuse controls with Ghana counsel.
3. Discovery now enforces minimum/maximum age, preferred gender and relationship-goal filters on the server. Distance is stored as a preference but is not enforced because this release does not collect/compute geographic coordinates.
4. Sprint 8 payment processing is Ghana + Paystack only. Other West African markets remain disabled; prices are illustrative until approved by the founder.
5. Recurring auto-renewal is not implemented; subscriptions are fixed-duration and members must initiate renewal checkout.
6. OTP requires a configured SMS provider. Selfie review is manual; no liveness or government-ID verification vendor is integrated.
7. App/admin source has not been compiled against a live project in this environment. Flutter/Dart SDK, Android SDK and live Supabase credentials were not available. The Android workflow generates an APK artifact in GitHub Actions after the project is pushed and the workflow is run; that artifact is a QA build, not a production-signed store release.
8. Supabase admin role assignment must use a trusted server/admin process to set `app_metadata.role=admin`. Never allow a client to set it.
9. Before deployment, configure Edge Function secrets, `APP_ORIGIN`, callback URL, SMS provider, auth redirects, monitoring, backups and data retention. Rehearse all migrations and RLS policies on staging.

## Recommended migration order
- `20261123_core_schema.sql`
- `20261124_sprint2.sql`
- `20261125_sprint4_matching_messaging.sql`
- `20261126_west_africa_regional_foundation.sql`
- `20261127_sprint7_regional_matching.sql`
- `20261128_sprint8_multi_country_payments.sql`
- `20261129_sprint9_trust_safety.sql`
- `20261130_release_candidate_admin_analytics.sql`

Never run this sequence directly on production before a staging rehearsal, backup and SQL review. The order is a proposed dependency sequence, not proof that the current schema is compatible.

## Definition of done for launch
- All migrations pass on a clean staging database and on a restored production-like backup.
- RLS tests demonstrate cross-user data isolation, including chats, reports, verification media, payments and admin operations.
- Payment tests cover invalid signatures, mismatched amount/currency/reference, replay, duplicate webhook, timeout and chargeback/refund operations.
- Flutter app builds for Android and iOS; critical user journeys pass on physical devices.
- Admin dashboard build passes; admin pages reject non-admin users and database policies independently enforce privileges.
- Ghana legal review, privacy policy, terms, age assurance, safety escalation and data-retention rules approved.
- Support mailbox, incident contacts, backups, monitoring and restore drills are operational.
- Store listings, privacy disclosures, age rating, screenshots, app signing and account ownership are complete.
- Founder signs off pricing, moderation policy, market scope, customer support and launch decision.
