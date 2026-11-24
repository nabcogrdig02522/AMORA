# AMORA Sprint 7 — Regional Matching Engine

## What this adds
- Replaces the discovery RPC with a country-aware version.
- Members continue to discover compatible profiles in their own country without changing settings.
- Cross-border discovery requires **both** the requesting member and the candidate to enable it.
- Supports an optional country allow-list in `member_regional_preferences.preferred_country_codes`; an empty list means all regional markets.
- Excludes blocked users in either direction, already-liked profiles and passed profiles.
- Returns `country_code` and `country_name` so discovery cards can identify cross-border profiles.
- Updates the Region screen copy and fixes its preference save behaviour.

## Apply in order
1. Apply the Sprint 1 base schema.
2. Apply Sprint 2 migration.
3. Apply Sprint 4 migration.
4. Apply Sprint 6 regional foundation migration `20261126_west_africa_regional_foundation.sql`.
5. Apply this migration `20261127_sprint7_regional_matching.sql`.

The migration drops and recreates `discover_profiles(integer)` because PostgreSQL does not permit changing a function's table return shape with `CREATE OR REPLACE`. Review any other database functions or clients that depend on the previous discovery return columns.

## Consent behaviour
| Requester opt-in | Candidate opt-in | Same country | Different country |
|---|---|---|---|
| Off | Off | Eligible | Hidden |
| On | Off | Eligible | Hidden |
| Off | On | Eligible | Hidden |
| On | On | Eligible | Eligible, subject to allow-list |

This is mutual visibility consent, not a guarantee of compatibility or a match. Likes remain separate and a match is created only through the existing reciprocal-like workflow.

## Important caveats
- This migration assumes the Sprint 6 regional tables and Sprint 4 `profile_passes` table exist.
- Existing profile RLS, block-table structure and compatibility scoring are unchanged.
- This version does not yet implement age, gender, distance, relationship-goal preference filtering; it retains the existing discovery filtering scope. Those should be enforced server-side before a public launch.
- Country selection is self-declared, not verified residence or GPS location.
- The SQL has not been run against the user's Supabase project. Test migration order, policies, query plans and consent cases in a staging project.
