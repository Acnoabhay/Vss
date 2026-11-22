-- VSS Admin Panel + Member Dashboard foundation
-- Run once in Supabase Dashboard -> SQL Editor.
-- Keeps public member registration and ID + registered-email access unchanged.

create table if not exists public.vss_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  category text not null default 'General',
  is_published boolean not null default true,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vss_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  event_date timestamptz,
  venue text not null default '',
  registration_url text not null default '',
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.vss_announcements enable row level security;
alter table public.vss_events enable row level security;

drop policy if exists "VSS public can read published announcements" on public.vss_announcements;
create policy "VSS public can read published announcements"
on public.vss_announcements for select to anon, authenticated
using (is_published = true or lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');

drop policy if exists "VSS admin can manage announcements" on public.vss_announcements;
create policy "VSS admin can manage announcements"
on public.vss_announcements for all to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');

drop policy if exists "VSS public can read published events" on public.vss_events;
create policy "VSS public can read published events"
on public.vss_events for select to anon, authenticated
using (is_published = true or lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');

drop policy if exists "VSS admin can manage events" on public.vss_events;
create policy "VSS admin can manage events"
on public.vss_events for all to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');

-- Allow the existing VSS admin account to correct member details from the Admin Panel.
drop policy if exists "VSS admin can update members" on public.vss_id_cards;
create policy "VSS admin can update members"
on public.vss_id_cards for update to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');

grant select, insert, update, delete on public.vss_announcements to authenticated;
grant select, insert, update, delete on public.vss_events to authenticated;
grant select on public.vss_announcements, public.vss_events to anon;
grant update on public.vss_id_cards to authenticated;
