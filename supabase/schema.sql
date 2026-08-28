-- وصلة: production schema (Supabase/Postgres)
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  role text not null check (role in ('customer','cook','supplier','driver','admin')) default 'customer',
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id),
  name text not null,
  description text,
  retail_price integer not null check (retail_price >= 0),
  wholesale_price integer not null check (wholesale_price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  customer_id uuid not null references public.profiles(id),
  driver_id uuid references public.profiles(id),
  status text not null check (status in ('pending','accepted','preparing','picked_up','delivered','cancelled')) default 'pending',
  food_total integer not null default 0,
  delivery_fee integer not null default 200,
  total integer generated always as (food_total + delivery_fee) stored,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  retail_unit_price integer not null,
  wholesale_unit_price integer not null
);

create table if not exists public.wallet_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  order_id uuid references public.orders(id),
  entry_type text not null check (entry_type in ('sale','commission','delivery_fee','settlement_hold','settlement_paid','adjustment')),
  amount integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.settlements (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  amount integer not null check (amount > 0),
  status text not null check (status in ('requested','held','paid','rejected')) default 'requested',
  requested_at timestamptz not null default now(),
  paid_at timestamptz
);

-- Prevents a double withdrawal: hold is created in the same transaction as request.
create or replace function public.request_settlement(p_amount integer)
returns public.settlements
language plpgsql security definer as $$
declare result public.settlements;
begin
  if p_amount <= 0 then raise exception 'amount must be positive'; end if;
  insert into public.settlements(owner_id, amount, status)
  values (auth.uid(), p_amount, 'held') returning * into result;
  insert into public.wallet_entries(owner_id, entry_type, amount, metadata)
  values (auth.uid(), 'settlement_hold', -p_amount, jsonb_build_object('settlement_id', result.id));
  return result;
end;
$$;
