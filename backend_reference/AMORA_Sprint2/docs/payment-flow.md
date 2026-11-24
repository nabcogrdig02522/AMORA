# AMORA Payment Flow

1. Authenticated member selects Plus / Premium / Elite.
2. Mobile app calls `create-payment` with `{ "plan_code": "plus" }`.
3. Edge Function validates Supabase JWT, checks fixed server-side plan pricing, creates pending intent and initializes Paystack checkout.
4. App opens returned `authorization_url` in a secure external browser / provider-approved checkout surface.
5. Customer selects card or supported Ghana mobile money channel and approves.
6. Paystack sends `charge.success` to webhook.
7. Webhook validates `x-paystack-signature` over the exact raw request body.
8. Server verifies transaction by reference with Paystack and checks status, currency, amount and reference against local intent.
9. Server creates subscription entitlement idempotently and marks payment intent successful.
10. App refreshes subscription status from RLS-protected database.

Never grant premium access based on callback URL parameters, a client-side "success" screen, or a pending `pay_offline` response.

Plan prices are stored server-side in `create-payment`. The sample amounts are GHS 35, 65 and 120 represented as pesewas (3500, 6500, 12000). Confirm the final prices and tax treatment before live launch.
