# AMORA West Africa Expansion — Sprint 6

## Product direction
AMORA remains Ghana-first for the initial pilot, but its data model and app navigation are extended for a multi-country West African rollout. The starter includes a 16-market country catalogue covering Ghana, Nigeria, Côte d’Ivoire, Senegal, Benin, Togo, Burkina Faso, Mali, Niger, Guinea, Guinea-Bissau, Liberia, Sierra Leone, The Gambia, Cabo Verde and Mauritania.

Country membership in this catalogue does not mean the app, payment rails, customer support or legal operations are live there. The migration marks Ghana as `pilot` and all other markets as `planned`.

## Included in this package
- Country and currency reference catalogue.
- `country_code` on member profiles.
- Member-owned regional preferences with an explicit cross-border discovery opt-in.
- Flutter Region tab to choose country/city and save cross-border preference.
- Regional market configuration table for launch status and payment-provider mapping.
- Rollout notes and implementation requirements.

## Apply the migration
Apply `supabase/migrations/20261126_west_africa_regional_foundation.sql` after the existing Sprint 1 base schema and the prior Sprint 2/Sprint 4 migrations.

Assumptions to verify:
- `public.profiles.id` is the authenticated user's UUID.
- `public.profiles.city` exists and is writable by the member under existing RLS.
- Existing profile RLS permits a member to update their own row.
- No conflicting check constraint or policy name exists in your deployed database.

The migration is additive. It does not replace the existing schema or automatically change the discovery RPC.

## Important next backend work
1. Update the discovery RPC so that cross-border candidates are returned only when the requesting member has opted in and the candidate's country is allowed by the product's matching rules. Respect both users' privacy and block lists. The current migration stores preferences but does not yet change matching behaviour.
2. Add a country/currency-aware plan catalogue on the server. Never convert Ghana sample prices into other currencies by simple exchange-rate arithmetic. Set local commercial prices after market research, tax review and provider confirmation.
3. Introduce a payment-provider adapter per market. Paystack remains the existing Ghana implementation in this scaffold. Other providers must be separately onboarded, configured and tested. Do not expose payment options in a market until its provider, settlement account, refunds, webhook verification and local payment methods are approved.
4. Store money as integer minor units plus ISO currency code. Do not mix currencies in aggregate revenue reports without FX conversion and a documented reporting rate.
5. Add country-specific customer support, moderation coverage, consumer terms, privacy notices, consent language and data-retention rules before opening each market.
6. Add language localisation. Suggested initial product languages: English and French, with Portuguese considered for Cabo Verde and Guinea-Bissau. Validate translations with local reviewers.
7. Add phone-number country code handling and test OTP delivery country by country; SMS delivery is not guaranteed merely because a country is listed.
8. Add market-aware age/consent checks and safety escalation processes before onboarding members in each jurisdiction.

## Suggested rollout sequence
- Phase 1: Ghana pilot; harden trust/safety, payments, support and retention.
- Phase 2: Nigeria and Côte d’Ivoire, subject to legal, payment, support and operational readiness.
- Phase 3: Senegal, Benin and Togo.
- Phase 4: Liberia, Sierra Leone, The Gambia, Guinea, Guinea-Bissau, Burkina Faso, Mali, Niger, Cabo Verde and Mauritania, based on validated demand and operational readiness.

This is a proposed sequencing strategy, not a statement that these markets have been approved or that legal requirements are identical across them.

## Current limitations
- No new country-specific payment gateway has been integrated.
- The existing payment screen and Paystack Edge Function still contain Ghana-specific sample pricing and assumptions. Treat paid checkout as Ghana-only until the server-side market and currency validation is implemented.
- Cross-border preference is saved, but the current discovery SQL function has not yet been updated to enforce it.
- Country selection is not GPS geolocation and does not verify a member's residence.
- This is a development scaffold, not a deployed or tested regional service.
