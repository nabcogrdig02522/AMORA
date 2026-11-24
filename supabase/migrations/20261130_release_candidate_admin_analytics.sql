-- AMORA Release Candidate: admin controls, analytics, operational configuration.
-- Apply AFTER migrations 20261124 through 20261129 in a staging project first.

create table if not exists public.platform_settings (
  setting_key text primary key,
  setting_value jsonb not null default '{}'::jsonb,
  description text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
alter table public.platform_settings enable row level security;
drop policy if exists "admins manage platform settings" on public.platform_settings;
create policy "admins manage platform settings" on public.platform_settings
  for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Member status is separate from profile presentation fields.
alter table public.profiles add column if not exists account_status text not null default 'active'
  check (account_status in ('active','suspended','under_review','deleted_pending'));
alter table public.profiles add column if not exists suspended_at timestamptz;
alter table public.profiles add column if not exists suspension_reason text;
create index if not exists profiles_account_status_idx on public.profiles(account_status);

-- Protect date_of_birth and internal suspension metadata from direct PostgREST reads.
-- Members receive only the profile columns required by the application/admin UI.
revoke all on table public.profiles from anon, authenticated;
grant select (id, display_name, gender, city, bio, relationship_goal, photo_url,
  is_active, created_at, updated_at, country_code, account_status)
  on table public.profiles to authenticated;
grant insert (id, display_name, gender, city, bio, relationship_goal, photo_url,
  is_active, country_code, updated_at)
  on table public.profiles to authenticated;
grant update (display_name, gender, city, bio, relationship_goal, photo_url,
  is_active, country_code, updated_at)
  on table public.profiles to authenticated;

drop policy if exists "active profiles visible to authenticated users" on public.profiles;
create policy "active profiles visible to authenticated users" on public.profiles
  for select to authenticated using (
    (is_active = true and coalesce(account_status,'active') = 'active') or id = auth.uid()
  );


-- Prevent members from self-assigning account status or clearing a suspension.
create or replace function public.guard_profile_account_status()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if (new.account_status is distinct from old.account_status)
     or (new.suspended_at is distinct from old.suspended_at)
     or (new.suspension_reason is distinct from old.suspension_reason) then
    if coalesce(auth.role(),'') <> 'service_role' and not public.is_platform_admin() then
      raise exception 'Account status can only be changed by platform administrators';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists profiles_guard_account_status on public.profiles;
create trigger profiles_guard_account_status
before update on public.profiles
for each row execute function public.guard_profile_account_status();

create or replace function public.admin_set_member_status(
  p_member_id uuid, p_status text, p_reason text default null
) returns void language plpgsql security definer set search_path = public
as $$
declare v_admin uuid := auth.uid();
begin
  if v_admin is null or not public.is_platform_admin() then raise exception 'Administrator access required'; end if;
  if p_status not in ('active','suspended','under_review','deleted_pending') then raise exception 'Invalid account status'; end if;
  if p_member_id is null or p_member_id = v_admin then raise exception 'Invalid target member'; end if;
  update public.profiles set account_status=p_status,
    is_active=(p_status='active'),
    suspended_at=case when p_status='suspended' then now() else null end,
    suspension_reason=case when p_status='suspended' then left(coalesce(p_reason,''),1000) else null end
    where id=p_member_id;
  if not found then raise exception 'Member not found'; end if;
  insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
  values(v_admin,'member_status_changed','profile',p_member_id::text,
    jsonb_build_object('status',p_status,'reason',left(coalesce(p_reason,''),1000)));
end; $$;
revoke all on function public.admin_set_member_status(uuid,text,text) from public;
grant execute on function public.admin_set_member_status(uuid,text,text) to authenticated;

create or replace function public.admin_review_member_report(
  p_report_id uuid, p_status text, p_note text default null
) returns void language plpgsql security definer set search_path = public
as $$
declare v_admin uuid := auth.uid();
begin
  if v_admin is null or not public.is_platform_admin() then raise exception 'Administrator access required'; end if;
  if p_status not in ('reviewing','actioned','dismissed') then raise exception 'Invalid report status'; end if;
  update public.member_reports set status=p_status, moderator_id=v_admin,
    moderator_note=left(coalesce(p_note,''),2000), reviewed_at=case when p_status in ('actioned','dismissed') then now() else null end
    where id=p_report_id;
  if not found then raise exception 'Report not found'; end if;
  insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
  values(v_admin,'report_reviewed','member_report',p_report_id::text,jsonb_build_object('status',p_status));
end; $$;
revoke all on function public.admin_review_member_report(uuid,text,text) from public;
grant execute on function public.admin_review_member_report(uuid,text,text) to authenticated;

create or replace function public.admin_review_verification(
  p_request_id uuid, p_status text, p_note text default null
) returns void language plpgsql security definer set search_path = public
as $$
declare v_admin uuid := auth.uid();
begin
  if v_admin is null or not public.is_platform_admin() then raise exception 'Administrator access required'; end if;
  if p_status not in ('approved','rejected','needs_resubmission') then raise exception 'Invalid verification status'; end if;
  update public.verification_requests set status=p_status, reviewer_id=v_admin,
    reviewer_note=left(coalesce(p_note,''),2000), reviewed_at=now()
    where id=p_request_id;
  if not found then raise exception 'Verification request not found'; end if;
  insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
  values(v_admin,'verification_reviewed','verification_request',p_request_id::text,jsonb_build_object('status',p_status));
end; $$;
revoke all on function public.admin_review_verification(uuid,text,text) from public;
grant execute on function public.admin_review_verification(uuid,text,text) to authenticated;

-- Aggregated operational views. These are intentionally counts/totals, not profile-level exports.
create or replace view public.admin_daily_signups with (security_invoker=true) as
select date_trunc('day', created_at)::date as signup_date, count(*)::bigint as registrations
from public.profiles group by 1;
create or replace view public.admin_subscription_summary with (security_invoker=true) as
select plan_code, status, count(*)::bigint as subscription_count
from public.subscriptions group by plan_code,status;
create or replace view public.admin_payment_summary with (security_invoker=true) as
select currency, status, count(*)::bigint as transaction_count,
       coalesce(sum(amount_minor),0)::numeric as amount_minor
from public.payment_intents group by currency,status;
revoke all on public.admin_daily_signups from anon, authenticated;
revoke all on public.admin_subscription_summary from anon, authenticated;
revoke all on public.admin_payment_summary from anon, authenticated;
grant select on public.admin_daily_signups, public.admin_subscription_summary, public.admin_payment_summary to authenticated;

-- Seed safe default settings. No payment or launch feature is enabled by this seed.
insert into public.platform_settings(setting_key,setting_value,description) values
 ('maintenance_mode','false'::jsonb,'When true, app clients should show maintenance messaging.'),
 ('new_market_registration','false'::jsonb,'New-country registrations remain disabled until local launch approval.'),
 ('minimum_member_age','18'::jsonb,'Minimum member age.'),
 ('support_contact','"support@amora.example"'::jsonb,'Replace with a monitored support address before launch.'),
 ('privacy_policy_version','"draft-1"'::jsonb,'Replace after Ghana legal review and publication.'),
 ('terms_version','"draft-1"'::jsonb,'Replace after Ghana legal review and publication.')
on conflict(setting_key) do nothing;

-- Explicitly limit default client access to platform settings; admin-only policies above apply.


-- Enforce suspension in discovery and chat membership. The profile status is authoritative.
create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.conversations c
    join public.matches m on m.id=c.match_id
    join public.profiles p1 on p1.id=m.user_one_id
    join public.profiles p2 on p2.id=m.user_two_id
    where c.id=p_conversation_id
      and auth.uid() in (m.user_one_id,m.user_two_id)
      and coalesce(p1.account_status,'active')='active'
      and coalesce(p2.account_status,'active')='active'
      and not exists (select 1 from public.blocks b
        where (b.blocker_id=m.user_one_id and b.blocked_id=m.user_two_id)
           or (b.blocker_id=m.user_two_id and b.blocked_id=m.user_one_id))
  );
$$;

-- Keep the Sprint 7 regional contract while excluding suspended / review / deletion accounts.
drop function if exists public.discover_profiles(integer);
create function public.discover_profiles(limit_count integer default 20)
returns table (
  id uuid, display_name text, city text, bio text, relationship_goal text,
  photo_url text, compatibility numeric, country_code text, country_name text
) language sql stable security definer set search_path = public
as $$
  with me as (
    select p.id,p.country_code,
      coalesce(r.cross_border_enabled,false) as cross_border_enabled,
      coalesce(r.preferred_country_codes,'{}'::text[]) as preferred_country_codes
    from public.profiles p
    left join public.member_regional_preferences r on r.user_id=p.id
    where p.id=auth.uid() and coalesce(p.account_status,'active')='active'
  )
  select p.id,p.display_name,p.city,p.bio,p.relationship_goal,p.photo_url,
    public.compatibility_score(p.id),p.country_code,
    coalesce(market.country_name,p.country_code)
  from public.profiles p cross join me
  left join public.member_preferences pref on pref.user_id=me.id
  left join public.member_regional_preferences candidate_region on candidate_region.user_id=p.id
  left join public.regional_market_config market on market.country_code=p.country_code
  where auth.uid() is not null and p.id<>auth.uid() and p.is_active=true
    and coalesce(p.account_status,'active')='active'
    and p.date_of_birth <= (current_date - interval '18 years')::date
    and (pref.user_id is null or extract(year from age(current_date,p.date_of_birth)) between pref.min_age and pref.max_age)
    and (pref.user_id is null or cardinality(pref.preferred_genders)=0 or p.gender=any(pref.preferred_genders))
    and (pref.user_id is null or cardinality(pref.preferred_goals)=0 or p.relationship_goal=any(pref.preferred_goals))
    and (p.country_code=me.country_code or (
      me.cross_border_enabled=true and coalesce(candidate_region.cross_border_enabled,false)=true
      and (cardinality(me.preferred_country_codes)=0 or p.country_code=any(me.preferred_country_codes))))
    and not exists (select 1 from public.blocks b where
      (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
    and not exists (select 1 from public.likes x where x.liker_id=auth.uid() and x.liked_id=p.id)
    and not exists (select 1 from public.profile_passes x where x.passer_id=auth.uid() and x.passed_id=p.id)
  order by public.compatibility_score(p.id) desc nulls last,p.created_at desc
  limit greatest(1,least(limit_count,50));
$$;
grant execute on function public.discover_profiles(integer) to authenticated;


-- Atomic Paystack entitlement activation. This serializes concurrent successful
-- payments per member and makes webhook retries idempotent.
create or replace function public.activate_subscription_for_payment(
  p_intent_id uuid,
  p_provider_transaction_id text,
  p_provider_payload jsonb default '{}'::jsonb
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_intent public.payment_intents%rowtype;
  v_now timestamptz := now();
  v_existing_end timestamptz;
  v_start timestamptz;
  v_end timestamptz;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'Service role required';
  end if;

  select * into v_intent from public.payment_intents
    where id = p_intent_id for update;
  if not found then raise exception 'Payment intent not found'; end if;
  if v_intent.status = 'success' then return 'already_processed'; end if;
  if v_intent.status not in ('initialized','pending') then
    raise exception 'Payment intent is not payable';
  end if;

  -- Lock the member row so two distinct purchases cannot calculate the same extension.
  perform 1 from public.profiles where id = v_intent.user_id for update;
  if not found then raise exception 'Member profile not found'; end if;

  select max(ends_at) into v_existing_end
    from public.subscriptions
    where user_id = v_intent.user_id and status = 'active' and ends_at > v_now;
  v_start := greatest(coalesce(v_existing_end, v_now), v_now);
  v_end := v_start + make_interval(days => greatest(1, least(coalesce(v_intent.plan_days,30),366)));

  insert into public.subscriptions(
    user_id, plan_code, status, starts_at, ends_at, payment_intent_id
  ) values (
    v_intent.user_id, v_intent.plan_code, 'active', v_start, v_end, v_intent.id
  ) on conflict (payment_intent_id) do nothing;

  update public.payment_intents set
    status = 'success',
    provider_transaction_id = p_provider_transaction_id,
    provider_payload = coalesce(p_provider_payload, '{}'::jsonb),
    updated_at = v_now
  where id = v_intent.id;
  return 'activated';
end;
$$;
revoke all on function public.activate_subscription_for_payment(uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.activate_subscription_for_payment(uuid,text,jsonb) to service_role;
