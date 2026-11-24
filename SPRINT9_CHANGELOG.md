# Sprint 9 changelog

- Added `TrustSafetyService` for authenticated phone-number change verification, private selfie submission, member reports, block RPC and account deletion requests.
- Added `TrustSafetyScreen`, reachable from the shield icon in the main app bar.
- Added `member_reports`, `account_deletion_requests`, private Storage bucket policies and `block_member(uuid)` in the Sprint 9 migration.
- Added `/admin/moderation` in the founder console for report and verification status handling.
- Added setup, migration-order, privacy and production-readiness notes.

## Validation status

Source files and package structure were reviewed. Flutter/Dart SDK was not available in this runtime, and no Supabase project credentials or staging database were connected. Therefore Flutter compilation, SQL execution, RLS verification, admin workflow tests and device tests have not been performed.
