# AMORA Sprint 9 — Trust, Safety & Identity Verification

## What this sprint adds

- Phone OTP actions using Supabase Auth SMS OTP (`signInWithOtp` and `verifyOTP`). Phone delivery requires a configured SMS provider and supported Auth settings.
- Private selfie evidence upload to the `amora-verification` Storage bucket, with consent timestamp and a `verification_requests` record for human review.
- Member reporting with fixed categories and optional description.
- Blocking through a database RPC. It creates a block, removes likes in both directions, deletes the match and cascades its conversation.
- Account-deletion request workflow. This is a request queue, not instant deletion.
- Founder admin moderation route at `/admin/moderation` for report status and pending verification status.

## Migration order and prerequisites

1. Apply the original AMORA Sprint 1/base schema first. It must provide `profiles`, `likes`, `blocks`, `reports` and the fields referenced by the earlier migrations. The Sprint 1 migration is not bundled in this package because the source project did not include it.
2. Apply `20261124_sprint2.sql`.
3. Apply `20261125_sprint4_matching_messaging.sql`.
4. Apply `20261126_west_africa_regional_foundation.sql`.
5. Apply `20261127_sprint7_regional_matching.sql`.
6. Apply `20261128_sprint8_multi_country_payments.sql`.
7. Apply `20261129_sprint9_trust_safety.sql`.

The Sprint 2 migration is included in `supabase/migrations/` for a single ordered migration directory. Validate all historical schema assumptions against the actual Sprint 1 database before applying. In particular, the block RPC expects `blocks(blocker_id, blocked_id)` and Sprint 4 match/conversation tables.

## Setup

- Configure Supabase Auth phone login and an SMS provider; test Ghanaian numbers and international formats. E.164 format is recommended (for example, `+233...`).
- Confirm the `image_picker` permission declarations for Android and iOS. Camera permissions and app-store privacy disclosures are required.
- The Storage bucket is private and limited to JPEG, PNG and WebP up to 10 MB. The client may upload/read/delete only inside its own user-id folder. Admins can read bucket objects under the RLS policy; use signed URLs with short expiry in any future evidence viewer and log access.
- Assign administrator role only through a trusted server-side Supabase Admin API process using `app_metadata.role = 'admin'`. Never let clients set this field.
- Admin dashboard requires the existing `.env` values and an authenticated admin session. Route access is additionally checked against `app_metadata.role` and database RLS.

## Important limitations / production controls

- Selfie review is manual. This sprint does not provide liveness detection, face matching, age estimation or government-ID validation. Do not display a verified identity badge merely because a selfie was uploaded; only an authorised review decision should qualify, and the policy/meaning of that badge must be explicit.
- Phone OTP proves control of a phone number at the time of verification; it does not prove legal identity, age or account uniqueness.
- Report and verification queue UI is a starter. It does not yet include evidence preview, moderator notes, escalation, appeals, suspensions, moderator access logs or a complete immutable audit event for every decision.
- Account deletion is request-only. Build a secure server-side workflow that reauthenticates the member, checks retention/legal obligations, handles storage and related records, and deletes the Auth user through the Admin API. Never put a service-role key in Flutter or browser code.
- The database currently retains verification metadata after a review. Define retention periods and a secure evidence deletion schedule before launch.
- Blocking deletes a match and its conversation through cascade. This is consequential and cannot be undone from the current UI. Confirm this product policy and consider retaining minimal abuse-prevention evidence while deleting chat content as legally appropriate.
- Review all existing RLS policies. PostgreSQL permissive policies are OR-combined; broad legacy policies can weaken these controls.
- Apply in staging first and run security tests with two ordinary users, one blocked pair, and one admin. This package has not been deployed to a live Supabase project or device-tested.
