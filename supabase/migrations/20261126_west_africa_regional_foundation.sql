-- AMORA West Africa regional foundation.
-- Apply after the existing Sprint 1 base schema. This migration assumes profiles.id = auth.users.id.
alter table public.profiles
  add column if not exists country_code text not null default 'GH';

alter table public.profiles drop constraint if exists profiles_country_code_iso2_check;
alter table public.profiles
  add constraint profiles_country_code_iso2_check
  check (country_code ~ '^[A-Z]{2}$');

create table if not exists public.regional_market_config (
  country_code text primary key check (country_code ~ '^[A-Z]{2}$'),
  country_name text not null,
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  launch_status text not null default 'planned'
    check (launch_status in ('pilot','planned','enabled','paused')),
  payment_provider text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.regional_market_config(country_code,country_name,currency_code,launch_status)
values
 ('GH','Ghana','GHS','pilot'),
 ('NG','Nigeria','NGN','planned'),
 ('CI','Côte d’Ivoire','XOF','planned'),
 ('SN','Senegal','XOF','planned'),
 ('BJ','Benin','XOF','planned'),
 ('TG','Togo','XOF','planned'),
 ('BF','Burkina Faso','XOF','planned'),
 ('ML','Mali','XOF','planned'),
 ('NE','Niger','XOF','planned'),
 ('GN','Guinea','GNF','planned'),
 ('GW','Guinea-Bissau','XOF','planned'),
 ('LR','Liberia','LRD','planned'),
 ('SL','Sierra Leone','SLE','planned'),
 ('GM','The Gambia','GMD','planned'),
 ('CV','Cabo Verde','CVE','planned'),
 ('MR','Mauritania','MRU','planned')
on conflict (country_code) do update set
  country_name = excluded.country_name,
  currency_code = excluded.currency_code,
  updated_at = now();

create table if not exists public.member_regional_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  cross_border_enabled boolean not null default false,
  preferred_country_codes text[] not null default '{}',
  updated_at timestamptz not null default now(),
  constraint preferred_country_codes_valid check (
    array_position(preferred_country_codes, null) is null
  )
);

alter table public.member_regional_preferences enable row level security;

drop policy if exists "Members read own regional preferences" on public.member_regional_preferences;
create policy "Members read own regional preferences"
  on public.member_regional_preferences for select
  using (auth.uid() = user_id);

drop policy if exists "Members insert own regional preferences" on public.member_regional_preferences;
create policy "Members insert own regional preferences"
  on public.member_regional_preferences for insert
  with check (auth.uid() = user_id);

drop policy if exists "Members update own regional preferences" on public.member_regional_preferences;
create policy "Members update own regional preferences"
  on public.member_regional_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

alter table public.regional_market_config enable row level security;
drop policy if exists "Authenticated users read market configuration" on public.regional_market_config;
create policy "Authenticated users read market configuration"
  on public.regional_market_config for select
  to authenticated using (true);

create index if not exists profiles_country_code_idx on public.profiles(country_code);


-- Prevent members from self-selecting a market before local launch approval.
create or replace function public.guard_profile_market()
returns trigger language plpgsql security definer set search_path = public
as $$
declare v_status text;
begin
  if new.country_code is distinct from old.country_code then
    select launch_status into v_status from public.regional_market_config
      where country_code = new.country_code;
    if v_status is null or v_status not in ('pilot','enabled') then
      raise exception 'This AMORA market is not open for registration';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_guard_market on public.profiles;
create trigger profiles_guard_market before update of country_code on public.profiles
for each row execute function public.guard_profile_market();
