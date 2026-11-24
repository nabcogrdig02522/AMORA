-- AMORA Sprint 2 schema additions. Review and apply in staging first.
create extension if not exists pgcrypto;

-- Admin status is read from trusted auth app_metadata, never user-editable user_metadata.
create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

create table if not exists public.member_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  min_age smallint not null default 18 check (min_age >= 18 and min_age <= 100),
  max_age smallint not null default 99 check (max_age >= min_age and max_age <= 100),
  preferred_genders text[] not null default '{}',
  preferred_goals text[] not null default '{}',
  max_distance_km integer check (max_distance_km is null or max_distance_km between 1 and 500),
  updated_at timestamptz not null default now()
);

create table if not exists public.member_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  interest text not null check (char_length(interest) between 1 and 40),
  primary key(user_id, interest)
);
create table if not exists public.member_values (
  user_id uuid not null references public.profiles(id) on delete cascade,
  value_key text not null check (char_length(value_key) between 1 and 40),
  primary key(user_id, value_key)
);
create table if not exists public.member_lifestyles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  lifestyle_key text not null check (char_length(lifestyle_key) between 1 and 40),
  primary key(user_id, lifestyle_key)
);

create table if not exists public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_code text not null check (plan_code in ('plus','premium','elite')),
  amount_minor integer not null check (amount_minor > 0),
  currency text not null default 'GHS' check (currency = 'GHS'),
  provider text not null default 'paystack',
  provider_reference text unique,
  checkout_url text,
  status text not null default 'initialized' check (status in ('initialized','pending','success','failed','abandoned')),
  provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_code text not null check (plan_code in ('plus','premium','elite')),
  status text not null default 'active' check (status in ('active','expired','cancelled')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  payment_intent_id uuid unique references public.payment_intents(id),
  created_at timestamptz not null default now()
);

create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  verification_type text not null check (verification_type in ('selfie','identity')),
  status text not null default 'pending' check (status in ('pending','approved','rejected','needs_resubmission')),
  private_object_path text,
  provider_name text,
  provider_reference text,
  reviewer_id uuid references auth.users(id),
  reviewer_note text,
  consented_at timestamptz not null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users(id),
  action text not null,
  target_type text not null,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Compatibility score: shared declared preferences only. Score is a recommendation aid.
create or replace function public.compatibility_score(candidate_id uuid)
returns numeric language plpgsql stable security definer set search_path = public
as $$
declare me uuid := auth.uid();
declare i numeric; v numeric; l numeric; g numeric;
declare total numeric := 0; weight numeric := 0;
begin
  if me is null or candidate_id = me then return null; end if;

  select case when count(*) = 0 then null
    else 100.0 * count(*) filter (where a.interest = b.interest)::numeric / count(*) end
    into i
  from public.member_interests a
  cross join public.member_interests b
  where a.user_id = me and b.user_id = candidate_id;

  -- For interests use Jaccard similarity to account for list sizes.
  select case when count(*) = 0 then null
    else 100.0 * count(*) filter (where a.interest = b.interest)::numeric /
      nullif((select count(*) from public.member_interests where user_id = me)
       + (select count(*) from public.member_interests where user_id = candidate_id)
       - count(*) filter (where a.interest = b.interest),0) end
    into i
  from public.member_interests a
  full join public.member_interests b on a.interest = b.interest and b.user_id = candidate_id
  where a.user_id = me or b.user_id = candidate_id;

  select case when count(*) = 0 then null else
    100.0 * count(*) filter (where a.value_key = b.value_key)::numeric /
    nullif((select count(*) from public.member_values where user_id = me)
      + (select count(*) from public.member_values where user_id = candidate_id)
      - count(*) filter (where a.value_key = b.value_key),0) end
  into v
  from public.member_values a
  full join public.member_values b on a.value_key = b.value_key and b.user_id = candidate_id
  where a.user_id = me or b.user_id = candidate_id;

  select case when count(*) = 0 then null else
    100.0 * count(*) filter (where a.lifestyle_key = b.lifestyle_key)::numeric /
    nullif((select count(*) from public.member_lifestyles where user_id = me)
      + (select count(*) from public.member_lifestyles where user_id = candidate_id)
      - count(*) filter (where a.lifestyle_key = b.lifestyle_key),0) end
  into l
  from public.member_lifestyles a
  full join public.member_lifestyles b on a.lifestyle_key = b.lifestyle_key and b.user_id = candidate_id
  where a.user_id = me or b.user_id = candidate_id;

  select case when a.relationship_goal = b.relationship_goal then 100.0 else 0.0 end
  into g from public.profiles a, public.profiles b where a.id = me and b.id = candidate_id;

  if i is not null then total := total + i * 0.30; weight := weight + 0.30; end if;
  if v is not null then total := total + v * 0.30; weight := weight + 0.30; end if;
  if l is not null then total := total + l * 0.20; weight := weight + 0.20; end if;
  if g is not null then total := total + g * 0.20; weight := weight + 0.20; end if;
  if weight = 0 then return null; end if;
  return round(total / weight, 1);
end; $$;

-- Discovery RPC returns only fields intended for member discovery.
create or replace function public.discover_profiles(limit_count integer default 20)
returns table (
  id uuid, display_name text, city text, bio text, relationship_goal text,
  photo_url text, compatibility numeric
) language sql stable security invoker set search_path = public
as $$
  select p.id, p.display_name, p.city, p.bio, p.relationship_goal, p.photo_url,
         public.compatibility_score(p.id)
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.is_active = true
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
    and not exists (select 1 from public.likes x where x.liker_id = auth.uid() and x.liked_id = p.id)
  order by public.compatibility_score(p.id) desc nulls last, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;

-- RLS and grants
alter table public.member_preferences enable row level security;
alter table public.member_interests enable row level security;
alter table public.member_values enable row level security;
alter table public.member_lifestyles enable row level security;
alter table public.payment_intents enable row level security;
alter table public.subscriptions enable row level security;
alter table public.verification_requests enable row level security;
alter table public.admin_audit_log enable row level security;

create policy "member manages own preferences" on public.member_preferences
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "member manages own interests" on public.member_interests
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "member manages own values" on public.member_values
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "member manages own lifestyle" on public.member_lifestyles
for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "member reads own payment intents" on public.payment_intents
for select to authenticated using (user_id = auth.uid());
create policy "admins read all payment intents" on public.payment_intents
for select to authenticated using (public.is_platform_admin());
-- No client insert/update policy: only trusted Edge Functions use service credentials.

create policy "member reads own subscription" on public.subscriptions
for select to authenticated using (user_id = auth.uid());
create policy "admins manage subscriptions" on public.subscriptions
for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy "member creates own verification request" on public.verification_requests
for insert to authenticated with check (user_id = auth.uid() and status = 'pending' and reviewer_id is null);
create policy "member reads own verification status" on public.verification_requests
for select to authenticated using (user_id = auth.uid());
create policy "admins manage verification" on public.verification_requests
for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

create policy "admins read audit log" on public.admin_audit_log
for select to authenticated using (public.is_platform_admin());
create policy "admins insert audit log" on public.admin_audit_log
for insert to authenticated with check (public.is_platform_admin() and admin_id = auth.uid());

grant execute on function public.compatibility_score(uuid) to authenticated;
grant execute on function public.discover_profiles(integer) to authenticated;

-- NOTE: If an earlier migration has permissive policies on the same tables,
-- inspect and remove overly broad policies. RLS policies are OR-combined.


-- Admin moderation visibility for the existing reports table from Sprint 1.
drop policy if exists "admins read all reports" on public.reports;
create policy "admins read all reports" on public.reports
for select to authenticated using (public.is_platform_admin());
drop policy if exists "admins update reports" on public.reports;
create policy "admins update reports" on public.reports
for update to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Admins can inspect member profiles for support/moderation; access is audited operationally.
drop policy if exists "admins read all profiles" on public.profiles;
create policy "admins read all profiles" on public.profiles
for select to authenticated using (public.is_platform_admin());
