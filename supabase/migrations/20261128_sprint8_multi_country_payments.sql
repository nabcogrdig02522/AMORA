-- AMORA Sprint 8: market-aware plans, prices and payment intents.
-- Ghana is the only enabled market in this release. Other markets remain disabled
-- until provider onboarding, local pricing, settlement and legal review are complete.

alter table public.payment_intents
  add column if not exists country_code text not null default 'GH';

alter table public.payment_intents
  add column if not exists market_currency text;

alter table public.payment_intents
  add column if not exists plan_days integer not null default 30;

alter table public.payment_intents
  add column if not exists provider_transaction_id text;

alter table public.payment_intents
  alter column currency drop default;

alter table public.payment_intents
  drop constraint if exists payment_intents_currency_check;

alter table public.payment_intents
  add constraint payment_intents_currency_iso_check
  check (currency ~ '^[A-Z]{3}$');

alter table public.payment_intents
  drop constraint if exists payment_intents_amount_minor_check;

alter table public.payment_intents
  add constraint payment_intents_amount_minor_positive_check
  check (amount_minor > 0);

create table if not exists public.market_plan_prices (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.regional_market_config(country_code),
  plan_code text not null check (plan_code in ('plus','premium','elite')),
  amount_minor integer not null check (amount_minor > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  billing_days integer not null default 30 check (billing_days between 1 and 366),
  provider_code text not null,
  enabled boolean not null default false,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  unique(country_code, plan_code, effective_from)
);

create index if not exists market_plan_prices_active_idx
  on public.market_plan_prices(country_code, plan_code, enabled, effective_from desc);

alter table public.market_plan_prices enable row level security;
drop policy if exists "Authenticated members read enabled market prices" on public.market_plan_prices;
create policy "Authenticated members read enabled market prices"
  on public.market_plan_prices for select to authenticated
  using (enabled = true and (effective_to is null or effective_to > now()));

-- Illustrative Ghana prices retained from the earlier build; founder must approve before live sales.
insert into public.market_plan_prices
(country_code,plan_code,amount_minor,currency_code,billing_days,provider_code,enabled)
values
 ('GH','plus',3500,'GHS',30,'paystack',true),
 ('GH','premium',6500,'GHS',30,'paystack',true),
 ('GH','elite',12000,'GHS',30,'paystack',true)
on conflict (country_code,plan_code,effective_from) do nothing;

-- No prices are inserted or enabled for other markets until locally approved.
