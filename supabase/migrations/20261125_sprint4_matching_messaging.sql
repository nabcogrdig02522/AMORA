-- AMORA Sprint 4: mutual matches, conversations, messages and passes.
-- Apply only after the Sprint 1 schema and Sprint 2 migration.
-- Assumes public.profiles(id), public.likes(liker_id, liked_id), and public.blocks(blocker_id, blocked_id).

create unique index if not exists likes_liker_liked_unique
  on public.likes(liker_id, liked_id);

create table if not exists public.profile_passes (
  passer_id uuid not null references public.profiles(id) on delete cascade,
  passed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (passer_id, passed_id),
  check (passer_id <> passed_id)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  user_one_id uuid not null references public.profiles(id) on delete cascade,
  user_two_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_one_id, user_two_id),
  check (user_one_id < user_two_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists messages_conversation_created_idx
  on public.messages(conversation_id, created_at desc);
create index if not exists conversations_last_message_idx
  on public.conversations(last_message_at desc nulls last);

-- Match is created only when the other member has already liked the current member.
create or replace function public.create_mutual_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_one uuid;
  v_two uuid;
begin
  if new.liker_id = new.liked_id then
    return new;
  end if;

  if exists (
    select 1 from public.likes reciprocal
    where reciprocal.liker_id = new.liked_id
      and reciprocal.liked_id = new.liker_id
  ) then
    v_one := least(new.liker_id, new.liked_id);
    v_two := greatest(new.liker_id, new.liked_id);

    insert into public.matches(user_one_id, user_two_id)
    values (v_one, v_two)
    on conflict (user_one_id, user_two_id) do nothing
    returning id into v_match_id;

    if v_match_id is null then
      select id into v_match_id from public.matches
      where user_one_id = v_one and user_two_id = v_two;
    end if;

    insert into public.conversations(match_id)
    values (v_match_id)
    on conflict (match_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists likes_create_mutual_match on public.likes;
create trigger likes_create_mutual_match
after insert on public.likes
for each row execute function public.create_mutual_match();

create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    join public.matches m on m.id = c.match_id
    where c.id = p_conversation_id
      and auth.uid() in (m.user_one_id, m.user_two_id)
  );
$$;

alter table public.profile_passes enable row level security;
alter table public.matches enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "members create own likes" on public.likes;
create policy "members create own likes" on public.likes
  for insert to authenticated with check (liker_id = auth.uid() and liker_id <> liked_id);
drop policy if exists "members read own likes" on public.likes;
create policy "members read own likes" on public.likes
  for select to authenticated using (liker_id = auth.uid() or liked_id = auth.uid());

drop policy if exists "members manage own passes" on public.profile_passes;
create policy "members manage own passes" on public.profile_passes
  for all to authenticated
  using (passer_id = auth.uid())
  with check (passer_id = auth.uid() and passer_id <> passed_id);

drop policy if exists "members read own matches" on public.matches;
create policy "members read own matches" on public.matches
  for select to authenticated
  using (auth.uid() in (user_one_id, user_two_id));

drop policy if exists "members read own conversations" on public.conversations;
create policy "members read own conversations" on public.conversations
  for select to authenticated
  using (public.is_conversation_member(id));

drop policy if exists "members read messages in own conversations" on public.messages;
create policy "members read messages in own conversations" on public.messages
  for select to authenticated
  using (public.is_conversation_member(conversation_id));

drop policy if exists "members send messages in own conversations" on public.messages;
create policy "members send messages in own conversations" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_member(conversation_id)
  );

drop policy if exists "members mark received messages read" on public.messages;
create policy "members mark received messages read" on public.messages
  for update to authenticated
  using (
    public.is_conversation_member(conversation_id)
    and sender_id <> auth.uid()
  )
  with check (
    public.is_conversation_member(conversation_id)
    and sender_id <> auth.uid()
  );

-- Extend discovery to omit passed profiles as well as already-liked profiles.
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
    and not exists (select 1 from public.profile_passes x where x.passer_id = auth.uid() and x.passed_id = p.id)
  order by public.compatibility_score(p.id) desc nulls last, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;
