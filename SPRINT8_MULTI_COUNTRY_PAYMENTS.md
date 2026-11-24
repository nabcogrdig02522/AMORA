# AMORA Sprint 8 — Multi-country Payments and Subscriptions

## Delivered
- Market-specific price catalogue (`market_plan_prices`) with currency, amount in minor units, billing days, provider code and activation windows.
- Payment intents now retain the member's country, currency and billing duration.
- Edge Function resolves the member's country from the trusted profile row and price from the server-side catalogue. The client cannot submit its own amount or currency.
- Ghana is the only enabled paid market in the seed data; other markets have no enabled prices and remain unavailable.
- Updated Paystack webhook validates against the exact currency and amount stored in the payment intent.
- Renewal periods extend from the latest active subscription end date rather than overwriting remaining time.
- Flutter membership screen loads current market's enabled plans and displays currency-aware transaction history.

## Apply / deploy
1. Apply base Sprint 1 schema, Sprint 2, Sprint 4, Sprint 6 regional foundation, Sprint 7 regional matching, then `20261128_sprint8_multi_country_payments.sql`.
2. Deploy the updated `create-payment` and `paystack-webhook` functions from `backend_reference/AMORA_Sprint2/supabase/functions/`.
3. Configure Supabase secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `PAYSTACK_SECRET_KEY`, `APP_ORIGIN`, `APP_CHECKOUT_URL`.
4. Confirm the Paystack Ghana merchant account and channels are enabled.
5. Test in staging: a Ghana user sees enabled plans; a user in a planned market sees no paid plans and the checkout endpoint refuses the request; tampering with client amount/currency is impossible because the function does not accept either.
6. Test webhook signature, amount/currency mismatch, duplicate webhook delivery, renewal extension and expired subscriptions.

## Market activation rules
A market should be enabled only after:
- provider onboarding and merchant approval;
- supported local payment methods confirmed;
- settlement bank account and payout currency verified;
- pricing approved in local minor units;
- refunds, chargebacks and customer support processes defined;
- local tax and consumer-law review completed;
- signed webhook verification and end-to-end sandbox/live tests passed.

Do not copy GHS prices into NGN, XOF, GNF, LRD, SLE, GMD, CVE or MRU by a simple exchange-rate conversion. Set local prices intentionally. For currencies with different minor-unit conventions, verify provider amount encoding before launch; this implementation assumes the payment provider's minor-unit convention and the Flutter display's 2-decimal convention, which must be revisited for zero-decimal currencies before enabling them.

## Known limitations / review items
- This is not a multi-provider gateway router yet. The function intentionally supports only Paystack + GHS + Ghana in this sprint.
- Country/currency display assumes 2 decimal minor units in the Flutter view. Do not enable currencies with different decimal conventions until a currency metadata table and display formatter are added.
- The market catalogue seeds illustrative Ghana prices of GHS 35, 65 and 120 per 30 days. Founder approval required before production.
- Existing subscription schema stores plan code and dates but not a separate currency snapshot. Payment history stores currency; subscription reporting should join to payment intent if historical currency is required.
- Payment webhook concurrency and provider event replay should be load-tested; use a database RPC/transaction for strict serialisation before large-scale production.
- No credentials, payment merchant account, webhook endpoint or live transaction have been configured in this environment. No Flutter build or Supabase migration has been executed here.
