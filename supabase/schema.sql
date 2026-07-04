-- ============================================================================
-- SKIN-PROFILE — Supabase schema
-- Run this whole file once in: Supabase Dashboard → SQL Editor → New query
-- Replaces the old Firebase Realtime Database + Storage setup.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------------

-- Coin wallet, keyed by the app's own device UID (localStorage "skin_profile_uid")
create table if not exists public.users (
  uid         text primary key,
  coins       bigint not null default 60,
  email_bonus boolean not null default false,
  updated_at  timestamptz not null default now()
);

-- Global chat (text + voice messages)
create table if not exists public.chat_messages (
  id          bigint generated always as identity primary key,
  type        text not null default 'text',        -- 'text' | 'voice'
  sender_uid  text not null,
  sender_name text not null,
  avatar      text,
  message     text,
  audio_url   text,
  created_at  timestamptz not null default now()
);

-- Marketplace listings
create table if not exists public.marketplace_items (
  id              bigint generated always as identity primary key,
  seller_uid      text not null,
  seller_name     text not null,
  seller_avatar   text,
  item_name       text not null,
  desc            text,
  price           integer not null check (price > 0),
  screenshot      text,
  preview_images  jsonb,
  full_state      jsonb,
  is_storage_file boolean not null default false,
  file_name       text,
  file_ext        text,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. ROW LEVEL SECURITY
--    Mirrors the original Firebase "test mode" rules (public read/write, no
--    auth). Tighten these later if you add real user accounts.
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.chat_messages enable row level security;
alter table public.marketplace_items enable row level security;

drop policy if exists "public read users" on public.users;
create policy "public read users" on public.users for select using (true);
drop policy if exists "public insert users" on public.users;
create policy "public insert users" on public.users for insert with check (true);
drop policy if exists "public update users" on public.users;
create policy "public update users" on public.users for update using (true) with check (true);

drop policy if exists "public read chat" on public.chat_messages;
create policy "public read chat" on public.chat_messages for select using (true);
drop policy if exists "public insert chat" on public.chat_messages;
create policy "public insert chat" on public.chat_messages for insert with check (true);
drop policy if exists "public delete chat" on public.chat_messages;
create policy "public delete chat" on public.chat_messages for delete using (true);

drop policy if exists "public read market" on public.marketplace_items;
create policy "public read market" on public.marketplace_items for select using (true);
drop policy if exists "public insert market" on public.marketplace_items;
create policy "public insert market" on public.marketplace_items for insert with check (true);
drop policy if exists "public update market" on public.marketplace_items;
create policy "public update market" on public.marketplace_items for update using (true) with check (true);
drop policy if exists "public delete market" on public.marketplace_items;
create policy "public delete market" on public.marketplace_items for delete using (true);

-- ---------------------------------------------------------------------------
-- 3. REALTIME
--    Enables live INSERT/UPDATE/DELETE events for chat + marketplace + coins.
--    (Voice-room signaling/presence use Realtime Broadcast & Presence, which
--    don't need a table or this publication.)
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.marketplace_items;
alter publication supabase_realtime add table public.users;

-- ---------------------------------------------------------------------------
-- 4. FUNCTIONS
--    security definer functions give us atomic, race-free coin updates —
--    the equivalent of Firebase RTDB's ref().transaction().
-- ---------------------------------------------------------------------------

-- Directly set a user's coin balance (used for the admin/bonus coin grants)
create or replace function public.set_user_coins(p_uid text, p_coins bigint)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.users (uid, coins) values (p_uid, p_coins)
  on conflict (uid) do update set coins = excluded.coins, updated_at = now();
$$;

-- Atomic marketplace purchase: deducts the buyer, credits the seller,
-- and removes the listing — all inside a single Postgres transaction so it
-- can never leave coins double-spent or a listing "sold" to two buyers.
create or replace function public.purchase_marketplace_item(p_item_id bigint, p_buyer_uid text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item  public.marketplace_items%rowtype;
  v_coins bigint;
begin
  select * into v_item from public.marketplace_items where id = p_item_id for update;
  if not found then
    raise exception 'ITEM_NOT_FOUND';
  end if;

  if v_item.seller_uid = p_buyer_uid then
    raise exception 'CANNOT_BUY_OWN_ITEM';
  end if;

  insert into public.users (uid, coins) values (p_buyer_uid, 60)
    on conflict (uid) do nothing;

  select coins into v_coins from public.users where uid = p_buyer_uid for update;
  if v_coins < v_item.price then
    raise exception 'INSUFFICIENT_COINS';
  end if;

  update public.users set coins = coins - v_item.price, updated_at = now()
    where uid = p_buyer_uid;

  insert into public.users (uid, coins) values (v_item.seller_uid, 60 + v_item.price)
    on conflict (uid) do update
      set coins = public.users.coins + v_item.price, updated_at = now();

  delete from public.marketplace_items where id = p_item_id;

  return jsonb_build_object(
    'item', to_jsonb(v_item),
    'buyer_coins', v_coins - v_item.price
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. STORAGE (voice messages)
--    Equivalent of the old Firebase Storage "voice/" folder + open rules.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
  values ('voice', 'voice', true)
  on conflict (id) do nothing;

drop policy if exists "public read voice" on storage.objects;
create policy "public read voice" on storage.objects
  for select using (bucket_id = 'voice');

drop policy if exists "public upload voice" on storage.objects;
create policy "public upload voice" on storage.objects
  for insert with check (bucket_id = 'voice');

-- ============================================================================
-- Done. Voice chat WebRTC signaling and the participant list use Supabase
-- Realtime's Broadcast + Presence features directly over a per-room channel
-- (`voice-room-<roomId>`) — no table needed for those.
-- ============================================================================
