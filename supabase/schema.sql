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

-- Row-level security for the production API.
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.wallet_entries enable row level security;
alter table public.settlements enable row level security;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
create or replace function public.is_driver() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'driver');
$$;

create policy "profiles_self_or_admin" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles_update_self" on public.profiles for update using (id = auth.uid());
create policy "products_public_read" on public.products for select using (active = true or owner_id = auth.uid() or public.is_admin());
create policy "products_owner_write" on public.products for all using (owner_id = auth.uid() or public.is_admin()) with check (owner_id = auth.uid() or public.is_admin());
create policy "orders_participants_read" on public.orders for select using (customer_id = auth.uid() or driver_id = auth.uid() or (driver_id is null and public.is_driver()) or public.is_admin());
create policy "orders_customer_insert" on public.orders for insert with check (customer_id = auth.uid());
create policy "orders_driver_update" on public.orders for update using (driver_id = auth.uid() or (driver_id is null and public.is_driver() and status = 'draft') or public.is_admin()) with check (driver_id = auth.uid() or public.is_admin());
create policy "items_participants_read" on public.order_items for select using (exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or o.driver_id = auth.uid() or public.is_admin())));
create policy "items_customer_insert" on public.order_items for insert with check (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid()));
create policy "wallet_owner_read" on public.wallet_entries for select using (owner_id = auth.uid() or public.is_admin());
create policy "settlement_owner_read" on public.settlements for select using (owner_id = auth.uid() or public.is_admin());

create unique index if not exists wallet_entries_once on public.wallet_entries(order_id, owner_id, entry_type);

create or replace function public.credit_order_wallets() returns trigger language plpgsql security definer set search_path = public as $$
declare admin_id uuid;
begin
  if new.status = 'delivered' and old.status <> 'delivered' then
    select id into admin_id from public.profiles where role = 'admin' limit 1;
    insert into public.wallet_entries(owner_id, order_id, entry_type, amount, metadata)
      select p.owner_id, new.id, 'sale', round(sum(oi.retail_unit_price * oi.quantity) * .8), jsonb_build_object('share', .8)
      from public.order_items oi join public.products p on p.id = oi.product_id
      where oi.order_id = new.id and p.owner_id is not null group by p.owner_id
      on conflict (order_id, owner_id, entry_type) do nothing;
    if admin_id is not null then
      insert into public.wallet_entries(owner_id, order_id, entry_type, amount, metadata)
        values (admin_id, new.id, 'commission', round(new.food_total * .2), jsonb_build_object('share', .2))
        on conflict (order_id, owner_id, entry_type) do nothing;
    end if;
    if new.driver_id is not null then
      insert into public.wallet_entries(owner_id, order_id, entry_type, amount)
        values (new.driver_id, new.id, 'delivery_fee', new.delivery_fee)
        on conflict (order_id, owner_id, entry_type) do nothing;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_credit_order_wallets on public.orders;
create trigger trg_credit_order_wallets after update of status on public.orders for each row execute function public.credit_order_wallets();
