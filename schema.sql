-- MOONI store schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('customer','admin')),
  created_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 150),
  description text not null default '',
  price numeric(12,2) not null check (price >= 0),
  category text not null default 'ของใช้',
  emoji text not null default '✳',
  color text not null default '#e8ddd0',
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null check (char_length(customer_name) between 1 and 100),
  phone text not null check (char_length(phone) between 1 and 30),
  email text,
  address text not null check (char_length(address) between 1 and 1000),
  note text,
  items jsonb not null check (jsonb_typeof(items)='array'),
  total numeric(12,2) not null check (total >= 0),
  status text not null default 'pending_payment' check (status in ('pending_payment','paid','preparing','shipped','completed','cancelled')),
  created_at timestamptz not null default now()
);
create index if not exists products_active_created_idx on public.products(active,created_at desc);
create index if not exists orders_created_idx on public.orders(created_at desc);

-- Create a profile for every new auth user. New accounts are customers by default.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$ begin insert into public.profiles(id,role) values(new.id,'customer') on conflict(id) do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
revoke all on public.profiles from anon, authenticated;
revoke all on public.products from anon, authenticated;
revoke all on public.orders from anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant insert on public.orders to anon, authenticated;
grant select, update on public.orders to authenticated;
grant select on public.profiles to authenticated;

-- Admin role is stored in profiles and only changed by the project owner through SQL.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

drop policy if exists "Anyone can read active products" on public.products;
create policy "Anyone can read active products" on public.products for select to anon, authenticated using (active or public.is_admin());
drop policy if exists "Admins insert products" on public.products;
create policy "Admins insert products" on public.products for insert to authenticated with check (public.is_admin());
drop policy if exists "Admins update products" on public.products;
create policy "Admins update products" on public.products for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins delete products" on public.products;
create policy "Admins delete products" on public.products for delete to authenticated using (public.is_admin());

-- Public checkout can create orders only. Customer PII and order reads are never public.
drop policy if exists "Public can place orders" on public.orders;
create policy "Public can place orders" on public.orders for insert to anon, authenticated with check (
  char_length(customer_name) between 1 and 100 and char_length(phone) between 1 and 30
  and char_length(address) between 1 and 1000 and total >= 0 and status='pending_payment'
);
drop policy if exists "Admins read orders" on public.orders;
create policy "Admins read orders" on public.orders for select to authenticated using (public.is_admin());
drop policy if exists "Admins update orders" on public.orders;
create policy "Admins update orders" on public.orders for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile" on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());

-- IMPORTANT: after creating the owner account in Authentication > Users, run this
-- separately with that account's UUID to grant admin privileges:
-- update public.profiles set role='admin' where id='PASTE-AUTH-USER-UUID-HERE';
