-- AMORA core schema. Must run before 20261124_sprint2.sql.
-- This file deliberately does not create matches/messages: Sprint 4 owns their schema.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  date_of_birth date not null,
  gender text not null default 'Prefer to discuss',
  city text,
  bio text not null default '' check (char_length(bio) <= 300),
  relationship_goal text,
  photo_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_adult_only check (date_of_birth <= (current_date - interval '18 years')::date)
);

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  liker_id uuid not null references public.profiles(id) on delete cascade,
  liked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint likes_pair_unique unique(liker_id, liked_id),
  check (liker_id <> liked_id)
);
create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint blocks_pair_unique unique(blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  details text,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);

-- Create a profile at sign-up. Age and required fields are validated server-side,
-- not trusted solely to the Flutter form. The auth trigger also handles email-confirmation flows.
create or replace function public.handle_new_amora_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare v_dob date; v_name text;
begin
  begin
    v_dob := (new.raw_user_meta_data ->> 'date_of_birth')::date;
  exception when others then
    raise exception 'A valid date of birth is required';
  end;
  v_name := trim(coalesce(new.raw_user_meta_data ->> 'display_name',''));
  if v_dob is null or v_dob > (current_date - interval '18 years')::date then
    raise exception 'AMORA is available only to adults aged 18 and above';
  end if;
  if char_length(v_name) < 1 or char_length(v_name) > 60 then
    raise exception 'Display name must contain 1 to 60 characters';
  end if;
  insert into public.profiles(id, display_name, date_of_birth, gender)
  values(new.id, v_name, v_dob, coalesce(nullif(new.raw_user_meta_data ->> 'gender',''),'Prefer to discuss'))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_amora_profile on auth.users;
create trigger on_auth_user_created_amora_profile
  after insert on auth.users for each row execute function public.handle_new_amora_user();

alter table public.profiles enable row level security;
alter table public.likes enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

drop policy if exists "active profiles visible to authenticated users" on public.profiles;
create policy "active profiles visible to authenticated users" on public.profiles
  for select to authenticated using (is_active = true or id = auth.uid());
drop policy if exists "members insert own profile" on public.profiles;
create policy "members insert own profile" on public.profiles
  for insert to authenticated with check (id = auth.uid());
drop policy if exists "members update own profile" on public.profiles;
create policy "members update own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "members see likes they sent or received" on public.likes;
create policy "members see likes they sent or received" on public.likes
  for select to authenticated using (liker_id = auth.uid() or liked_id = auth.uid());
drop policy if exists "members send likes as themselves" on public.likes;
create policy "members send likes as themselves" on public.likes
  for insert to authenticated with check (liker_id = auth.uid() and liker_id <> liked_id);

drop policy if exists "members manage blocks they create" on public.blocks;
create policy "members manage blocks they create" on public.blocks
  for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid() and blocker_id <> blocked_id);
drop policy if exists "members create reports" on public.reports;
create policy "members create reports" on public.reports
  for insert to authenticated with check (reporter_id = auth.uid() and reporter_id <> reported_id);
drop policy if exists "members view their own reports" on public.reports;
create policy "members view their own reports" on public.reports
  for select to authenticated using (reporter_id = auth.uid());

create index if not exists profiles_active_created_idx on public.profiles(is_active, created_at desc);
create index if not exists likes_liked_id_idx on public.likes(liked_id);
create index if not exists blocks_blocked_id_idx on public.blocks(blocked_id);
