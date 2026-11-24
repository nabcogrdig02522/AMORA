# AMORA Sprint 2 — Implementation Package

This package extends the AMORA Flutter/Supabase MVP with implementation foundations for:
- Ghana payments through Paystack hosted checkout: MTN MoMo, Telecel Cash, AT Money/AirtelTigo Money and cards, subject to merchant account/channel enablement.
- Subscription and payment records, server-side webhook confirmation.
- Compatibility profile data and a transparent weighted compatibility score.
- Phone verification through Supabase Auth phone OTP.
- Private selfie / optional ID verification review workflow (provider-neutral; no ID document is exposed to other members).
- Founder admin dashboard starter (Next.js) using Supabase Auth and RLS-protected admin views.

This is source code for integration and staging, not a deployed service. It cannot process live payments until you open and verify a Paystack merchant account, configure keys and webhook, enable channels, deploy functions and test with provider-approved test credentials.

## Architecture decisions

**Payments:** Paystack is the initial aggregator adapter because its Ghana documentation explicitly lists MTN MoMo, Telecel Cash and ATMoney/Airtel Money (`atl`) as mobile money providers and supports card checkout. The app uses hosted checkout so card data is handled by the payment provider rather than AMORA. Paystack's documented mobile-money provider codes are `mtn`, `vod`, and `atl`. Check merchant eligibility and current channel availability before launch.

**Subscriptions:** Payment authorization is one-time. A successful verified webhook activates a fixed-duration entitlement. Do not treat a pending/offline charge response as payment success. For automatic recurring card billing, build and separately test the provider's subscription/authorization flow; this package deliberately implements one-time renewal checkout.

**Phone:** Supabase phone OTP requires an enabled SMS provider and appropriate rate limits. Phone verification is separate from legal identity verification.

**Selfie / ID:** This package stores verification request metadata and review status only. It does not claim to perform biometric liveness or validate Ghana Cards. For production, select a contracted identity provider, complete privacy/legal review, and integrate its server-side SDK/API. Keep raw selfie/ID files in private storage with narrow staff access and short retention. Never expose them through public profile queries.

**Compatibility:** Weighted, explainable score over mutually declared interests, values, lifestyle and relationship goals. It is a recommendation aid, not a psychological assessment and not a guarantee of relationship success. Do not infer sensitive traits.

## 1. Prerequisites
- Supabase project with Auth, Database, Storage and Edge Functions.
- Paystack Ghana merchant account with test/live keys.
- Flutter stable (for the existing mobile project).
- Node.js 20+ and npm (for admin dashboard).
- Supabase CLI.
- A verified HTTPS domain for admin and webhook endpoints.

## 2. Apply database migration
Run `supabase/migrations/20261124_sprint2.sql` in the Supabase SQL Editor or through your migration workflow.

Create private Storage buckets:
- `verification-private` (private; no public read)
- `profile-photos` (private or public derivatives only; do not expose original verification media)

Storage access for verification media should be mediated by a trusted backend/admin role. Do not create broad authenticated read policies.

## 3. Configure phone OTP
In Supabase Dashboard:
1. Authentication → Providers → Phone: enable.
2. Configure an SMS provider and sender settings.
3. Set OTP expiry and rate limits appropriate to your provider.
4. Configure allowed redirect URLs and test Ghana phone formats (+233...).
5. Test signup, resend, expiry, invalid code and abuse throttling.

The Flutter phone OTP screen is not yet wired into the original app; use Supabase `signInWithOtp(phone: ...)` and `verifyOTP(phone: ..., token: ..., type: OtpType.sms)` after adding phone fields and consent UX.

## 4. Configure Paystack
Set Edge Function secrets (never commit these):
```bash
supabase secrets set PAYSTACK_SECRET_KEY=sk_test_xxx
supabase secrets set PAYSTACK_WEBHOOK_SECRET=sk_test_xxx
supabase secrets set APP_CHECKOUT_URL=https://your-domain.example/payment-result
```
Deploy:
```bash
supabase functions deploy create-payment
supabase functions deploy paystack-webhook --no-verify-jwt
```
Set the Paystack webhook URL to:
`https://YOUR_PROJECT_REF.supabase.co/functions/v1/paystack-webhook`

Use the Paystack secret key only in Edge Functions. The mobile app calls `create-payment` with its authenticated Supabase JWT. The function initializes a hosted checkout transaction; the user completes payment on Paystack. The webhook verifies the HMAC signature against the raw request body and confirms the reference with Paystack before entitlement activation.

Supported initial checkout options:
- `card`
- `mobile_money` (provider selection is handled by Paystack checkout)
The Paystack Ghana docs list MTN (`mtn`), Telecel (`vod`) and ATMoney/AirtelTigo (`atl`) mobile-money codes. Confirm exact channel enablement in the merchant dashboard.

## 5. Deploy admin dashboard
```bash
cd admin
cp .env.example .env.local
# Fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
npm install
npm run dev
```
For production:
```bash
npm run build
npm start
```
Deploy to a trusted hosting provider with HTTPS. Protect `/admin` through Supabase Auth and RLS. Admin status must be set in trusted `app_metadata` by a project owner/service process; never allow users to edit their own role from a client.

## 6. Compatibility questionnaire
The migration creates `member_preferences`, `member_interests`, `member_values`, `member_lifestyles`, and `compatibility_score()`.

Collect explicit answers during onboarding. Keep the options respectful and non-sensitive. The sample score is:
- 30% shared interests
- 30% shared values
- 20% lifestyle alignment
- 20% relationship-goal alignment

Missing categories are excluded and remaining weights normalized. Add hard filters (age range, distance/area, gender preference) separately, with clear user controls. Avoid using protected characteristics or sensitive inferred data.

## 7. Verification operations
The migration creates `verification_requests` with statuses `pending`, `approved`, `rejected`, `needs_resubmission`. The mobile app should:
1. Explain what each check does and why it is requested.
2. Ask for explicit consent before camera/file access.
3. Upload to private `verification-private` storage using short-lived signed upload URLs issued by a trusted function.
4. Store only object path and request metadata in `verification_requests`.
5. Allow a restricted reviewer to approve/reject with a reason.
6. Delete source media according to an approved retention schedule.

Do not store Ghana Card numbers, document images, face templates or biometric vectors in ordinary profile tables. Optional ID verification requires a vetted provider and legal basis. Selfie image review alone is not liveness verification.

## 8. Security checklist before public beta
- Enable RLS on every exposed table; review policies with a second engineer.
- Keep Supabase service-role / secret keys, Paystack secret, SMS credentials and identity-provider secrets server-side only.
- Verify payment webhook signatures and then verify each transaction with Paystack; make webhook handling idempotent.
- Never activate premium access from a client redirect or unverified API response.
- Add rate limits and abuse detection to likes, OTP, chat, reports and payment initialization.
- Add block/report UI and moderation queue before public onboarding.
- Configure private buckets, signed URLs, malware/image moderation and retention controls.
- Implement account deletion, data export, consent records, privacy notice and terms.
- Conduct penetration testing, dependency scanning, backup/restore test and incident-response rehearsal.
- Obtain Ghana-specific legal advice on data protection, consumer protection, payments, age assurance and cross-border processing.

## 9. Known implementation boundary
The Edge Functions and SQL are concrete integration scaffolds. The admin UI is a starter dashboard. Provider accounts, merchant approvals, credentials, SMS delivery, identity vendor contracts, app store signing, hosting and live acceptance testing require actions by the founder and development team. No credentials or live services are included.

## 10. Recommended staging acceptance tests
1. User A and User B complete profiles and preferences.
2. Compatibility score is computed only from user-declared data.
3. A likes B; B likes A; exactly one match is created.
4. User requests Plus checkout; Paystack test checkout opens.
5. Pending charge does not grant Plus.
6. Valid signed webhook + successful transaction verification grants entitlement once.
7. Duplicate webhook does not extend entitlement twice.
8. Invalid webhook signature is rejected.
9. Non-admin cannot access admin tables or verification media.
10. User can submit a selfie verification request but cannot approve it.
11. Admin can review request and record an auditable decision.
12. Blocked users are excluded from discovery and messaging.

## 11. Flutter integration snippets
The `mobile_integration/` folder contains:
- `payment_service.dart`: invokes the authenticated payment Edge Function and opens hosted checkout. Add `url_launcher` to the Flutter app dependencies.
- `compatibility_service.dart`: saves declared preferences and calls the discovery RPC.
- `phone_otp_notes.dart`: Supabase SMS OTP request/verification helper.

Integrate these into screens with loading/error states and explicit consent. Do not show a "Premium active" badge until the verified subscription row is present.
