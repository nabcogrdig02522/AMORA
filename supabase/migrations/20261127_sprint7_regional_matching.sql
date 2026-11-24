-- AMORA Sprint 7: enforce mutual cross-border discovery consent.
-- Apply after 20261126_west_africa_regional_foundation.sql.
-- Same-country discovery remains available without cross-border opt-in.
-- Cross-border profiles appear only when BOTH members have opted in.

drop function if exists public.discover_profiles(integer);

create function public.discover_profiles(limit_count integer default 20)
returns table (
  id uuid,
  display_name text,
  city text,
  bio text,
  relationship_goal text,
  photo_url text,
  compatibility numeric,
  country_code text,
  country_name text
)
language sql
stable
security invoker
set search_path = public
as $$
  with me as (
    select p.id, p.country_code,
      coalesce(r.cross_border_enabled, false) as cross_border_enabled,
      coalesce(r.preferred_country_codes, '{}'::text[]) as preferred_country_codes
    from public.profiles p
    left join public.member_regional_preferences r on r.user_id = p.id
    where p.id = auth.uid()
  )
  select
    p.id, p.display_name, p.city, p.bio, p.relationship_goal, p.photo_url,
    public.compatibility_score(p.id),
    p.country_code,
    coalesce(market.country_name, p.country_code)
  from public.profiles p
  cross join me
  left join public.member_regional_preferences candidate_region on candidate_region.user_id = p.id
  left join public.regional_market_config market on market.country_code = p.country_code
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.is_active = true
    and (
      p.country_code = me.country_code
      or (
        me.cross_border_enabled = true
        and coalesce(candidate_region.cross_border_enabled, false) = true
        and (
          cardinality(me.preferred_country_codes) = 0
          or p.country_code = any(me.preferred_country_codes)
        )
      )
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
    and not exists (
      select 1 from public.likes x
      where x.liker_id = auth.uid() and x.liked_id = p.id
    )
    and not exists (
      select 1 from public.profile_passes x
      where x.passer_id = auth.uid() and x.passed_id = p.id
    )
  order by public.compatibility_score(p.id) desc nulls last, p.created_at desc
  limit greatest(1, least(limit_count, 50));
$$;

grant execute on function public.discover_profiles(integer) to authenticated;
