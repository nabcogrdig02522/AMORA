# AMORA QA and Acceptance Test Plan

## Authentication and onboarding
- Register with valid/invalid email or phone; confirm OTP expiry, resend throttling, wrong code and account recovery.
- Confirm under-18 users cannot create/use accounts. Add a robust age assurance flow; a date-of-birth field alone is not sufficient.
- Confirm required consent text and version are recorded before sensitive processing.

## Profile and discovery
- Create/edit profile; reject invalid lengths and missing required fields.
- Verify private profile fields are not returned by discovery RPC.
- Confirm inactive, suspended, blocked, passed and already-liked profiles are excluded.
- Test cross-border discovery only when both parties opt in; enforce country allow-lists and age/gender/goal/distance filters on the server.
- Test empty states, deleted photos, pagination, abuse throttling and location permission denial.

## Likes, matches and chat
- Like/skip; mutual like creates exactly one match/conversation.
- Test duplicate likes, concurrent mutual likes, block/unmatch and message access after a block.
- Test realtime reconnect, offline queue, message ordering, report-from-chat, spam limits and media restrictions.

## Payments
- Use Paystack test mode. Test success, failure, abandoned checkout, timeout and webhook retries.
- Reject invalid HMAC, wrong transaction reference, amount/currency mismatch, wrong member and duplicate callback.
- Confirm only server-verified webhook activates or extends a subscription.
- Reconcile every transaction to provider dashboard and accounting ledger; test refund/chargeback handling.
- Do not enable non-Ghana markets until provider, currency precision, tax, FX, settlement and refund paths are validated.

## Trust and safety
- Submit report; verify reporter can see only own report and target cannot read it.
- Upload allowed and disallowed files; verify private bucket, size/type restrictions and object ownership.
- Verify moderator decisions require admin role and are audit logged.
- Block another user; ensure likes/matches are removed and neither can message or discover the other.
- Test deletion request, identity confirmation, export/retention and irreversible deletion workflow.
- Conduct a tabletop exercise for threats, stalking, underage reports, self-harm disclosures and law-enforcement requests with counsel-approved protocols.

## Admin and analytics
- Non-admin cannot query admin views, member records, verification evidence or invoke admin RPCs.
- Admin can search members, suspend/reactivate, review reports and verification; every action creates audit record.
- Compare counts and payment summaries with source tables and provider records.
- Verify pagination, rate limits, audit retention and no sensitive PII in logs.

## Release gates
- P0: auth, data leakage, RLS, payment fraud, child safety, block/report and account deletion defects — must be zero.
- P1: crashes, match/chat reliability, accessibility and core onboarding defects — must be zero or explicitly waived.
- P2: cosmetic issues — triaged with owner/date.


## Additional release-candidate security checks
- Confirm `profiles.date_of_birth`, `suspended_at` and `suspension_reason` cannot be selected or modified by ordinary authenticated users through PostgREST.
- Confirm discovery RPC returns only public profile fields while applying age, gender and relationship-goal preferences server-side.
- Confirm a verification request cannot reference another member's Storage object path and members cannot set moderator fields.
- Confirm direct block deletion is denied to members and the block RPC removes the corresponding match/conversation.
- Confirm a non-active account cannot appear in discovery or send chat messages.
- Confirm duplicate/concurrent successful Paystack webhooks activate one payment entitlement only and serialize separate payments per member.
