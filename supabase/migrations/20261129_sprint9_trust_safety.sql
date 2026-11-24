-- AMORA Sprint 9: trust, safety, privacy and verification workflow.
-- Apply after Sprint 2 and Sprint 4 migrations. Review in staging first.

create table if not exists public.member_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('fake_profile','harassment','scam_or_spam','underage_safety','inappropriate_content','other')),
  description text check (description is null or char_length(description) <= 2000),
  status text not null default 'open' check (status in ('open','reviewing','actioned','dismissed')),
  moderator_id uuid references auth.users(id),
  moderator_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  check (reporter_id <> reported_user_id)
);
create index if not exists member_reports_queue_idx on public.member_reports(status, created_at desc);
create index if not exists member_reports_target_idx on public.member_reports(reported_user_id, created_at desc);
alter table public.member_reports enable row level security;
drop policy if exists "members submit own reports" on public.member_reports;
create policy "members submit own reports" on public.member_reports
  for insert to authenticated with check (reporter_id = auth.uid() and reporter_id <> reported_user_id and status = 'open' and moderator_id is null);
drop policy if exists "members read own submitted reports" on public.member_reports;
create policy "members read own submitted reports" on public.member_reports
  for select to authenticated using (reporter_id = auth.uid());
drop policy if exists "admins manage member reports" on public.member_reports;
create policy "admins manage member reports" on public.member_reports
  for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Request-only deletion workflow. A trusted operator must verify identity and process
-- deletion through the Supabase Admin API; never expose service-role credentials in the app.
create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text check (reason is null or char_length(reason) <= 1000),
  status text not null default 'requested' check (status in ('requested','reviewing','completed','cancelled')),
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references auth.users(id)
);
create unique index if not exists one_open_deletion_request_per_member
  on public.account_deletion_requests(user_id) where status in ('requested','reviewing');
alter table public.account_deletion_requests enable row level security;
drop policy if exists "members create deletion request" on public.account_deletion_requests;
create policy "members create deletion request" on public.account_deletion_requests
  for insert to authenticated with check (user_id = auth.uid() and status = 'requested' and processed_by is null);
drop policy if exists "members read own deletion requests" on public.account_deletion_requests;
create policy "members read own deletion requests" on public.account_deletion_requests
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "admins manage deletion requests" on public.account_deletion_requests;
create policy "admins manage deletion requests" on public.account_deletion_requests
  for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());


-- Restrict client verification inserts to a selfie object under the member's own folder.
drop policy if exists "member creates own verification request" on public.verification_requests;
create policy "member creates own verification request" on public.verification_requests
for insert to authenticated with check (
  user_id = auth.uid()
  and verification_type = 'selfie'
  and status = 'pending'
  and reviewer_id is null
  and private_object_path is not null
  and split_part(private_object_path, '/', 1) = auth.uid()::text
);

-- Clients can submit and inspect only the fields required for the workflow.
-- Moderator identity and decision fields are written only through trusted admin RPCs.
revoke all on table public.verification_requests from anon, authenticated;
grant select (id, user_id, verification_type, status, private_object_path,
  reviewer_note, created_at, reviewed_at)
  on table public.verification_requests to authenticated;
grant insert (user_id, verification_type, status, private_object_path, consented_at)
  on table public.verification_requests to authenticated;

-- Private evidence bucket. The app uploads only into its own auth.uid() folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('amora-verification', 'amora-verification', false, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];
drop policy if exists "member uploads own verification image" on storage.objects;
create policy "member uploads own verification image" on storage.objects
  for insert to authenticated with check (bucket_id = 'amora-verification' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "member reads own verification image" on storage.objects;
create policy "member reads own verification image" on storage.objects
  for select to authenticated using (bucket_id = 'amora-verification' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "member deletes own verification image" on storage.objects;
create policy "member deletes own verification image" on storage.objects
  for delete to authenticated using (bucket_id = 'amora-verification' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "admins read verification images" on storage.objects;
create policy "admins read verification images" on storage.objects
  for select to authenticated using (bucket_id = 'amora-verification' and public.is_platform_admin());

-- Blocking is deliberately irreversible from the client through this RPC: it removes
-- likes in both directions and any match (conversation cascades). Users can unblock
-- only through a separately designed, audited workflow if product policy permits.
create or replace function public.block_member(p_target_user_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  if p_target_user_id is null or p_target_user_id = v_me then raise exception 'Invalid member'; end if;
  if not exists (select 1 from public.profiles where id = p_target_user_id) then raise exception 'Member not found'; end if;
  insert into public.blocks(blocker_id, blocked_id) values (v_me, p_target_user_id) on conflict do nothing;
  delete from public.likes where (liker_id = v_me and liked_id = p_target_user_id)
    or (liker_id = p_target_user_id and liked_id = v_me);
  delete from public.matches where (user_one_id = least(v_me, p_target_user_id) and user_two_id = greatest(v_me, p_target_user_id));
end; $$;
revoke all on function public.block_member(uuid) from public;
grant execute on function public.block_member(uuid) to authenticated;

-- Admins can update verification requests and reports; record review actions in audit log.
-- Existing Sprint 2 policies already grant admins management of verification_requests.


-- Blocking is intentionally not client-deletable in this release. A future unblock
-- workflow must be explicit and audited rather than using direct table deletion.
drop policy if exists "members manage blocks they create" on public.blocks;
drop policy if exists "members read blocks they created" on public.blocks;
drop policy if exists "members insert blocks as themselves" on public.blocks;
create policy "members read blocks they created" on public.blocks
  for select to authenticated using (blocker_id = auth.uid());
create policy "members insert blocks as themselves" on public.blocks
  for insert to authenticated with check (blocker_id = auth.uid() and blocker_id <> blocked_id);
